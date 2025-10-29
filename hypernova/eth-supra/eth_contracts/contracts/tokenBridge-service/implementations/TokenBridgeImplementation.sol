// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/tokenBridge-service/implementations/Helpers.sol";
import "contracts/interfaces/ITokenBridgeService.sol";
import "contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract TokenBridgeImplementation is Initializable, Helpers {
    using SafeERC20 for IERC20;
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _hypernova,
        address _admin,
        address _feeOperator,
        address _vaultAddr,
        address _nativeToken
    ) public initializer {
        _setFeeOperator(_feeOperator);
        _setAdmin(_admin);
        _setNativeToken(_nativeToken);
        _setVault(_vaultAddr);
        _setHypernova(_hypernova);
    }

    function setAdmin(address _admin) external onlyAdmin {
        _setAdmin(_admin);
        emit ITokenBridgeService.UpdatedAdmin(msg.sender, _admin);
    }
    function setHypernova(address _hypernova) external onlyAdmin {
        _setHypernova(_hypernova);
        emit ITokenBridgeService.UpdatedHypernova(msg.sender, _hypernova);
    }

    function setFeeOperator(address _feeOperator) external onlyAdmin {
        _setFeeOperator(_feeOperator);
        emit ITokenBridgeService.UpdatedFeeOperator(msg.sender, _feeOperator);
    }

    function setVault(address _vault) external onlyAdmin {
        _setVault(_vault);
        emit ITokenBridgeService.UpdatedVault(msg.sender, _vault);
    }

    function setNativeToken(address _nativeToken) external onlyAdmin {
        _setNativeToken(_nativeToken);
        emit ITokenBridgeService.UpdatedNativeToken(msg.sender, _nativeToken);
    }

    function registerFixedFeeToken(uint64 _toChainId, address tokenAddr, uint64 _fixedServiceFee, uint64 _fixedRelayerReward, bool _register) external onlyAdmin {
        _registerTokenImpl(_toChainId, tokenAddr, address(0), true, _fixedServiceFee, _fixedRelayerReward, _register);
    }

    function registerToken(uint64 _toChainId, address tokenAddr, address _uniswapPool, bool _register) external onlyAdmin {
        _registerTokenImpl(_toChainId, tokenAddr, _uniswapPool, false, 0, 0, _register);
    }

    function registerChainId(uint64 _toChainId, bool _registered) external onlyAdmin {
        if (checkZeroValue(_toChainId)) revert InvalidInput();
        bool registered = supportedChains[_toChainId];
        if (registered && _registered) revert ChainIdAlreadyRegistered();
        if (!registered && !_registered) revert ChainIdNotRegistered();
        supportedChains[_toChainId] = _registered;
        emit ITokenBridgeService.ToChainRegistered(msg.sender, _toChainId, _registered);
    }


    function sendTokens(
        address tokenAddr,
        uint256 amount,
        bytes32 receiverAddr,
        bytes32 payload,
        uint64 toChainId
    ) external isNotPaused {
        if (
            checkZeroAddr(tokenAddr) ||
            checkZeroBytes32(receiverAddr) ||
            checkZeroValue(amount) ||
            checkZeroValue(toChainId)
        ) {
            revert InvalidInput();
        }
        if (!isToChainIdRegistered(toChainId)) {
            revert ChainIdNotRegistered();
        }
        ITokenBridgeService.TokenInfo memory tokenInfo = getRegisteredTokenInfo(toChainId, tokenAddr);
        if (!tokenInfo.isRegistered) {
            revert TokenNotRegistered();
        }

        // Enough Fee check is done in FeeOperator
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = computeFeeDetails(toChainId, amount, tokenInfo);
        _updateBridgedAmountPerToken(toChainId, tokenAddr, finalAmount);

        // Not using dust from as user approved allownaces
        IERC20(tokenAddr).safeTransferFrom(msg.sender, vault, amount - dust);
        getVault().lockTokens(tokenAddr, amount - dust);

        ITokenBridgeService.MessageData memory _messageData = ITokenBridgeService.MessageData({
            senderAddr: bytes32(uint256(uint160(msg.sender))),
            tokenAddress: bytes32(uint256(uint160(tokenAddr))),
            sourceChainId: uint64(block.chainid),
            payload: payload,
            finalAmount: finalAmount,
            feeCutToService: feeCutToService,
            relayerReward: relayerReward,
            receiverAddr: receiverAddr
        });

        bytes memory messageData = abi.encode(_messageData);
        getHypernova().postMessage(messageData, toChainId);
    }

    function sendNative(
        bytes32 receiverAddr,
        uint256 amount,
        bytes32 payload,
        uint64 toChainId
    ) external payable isNotPaused {
        uint256 msgValue = msg.value;
        address _nativeToken = nativeToken;
        if (checkZeroBytes32(receiverAddr) || 
            checkZeroValue(toChainId) || 
            checkZeroValue(amount)) 
        revert InvalidInput();

        if (msgValue != amount) revert IncorrectAmount();

        if (!isToChainIdRegistered(toChainId)) {
            revert ChainIdNotRegistered();
        }

        ITokenBridgeService.TokenInfo memory tokenInfo = getRegisteredTokenInfo(toChainId, _nativeToken);
        if (!tokenInfo.isRegistered) {
            revert TokenNotRegistered();
        }

        // Enough Fee and Amount check is done in FeeOperator
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = computeFeeDetails(toChainId, msgValue, tokenInfo);

        _updateBridgedAmountPerToken(toChainId, _nativeToken, finalAmount);

        getVault().lockNative{value: msgValue - dust}(_nativeToken, msgValue - dust);
        // refund dust
        if (dust > 0) {
            payable(msg.sender).transfer(dust);
        }

        ITokenBridgeService.MessageData memory _messageData = ITokenBridgeService.MessageData({
            senderAddr: bytes32(uint256(uint160(msg.sender))),
            tokenAddress: bytes32(uint256(uint160(_nativeToken))),
            sourceChainId: uint64(block.chainid),
            payload: payload,
            finalAmount: finalAmount,
            feeCutToService: feeCutToService,
            relayerReward: relayerReward,
            receiverAddr: receiverAddr
        });

        bytes memory messageData = abi.encode(_messageData);
        getHypernova().postMessage(messageData, toChainId);
    }
    function upgradeImplementation(
        address newImplementation
    ) external onlyAdmin returns (address) {
        if (checkZeroAddr(newImplementation)) revert InvalidInput();
        ERC1967Utils.upgradeToAndCall(newImplementation, "");
        return newImplementation;
    }

    function changeState(bool _isPaused) external onlyAdmin {
        isPaused = _isPaused;
        emit ITokenBridgeService.TokenBridgePauseState(msg.sender, _isPaused);
    }

    function _registerTokenImpl(uint64 _toChainId, address tokenAddr, address _uniswapPool, bool _isFixedFee, uint64 _fixedServiceFee, uint64 _fixedRelayerReward, bool _register) internal {
        if (checkZeroAddr(tokenAddr)) revert InvalidInput();
        if (!isToChainIdRegistered(_toChainId)) {
            revert ChainIdNotRegistered();
        }
        
        ITokenBridgeService.TokenInfo storage tokenInfo = supportedTokens[_toChainId][tokenAddr];
        bool _isBaseToken;
        
        if (_uniswapPool != address(0)) { // uniswap is specified
            if (IUniswapV3Pool(_uniswapPool).token0() == tokenAddr) {
                _isBaseToken = true;
            }
        }

        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS
            ? 10 ** (originalDecimals - MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS)
            : 1;

        tokenInfo.isRegistered = _register;
        tokenInfo.uniswapPool = _uniswapPool;
        tokenInfo.isBaseToken = _isBaseToken;
        tokenInfo.decimalRate = _decimalRate;
        tokenInfo.isFixedFee = _isFixedFee;
        tokenInfo.fixedServiceFee = _fixedServiceFee;
        tokenInfo.fixedRelayerReward = _fixedRelayerReward;

        emit ITokenBridgeService.TokenRegistered(
            msg.sender, _toChainId, tokenAddr, _register, _uniswapPool, _isBaseToken
        );
    }

}
