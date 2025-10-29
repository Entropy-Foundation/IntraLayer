// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {IUniswapV3Pool} from "contracts/interfaces/IUniswapV3Pool.sol";

contract MockUniswapV3Pool_USDC_USDT is IUniswapV3Pool {
    address public token0;
    address public token1;
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
    function slot0() public view
    returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    ) {
        return (
            // values at : June 12/25, on mainnet pool : 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6 
            79215789140314545691579102155, //sqrtPriceX96,
            -4, //tick,
            103,//observationIndex,
            180, //observationCardinality,
            180, //observationCardinalityNext,
            0, //feeProtocol,
            true //unlocked
        );
    }
}