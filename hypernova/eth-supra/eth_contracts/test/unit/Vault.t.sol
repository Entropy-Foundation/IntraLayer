// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {Errors as hnErrors} from "contracts/hypernova-core/implementations/Errors.sol";
import {Errors as tbErrors} from "contracts/tokenBridge-service/implementations/Errors.sol";
import {Errors as vtErrors} from "contracts/token-vault/implementations/Errors.sol";
import {console} from "forge-std/console.sol";
import {InitDeploy} from "test/InitDeploy.t.sol";
import {IVault} from "contracts/interfaces/IVault.sol";
import {TokenBridgeImplementation} from "contracts/tokenBridge-service/implementations/TokenBridgeImplementation.sol";
import {VaultImplementation} from "contracts/token-vault/implementations/VaultImplementation.sol";
import {TokenVault} from "contracts/token-vault/TokenVault.sol";

contract VaultTest is InitDeploy {
    function setUp() public {
        init();
    }
    function test_initialize() external {
        address attacker = address(0xdead);
        address _admin = vm.addr(2);
        address _tokenBridgeService =  vm.addr(3);
        uint256 _delay =  5;

        VaultImplementation newVaultImpl = new VaultImplementation();
        
        vm.prank(attacker);
        vm.expectRevert();
        newVaultImpl.initialize(address(0xdead), _tokenBridgeService, _delay);

        vm.prank(ADMIN);
        IVault newVault = IVault(address(new TokenVault(address(newVaultImpl), "")));
        newVault.initialize(_admin, _tokenBridgeService, _delay);

        VaultImplementation newVaultImpl2 = new VaultImplementation();
        vm.prank(attacker);
        vm.expectRevert();
        newVaultImpl.initialize(attacker, _tokenBridgeService, _delay);

        vm.prank(attacker);
        vm.expectRevert();
        newVault.upgradeImplementation(address(newVaultImpl2));

        vm.prank(_admin);
        newVault.upgradeImplementation(address(newVaultImpl2));

        vm.prank(attacker);
        vm.expectRevert();
        newVaultImpl2.initialize(attacker, _tokenBridgeService, _delay);


        vm.prank(_admin);
        vm.expectRevert();
        newVault.initialize(_admin, _tokenBridgeService, _delay);
        
        assertEq(newVault.admin(), _admin);
    }
    function test_changeState() external {
        vm.prank(ADMIN);
        vault.changeState(true);
        assert(vault.checkIsVaultPaused() == true);
    }

    function test_Revert_changeStateWhenCallerNotAdmin() external {
        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.changeState(true);
    }

    function test_setLockLimits() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
    }
    function test_setLockLimits_Two_Tokens() external {
        address[] memory _tokens = new address[](2);
        _tokens[0] = address(mockERC20);
        _tokens[1] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](2);
        _maxAmounts[0] = 1 ether;
        _maxAmounts[1] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](2);
        _minAmounts[0] = 2;
        _minAmounts[1] = 2;
        uint256[] memory _globalMax = new uint256[](2);
        _globalMax[0] = 100 ether;
        _globalMax[1] = 200 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        (uint256 min, uint256 max, uint256 _gMax) = vault.getLockLimits(address(mockERC20));
        assertEq(min, 2);
        assertEq(max, 1 ether);
        assertEq(_gMax, 100 ether);
        (min, max, _gMax) = vault.getLockLimits(address(weth));
        assertEq(min, 2);
        assertEq(max, 1 ether);
        assertEq(_gMax, 200 ether);
    }


    function test_Revert_setLockLimitsWhenCallerNotAdmin() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
    }

    function test_Revert_setLockLimitsWhenTokenAddressIsZero() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(0);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
    }

    function test_Revert_setLockLimitsWhenLengthMistMatch() external {
        address[] memory _tokens = new address[](2);
        _tokens[0] = address(mockERC20);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
    }

    function test_Revert_setLockLimitsWhenInvalidMinMax() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 2 ether;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);

        _maxAmounts[0] = 1 ether;
        _minAmounts[0] = 1 ether;
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
    }

    function test_setLockLimitsWhenGlobalMaxisZero() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 1 ether;
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 2 ether;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 0 ;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
    }

    function test_setReleaseLimits() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
    }
    function test_setReleaseLimits_Two_Tokens() external {
        address[] memory _tokens = new address[](2);
        _tokens[0] = address(mockERC20);
        _tokens[1] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](2);
        _maxAmounts[0] = 1 ether;
        _maxAmounts[1] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](2);
        _minAmounts[0] = 2;
        _minAmounts[1] = 2;
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
        (uint256 min, uint256 max) = vault.getReleaseLimits(address(mockERC20));
        assertEq(min, 2);
        assertEq(max, 1 ether);
        (min, max) = vault.getReleaseLimits(address(weth));
        assertEq(min, 2);
        assertEq(max, 1 ether);
    }
    function test_Revert_setReleaseLimitsWhenCallerNotAdmin() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
    }

    function test_Revert_setReleaseLimitsWhenTokenAddressIsZero() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(0);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
    }

    function test_Revert_setReleaseLimitsWhenLengthMistMatch() external {
        address[] memory _tokens = new address[](2);
        _tokens[0] = address(mockERC20);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
    }

    function test_Revert_setReleaseLimitsWhenInvalidMinMax() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 2 ether;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);

        _maxAmounts[0] = 1 ether;
        _minAmounts[0] = 1 ether;
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
    }


    function test_lockTokens() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(address(tokenBridge));
        vault.lockTokens(address(mockERC20), 100);
        assert(vault.getLockedTokenBalance(address(mockERC20)) == 100);
    }
    function test_lockTokens_Emit_Event() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(address(tokenBridge));
        vm.expectEmit(true, true, true, true);
        emit IVault.Locked(address(mockERC20), 100);
        vault.lockTokens(address(mockERC20), 100);
        assert(vault.getLockedTokenBalance(address(mockERC20)) == 100);
    }

    function test_Revert_lock_When_callerIsNotBridge() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.lockTokens(address(mockERC20), 100);
    }

    function test_Revert_lock_When_VaultIsPaused() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.startPrank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vault.changeState(true);
        vm.stopPrank();
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.VaultPaused.selector);
        vault.lockTokens(address(mockERC20), 100);
    }

    function test_Revert_lock_When_MinLimitReached() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.lockTokens(address(mockERC20), 5);
    }

    function test_Revert_lock_When_MaxLimitReached() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.lockTokens(address(mockERC20), 1.1 ether);
    }

    function test_lockNative() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 0.5 ether}(address(weth), 0.5 ether);
        assert(vault.getLockedTokenBalance(address(weth)) == 0.5 ether);
    }
    function test_Revert_lockNative_With_Other_ERC20_Without_Deposit_Implemented() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vm.expectRevert();
        vault.lockNative{value: 0.5 ether}(address(mockERC20), 0.5 ether);
    }

    function test_lockNative_Emit_Event() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);

        vm.expectEmit(true, true, false, false);
        emit IVault.Locked(address(weth), 0.5 ether);
        vm.deal(address(tokenBridge), 1 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 0.5 ether}(address(weth), 0.5 ether);
        assert(vault.getLockedTokenBalance(address(weth)) == 0.5 ether);
    }

    function test_Revert_lockNative_When_callerIsNotBridge() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.deal(vm.addr(1), 1 ether);
        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.lockNative{value: 0.5 ether}(address(weth), 0.5 ether);
    }

    function test_Revert_lockNative_When_VaultIsPaused() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        vm.prank(ADMIN);
        vault.changeState(true);
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.deal(address(tokenBridge), 1 ether);
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.VaultPaused.selector);
        vault.lockNative{value: 0.5 ether}(address(weth), 0.5 ether);
    }

    function test_Revert_lockNative_When_MinLimitReached() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.deal(address(tokenBridge), 10);
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.lockNative{value: 5}(address(weth), 5);
    }

    function test_Revert_lockNative_When_MaxLimitReached() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.deal(address(tokenBridge), 2 ether);
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.lockNative{value: 2 ether}(address(weth), 2 ether);
    }
    function test_Revert_lockNative_When_GlobalMaxLimitReached() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.deal(address(tokenBridge), 100 ether);
        for (uint i = 1; i<=9; i++) {
            vm.prank(address(tokenBridge));
            vault.lockNative{value: 10 ether}(address(weth), 10 ether);
        }
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.GlobaTokenLockLimitBreached.selector);
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        _globalMax[0] = 0; // No limit
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);

        vm.deal(address(tokenBridge), 1000 ether);
        for (uint i = 1; i<=100; i++) {
            vm.prank(address(tokenBridge));
            vault.lockNative{value: 10 ether}(address(weth), 10 ether);
        }
    }

    function test_Revert_lockNative_When_Amount_IsNotEqual_To_Value() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.deal(address(tokenBridge), 1 ether);
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.lockNative{value: 0.5 ether}(address(weth), 0.1 ether);
    }

    function test_release_native_token() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.startPrank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
        vm.stopPrank();

        vm.deal(address(tokenBridge), 0.5 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 0.5 ether}(address(weth), 0.5 ether);
        
        vm.prank(ADMIN);
        vault.changeReleaseState(true);
        
        vm.prank(address(tokenBridge));
        vault.release(address(weth), 100, vm.addr(1));
        assert(weth.balanceOf(vm.addr(1)) == 100);
    }

    function test_release_ERC20_token() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
        
        vm.startPrank(address(tokenBridge));
        mockERC20.mint(address(tokenBridge), 1 ether);
        mockERC20.transfer(address(vault), 100);
        vault.lockTokens(address(mockERC20), 100);
        vm.stopPrank();

        vm.prank(ADMIN);
        vault.changeReleaseState(true);
        vm.prank(address(tokenBridge));

        vault.release(address(mockERC20), 100, vm.addr(1));
        assert(mockERC20.balanceOf(vm.addr(1)) == 100);
    }
    function test_Revert_release_When_callerIsNotBridge() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(address(tokenBridge));
        vault.lockTokens(address(mockERC20), 100);
        
        vm.prank(ADMIN);
        vault.changeReleaseState(true);
        
        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.release(address(mockERC20), 100, vm.addr(1));
    }

    function test_Revert_release_When_VaultIsPaused() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(address(tokenBridge));
        vault.lockTokens(address(mockERC20), 100);

        vm.prank(ADMIN);
        vault.changeState(true);
        
        vm.prank(ADMIN);
        vault.changeReleaseState(true);

        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.VaultPaused.selector);
        vault.release(address(mockERC20), 100, vm.addr(1));
    }

    function test_Revert_release_When_MinLimitReached() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
        (uint256 min, uint256 max, uint256 gMax) = vault.getLockLimits(address(mockERC20));
        assertEq(min, 10);
        assertEq(max, 1 ether);
        assertEq(gMax, 100 ether);
        (min, max) = vault.getReleaseLimits(address(mockERC20));
        assertEq(min, 10);
        assertEq(max, 1 ether);

        vm.prank(address(tokenBridge));
        vault.lockTokens(address(mockERC20), 0.5 ether);
        
        vm.prank(ADMIN);
        vault.changeReleaseState(true);
        
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.release(address(mockERC20), 5 , vm.addr(1));
    }

    function test_Revert_release_When_MaxLimitReached() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
        (uint256 min, uint256 max, uint256 gMax) = vault.getLockLimits(address(mockERC20));
        assertEq(min, 10);
        assertEq(max, 1 ether);
        assertEq(gMax, 100 ether);

        (min, max) = vault.getReleaseLimits(address(mockERC20));
        assertEq(min, 10);
        assertEq(max, 1 ether);

        vm.prank(address(tokenBridge));
        vault.lockTokens(address(mockERC20), 0.5 ether);
        
        vm.prank(ADMIN);
        vault.changeReleaseState(true);
        
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.release(address(mockERC20), 1.1 ether, vm.addr(1));
    }

    function test_Revert_release_When_userAddressIsZeroAddress() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);

        vm.prank(address(tokenBridge));
        vault.lockTokens(address(mockERC20), 100);

        vm.prank(ADMIN);
        vault.changeReleaseState(true);

        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.release(address(mockERC20), 100, address(0));
    }

    function test_Revert_release_When_amountIsZero() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);

        vm.prank(address(tokenBridge));
        vault.lockTokens(address(mockERC20), 100);

        vm.prank(ADMIN);
        vault.changeReleaseState(true);

        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.release(address(mockERC20), 0, vm.addr(1));
    }

    function test_Revert_release_When_tokenAddressIsZero() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.prank(address(tokenBridge));
        vault.lockTokens(address(mockERC20), 100);

        vm.prank(ADMIN);
        vault.changeReleaseState(true);

        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.release(address(0), 100, vm.addr(1));
    }

    function testAdminWithdraw() public {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);
        assertEq(vault.getLockedTokenBalance(address(weth)), 10 ether);

        address to = address(0xdead);
        uint256 amount = 10 ether;
        bytes32 expectedId = vault.getId(
            address(weth),
            amount,
            to,
            0
        );

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IVault.AdminWithdrawAdded(expectedId, address(weth), to, amount, 0, block.timestamp);
        bytes32 id = vault.addAdminWithdraw(address(weth), amount, to);

        assertEq(id, expectedId);
        assertEq(amount, vault.getAdminTransfers(id).amount);
        assertEq(to, vault.getAdminTransfers(id).to);
        assertEq(address(weth), vault.getAdminTransfers(id).token);
        assertEq(0, vault.getAdminTransfers(id).nonce);
        assertEq(block.timestamp, vault.getAdminTransfers(id).timestamp);
        assertEq(true, vault.getAdminTransfers(id).isAdded);
        
        assertEq(weth.balanceOf(to), 0);

        vm.warp(block.timestamp + vault.getAdminWithdrawDelay() + 1);
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IVault.AdminWithdrawExecuted(expectedId, address(weth), to, amount, 0, block.timestamp);
        vault.execAdminWithdraw(id);
        assertEq(false, vault.getAdminTransfers(id).isAdded);

        assertEq(weth.balanceOf(to), amount);
        assertEq(vault.getLockedTokenBalance(address(weth)), 0);
    }
    function test_upgradeImplementation() external {
        VaultImplementation newVaultImpl = new VaultImplementation();
        
        // Test upgrade by non-admin
        vm.prank(address(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.upgradeImplementation(address(newVaultImpl));

        // Test upgrade with zero address
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.upgradeImplementation(address(0));

        // Test successful upgrade
        vm.prank(ADMIN);
        vault.upgradeImplementation(address(newVaultImpl));
        assertEq(vault.getImplementationAddress(), address(newVaultImpl));
    }

    function test_Revert_initialize_When_AlreadyInitialized() external {
        VaultImplementation newVaultImpl = new VaultImplementation();
        vm.prank(ADMIN);
        IVault newVault = IVault(address(new TokenVault(address(newVaultImpl), "")));
        newVault.initialize(address(1), address(2), 5);

        vm.prank(ADMIN);
        vm.expectRevert();
        newVault.initialize(address(1), address(2), 5);
    }

    function test_Revert_initialize_When_ZeroAddresses() external {
        VaultImplementation newVaultImpl = new VaultImplementation();
        vm.prank(ADMIN);
        IVault newVault = IVault(address(new TokenVault(address(newVaultImpl), "")));

        // Test zero admin address
        vm.expectRevert(vtErrors.InvalidInput.selector);
        newVault.initialize(address(0), address(2), 5);

        // Test zero token bridge address
        vm.expectRevert(vtErrors.InvalidInput.selector);
        newVault.initialize(address(1), address(0), 5);
    }

    function test_Revert_initialize_When_InvalidDelay() external {
        VaultImplementation newVaultImpl = new VaultImplementation();
        vm.prank(ADMIN);
        IVault newVault = IVault(address(new TokenVault(address(newVaultImpl), "")));

        // Test zero delay
        vm.expectRevert(vtErrors.InvalidInput.selector);
        newVault.initialize(address(1), address(2), 0);
    }

    function test_setAdmin() external {
        address newAdmin = vm.addr(2);
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IVault.UpdatedAdmin(ADMIN, newAdmin);
        vault.setAdmin(newAdmin);
        vm.prank(newAdmin);
        vault.changeState(true);
        assert(vault.checkIsVaultPaused() == true);
    }

    function test_Revert_setAdmin_When_CallerNotAdmin() external {
        address newAdmin = vm.addr(2);
        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.setAdmin(newAdmin);
    }

    function test_setTokenBridgeContract() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);

        address newTokenBridge = vm.addr(3);
        vm.prank(ADMIN);
        vault.setTokenBridgeContract(newTokenBridge);
        vm.prank(newTokenBridge);
        vault.lockTokens(address(mockERC20), 100);
    }

    function test_Revert_setTokenBridgeContract_When_CallerNotAdmin() external {
        address newBridge = vm.addr(3);
        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.setTokenBridgeContract(newBridge);
    }

    function test_Revert_setTokenBridgeContract_When_VaultPaused() external {
        address newBridge = vm.addr(3);
        vm.startPrank(ADMIN);
        vault.changeState(true);
        vm.expectRevert(vtErrors.VaultPaused.selector);
        vault.setTokenBridgeContract(newBridge);
        vm.stopPrank();
    }

    function test_addAdminWithdraw() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);
        assertEq(vault.getLockedTokenBalance(address(weth)), 10 ether);

        address to = address(0xdead);
        uint256 amount = 10 ether;
        bytes32 expectedId = vault.getId(
            address(weth),
            amount,
            to,
            0
        );

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IVault.AdminWithdrawAdded(expectedId, address(weth), to, amount, 0, block.timestamp);
        bytes32 id = vault.addAdminWithdraw(address(weth), amount, to);

        assertEq(id, expectedId);
        assertEq(amount, vault.getAdminTransfers(id).amount);
        assertEq(to, vault.getAdminTransfers(id).to);
        assertEq(address(weth), vault.getAdminTransfers(id).token);
        assertEq(0, vault.getAdminTransfers(id).nonce);
        assertEq(block.timestamp, vault.getAdminTransfers(id).timestamp);
        assertEq(true, vault.getAdminTransfers(id).isAdded);
    }

    function test_addAdminWithdraw_multiple() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        address to = address(0xdead);
        uint256 amount = 10 ether;

        assertEq(vault.getNextWithdrawNonce(), 0);
        // First add
        vm.prank(ADMIN);
        bytes32 id = vault.addAdminWithdraw(address(weth), amount, to);
        assertNotEq(id, bytes32(0));
        // Try to add again with same parameters
        assertEq(vault.getNextWithdrawNonce(), 1);
        vm.prank(ADMIN);
        bytes32 _id = vault.addAdminWithdraw(address(weth), amount, to);
        assertNotEq(_id, bytes32(0));
        assertNotEq(id, _id);

    }

    function test_Revert_addAdminWithdraw_When_CallerNotAdmin() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        address to = address(0xdead);
        uint256 amount = 10 ether;

        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.addAdminWithdraw(address(weth), amount, to);
    }

    function test_Revert_addAdminWithdraw_When_InvalidInput() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        // Test with zero address
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.addAdminWithdraw(address(0), 10 ether, address(0xdead));

        // Test with zero amount
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.addAdminWithdraw(address(weth), 0, address(0xdead));

        // Test with zero to address
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.addAdminWithdraw(address(weth), 10 ether, address(0));
    }

    function test_Revert_addAdminWithdraw_When_InsufficientBalance() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        address to = address(0xdead);
        uint256 amount = 11 ether; // More than locked balance

        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InsufficientBalance.selector);
        vault.addAdminWithdraw(address(weth), amount, to);
    }

    function test_Revert_execAdminWithdraw_When_Withdraw_Removed() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        address to = address(0xdead);
        uint256 amount = 10 ether;
        vm.prank(ADMIN);
        bytes32 id = vault.addAdminWithdraw(address(weth), amount, to);

        // Remove the withdraw
        vm.prank(ADMIN);
        vault.removeAddedAdminWithdraw(id);

        // Try to execute the removed withdraw
        vm.warp(block.timestamp + vault.getAdminWithdrawDelay() + 1);
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(vtErrors.WithdrawDoesNotExist.selector, id));
        vault.execAdminWithdraw(id);
    }

    function test_Revert_upgradeImplementation_When_CallerNotAdmin() external {
        VaultImplementation newVaultImpl = new VaultImplementation();
        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.upgradeImplementation(address(newVaultImpl));
    }

    function test_removeAddedAdminWithdraw() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        address to = address(0xdead);
        uint256 amount = 10 ether;
        vm.prank(ADMIN);
        bytes32 id = vault.addAdminWithdraw(address(weth), amount, to);

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit IVault.AdminWithdrawRemoved(id, address(weth), to, amount, 0, block.timestamp);
        bytes32 removedId = vault.removeAddedAdminWithdraw(id);
        
        assertEq(removedId, id);
        assertEq(false, vault.getAdminTransfers(id).isAdded);
        
        // Verify that the withdraw cannot be executed after removal
        vm.warp(block.timestamp + vault.getAdminWithdrawDelay() + 1);
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(vtErrors.WithdrawDoesNotExist.selector, id));
        vault.execAdminWithdraw(id);
    }

    function test_Revert_removeAddedAdminWithdraw_When_CallerNotAdmin() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        address to = address(0xdead);
        uint256 amount = 10 ether;
        vm.prank(ADMIN);
        bytes32 id = vault.addAdminWithdraw(address(weth), amount, to);

        vm.prank(vm.addr(1));
        vm.expectRevert(vtErrors.UnauthorizedSender.selector);
        vault.removeAddedAdminWithdraw(id);
    }

    function test_Revert_removeAddedAdminWithdraw_When_WithdrawDoesNotExist() external {
        bytes32 nonExistentId = keccak256(abi.encodePacked("non-existent"));
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(vtErrors.WithdrawDoesNotExist.selector, nonExistentId));
        vault.removeAddedAdminWithdraw(nonExistentId);
    }

    function test_Revert_removeAddedAdminWithdraw_When_WithdrawAlreadyRemoved() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        address to = address(0xdead);
        uint256 amount = 10 ether;
        vm.prank(ADMIN);
        bytes32 id = vault.addAdminWithdraw(address(weth), amount, to);

        // First removal
        vm.prank(ADMIN);
        vault.removeAddedAdminWithdraw(id);

        // Try to remove again
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(vtErrors.WithdrawDoesNotExist.selector, id));
        vault.removeAddedAdminWithdraw(id);
    }


    function test_Revert_execAdminWithdraw_When_InsufficientBalance() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(weth);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 11 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);

        
        vm.deal(address(tokenBridge), 100 ether);
        vm.prank(address(tokenBridge));
        // Only lock, no amount sent
        vault.lockNative{value: 10 ether}(address(weth), 10 ether);

        address to = address(0xdead);
        uint256 amount = 10 ether;
        vm.prank(ADMIN);
        bytes32 id = vault.addAdminWithdraw(address(weth), amount, to);

        // Release some tokens to make balance insufficient
        vm.prank(ADMIN);
        vault.changeReleaseState(true);
        vm.prank(address(tokenBridge));
        vault.release(address(weth), 5 ether, vm.addr(1));

        // Try to execute the withdraw
        vm.warp(block.timestamp + vault.getAdminWithdrawDelay() + 1);
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InsufficientBalance.selector);
        vault.execAdminWithdraw(id);
    }

    // Missing branches in Helpers
    function test_Revert_setAdmin_When_ZeroAddress() external {
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setAdmin(address(0));
    }

    function test_Revert_setTokenBridgeService_When_ZeroAddress() external {
        vm.prank(ADMIN);
        vm.expectRevert(vtErrors.InvalidInput.selector);
        vault.setTokenBridgeContract(address(0));
    }

    function test_Revert_setAdminWithdrawDelay_When_ZeroDelay() external {
        vm.startPrank(ADMIN);
        vm.expectRevert();
        vault.initialize(address(0), address(tokenBridge), 5);
        vm.expectRevert();
        vault.initialize(ADMIN, address(tokenBridge), 0);
        vm.expectRevert();
        vault.initialize(ADMIN, address(0), 5);
        vm.stopPrank();
    }

    function test_Revert_release_When_ReleaseDisabled() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
        
        vm.startPrank(address(tokenBridge));
        mockERC20.mint(address(tokenBridge), 1 ether);
        mockERC20.transfer(address(vault), 100);
        vault.lockTokens(address(mockERC20), 100);
        vm.stopPrank();

        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.ReleaseDisabled.selector);
        vault.release(address(mockERC20), 100, vm.addr(1));
    }

    function test_Revert_release_When_InsufficientBalance() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
        
        vm.startPrank(address(tokenBridge));
        mockERC20.mint(address(tokenBridge), 1 ether);
        mockERC20.transfer(address(vault), 100);
        vault.lockTokens(address(mockERC20), 100);
        vm.stopPrank();

        vm.prank(ADMIN);
        vault.changeReleaseState(true);
        
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.InsufficientBalance.selector);
        vault.release(address(mockERC20), 200, vm.addr(1));
    }

    function test_Revert_release_When_ReleaseLimitBreached() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 1 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 10;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);
        
        vm.startPrank(address(tokenBridge));
        mockERC20.mint(address(tokenBridge), 1 ether);
        mockERC20.transfer(address(vault), 100);
        vault.lockTokens(address(mockERC20), 100);
        vm.stopPrank();

        vm.prank(ADMIN);
        vault.changeReleaseState(true);
        
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.release(address(mockERC20), 5, vm.addr(1)); // Amount less than min limit
    }

    function test_isValidLimit_Through_Lock_And_Release() external {
        address[] memory _tokens = new address[](1);
        _tokens[0] = address(mockERC20);
        uint256[] memory _maxAmounts = new uint256[](1);
        _maxAmounts[0] = 10 ether;
        uint256[] memory _minAmounts = new uint256[](1);
        _minAmounts[0] = 1 ether;
        uint256[] memory _globalMax = new uint256[](1);
        _globalMax[0] = 100 ether;
        vm.prank(ADMIN);
        vault.setLockLimits(_tokens, _minAmounts, _maxAmounts, _globalMax);
        vm.prank(ADMIN);
        vault.setReleaseLimits(_tokens, _minAmounts, _maxAmounts);

        // Test valid amount (5 is between 1 and 10)
        vm.startPrank(address(tokenBridge));
        mockERC20.mint(address(tokenBridge), 1.1 ether);
        mockERC20.transfer(address(vault), 1.1 ether);
        vault.lockTokens(address(mockERC20), 1.1 ether);
        assertEq(vault.getLockedTokenBalance(address(mockERC20)), 1.1 ether);
        vm.stopPrank();
        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.lockTokens(address(mockERC20), 1);

        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.lockTokens(address(mockERC20), 10.1 ether);

        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.lockTokens(address(mockERC20), 0);

        vm.prank(address(tokenBridge));
        vm.expectRevert(vtErrors.LimitBreached.selector);
        vault.lockTokens(address(mockERC20), 11 ether);

        // Test release with valid amount
        vm.prank(ADMIN);
        vault.changeReleaseState(true);
        vm.prank(address(tokenBridge));
        vault.release(address(mockERC20), 1.1 ether, vm.addr(1));
        assertEq(vault.getLockedTokenBalance(address(mockERC20)), 0);
    }
}