// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {Errors as hnErrors} from "contracts/hypernova-core/implementations/Errors.sol";
import {Errors as foErrors} from "contracts/fee-operator/implementations/Errors.sol";
import {Errors as tbErrors} from "contracts/tokenBridge-service/implementations/Errors.sol";
import {console} from "forge-std/console.sol";
import {InitDeploy} from "test/InitDeploy.t.sol";
import {IHypernova} from "contracts/interfaces/IHypernova.sol";
import {ITokenBridgeService} from "contracts/interfaces/ITokenBridgeService.sol";
import {IFeeOperator} from "contracts/interfaces/IFeeOperator.sol";
import {FeeOperatorImpl} from "contracts/fee-operator/implementations/FeeOperatorImpl.sol";
import {FeeOperator} from "contracts/fee-operator/FeeOperator.sol";
import {ISupraSValueFeed} from "contracts/interfaces/ISupraSValueFeed.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";

contract FeeOperatorTest is InitDeploy {
    uint64 constant PERCENTAGE_BASE = 1e4;

    function setUp() public {
        init();
    }

    function test_setAdmin() external {
        address newAdmin = vm.addr(2);
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IFeeOperator.UpdatedAdmin(ADMIN, newAdmin);
        feeOperator.setAdmin(newAdmin);
        
        vm.prank(newAdmin);
        feeOperator.changeState(true);
        assert(feeOperator.checkIsFeeOperatorPaused() == true);
    }
    function test_initialize() external {
        address attacker = address(0xdead);
        address _admin = vm.addr(2);
        address _hypernova = vm.addr(3);
        address _sValueFeed = vm.addr(4);
        uint256 _supraUsdtPairIndex = 500;

        FeeOperatorImpl newFeeOperatorImpl = new FeeOperatorImpl();
        
        vm.prank(attacker);
        vm.expectRevert();
        newFeeOperatorImpl.initialize(attacker, _hypernova, _sValueFeed, supraUsdtPairIndex);

        vm.prank(ADMIN);
        IFeeOperator newFeeOperator = IFeeOperator(address(new FeeOperator(address(newFeeOperatorImpl), "")));
        newFeeOperator.initialize(_admin, _hypernova, _sValueFeed, _supraUsdtPairIndex);

        FeeOperatorImpl newFeeOperatorImpl2 = new FeeOperatorImpl();
        vm.prank(attacker);
        vm.expectRevert();
        newFeeOperatorImpl.initialize(attacker, _hypernova, _sValueFeed, _supraUsdtPairIndex);

        vm.prank(attacker);
        vm.expectRevert();
        newFeeOperator.upgradeImplementation(address(newFeeOperatorImpl2));

        vm.prank(_admin);
        newFeeOperator.upgradeImplementation(address(newFeeOperatorImpl2));

        vm.prank(attacker);
        vm.expectRevert();
        newFeeOperatorImpl2.initialize(attacker, _hypernova, _sValueFeed, _supraUsdtPairIndex);


        vm.prank(_admin);
        vm.expectRevert();
        newFeeOperator.initialize(_admin, _hypernova, _sValueFeed, _supraUsdtPairIndex);
        
        assertEq(address(newFeeOperator.admin()), _admin);
    }
    function test_Revert_setAdmin_When_CallerNotAdmin() external {
        address newAdmin = vm.addr(2);
        vm.prank(vm.addr(1));
        vm.expectRevert(foErrors.UnauthorizedSender.selector);
        feeOperator.setAdmin(newAdmin);
    }

    function test_changeState() external {
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IFeeOperator.FeeOperatorPauseState(ADMIN, true);
        feeOperator.changeState(true);
    }

    function test_Revert_changeStateWhenNotAdmin() external {
        vm.expectRevert();
        hypernova.changeState(true);
    }
    function test_upgradeImplementation() external {
        FeeOperatorImpl newFeeOperatorImpl = new FeeOperatorImpl();
        
        // Test upgrade by non-admin
        vm.prank(address(1));
        vm.expectRevert(foErrors.UnauthorizedSender.selector);
        feeOperator.upgradeImplementation(address(newFeeOperatorImpl));

        // Test upgrade with zero address
        vm.prank(ADMIN);
        vm.expectRevert(foErrors.InvalidInput.selector);
        feeOperator.upgradeImplementation(address(0));

        // Test successful upgrade
        vm.prank(ADMIN);
        feeOperator.upgradeImplementation(address(newFeeOperatorImpl));
        assertEq(feeOperator.getImplementationAddress(), address(newFeeOperatorImpl));
    }

    function test_Revert_initialize_When_AlreadyInitialized() external {
        FeeOperatorImpl newFeeOperatorImpl = new FeeOperatorImpl();
        vm.prank(ADMIN);
        IFeeOperator newFeeOperator = IFeeOperator(address(new FeeOperator(address(newFeeOperatorImpl), "")));
        newFeeOperator.initialize(address(1), address(2), address(3), 500);

        vm.prank(ADMIN);
        vm.expectRevert();
        newFeeOperator.initialize(address(1), address(2), address(3), 500);
    }

    function test_Revert_initialize_When_ZeroAddresses() external {
        FeeOperatorImpl newFeeOperatorImpl = new FeeOperatorImpl();
        vm.prank(ADMIN);
        IFeeOperator newFeeOperator = IFeeOperator(address(new FeeOperator(address(newFeeOperatorImpl), "")));

        // Test zero admin address
        vm.expectRevert(foErrors.InvalidInput.selector);
        newFeeOperator.initialize(address(0), address(2), address(3), 500);

        // Test zero hypernova address
        vm.expectRevert(foErrors.InvalidInput.selector);
        newFeeOperator.initialize(address(1), address(0), address(3), 500);

        // Test zero sValueFeed address
        vm.expectRevert(foErrors.InvalidInput.selector);
        newFeeOperator.initialize(address(1), address(2), address(0), 500);

        // Test zero _supraUsdtPairIndex
        vm.expectRevert(foErrors.InvalidInput.selector);
        newFeeOperator.initialize(address(1), address(2), address(3), 0);
    }

    function test_setHypernova() external {
        address newHypernova = address(0x1234);
        vm.prank(ADMIN);
        feeOperator.setHypernova(newHypernova);
        assert(address(feeOperator.getHypernova()) == newHypernova);
    }

    function test_Revert_setHypernova_When_CallerIsNotAdmin() external {
        address newHypernova = address(0x1234);
        vm.expectRevert();
        feeOperator.setHypernova(newHypernova);
    }
    function test_Revert_setHypernova_When_ZeroAddr() external {
        address newHypernova = address(0);
        vm.prank(ADMIN);
        vm.expectRevert();
        feeOperator.setHypernova(newHypernova);
    }
    function test_setSValueFeed() external {
        address newSValueFeed = address(0x5678);
        uint256 _newSupraUsdtPairIndex = 500;
        vm.prank(ADMIN);
        feeOperator.setSValueFeed(newSValueFeed, _newSupraUsdtPairIndex);
        (ISupraSValueFeed _sValueFeed, uint256 _supraUsdtPairIndex) = feeOperator.getSValueFeed();
        assert(address(_sValueFeed) == newSValueFeed);
        assert(_supraUsdtPairIndex == _newSupraUsdtPairIndex);
    }

    function test_Revert_setSValueFeed_When_Zero() external {
        address newSValueFeed = address(0);
        uint256 _newSupraUsdtPairIndex = 0;
        vm.prank(ADMIN);
        vm.expectRevert();
        feeOperator.setSValueFeed(newSValueFeed, _newSupraUsdtPairIndex);
    }
    function test_Revert_setSValueFeed_When_CallerIsNotAdmin() external {
        address newSValueFeed = address(0x5678);
        uint256 _newSupraUsdtPairIndex = 500;
        vm.expectRevert();
        feeOperator.setSValueFeed(newSValueFeed, _newSupraUsdtPairIndex);
    }

    function test_addOrUpdateTBFeeConfig() public {
        uint64 toChainId = 1;
        bool enabled = true;
        uint256 rg = 100;
        uint64 rm = 2000; // 20%
        uint64 sm = 1000; // 10%
        uint64 tierMicroUSDT = 100;
        uint128 tierWhaleUSDT = 1000;
        uint64 tierMicroPercentage = 500; // 5%
        uint64 tierStandardPercentage = 1000; // 10%
        uint64 tierWhalePercentage = 1500; // 15%

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IFeeOperator.UpdatedTBFeeConfig(ADMIN, IFeeOperator.FeeConfig({
            enabled: enabled,
            rg: rg,
            rm: rm,
            sm: sm,
            tierMicroUSDT: tierMicroUSDT, 
            tierWhaleUSDT: tierWhaleUSDT,
            tierMicroPercentage: tierMicroPercentage,
            tierStandardPercentage: tierStandardPercentage,
            tierWhalePercentage: tierWhalePercentage
        }));
        feeOperator.addOrUpdateTBFeeConfig(
            enabled,
            toChainId,
            rg,
            rm,
            sm,
            tierMicroUSDT,
            tierWhaleUSDT,
            tierMicroPercentage,
            tierStandardPercentage,
            tierWhalePercentage
        );

        IFeeOperator.FeeConfig memory config = feeOperator.getTBFeeConfig(toChainId);
        assert(config.enabled == enabled);
        assert(config.rg == rg);
        assert(config.rm == rm);
        assert(config.sm == sm);
        assert(config.tierMicroUSDT == tierMicroUSDT);
        assert(config.tierWhaleUSDT == tierWhaleUSDT);
        assert(config.tierMicroPercentage == tierMicroPercentage);
        assert(config.tierStandardPercentage == tierStandardPercentage);
        assert(config.tierWhalePercentage == tierWhalePercentage);
    }

    function test_Revert_addOrUpdateTBFeeConfig_When_CallerIsNotAdmin() external {
        uint64 toChainId = 1;
        bool enabled = true;
        uint256 rg = 100;
        uint64 rm = 2000;
        uint64 sm = 1000;
        uint64 tierMicroUSDT = 100;
        uint128 tierWhaleUSDT = 1000;
        uint64 tierMicroPercentage = 500;
        uint64 tierStandardPercentage = 1000;
        uint64 tierWhalePercentage = 1500;
        vm.expectRevert();
        feeOperator.addOrUpdateTBFeeConfig(
            enabled,
            toChainId,
            rg,
            rm,
            sm,
            tierMicroUSDT,
            tierWhaleUSDT,
            tierMicroPercentage,
            tierStandardPercentage,
            tierWhalePercentage
        );
    }

    function test_Revert_addOrUpdateTBFeeConfig_When_InvalidInput() external {
        uint64 toChainId = 0; // Invalid chain ID
        bool enabled = true;
        uint256 rg = 0; // Invalid rg
        uint64 rm = 2000;
        uint64 sm = 1000;
        uint64 tierMicroUSDT = 100;
        uint128 tierWhaleUSDT = 1000;
        uint64 tierMicroPercentage = 500;
        uint64 tierStandardPercentage = 1000;
        uint64 tierWhalePercentage = 1500;

        vm.prank(ADMIN);
        vm.expectRevert();
        feeOperator.addOrUpdateTBFeeConfig(
            enabled,
            toChainId,
            rg,
            rm,
            sm,
            tierMicroUSDT,
            tierWhaleUSDT,
            tierMicroPercentage,
            tierStandardPercentage,
            tierWhalePercentage
        );
    }

    function test_Revert_addOrUpdateTBFeeConfig_When_InvalidMargin() external {
        uint64 toChainId = 1;
        bool enabled = true;
        uint256 rg = 100;
        uint64 rm = PERCENTAGE_BASE; // Invalid margin (100%)
        uint64 sm = 1000;
        uint64 tierMicroUSDT = 100;
        uint128 tierWhaleUSDT = 1000;
        uint64 tierMicroPercentage = 500;
        uint64 tierStandardPercentage = 1000;
        uint64 tierWhalePercentage = 1500;

        vm.prank(ADMIN);
        vm.expectRevert();
        feeOperator.addOrUpdateTBFeeConfig(
            enabled,
            toChainId,
            rg,
            rm,
            sm,
            tierMicroUSDT,
            tierWhaleUSDT,
            tierMicroPercentage,
            tierStandardPercentage,
            tierWhalePercentage
        );
    }

    function test_Revert_addOrUpdateTBFeeConfig_When_InvalidPercentage() external {
        uint64 toChainId = 1;
        bool enabled = true;
        uint256 rg = 100;
        uint64 rm = 2000;
        uint64 sm = 1000;
        uint64 tierMicroUSDT = 100;
        uint128 tierWhaleUSDT = 1000;
        uint64 tierMicroPercentage = PERCENTAGE_BASE + 1; // Invalid percentage > 100%
        uint64 tierStandardPercentage = 1000;
        uint64 tierWhalePercentage = 1500;

        vm.prank(ADMIN);
        vm.expectRevert();
        feeOperator.addOrUpdateTBFeeConfig(
            enabled,
            toChainId,
            rg,
            rm,
            sm,
            tierMicroUSDT,
            tierWhaleUSDT,
            tierMicroPercentage,
            tierStandardPercentage,
            tierWhalePercentage
        );
    }

    function test_getTBFeeConfig() external {
        uint64 toChainId = 1;
        bool enabled = true;
        uint256 rg = 100;
        uint64 rm = 2000;
        uint64 sm = 1000;
        uint64 tierMicroUSDT = 100;
        uint128 tierWhaleUSDT = 1000;
        uint64 tierMicroPercentage = 500;
        uint64 tierStandardPercentage = 1000;
        uint64 tierWhalePercentage = 1500;

        vm.prank(ADMIN);
        feeOperator.addOrUpdateTBFeeConfig(
            enabled,
            toChainId,
            rg,
            rm,
            sm,
            tierMicroUSDT,
            tierWhaleUSDT,
            tierMicroPercentage,
            tierStandardPercentage,
            tierWhalePercentage
        );

        IFeeOperator.FeeConfig memory config = feeOperator.getTBFeeConfig(toChainId);
        assert(config.enabled == enabled);
        assert(config.rg == rg);
        assert(config.rm == rm);
        assert(config.sm == sm);
        assert(config.tierMicroUSDT == tierMicroUSDT);
        assert(config.tierWhaleUSDT == tierWhaleUSDT);
        assert(config.tierMicroPercentage == tierMicroPercentage);
        assert(config.tierStandardPercentage == tierStandardPercentage);
        assert(config.tierWhalePercentage == tierWhalePercentage);
    }

    function test_getFeeDetails_pass1() external {
        // Setup required configs first
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 9990; // 99.90%
            uint64 _vm = 2000; // 20%
            uint64 x = 20; 

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 8000; // 80%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %
            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        uint256 amount = 1 ether; 
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
        
        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(finalAmount,_decimalRate)  < amount);
        assert(feeCutToService > 0);
        assert(relayerReward > 0);
        assertEq(amount, deNormalizeDecimals(finalAmount, _decimalRate) + deNormalizeDecimals(feeCutToService, _decimalRate) + dust);
    }

    function test_getFeeDetails_pass2() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 5000; // 50%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 5000; // 50%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0            
        });

        uint256 amount = 1 ether; 
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
        
        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(finalAmount,_decimalRate)  < amount);
        assert(feeCutToService > 0);
        assert(relayerReward > 0);
        assertEq(amount, deNormalizeDecimals(finalAmount, _decimalRate) + deNormalizeDecimals(feeCutToService, _decimalRate) + dust);
    }


    function test_getFeeDetails_pass3() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 2000; // 20%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 5000; // 50%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });
        uint256 amount = 1 ether; 
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
        
        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(finalAmount,_decimalRate)  < amount);
        assert(feeCutToService > 0);
        assert(relayerReward > 0);
        assertEq(amount, deNormalizeDecimals(finalAmount, _decimalRate) + deNormalizeDecimals(feeCutToService, _decimalRate) + dust);


         // Updating the cm, _vm
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 3000; // 30%
            uint64 _vm = 3000; // 30%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        (uint64 _finalAmount, uint64 _feeCutToService, uint64 _relayerReward, uint256 _dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
        
        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(_finalAmount,_decimalRate)  < amount);
        assert(_feeCutToService > 0);
        assert(_relayerReward > 0);
        assertEq(amount, deNormalizeDecimals(_finalAmount, _decimalRate) + deNormalizeDecimals(_feeCutToService, _decimalRate) + dust);

        assert(_finalAmount < finalAmount);
        assert(_feeCutToService > feeCutToService);
        assert(_relayerReward > relayerReward);
    }

    function test_getFeeDetails_pass4_usdc() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 5000; // 50%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 5000; // 50%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }

        address tokenAddr = address(usdc);
        address uni_pool = address(uniswapV3Pool_USDC_USDT);
        bool isBridgeTokenBaseToken = true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        uint256 amount = 1 ether; 
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
        
        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(finalAmount,_decimalRate)  < amount);
        assert(feeCutToService > 0);
        assert(relayerReward > 0);
        assertEq(amount, deNormalizeDecimals(finalAmount, _decimalRate) + deNormalizeDecimals(feeCutToService, _decimalRate) + dust);
    }

    function test_getFixedFeeDetails_pass() external {
        // Setup required configs first
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 9990; // 99.90%
            uint64 _vm = 2000; // 20%
            uint64 x = 20; 

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 8000; // 80%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %
            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address uni_pool = address(0); // not needed
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info with fixed fees
        uint64 fixedServiceFeeAmount = 0.0003 ether;
        uint64 fixedRelayerRewardAmount = 0.0001 ether;
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: true,
            fixedServiceFee: fixedServiceFeeAmount,
            fixedRelayerReward: fixedRelayerRewardAmount
        });

        uint256 amount = 1 ether; 
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
        
        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(finalAmount,_decimalRate)  < amount);
        assert(feeCutToService > 0);
        assert(relayerReward > 0);
        assert(fixedServiceFeeAmount == deNormalizeDecimals(feeCutToService, _decimalRate));
        assert(fixedRelayerRewardAmount == deNormalizeDecimals(relayerReward, _decimalRate));        
        assertEq(amount, deNormalizeDecimals(finalAmount, _decimalRate) + deNormalizeDecimals(feeCutToService, _decimalRate) + dust);

        // check when no fees
        ITokenBridgeService.TokenInfo memory tokenInfoNoFees = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: true,
            fixedServiceFee: 0, // no fees
            fixedRelayerReward: 0 // no fees
        });

        (uint64 finalAmount_2, uint64 feeCutToService_2, uint64 relayerReward_2, uint256 dust_2) = feeOperator.getFeeDetails(toChainId, amount, tokenInfoNoFees);

        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(finalAmount_2,_decimalRate)  == amount); // no fees
        assert(feeCutToService_2 == 0);
        assert(relayerReward_2 == 0);
        assert(dust_2 == 0);

    }

    function test_getFeeDetails_tierStandard() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 10_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 70; // 0.7%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        uint256 amount = 10 ether; 
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
        
        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(finalAmount,_decimalRate)  < amount);
        assert(feeCutToService > 0);
        assert(relayerReward > 0);
        assertEq(amount, deNormalizeDecimals(finalAmount, _decimalRate) + deNormalizeDecimals(feeCutToService, _decimalRate) + dust);
    }

    function test_getFeeDetails_tierWhale() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 10_000000;
            uint128 tierWhaleUSDT = 20_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 70; // 0.7%
            uint64 tierWhalePercentage = 40; // 0.4 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0            
        });

        uint256 amount = 10 ether; 
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
        
        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(finalAmount,_decimalRate)  < amount);
        assert(feeCutToService > 0);
        assert(relayerReward > 0);
        assertEq(amount, deNormalizeDecimals(finalAmount, _decimalRate) + deNormalizeDecimals(feeCutToService, _decimalRate) + dust);
    }

    function test_Revert_getTBFeeConfig_When_Paused() external {
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        
        // Pause FeeOperator
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IFeeOperator.FeeOperatorPauseState(ADMIN, true);
        feeOperator.changeState(true);

        vm.expectRevert(foErrors.FeeOperatorPaused.selector);
        feeOperator.getTBFeeConfig(6);
    }

    function test_Revert_getFeeDetails_When_Paused() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        uint256 amount = 1 ether; 
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
        
        // Verify that the amounts are calculated correctly
        assert(deNormalizeDecimals(finalAmount,_decimalRate)  < amount);
        assert(feeCutToService > 0);
        assert(relayerReward > 0);
        assertEq(amount, deNormalizeDecimals(finalAmount, _decimalRate) + deNormalizeDecimals(feeCutToService, _decimalRate) + dust);

        // Pausing
        vm.prank(ADMIN);
        feeOperator.changeState(true);

        vm.expectRevert(foErrors.FeeOperatorPaused.selector);
        (finalAmount, feeCutToService, relayerReward, dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);


        // UnPausing
        vm.prank(ADMIN);
        feeOperator.changeState(false);
        (finalAmount, feeCutToService, relayerReward, dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
    }

    function test_Revert_getFeeDetails_When_Margins_are_high_and_insufficient_amount() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 9999; // 99.99%
            uint64 _vm = 9999; // 99.99%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 9999; // 99.99%
            uint64 sm = 9999; // 99.99%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        uint256 amount = 2 ether; 
        vm.expectRevert();
        (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
    }

    function test_getAmountInUsdtAndtRelayerRewardInBridgedAsset_pass1() external {
        // Check 1
        uint256 amount = 1 ether; // 1 Ether
        // Test with a known relayer reward in SUPRA
        uint64 relayerRewardInSupra = 1_00000000; // 1 SUPRA
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        // Get the price feed from mock
        ISupraSValueFeed.priceFeed memory supraPriceInUsdt = sValueFeed.getSvalue(supraUsdtPairIndex);
        // Calculate expected reward in USDT
        uint256 expectedRewardInUsdt = (supraPriceInUsdt.price * relayerRewardInSupra) / 10 ** feeOperator.NORMALIZED_DECIMALS();
        uint256 relayerRewardInUsdt = feeOperator.getRelayerRewardInUsdt(relayerRewardInSupra);
        (uint256 tokenAmountInUsdt, uint256 relayerRewardInBridgedAsset) = feeOperator.getAmountInUsdtAndtRelayerRewardInBridgedAsset(uni_pool, amount, isBridgeTokenBaseToken, relayerRewardInUsdt);

        // Verify the reward is calculated correctly
        assertEq(relayerRewardInUsdt, expectedRewardInUsdt);
        assertNotEq(relayerRewardInBridgedAsset, 0);
        assertNotEq(tokenAmountInUsdt, 0);
    }
    function test_getAmountInUsdtAndtRelayerRewardInBridgedAsset_pass2() external {
        // Check 1
        uint256 amount = 2 ether; // 2 Ether
        // Test with a known relayer reward in SUPRA
        uint64 relayerRewardInSupra = 2_00000000; // 2 SUPRA
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        // Get the price feed from mock
        ISupraSValueFeed.priceFeed memory supraPriceInUsdt = sValueFeed.getSvalue(supraUsdtPairIndex);
        // Calculate expected reward in USDT
        uint256 expectedRewardInUsdt = (supraPriceInUsdt.price * relayerRewardInSupra) / 10 ** feeOperator.NORMALIZED_DECIMALS();
        uint256 relayerRewardInUsdt = feeOperator.getRelayerRewardInUsdt(relayerRewardInSupra);
        (uint256 tokenAmountInUsdt, uint256 relayerRewardInBridgedAsset) = feeOperator.getAmountInUsdtAndtRelayerRewardInBridgedAsset(uni_pool, amount, isBridgeTokenBaseToken, relayerRewardInUsdt);

        // Verify the reward is calculated correctly
        assertEq(relayerRewardInUsdt, expectedRewardInUsdt);
        assertNotEq(relayerRewardInBridgedAsset, 0);
        assertNotEq(tokenAmountInUsdt, 0);
    }
    function test_getAmountInUsdtAndtRelayerRewardInBridgedAsset_pass3() external {
        // Check 1
        uint256 amount = 0.5 ether; // 0.5 Ether
        // Test with a known relayer reward in SUPRA
        uint64 relayerRewardInSupra = 5_0000000; // 0.5 SUPRA
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        // Get the price feed from mock
        ISupraSValueFeed.priceFeed memory supraPriceInUsdt = sValueFeed.getSvalue(supraUsdtPairIndex);
        // Calculate expected reward in USDT
        uint256 expectedRewardInUsdt = (supraPriceInUsdt.price * relayerRewardInSupra) / 10 ** feeOperator.NORMALIZED_DECIMALS();
        uint256 relayerRewardInUsdt = feeOperator.getRelayerRewardInUsdt(relayerRewardInSupra);
        (uint256 tokenAmountInUsdt, uint256 relayerRewardInBridgedAsset) = feeOperator.getAmountInUsdtAndtRelayerRewardInBridgedAsset(uni_pool, amount, isBridgeTokenBaseToken, relayerRewardInUsdt);

        // Verify the reward is calculated correctly
        assertEq(relayerRewardInUsdt, expectedRewardInUsdt);
        assertNotEq(relayerRewardInBridgedAsset, 0);
        assertNotEq(tokenAmountInUsdt, 0);
    }
    function test_getAmountInUsdtAndtRelayerRewardInBridgedAsset_pass4() external {
        // Check 1
        uint256 amount = 0.001 ether; // 0.001 Ether
        // Test with a known relayer reward in SUPRA
        uint64 relayerRewardInSupra = 186495; // 186495 $Quant
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        // Get the price feed from mock
        ISupraSValueFeed.priceFeed memory supraPriceInUsdt = sValueFeed.getSvalue(supraUsdtPairIndex);
        // Calculate expected reward in USDT
        uint256 expectedRewardInUsdt = (supraPriceInUsdt.price * relayerRewardInSupra) / 10 ** feeOperator.NORMALIZED_DECIMALS();
        uint256 relayerRewardInUsdt = feeOperator.getRelayerRewardInUsdt(relayerRewardInSupra);
        (uint256 tokenAmountInUsdt, uint256 relayerRewardInBridgedAsset) = feeOperator.getAmountInUsdtAndtRelayerRewardInBridgedAsset(uni_pool, amount, isBridgeTokenBaseToken, relayerRewardInUsdt);

        // Verify the reward is calculated correctly
        assertEq(relayerRewardInUsdt, expectedRewardInUsdt);
        assertNotEq(relayerRewardInBridgedAsset, 0);
        assertNotEq(tokenAmountInUsdt, 0);
    }
    function test_getAmountInUsdtAndtRelayerRewardInBridgedAsset_pass5() external {
        // Check 1
        uint256 amount = 12; 
        // Test with a known relayer reward in SUPRA
        uint64 relayerRewardInSupra = 186495; // 1 SUPRA
        address uni_pool = address(uniswapV3Pool_USDC_USDT); 
        bool isBridgeTokenBaseToken = true;
        // Get the price feed from mock
        ISupraSValueFeed.priceFeed memory supraPriceInUsdt = sValueFeed.getSvalue(supraUsdtPairIndex);
        // Calculate expected reward in USDT
        uint256 expectedRewardInUsdt = (supraPriceInUsdt.price * relayerRewardInSupra) / 10 ** feeOperator.NORMALIZED_DECIMALS();
        uint256 relayerRewardInUsdt = feeOperator.getRelayerRewardInUsdt(relayerRewardInSupra);
        (uint256 tokenAmountInUsdt, uint256 relayerRewardInBridgedAsset) = feeOperator.getAmountInUsdtAndtRelayerRewardInBridgedAsset(uni_pool, amount, isBridgeTokenBaseToken, relayerRewardInUsdt);

        // Verify the reward is calculated correctly
        assertEq(relayerRewardInUsdt, expectedRewardInUsdt);
        assertNotEq(relayerRewardInBridgedAsset, 0);
        assertNotEq(tokenAmountInUsdt, 0);
    }

    function test_Revert_getFeeDetails_When_HN_TB_Config_Not_Enabled() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = false;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = false;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        uint256 amount = 1 ether; 
        vm.expectRevert();
        (uint64 _finalAmount, uint64 _feeCutToService, uint64 _relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
    }

    function test_Revert_getFeeDetails_When_HN_Config_Not_Enabled() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = false;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        uint256 amount = 1 ether; 
        vm.expectRevert();
        (uint64 _finalAmount, uint64 _feeCutToService, uint64 _relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
    }

    function test_Revert_getFeeDetails_When_TB_Config_Not_Enabled() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = false;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        uint256 amount = 1 ether; 
        vm.expectRevert();
        (uint64 _finalAmount, uint64 _feeCutToService, uint64 _relayerReward, uint256 dust) = feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
    }

    function test_Revert_getFeeDetails_When_TokenNotRegistered() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }
        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: false,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        uint256 amount = 1 ether;
        vm.expectRevert();
        feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
    }

    function test_Revert_getFeeDetails_When_InsufficientAmount() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 9999; // 99.99%
            uint64 _vm = 9999; // 99.99%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 9999; // 99.99%
            uint64 sm = 9999; // 99.99%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }

        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        // Use a very small amount that will be less than total fees
        uint256 amount = 1;
        vm.expectRevert();
        feeOperator.getFeeDetails(toChainId, amount, tokenInfo);
    }

    function test_Revert_getFeeDetails_EdgeCases_Min_Amount() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }

        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        // Test with very small amount
        uint64 smallAmount = 1 wei;
        vm.expectRevert();
        (uint64 finalAmount1, uint64 feeCutToService1, uint64 relayerReward1, uint256 dust) = feeOperator.getFeeDetails(toChainId, smallAmount, tokenInfo);
    }

    function test_getFeeDetails_EdgeCases_Max_Amount() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }

        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });
        // Test with very large amount
        uint64 largeAmount = type(uint64).max;
        (uint64 finalAmount2, uint64 feeCutToService2, uint64 relayerReward2, uint256 dust) = feeOperator.getFeeDetails(toChainId, largeAmount, tokenInfo);

        assert(deNormalizeDecimals(finalAmount2,_decimalRate)  < largeAmount);
        assert(feeCutToService2 > 0);
        assert(relayerReward2 > 0);
        assertEq(largeAmount, deNormalizeDecimals(finalAmount2, _decimalRate) + deNormalizeDecimals(feeCutToService2, _decimalRate) + dust);
    }

    function test_getFeeDetails_TierBoundaries() external {
        // Setup required configs first
        uint64 toChainId;
        {
            toChainId = 6;
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; // traffic

            vm.startPrank(ADMIN);
            adminHNSetup(
                enabled,
                toChainId,
                cg,
                cm,
                _vm,
                x
            );
            vm.stopPrank();
        }
        {
            toChainId = 6;
            bool enabled = true;
            uint256 rg = 5000000;
            uint64 rm = 2000; // 20%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 10_000000; // 10 USDT
            uint128 tierWhaleUSDT = 20_000000; // 20 USDT
            uint64 tierMicroPercentage = 0; // 0%
            uint64 tierStandardPercentage = 50; // 0.5%
            uint64 tierWhalePercentage = 30; // 0.3 %

            vm.startPrank(ADMIN);
            adminFOSetup(
                address(sValueFeed),
                supraUsdtPairIndex,
                enabled,
                toChainId,
                rg,
                rm,
                sm,
                tierMicroUSDT,
                tierWhaleUSDT,
                tierMicroPercentage,
                tierStandardPercentage,
                tierWhalePercentage
            );
            vm.stopPrank();
        }

        address tokenAddr = address(weth);
        address uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        (, bytes memory queriedDecimals) = tokenAddr.staticcall(abi.encodeWithSignature("decimals()"));
        uint8 originalDecimals = abi.decode(queriedDecimals, (uint8));
        uint256 _decimalRate = originalDecimals > tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS()
            ? 10 ** (originalDecimals - tokenBridge.MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS())
            : 1;
        // Setup token info
        ITokenBridgeService.TokenInfo memory tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });

        {
            // Test micro tier boundary
            uint64 microAmount = 0.001 ether; // Should be in micro tier
            (uint64 finalAmount1, uint64 feeCutToService1, uint64 relayerReward1, uint256 dust) = feeOperator.getFeeDetails(toChainId, microAmount, tokenInfo);
            assert(deNormalizeDecimals(finalAmount1,_decimalRate)  < microAmount);
            assert(feeCutToService1 > 0);
            assert(relayerReward1 > 0);
            assertEq(microAmount, deNormalizeDecimals(finalAmount1, _decimalRate) + deNormalizeDecimals(feeCutToService1, _decimalRate) + dust);
        }
        {
            // Test standard tier boundary
            uint64 standardAmount = 0.01 ether; // Should be in standard tier
            (uint64 finalAmount2, uint64 feeCutToService2, uint64 relayerReward2, uint256 dust2) = feeOperator.getFeeDetails(toChainId, standardAmount, tokenInfo);
            assert(deNormalizeDecimals(finalAmount2,_decimalRate)  < standardAmount);
            assert(feeCutToService2 > 0);
            assert(relayerReward2 > 0);
            assertEq(standardAmount, deNormalizeDecimals(finalAmount2, _decimalRate) + deNormalizeDecimals(feeCutToService2, _decimalRate) + dust2);
        
        }

        {
            // Test whale tier boundary
            uint64 whaleAmount = 0.1 ether; // Should be in whale tier
            (uint64 finalAmount3, uint64 feeCutToService3, uint64 relayerReward3, uint256 dust3) = feeOperator.getFeeDetails(toChainId, whaleAmount, tokenInfo);
            assert(deNormalizeDecimals(finalAmount3,_decimalRate)  < whaleAmount);
            assert(feeCutToService3 > 0);
            assert(relayerReward3 > 0);
            assertEq(whaleAmount, deNormalizeDecimals(finalAmount3, _decimalRate) + deNormalizeDecimals(feeCutToService3, _decimalRate) + dust3);
        }
    }

    function test_Revert_computeRelayerReward_When_ZeroValue() external {
        uint64 v = 0;
        uint256 rg = 100;
        uint64 rm = 2000;
        vm.expectRevert();
        feeOperator.computeRelayerReward(v, rg, rm);
    }

    function test_Revert_computeRelayerReward_When_ZeroRG() external {
        uint64 v = 100;
        uint256 rg = 0;
        uint64 rm = 2000;
        vm.expectRevert();
        feeOperator.computeRelayerReward(v, rg, rm);
    }

    function test_Revert_computeRelayerReward_When_InvalidMargin() external {
        uint64 v = 100;
        uint256 rg = 100;
        uint64 rm = PERCENTAGE_BASE; // 100%
        vm.expectRevert();
        feeOperator.computeRelayerReward(v, rg, rm);
    }

    function test_Revert_computeServiceFee_When_ZeroValue() external {
        uint256 amount = 0.5 ether;
        uint256 tokenAmountInUsdt = 0;
        uint64 relayerRewardInBridgedAsset = 100;
        IFeeOperator.FeeConfig memory _tbFeeConfig = IFeeOperator.FeeConfig({
            enabled: true,
            rg: 100,
            rm: 2000,
            sm: 1000,
            tierMicroUSDT: 100,
            tierWhaleUSDT: 1000,
            tierMicroPercentage: 500,
            tierStandardPercentage: 1000,
            tierWhalePercentage: 1500
        });
        vm.expectRevert();
        feeOperator.computeServiceFee(amount, tokenAmountInUsdt, relayerRewardInBridgedAsset, _tbFeeConfig);

        vm.expectRevert();
        feeOperator.computeServiceFee(0, tokenAmountInUsdt, relayerRewardInBridgedAsset, _tbFeeConfig);
    }

    function test_Revert_computeServiceFee_When_ZeroRelayerReward() external {
        uint256 amount = 0.5 ether;
        uint256 tokenAmountInUsdt = 100;
        uint64 relayerRewardInBridgedAsset = 0;
        IFeeOperator.FeeConfig memory _tbFeeConfig = IFeeOperator.FeeConfig({
            enabled: true,
            rg: 100,
            rm: 2000,
            sm: 1000,
            tierMicroUSDT: 100,
            tierWhaleUSDT: 1000,
            tierMicroPercentage: 500,
            tierStandardPercentage: 1000,
            tierWhalePercentage: 1500
        });
        vm.expectRevert();
        feeOperator.computeServiceFee(amount, tokenAmountInUsdt, relayerRewardInBridgedAsset, _tbFeeConfig);
    }

    function test_Revert_computeServiceFee_When_InvalidMicroPercentage() external {
        uint256 amount = 0.5 ether;
        uint256 tokenAmountInUsdt = 100;
        uint64 relayerRewardInBridgedAsset = 100;
        IFeeOperator.FeeConfig memory _tbFeeConfig = IFeeOperator.FeeConfig({
            enabled: true,
            rg: 100,
            rm: 2000,
            sm: 1000,
            tierMicroUSDT: 100,
            tierWhaleUSDT: 1000,
            tierMicroPercentage: PERCENTAGE_BASE + 1, // Invalid percentage > 100%
            tierStandardPercentage: 1000,
            tierWhalePercentage: 1500
        });
        vm.expectRevert();
        feeOperator.computeServiceFee(amount, tokenAmountInUsdt, relayerRewardInBridgedAsset, _tbFeeConfig);
    }

    function test_Revert_computeServiceFee_When_InvalidStandardPercentage() external {
        uint256 amount = 0.5 ether;
        uint256 tokenAmountInUsdt = 100;
        uint64 relayerRewardInBridgedAsset = 100;
        IFeeOperator.FeeConfig memory _tbFeeConfig = IFeeOperator.FeeConfig({
            enabled: true,
            rg: 100,
            rm: 2000,
            sm: 1000,
            tierMicroUSDT: 100,
            tierWhaleUSDT: 1000,
            tierMicroPercentage: 500,
            tierStandardPercentage: PERCENTAGE_BASE + 1, // Invalid percentage > 100%
            tierWhalePercentage: 1500
        });
        vm.expectRevert();
        feeOperator.computeServiceFee(amount, tokenAmountInUsdt, relayerRewardInBridgedAsset, _tbFeeConfig);
    }

    function test_Revert_computeServiceFee_When_InvalidWhalePercentage() external {
        uint256 amount = 0.5 ether;
        uint256 tokenAmountInUsdt = 100;
        uint64 relayerRewardInBridgedAsset = 100;
        IFeeOperator.FeeConfig memory _tbFeeConfig = IFeeOperator.FeeConfig({
            enabled: true,
            rg: 100,
            rm: 2000,
            sm: 1000,
            tierMicroUSDT: 100,
            tierWhaleUSDT: 1000,
            tierMicroPercentage: 500,
            tierStandardPercentage: 1000,
            tierWhalePercentage: PERCENTAGE_BASE + 1 // Invalid percentage > 100%
        });
        vm.expectRevert();
        feeOperator.computeServiceFee(amount, tokenAmountInUsdt, relayerRewardInBridgedAsset, _tbFeeConfig);
    }

    function test_Revert_computeServiceFee_When_ConfigNotEnabled() external {
        uint256 amount = 0.5 ether;
        uint256 tokenAmountInUsdt = 100;
        uint64 relayerRewardInBridgedAsset = 100;
        IFeeOperator.FeeConfig memory _tbFeeConfig = IFeeOperator.FeeConfig({
            enabled: false,
            rg: 100,
            rm: 2000,
            sm: 1000,
            tierMicroUSDT: 100,
            tierWhaleUSDT: 1000,
            tierMicroPercentage: 500,
            tierStandardPercentage: 1000,
            tierWhalePercentage: 1500
        });
        vm.expectRevert();
        feeOperator.computeServiceFee(amount, tokenAmountInUsdt, relayerRewardInBridgedAsset, _tbFeeConfig);
    }


    // Utils
    function normalizeDecimals(uint256 _amount, uint256 _decimalRate) internal pure returns (uint256){
        return (_amount / _decimalRate);
    }
    function deNormalizeDecimals(uint256 _amount, uint256 _decimalRate) internal pure returns (uint256){
        return (_amount * _decimalRate);
    }
}
