// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

contract Errors {
    error UnauthorizedSender();
    error UnsupportedToChain();
    error InvalidInput();
    error HNBridgePaused();
    error InvalidPercentage();
    error InvalidMargin();
    error XCannotBeMore();
    error InvalidVComputation(uint256 v);
    error InvalidCRComputation(uint256 cr);

}
