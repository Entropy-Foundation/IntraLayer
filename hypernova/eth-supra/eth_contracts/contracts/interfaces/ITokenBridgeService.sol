// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;
import {IHypernova} from "./IHypernova.sol";
import {IFeeOperator} from "./IFeeOperator.sol";
interface ITokenBridgeService {

    // Events
    event UpdatedAdmin(address indexed owner,address admin);
    event UpdatedHypernova(address indexed owner,address hypernova);
    event UpdatedVault(address indexed owner,address vault);
    event UpdatedFeeOperator(address indexed owner, address relayOperator);
    event UpdatedNativeToken(address indexed owner,address nativeToken);
    event TokenRegistered(
        address indexed owner,
        uint64 toChainId,
        address tokenAddr,
        bool registered,
        address uniswapPool,
        bool isBaseToken
    );
    event ToChainRegistered(address indexed owner, uint256 toChainId, bool status);
    event TokenBridgePauseState(address indexed owner, bool paused);
    
    // Structs
    struct MessageData {
        bytes32 senderAddr;
        bytes32 tokenAddress;
        uint64 sourceChainId;
        bytes32 payload;
        uint64 finalAmount;
        uint64 feeCutToService;
        uint64 relayerReward;
        bytes32 receiverAddr;
    }
    struct TokenInfo {
        bool isRegistered;
        address uniswapPool;
        bool isBaseToken;
        uint256 decimalRate;
        // if isFixedFee = true, then uniswapPool is not used
        bool isFixedFee;
        uint64 fixedServiceFee;
        uint64 fixedRelayerReward;
    }

    // Functions
    function initialize(
        address _hypernova,
        address _admin,
        address _feeOperator,
        address _vaultAddr,
        address _nativeToken
    ) external;
    function setAdmin(address _admin) external;
    function setHypernova(address _hypernova) external ;
    function setVault(address _vault) external;
    function setFeeOperator(address _feeOperator) external;
    function setNativeToken(address _nativeToken) external;
    function admin() external view returns (address);
    function changeState(bool _isPaused) external;
    function upgradeImplementation(address newImplementation) external;
    function registerChainId(uint64 _toChainId, bool _registered) external;
    function registerToken(uint64 _toChainId, address tokenAddr, address _uniswapPool, bool _register) external;
    function registerFixedFeeToken(uint64 _toChainId, address tokenAddr, uint64 _fixedServiceFee, uint64 _fixedRelayerReward, bool _register) external;
    function sendTokens(address tokenAddr, uint256 amount, bytes32 receiverAddr, bytes32 payload, uint64 toChainId) external;
    function sendNative(bytes32 receiverAddr, uint256 amount, bytes32 payload, uint64 toChainId) external payable;

    function getImplementationAddress() external view returns (address); 
    function getHypernova() external view returns (IHypernova);
    function getFeeOperator() external view returns (IFeeOperator);
    function getVault() external view returns(address);
    function getNativeToken() external view returns (address);
    function isTokenRegistered(uint64 chainId, address tokenAddr) external view returns (bool);
    function isToChainIdRegistered(uint64 chainId) external view returns(bool);
    function getRegisteredTokenInfo(uint64 chainId, address tokenAddr) external view returns (ITokenBridgeService.TokenInfo memory);
    function computeFeeDetails(uint64 _toChainId, uint256 _amount, ITokenBridgeService.TokenInfo memory _tokenInfo) external view returns (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust);
    function checkIsTokenBridgePaused() external view returns(bool);
    function getFeeForAmount(uint64 _toChainId, uint256 _amount, address _tokenAddr) external view returns (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust);

    function MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS() external view returns (uint8);
}