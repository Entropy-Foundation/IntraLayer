// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import "contracts/interfaces/IVault.sol";
contract State {
    address public admin;
    bool isPaused;
    bool releaseEnabled;
    address tokenBridgeContract;
    uint256 adminWithdrawDelay;
    uint256 withdrawNonce;

    mapping(bytes32 => IVault.DelayedTransfer) adminTransfers;
    mapping(address => IVault.LockLimit) lockLimits;
    mapping(address => IVault.ReleaseLimit) releaseLimits;
    mapping(address => uint256) lockedTokens;
}
