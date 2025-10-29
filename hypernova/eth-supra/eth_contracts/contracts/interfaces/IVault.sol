// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs

pragma solidity 0.8.22;

interface IVault {
    struct LockLimit {
        uint256 min;
        uint256 max;
        uint256 globalMax;
    }

    struct ReleaseLimit {
        uint256 min;
        uint256 max;
    }

    struct DelayedTransfer {
        uint256 amount;
        address to;
        address token;
        uint256 nonce;
        uint256 timestamp;
        bool isAdded;
    }
    event UpdatedAdmin(address indexed owner,address admin);
    event Locked(address indexed tokenAddr, uint256 indexed amount);
    event Released(address indexed to, address indexed tokenAddr, uint256 indexed amount);
    event AdminWithdrawAdded(bytes32 indexed id, address indexed token, address indexed to, uint256 amount, uint256 withdrawNonce, uint256 timestamp);
    event AdminWithdrawRemoved(bytes32 indexed id, address indexed token, address indexed to, uint256 amount, uint256 withdrawNonce, uint256 timestamp);
    event AdminWithdrawExecuted(bytes32 indexed id,address indexed token, address indexed to, uint256 amount, uint256 withdrawNonce, uint256 timestamp);
    
    function initialize(
        address _admin,
        address _tokenBridgeService,
        uint256 _delay
    ) external;
    function setAdmin(address _admin) external;
    function changeState(bool _isPaused) external;
    function changeReleaseState(bool _withdrawEnabled) external;
    function addAdminWithdraw(address token, uint256 amount, address to) external returns (bytes32);
    function removeAddedAdminWithdraw(bytes32 id) external returns (bytes32);
    function execAdminWithdraw(bytes32 id) external;
    function setTokenBridgeContract(address _tokenBridgeContract) external;
    function upgradeImplementation(address newImplementation) external returns (address);
    function setLockLimits(address[] calldata tokens, uint256[] calldata minLimits, uint256[] calldata maxLimits, uint256[] calldata globalMaxLimits) external;
    function setReleaseLimits(address[] calldata tokens, uint256[] calldata minLimits, uint256[] calldata maxLimits) external;

    function lockTokens(address tokenAddr, uint256 amount) external;
    function lockNative(address tokenAddr, uint256 amount) external payable;
    function release(address token,  uint256 amount, address to) external;
    function getImplementationAddress() external view returns (address);
    function getLockLimits(address token) external view returns (uint256, uint256, uint256);
    function getReleaseLimits(address token) external view returns (uint256, uint256);
    function getTokenBridgeContract() external view returns (address);
    function getLockedTokenBalance(address token) external view returns (uint256);
    function checkIsVaultPaused() external view returns(bool);
    function getId(address token, uint256 amount, address to, uint256 _withdrawNonce) external view returns (bytes32 id);
    function getNextWithdrawNonce() external view returns (uint256);
    function getAdminTransfers(bytes32 id) external view returns (IVault.DelayedTransfer memory);
    function getAdminWithdrawDelay() external view returns (uint256);
    function admin() external view returns (address);
}
