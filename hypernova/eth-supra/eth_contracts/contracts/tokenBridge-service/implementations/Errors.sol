// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

contract Errors {
    error InvalidInput();
    error IncorrectAmount();
    error TokenNotRegistered();
    error InsufficientFee();
    error MinimumFeeLimit();
    error InsufficientAllowance();
    error TokenAlreadyRegistered();
    error UnauthorizedSender();
    error BridgePaused();
    error DepositLimitBreached();
    error TransferFailed();
    error DepositFailed();
    error ChainIdAlreadyRegistered();
    error ChainIdNotRegistered();
    error MaxAmountReached();
    error OutGoingBridgeAmountLimitForTokenIsReached(uint64 _toChainId, address _tokenAddr, uint64 _finalAmount);
}
