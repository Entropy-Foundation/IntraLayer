// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

contract Errors {
    error UnauthorizedSender();
    error InvalidInput();
    error InvalidChainId();
    error InsufficientAmount(uint256 amount, uint256 feeCutToService, uint256 relayerRewardInBridgedAsset);
    error InvalidPercentage();
    error InvalidMargin();
    error TokenNotRegistered();
    error FeeConfigIsNotEnabled();
    error HNConfigIsNotEnabled();
    error FeeOperatorPaused();
    error InvalidRRComputation(uint256 rr);

    error InvalidSValue(uint256 s);
    error InvalidRRinBridgedAssetValue(uint256 rr);
    error InvalidAmountValue(uint256 amount);
}
