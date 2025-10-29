// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;
import "../../interfaces/IFeeOperator.sol";

contract State {
    uint64 constant public PERCENTAGE_BASE = 1e4;
    uint8 constant public NORMALIZED_DECIMALS = 20; //supraPriceInUsdt.decimals (18) - USDT_DECIMALS(6) + SUPRA_DECIMALS(8)
    address public admin;
    bool isPaused;
    address hypernova;
    address sValueFeed;
    uint256 supraUsdtPairIndex;
    mapping (uint64 toChainId => IFeeOperator.FeeConfig) public feeConfigs;
}