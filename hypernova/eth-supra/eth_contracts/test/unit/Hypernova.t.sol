// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {Errors as hnErrors} from "contracts/hypernova-core/implementations/Errors.sol";
import {Errors as foErrors} from "contracts/fee-operator/implementations/Errors.sol";
import {Errors as tbErrors} from "contracts/tokenBridge-service/implementations/Errors.sol";
import {console} from "forge-std/console.sol";
import {InitDeploy} from "test/InitDeploy.t.sol";
import {IHypernova} from "contracts/interfaces/IHypernova.sol";
import {HypernovaImplementation} from "contracts/hypernova-core/implementations/HypernovaImplementation.sol";
import {Hypernova} from "contracts/hypernova-core/Hypernova.sol";


contract HypernovaCoreTest is InitDeploy{
    function setUp() public {        
        init();
    }

    event AdminWithdraw(bytes32 id);
    event AdminWithdrawExecuted(
        uint256 indexed amount,
        address indexed to,
        address indexed token
    );
    function test_init() public {
        console.log("weth : ", address(weth));
        console.log("sValueFeed : ", address(sValueFeed));
        console.log("uniswapV3Pool_WETH_USDT : ", address(uniswapV3Pool_WETH_USDT));
        console.log("uniswapV3Pool_USDT_WETH_sepolia : ", address(uniswapV3Pool_USDT_WETH_sepolia));
    }
    function test_initialize() external {
        address attacker = address(0xdead);
        address _admin = vm.addr(2);

        HypernovaImplementation newHypernovaImpl = new HypernovaImplementation();
        
        vm.prank(attacker);
        vm.expectRevert();
        newHypernovaImpl.initialize(address(0xdead), MSG_ID);

        vm.prank(ADMIN);
        IHypernova newHypernova = IHypernova(address(new Hypernova(address(newHypernovaImpl), "")));
        newHypernova.initialize(_admin, MSG_ID);

        HypernovaImplementation newHypernovaImpl2 = new HypernovaImplementation();
        vm.prank(attacker);
        vm.expectRevert();
        newHypernovaImpl.initialize(attacker, MSG_ID);

        vm.prank(attacker);
        vm.expectRevert();
        newHypernova.upgradeImplementation(address(newHypernovaImpl2));

        vm.prank(_admin);
        newHypernova.upgradeImplementation(address(newHypernovaImpl2));

        vm.prank(attacker);
        vm.expectRevert();
        newHypernovaImpl2.initialize(attacker, MSG_ID);


        vm.prank(_admin);
        vm.expectRevert();
        newHypernova.initialize(_admin, MSG_ID);
        
        assertEq(address(newHypernova.admin()), _admin);
    }
    function test_setAdmin() external {
        address newAdmin = vm.addr(2);
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IHypernova.UpdatedAdmin(ADMIN, newAdmin);
        hypernova.setAdmin(newAdmin);
        
        vm.prank(newAdmin);
        hypernova.changeState(true);
        assert(hypernova.checkIsHypernovaPaused() == true);
    }

    function test_Revert_setAdmin_When_CallerNotAdmin() external {
        address newAdmin = vm.addr(2);
        vm.prank(vm.addr(1));
        vm.expectRevert(hnErrors.UnauthorizedSender.selector);
        hypernova.setAdmin(newAdmin);
    }

    function test_postMessage() public {
        bool enabled = true;
        uint64 toChaiID = 6;
        uint256 cg = 155500;
        uint64 cm = 1000; // 10%
        uint64 _vm = 1000; // 10%
        uint64 x = 10; 

        vm.prank(ADMIN);
        adminHNSetup(
            enabled,
            toChaiID,
            cg,
            cm,
            _vm,
            x
        );

        hypernova.postMessage(bytes("0x0"),toChaiID);
        assert(hypernova.getNextMsgId()==1);
    }
    function test_postMessageEmit() external {
        bool enabled = true;
        uint64 toChaiID = 6;
        uint256 cg = 155500;
        uint64 cm = 1000; // 10%
        uint64 _vm = 1000; // 10%
        uint64 x = 10; 

        vm.prank(ADMIN);
        adminHNSetup(
            enabled,
            toChaiID,
            cg,
            cm,
            _vm,
            x
        );

        vm.expectEmit(true, true, true, true);
        emit IHypernova.MessagePosted(address(this),0,toChaiID,bytes("0x11"));
        hypernova.postMessage(bytes("0x11"),toChaiID);
        assert(hypernova.getNextMsgId()==1);
    }
    function test_postMessageEmitMoreData() external {
        bool enabled = true;
        uint64 toChaiID = 6;
        uint256 cg = 155500;
        uint64 cm = 1000; // 10%
        uint64 _vm = 1000; // 10%
        uint64 x = 10; 

        vm.prank(ADMIN);
        adminHNSetup(
            enabled,
            toChaiID,
            cg,
            cm,
            _vm,
            x
        );
        vm.expectEmit(true, true, true, true);
        emit IHypernova.MessagePosted(address(this),0,toChaiID,bytes("0x7FA9385bE102ac3EAc297483Dd6233D62b3e14967FA9385bE102ac3EAc297483Dd6233D62b3e1496"));
        hypernova.postMessage(bytes("0x7FA9385bE102ac3EAc297483Dd6233D62b3e14967FA9385bE102ac3EAc297483Dd6233D62b3e1496"),toChaiID);
        assert(hypernova.getNextMsgId()==1);
    }
    function test_Revert_postMessageWhenUnsupportedToChain() external {
        test_postMessage();
        vm.expectRevert();
        hypernova.postMessage(bytes("0x0"),4444);
    }


    function test_addOrUpdateHNConfig() external {
        bool enabled = true;
        uint64 toChainID = 6;
        uint256 cg = 155500;
        uint64 cm = 1000; // 10%
        uint64 _vm = 1000; // 10%
        uint64 x = 10;
        uint64 cr = hypernova.computeCUreward(cg, cm);
        uint64 v = hypernova.computeVerificationFee(cr, x, _vm);

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IHypernova.UpdatedHNConfig(ADMIN, IHypernova.HNConfig({
            enabled: enabled,
            cg: cg,
            cm: cm,
            vm: _vm,
            x: x,
            v: v, 
            cr: cr 
        }));
        hypernova.addOrUpdateHNConfig(enabled, toChainID, cg, cm, _vm, x);
        
        IHypernova.HNConfig memory config = hypernova.getHNConfig(toChainID);
        assertEq(config.enabled, enabled);
        assertEq(config.cm, cm);
        assertEq(config.vm, _vm);
        assertEq(config.cg, cg);
        assertEq(config.cr, cr);
        assertEq(config.x, x);
        assertEq(config.v, v);
    }

    function test_Revert_addOrUpdateHNConfigWhenInvalidInput() external {
        vm.prank(ADMIN);
        vm.expectRevert();
        hypernova.addOrUpdateHNConfig(true, 0, 155500, 1000, 1000, 10); // toChainID is 0
    }

    function test_Revert_addOrUpdateHNConfigWhenInvalidMargin() external {
        vm.prank(ADMIN);
        vm.expectRevert();
        hypernova.addOrUpdateHNConfig(true, 6, 155500, 10000, 1000, 10); // cm = 10000
    }

    function test_Revert_If_addOrUpdateHNConfigWhenXCannotBeMore() external {
        vm.prank(ADMIN);
        vm.expectRevert();
        hypernova.addOrUpdateHNConfig(true, 6, 100, 1000, 1000, 1000); // x > cr
    }

    function test_Revert_addOrUpdateHNConfigWhenNotAdmin() external {
        vm.expectRevert();
        hypernova.addOrUpdateHNConfig(true, 6, 155500, 1000, 1000, 10);
    }

    function test_getHNConfig() external {
        bool enabled = true;
        uint64 toChainID = 6;
        uint256 cg = 155500;
        uint64 cm = 1000;
        uint64 _vm = 1000;
        uint64 x = 10;

        vm.prank(ADMIN);
        hypernova.addOrUpdateHNConfig(enabled, toChainID, cg, cm, _vm, x);

        IHypernova.HNConfig memory config = hypernova.getHNConfig(toChainID);
        assertEq(config.enabled, enabled);
        assertEq(config.cg, cg);
        assertEq(config.cm, cm);
        assertEq(config.vm, _vm);
        assertEq(config.x, x);
    }

    function test_getHNConfigForNonExistentChain() external {
        IHypernova.HNConfig memory config = hypernova.getHNConfig(999);
        assertEq(config.enabled, false);
        assertEq(config.cg, 0);
        assertEq(config.cm, 0);
        assertEq(config.vm, 0);
        assertEq(config.x, 0);
        assertEq(config.v, 0);
        assertEq(config.cr, 0);
    }

    function test_changeState() external {
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IHypernova.HNBridgePauseState(ADMIN, true);
        hypernova.changeState(true);
        
        // Test that the state was actually changed
        vm.expectRevert(hnErrors.HNBridgePaused.selector);
        hypernova.postMessage(bytes("0x0"), 6);
    }

    function test_Revert_changeStateWhenNotAdmin() external {
        vm.expectRevert();
        hypernova.changeState(true);
    }


    function test_upgradeImplementation() external {
        HypernovaImplementation newHypernovaImpl = new HypernovaImplementation();
        
        // Test upgrade by non-admin
        vm.prank(address(1));
        vm.expectRevert(hnErrors.UnauthorizedSender.selector);
        hypernova.upgradeImplementation(address(newHypernovaImpl));

        // Test upgrade with zero address
        vm.prank(ADMIN);
        vm.expectRevert(hnErrors.InvalidInput.selector);
        hypernova.upgradeImplementation(address(0));

        // Test successful upgrade
        vm.prank(ADMIN);
        hypernova.upgradeImplementation(address(newHypernovaImpl));
        assertEq(hypernova.getImplementationAddress(), address(newHypernovaImpl));

    }

    function test_Revert_initialize_When_AlreadyInitialized() external {
        HypernovaImplementation newHypernovaImpl = new HypernovaImplementation();
        vm.prank(ADMIN);
        IHypernova newHypernova = IHypernova(address(new Hypernova(address(newHypernovaImpl), "")));
        newHypernova.initialize(address(1), MSG_ID);

        vm.prank(ADMIN);
        vm.expectRevert();
        newHypernova.initialize(address(1), MSG_ID);
    }

    function test_Revert_initialize_When_ZeroAddresses() external {
        HypernovaImplementation newHypernovaImpl = new HypernovaImplementation();
        vm.prank(ADMIN);
        IHypernova newHypernova = IHypernova(address(new Hypernova(address(newHypernovaImpl), "")));

        // Test zero admin address
        vm.expectRevert(hnErrors.InvalidInput.selector);
        newHypernova.initialize(address(0), MSG_ID);
    }

    // Test for _setAdmin with zero address
    function test_Revert_setAdminWithZeroAddress() external {
        vm.prank(ADMIN);
        vm.expectRevert();
        hypernova.initialize(address(0), MSG_ID);
    }

    // Test for computeVerificationFee with zero values
    function test_Revert_computeVerificationFeeWithZeroCR() external {
        vm.expectRevert();
        hypernova.computeVerificationFee(0, 10, 1000);
    }

    function test_Revert_computeVerificationFeeWithZeroX() external {
        vm.expectRevert();
        hypernova.computeVerificationFee(1000, 0, 1000);
    }

    function test_Revert_computeVerificationFeeWithInvalidMargin() external {
        vm.expectRevert();
        hypernova.computeVerificationFee(1000, 10, 10000);
    }

    function test_RevertComputeVerificationFeeWithXCannotBeMore() external {
        vm.expectRevert();
        hypernova.computeVerificationFee(100, 1000, 1000);
    }

    // Test for computeCUreward with zero values
    function test_Revert_computeCUrewardWithZeroCG() external {
        vm.expectRevert();
        hypernova.computeCUreward(0, 1000);
    }

    function test_Revert_computeCUrewardWithInvalidMargin() external {
        vm.expectRevert();
        hypernova.computeCUreward(1000, 10000);
    }

    // Test for postMessage when bridge is paused
    function test_Revert_postMessageWhenBridgePaused() external {
        vm.prank(ADMIN);
        hypernova.changeState(true);
        vm.expectRevert();
        hypernova.postMessage(bytes("0x0"), 6);
    }

    // Test for addOrUpdateHNConfig with zero values
    function test_Revert_addOrUpdateHNConfigWithZeroCG() external {
        vm.prank(ADMIN);
        vm.expectRevert();
        hypernova.addOrUpdateHNConfig(true, 6, 0, 1000, 1000, 10);
    }

    function test_Revert_addOrUpdateHNConfigWithZeroX() external {
        vm.prank(ADMIN);
        vm.expectRevert();
        hypernova.addOrUpdateHNConfig(true, 6, 155500, 1000, 1000, 0);
    }

    // Test for addOrUpdateHNConfig with invalid margin
    function test_Revert_addOrUpdateHNConfigWithInvalidVM() external {
        vm.prank(ADMIN);
        vm.expectRevert();
        hypernova.addOrUpdateHNConfig(true, 6, 155500, 1000, 10000, 10);
    }
}
