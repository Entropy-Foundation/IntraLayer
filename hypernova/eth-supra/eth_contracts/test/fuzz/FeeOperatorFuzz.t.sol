// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {Errors as foErrors} from "contracts/fee-operator/implementations/Errors.sol";
import {console} from "forge-std/console.sol";
import {InitDeploy} from "test/InitDeploy.t.sol";
import {HypernovaImplementation} from "contracts/hypernova-core/implementations/HypernovaImplementation.sol";
import {IFeeOperator} from "contracts/interfaces/IFeeOperator.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";



contract FeeOperatorFuzzTest is InitDeploy{
    function setUp() public {        
        init();
    }
    function testFuzz_computeRelayerReward(uint64 v, uint256 rg, uint64 rm) external {
        rm = uint64(bound(rm, 0, 9999));
        // GasCost in Quants = gas_used * gas_unit_price => u64 * u64 => uint128 
        // So, rg will be within uint128. 
        rg = bound(rg, 1, type(uint128).max); 
        v = uint64(bound(rg, 1, type(uint64).max)); 
        
        uint256 expectedRR = FullMath.mulDiv((v+rg), feeOperator.PERCENTAGE_BASE(), (hypernova.PERCENTAGE_BASE() - rm));
        // If expected result would overflow uint64, expect revert
        if (expectedRR > type(uint64).max) {
            vm.expectRevert(abi.encodeWithSelector(foErrors.InvalidRRComputation.selector, expectedRR));
            feeOperator.computeRelayerReward(v, rg, rm);
            return;
        }
        uint64 rr = feeOperator.computeRelayerReward(v, rg, rm);
        
        // rr can never become 0
        assertNotEq(rr, 0);
        // Verify the result is greater than or equal to cg (since we're adding a margin)
        assertGe(rr, rg);
        
        assertEq(rr, expectedRR);
    }

    function testFuzz_computeServiceFee(uint256 amount, uint256 tokenAmountInUsdt, uint256 _relayerRewardInBridgedAsset, IFeeOperator.FeeConfig memory _tbFeeConfig) external {
        amount = bound(tokenAmountInUsdt, 1, type(uint192).max);
        
        // Bound tokenAmountInUsdt to positive values and reasonable range
        tokenAmountInUsdt = bound(tokenAmountInUsdt, 1, type(uint192).max);
        
        // Bound relayerReward to positive values and reasonable range
        _relayerRewardInBridgedAsset = bound(_relayerRewardInBridgedAsset, 1, type(uint192).max); 

        // Bound fee config values
        _tbFeeConfig.enabled = true;
        _tbFeeConfig.rg = bound(_tbFeeConfig.rg, 1, type(uint128).max);
        _tbFeeConfig.rm = uint64(bound(_tbFeeConfig.rm, 0, 9999));
        _tbFeeConfig.sm = uint64(bound(_tbFeeConfig.sm, 0, 9999));
        
        // Bound tier USDT values
        _tbFeeConfig.tierMicroUSDT = uint64(bound(_tbFeeConfig.tierMicroUSDT, 1, type(uint64).max));
        _tbFeeConfig.tierWhaleUSDT = uint128(bound(_tbFeeConfig.tierWhaleUSDT, _tbFeeConfig.tierMicroUSDT, type(uint128).max));
        
        // Bound tier percentages
        _tbFeeConfig.tierMicroPercentage = uint64(bound(_tbFeeConfig.tierMicroPercentage, 0, 10000));
        _tbFeeConfig.tierStandardPercentage = uint64(bound(_tbFeeConfig.tierStandardPercentage, 0, 10000));
        _tbFeeConfig.tierWhalePercentage = uint64(bound(_tbFeeConfig.tierWhalePercentage, 0, 10000));


        // Calculate expected service fee based on tier
        uint256 expectedTierFee;
        if (tokenAmountInUsdt <= _tbFeeConfig.tierMicroUSDT) {
            expectedTierFee = FullMath.mulDiv(amount, _tbFeeConfig.tierMicroPercentage, feeOperator.PERCENTAGE_BASE());
        } else if (tokenAmountInUsdt < _tbFeeConfig.tierWhaleUSDT) {
            expectedTierFee = FullMath.mulDiv(amount, _tbFeeConfig.tierStandardPercentage, feeOperator.PERCENTAGE_BASE());
        } else {
            expectedTierFee = FullMath.mulDiv(amount, _tbFeeConfig.tierWhalePercentage, feeOperator.PERCENTAGE_BASE());
        }
        
        uint256 expectedServiceFee = FullMath.mulDiv(_relayerRewardInBridgedAsset, feeOperator.PERCENTAGE_BASE(), (feeOperator.PERCENTAGE_BASE() - _tbFeeConfig.sm)) + expectedTierFee;
        uint256 decimalRate = 10**10; // considering ETH transfer
        uint256 normalizedExpectedServiceFee = normalizeDecimals(expectedServiceFee, decimalRate);
        // If expected result would overflow uint64, expect revert
        if (normalizedExpectedServiceFee > type(uint64).max) {
            return;
        }

        uint256 serviceFee = feeOperator.computeServiceFee(amount, tokenAmountInUsdt, _relayerRewardInBridgedAsset, _tbFeeConfig);
        
        // Service fee should never be 0
        assertNotEq(serviceFee, 0);
        // Service fee should be greater than or equal to relayerReward
        assertGe(serviceFee, _relayerRewardInBridgedAsset);
        assertEq(serviceFee, expectedServiceFee);
    }
    function normalizeDecimals(uint256 _amount, uint256 _decimalRate) internal pure returns (uint256){
        return (_amount / _decimalRate);
    }
}
