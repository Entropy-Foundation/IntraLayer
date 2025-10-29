// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;
import "../../interfaces/IHypernova.sol";

contract State {
    uint64 constant public PERCENTAGE_BASE = 1e4;
    address public admin;
    uint256 public msgId;
    bool public isPaused;
    mapping (uint64 toChainId => IHypernova.HNConfig) hnConfig;
}