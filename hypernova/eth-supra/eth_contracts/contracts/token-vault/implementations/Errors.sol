// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

contract Errors {
    error UnauthorizedSender();
    error VaultPaused();
    error InvalidInput();
    error LimitBreached();
    error GlobaTokenLockLimitBreached();
    error ReleaseDisabled();
    error WithdrawalAlreadyAdded(bytes32);
    error WithdrawDoesNotExist(bytes32);
    error TryLater();
    error InsufficientBalance();
}