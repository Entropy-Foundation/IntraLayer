// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import "contracts/tokenBridge-service/implementations/State.sol";
import "contracts/interfaces/IHypernova.sol";
import "contracts/interfaces/IFeeOperator.sol";
import "contracts/interfaces/IVault.sol";
import {ISupraSValueFeed} from "contracts/interfaces/ISupraSValueFeed.sol";
import "contracts/tokenBridge-service/implementations/Errors.sol";
import {ERC1967Utils} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol"; //@dev: Library
contract Helpers is State, Errors {
    function _setAdmin(address _admin) internal {
        if (_admin != address(0)) {
            admin = _admin;
        } else revert InvalidInput();
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert UnauthorizedSender();
        }
        _;
    }

    modifier isNotPaused() {
        if (isPaused) {
            revert BridgePaused();
        }
        _;
    }
    function _setHypernova(address _hypernova) internal {
        if (checkZeroAddr(_hypernova)) revert InvalidInput();
        hypernova = _hypernova;
    }
    function _setFeeOperator(address _feeOperatorContract) internal {
        if (checkZeroAddr(_feeOperatorContract)) revert InvalidInput();
        feeOperatorContract = _feeOperatorContract;
    }
    function _setNativeToken(address _nativeToken) internal {
        if (checkZeroAddr(_nativeToken)) revert InvalidInput();
        nativeToken = _nativeToken;
    }
    function _setVault(address _vault) internal {
        if (checkZeroAddr(_vault)) revert InvalidInput();
        vault = _vault;
    }

    function _updateBridgedAmountPerToken(uint64 _toChainId, address _tokenAddr, uint64 _finalAmount) internal {
        uint256 currentAmount = bridgedAmountPerToken[_toChainId][_tokenAddr];
        if ((currentAmount + _finalAmount) > type(uint64).max) {
            revert OutGoingBridgeAmountLimitForTokenIsReached(_toChainId, _tokenAddr, _finalAmount);
        }
        bridgedAmountPerToken[_toChainId][_tokenAddr] = currentAmount + _finalAmount;
    }

    function getHypernova() public view returns (IHypernova){
        return IHypernova(hypernova);
    }
    function getVault() public view returns(IVault){
        return IVault(vault);
    }
    function getFeeOperator() public view returns (IFeeOperator) {
        return IFeeOperator(feeOperatorContract);
    }
    function getNativeToken() public view returns (address) {
        return nativeToken;
    }
    function getImplementationAddress() public view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function isTokenRegistered(uint64 chainId, address tokenAddr) public view returns (bool) {
        return supportedTokens[chainId][tokenAddr].isRegistered;
    }

    function isToChainIdRegistered(uint64 chainId) public view returns(bool){
        return supportedChains[chainId];
    }
    function getRegisteredTokenInfo(uint64 chainId, address tokenAddr) public view returns (ITokenBridgeService.TokenInfo memory) {
        return supportedTokens[chainId][tokenAddr];
    }

    function computeFeeDetails(uint64 _toChainId, uint256 _amount, ITokenBridgeService.TokenInfo memory _tokenInfo) public view returns (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust){
        (finalAmount, feeCutToService, relayerReward, dust) = getFeeOperator().getFeeDetails(_toChainId, _amount, _tokenInfo);
    }

    function getFeeForAmount(uint64 _toChainId, uint256 _amount, address _tokenAddr) public view returns (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust){
        ITokenBridgeService.TokenInfo memory tokenInfo = getRegisteredTokenInfo(_toChainId, _tokenAddr);
        if (!tokenInfo.isRegistered) {
            revert TokenNotRegistered();
        }
        // Enough Fee and Amount check is done in FeeOperator
        (finalAmount, feeCutToService, relayerReward, dust) = computeFeeDetails(_toChainId, _amount, tokenInfo);
    }
    function checkIsTokenBridgePaused() public view returns(bool) {
        return isPaused;
    }
    function checkZeroValue(uint256 value) internal pure returns (bool) {
        return value == 0;
    }

    function checkZeroAddr(address value) internal pure returns (bool) {
        return value == address(0);
    }

    function checkZeroBytes32(bytes32 value) internal pure returns (bool) {
        return value == bytes32(0);
    }
}
