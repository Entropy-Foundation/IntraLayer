// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {Hypernova} from "contracts/hypernova-core/Hypernova.sol";
import {Errors as hnErrors} from "contracts/hypernova-core/implementations/Errors.sol";
import {Errors as foErrors} from "contracts/fee-operator/implementations/Errors.sol";
import {Errors as tbErrors} from "contracts/tokenBridge-service/implementations/Errors.sol";
import {console} from "forge-std/console.sol";
import {InitDeploy} from "test/InitDeploy.t.sol";
import {IHypernova} from "contracts/interfaces/IHypernova.sol";
import {HypernovaImplementation} from "contracts/hypernova-core/implementations/HypernovaImplementation.sol";


contract HypernovaCoreFuzzTest is InitDeploy{
    function setUp() public {        
        init();
    }
    function testFuzz_computeCUreward(uint256 cg, uint64 cm) external {
        // Bound cm to be within valid range (0 to PERCENTAGE_BASE-1)
        cm = uint64(bound(cm, 0, 9999));
        // GasCost in Quants = gas_used * gas_unit_price => u64 * u64 => uint128 
        // So, cg will be within uint128. 
        cg = bound(cg, 1, type(uint128).max); // 

        // Calculate expected result
        uint256 expectedCR = (cg * hypernova.PERCENTAGE_BASE()) / (hypernova.PERCENTAGE_BASE() - cm);
        
        // If expected result would overflow uint64, expect revert
        if (expectedCR > type(uint64).max) {
            vm.expectRevert(abi.encodeWithSelector(hnErrors.InvalidCRComputation.selector, expectedCR));
            hypernova.computeCUreward(cg, cm);
            return;
        }
        // Otherwise, compute and verify result
        uint64 cr = hypernova.computeCUreward(cg, cm);
        
        // cr will never become 0
        assertNotEq(cr, 0);
        // Verify the result is greater than or equal to cg (since we're adding a margin)
        assertGe(cr, cg);
        assertEq(cr, expectedCR);
    }

    function testFuzz_computeVerificationFee(uint64 cr, uint64 x, uint64 _vm) external {

        _vm = uint64(bound(_vm, 0, 9999));
        // Bound x to avoid division by zero and ensure it's less than cr
        x = uint64(bound(x, 1, type(uint64).max));
        cr = uint64(bound(cr, x, type(uint64).max));

        uint256 expectedV = (uint256(cr / x) * hypernova.PERCENTAGE_BASE()) / (hypernova.PERCENTAGE_BASE() - _vm);

        // If expected result would overflow uint64, expect revert
        if (expectedV > type(uint64).max) {
            vm.expectRevert(abi.encodeWithSelector(hnErrors.InvalidVComputation.selector, expectedV));
            hypernova.computeVerificationFee(cr, x, _vm);
            return;
        }
        uint64 v = hypernova.computeVerificationFee(cr, x, _vm);
        
        // V will never become zero
        assertNotEq(v, 0);
        
        assertEq(v, expectedV);
    }

    function testFuzz_computeVerificationFee_with_computeCUR(uint64 x, uint64 _vm, uint256 cg, uint64 cm) external {

        _vm = uint64(bound(_vm, 0, 9999));
        // Bound x to avoid division by zero and ensure it's less than cr
        cm = uint64(bound(cm, 0, 9999));
        
        // GasCost in Quants = gas_used * gas_unit_price => u64 * u64 => uint128 
        // So, cg will be within uint128. 
        cg = bound(cg, 1, type(uint128).max); // 
        // Calculate expected result
        uint256 expectedCR = (cg * hypernova.PERCENTAGE_BASE()) / (hypernova.PERCENTAGE_BASE() - cm);
        // If expected result would overflow uint64, expect revert
        if (expectedCR > type(uint64).max) {
            vm.expectRevert(abi.encodeWithSelector(hnErrors.InvalidCRComputation.selector, expectedCR));
            hypernova.computeCUreward(cg, cm);
            return;
        }
        // Otherwise, compute and verify result
        uint64 cr = hypernova.computeCUreward(cg, cm);
        x = uint64(bound(x, 1, cr));
        // cr can never become 0
        assertNotEq(cr, 0);
        // Verify the result is greater than or equal to cg (since we're adding a margin)
        assertGe(cr, cg);
        // Bound cr to avoid overflows

        uint256 expectedV = (uint256(cr / x) * hypernova.PERCENTAGE_BASE()) / (hypernova.PERCENTAGE_BASE() - _vm);
        // If expected result would overflow uint64, expect revert
        if (expectedV > type(uint64).max) {
            vm.expectRevert(abi.encodeWithSelector(hnErrors.InvalidVComputation.selector, expectedV));
            hypernova.computeVerificationFee(cr, x, _vm);
            return;
        }
        uint64 v = hypernova.computeVerificationFee(cr, x, _vm);
        
        // Verify the result is greater than 0
        assertNotEq(v, 0);
        
        assertEq(v, expectedV);
    }

    function testFuzz_computeVerificationFeeEdgeCases(uint64 _vm, uint64 cr, uint64 x) external {
        // Test with minimum valid values
        x = uint64(bound(x, 1, type(uint64).max));
        cr = uint64(bound(cr, x, type(uint64).max)); 
        
        // Test with maximum vm (99%)
        _vm = 9999;
        uint256 expectedV = (uint256(cr / x) * hypernova.PERCENTAGE_BASE()) / (hypernova.PERCENTAGE_BASE() - _vm);
        // If expected result would overflow uint64, expect revert
        if (expectedV > type(uint64).max) {
            vm.expectRevert(abi.encodeWithSelector(hnErrors.InvalidVComputation.selector, expectedV));
            hypernova.computeVerificationFee(cr, x, _vm);
            return;
        }
        uint64 v1 = hypernova.computeVerificationFee(cr, x, _vm);
        assertEq(v1, uint256(cr / x) * hypernova.PERCENTAGE_BASE());

        // Test with minimum vm (0%)
        _vm = 0;
        expectedV = (uint256(cr / x) * hypernova.PERCENTAGE_BASE()) / (hypernova.PERCENTAGE_BASE() - _vm);
        // If expected result would overflow uint64, expect revert
        if (expectedV > type(uint64).max) {
            vm.expectRevert(abi.encodeWithSelector(hnErrors.InvalidVComputation.selector, expectedV));
            hypernova.computeVerificationFee(cr, x, _vm);
            return;
        }
        uint64 v2 = hypernova.computeVerificationFee(cr, x, _vm);
        assertEq(v2, cr / x);

        // Test with x = cr
        _vm = uint64(bound(_vm, 0, 9999));
        expectedV = (uint256(cr / x) * hypernova.PERCENTAGE_BASE()) / (hypernova.PERCENTAGE_BASE() - _vm);
        // If expected result would overflow uint64, expect revert
        if (expectedV > type(uint64).max) {
            vm.expectRevert(abi.encodeWithSelector(hnErrors.InvalidVComputation.selector, expectedV));
            hypernova.computeVerificationFee(cr, x, _vm);
            return;
        }
        uint64 v3 = hypernova.computeVerificationFee(x, x, _vm);
        assertEq(v3, (hypernova.PERCENTAGE_BASE() / (hypernova.PERCENTAGE_BASE() -  _vm)));
    }

    function test_Revert_computeVerificationFeeWithInvalidVM() external {
        vm.expectRevert();
        hypernova.computeVerificationFee(1000, 10, 10000);
    }
}
