// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {IUniswapV3Pool} from "contracts/interfaces/IUniswapV3Pool.sol";

contract MockUniswapV3Pool_WETH_USDT is IUniswapV3Pool {
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
            // values at : June 11/25, on mainnet pool : 0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36 
            4164274393139738991784110, //sqrtPriceX96,
            -197081, //tick,
            66,//observationIndex,
            100, //observationCardinality,
            100, //observationCardinalityNext,
            0, //feeProtocol,
            true //unlocked
        );
    }
}