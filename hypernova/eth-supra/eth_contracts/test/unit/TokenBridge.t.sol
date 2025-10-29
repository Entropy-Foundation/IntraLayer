// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {Errors as hnErrors} from "contracts/hypernova-core/implementations/Errors.sol";
import {Errors as tbErrors} from "contracts/tokenBridge-service/implementations/Errors.sol";
import {Errors as vtErrors} from "contracts/token-vault/implementations/Errors.sol";
import {Errors as foErrors} from "contracts/fee-operator/implementations/Errors.sol";
import {console} from "forge-std/console.sol";
import {InitDeploy} from "test/InitDeploy.t.sol";
import {IHypernova} from "contracts/interfaces/IHypernova.sol";
import {ITokenBridgeService} from "contracts/interfaces/ITokenBridgeService.sol";
import {TokenBridgeImplementation} from "contracts/tokenBridge-service/implementations/TokenBridgeImplementation.sol";
import {TokenBridge} from "contracts/tokenBridge-service/TokenBridge.sol";
import {IWETH} from "contracts/interfaces/IWETH.sol";
import {IFeeOperator} from "contracts/interfaces/IFeeOperator.sol";
import {IVault} from "contracts/interfaces/IVault.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenBridgeTest is InitDeploy {
    function setUp() public {
        init();
    }

    function test_initialize() external {
        address _hypernova = vm.addr(1);
        address _admin = vm.addr(2);
        address _feeOperator = vm.addr(3);
        address _vault = vm.addr(4);
        address _nativeToken = vm.addr(5);

        TokenBridgeImplementation newTokenBridgeImpl = new TokenBridgeImplementation();
        
        vm.prank(address(1));
        vm.expectRevert();
        newTokenBridgeImpl.initialize(_hypernova, address(0xdead), _feeOperator, _vault, _nativeToken);

        vm.prank(ADMIN);
        ITokenBridgeService newTokenBridge = ITokenBridgeService(address(new TokenBridge(address(newTokenBridgeImpl), "")));
        newTokenBridge.initialize(_hypernova, _admin, _feeOperator, _vault, _nativeToken);

        TokenBridgeImplementation newTokenBridgeImpl2 = new TokenBridgeImplementation();
        vm.prank(address(1));
        vm.expectRevert();
        newTokenBridgeImpl.initialize(_hypernova, address(0xdead), _feeOperator, _vault, _nativeToken);

        vm.prank(address(1));
        vm.expectRevert();
        newTokenBridge.upgradeImplementation(address(newTokenBridgeImpl2));

        vm.prank(_admin);
        newTokenBridge.upgradeImplementation(address(newTokenBridgeImpl2));

        vm.prank(address(1));
        vm.expectRevert();
        newTokenBridgeImpl2.initialize(_hypernova, address(0xdead), _feeOperator, _vault, _nativeToken);

        vm.prank(_admin);
        vm.expectRevert();
        newTokenBridge.initialize(_hypernova, _admin, _feeOperator, _vault, _nativeToken);
        
        assertEq(address(newTokenBridge.getHypernova()), _hypernova);
        assertEq(address(newTokenBridge.admin()), _admin);
        assertEq(address(newTokenBridge.getFeeOperator()), _feeOperator);
        assertEq(address(newTokenBridge.getVault()), _vault);
        assertEq(address(newTokenBridge.getNativeToken()), _nativeToken);
    }

    function test_Revert_initialize_When_ZeroAddress() external {
        TokenBridgeImplementation newTokenBridge = new TokenBridgeImplementation();
        vm.expectRevert();
        newTokenBridge.initialize(address(0), ADMIN, address(feeOperator), address(vault), address(weth));
    }
    function test_setAdmin() external {
        address newAdmin = vm.addr(2);
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.UpdatedAdmin(ADMIN, newAdmin);
        tokenBridge.setAdmin(newAdmin);
        assertEq(tokenBridge.admin(), newAdmin);
        
        vm.prank(newAdmin);
        tokenBridge.changeState(true);
        assert(tokenBridge.checkIsTokenBridgePaused() == true);
    }

    function test_Revert_setAdmin_When_CallerNotAdmin() external {
        address newAdmin = vm.addr(2);
        vm.prank(vm.addr(1));
        vm.expectRevert(tbErrors.UnauthorizedSender.selector);
        tokenBridge.setAdmin(newAdmin);
    }

    function test_Revert_setAdmin_When_ZerorAddress() external {
        address newAdmin = address(0);
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.setAdmin(newAdmin);
    }

    function test_setHypernova() external {
        address newHypernova = vm.addr(2);
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.UpdatedHypernova(ADMIN, newHypernova);
        tokenBridge.setHypernova(newHypernova);
        assertEq(address(tokenBridge.getHypernova()), newHypernova);

    }

    function test_Revert_setHypernova_When_CallerNotAdmin() external {
        address newHypernova = vm.addr(2);
        vm.prank(vm.addr(1));
        vm.expectRevert(tbErrors.UnauthorizedSender.selector);
        tokenBridge.setHypernova(newHypernova);
    }

    function test_Revert_setHypernova_When_ZerorAddress() external {
        address newHypernova = address(0);
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.setHypernova(newHypernova);
    }

    function test_setFeeOperator() external {
        address newFeeOperator = vm.addr(2);
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.UpdatedFeeOperator(ADMIN, newFeeOperator);
        tokenBridge.setFeeOperator(newFeeOperator);
        assertEq(address(tokenBridge.getFeeOperator()), newFeeOperator);
    }

    function test_Revert_setFeeOperator_When_CallerNotAdmin() external {
        address newFeeOperator = vm.addr(2);
        vm.prank(vm.addr(1));
        vm.expectRevert(tbErrors.UnauthorizedSender.selector);
        tokenBridge.setFeeOperator(newFeeOperator);
    }

    function test_Revert_setFeeOperator_When_ZerorAddress() external {
        address newFeeOperator = address(0);
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.setFeeOperator(newFeeOperator);
    }

    function test_setVault() external {
        address newVault = vm.addr(2);
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.UpdatedVault(ADMIN, newVault);
        tokenBridge.setVault(newVault);
        assertEq(address(tokenBridge.getVault()), newVault);
    }

    function test_Revert_setVault_When_CallerNotAdmin() external {
        address newVault = vm.addr(2);
        vm.prank(vm.addr(1));
        vm.expectRevert(tbErrors.UnauthorizedSender.selector);
        tokenBridge.setVault(newVault);
    }

    function test_Revert_setVault_When_ZerorAddress() external {
        address newVault = address(0);
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.setVault(newVault);
    }

    function test_setNativeToken() external {
        address newNativeToken = vm.addr(2);
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.UpdatedNativeToken(ADMIN, newNativeToken);
        tokenBridge.setNativeToken(newNativeToken);
        assertEq(address(tokenBridge.getNativeToken()), newNativeToken);
    }

    function test_Revert_setNativeToken_When_CallerNotAdmin() external {
        address newNativeToken = vm.addr(2);
        vm.prank(vm.addr(1));
        vm.expectRevert(tbErrors.UnauthorizedSender.selector);
        tokenBridge.setNativeToken(newNativeToken);
    }

    function test_Revert_setNativeToken_When_ZerorAddress() external {
        address newNativeToken = address(0);
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.setNativeToken(newNativeToken);
    }

    function test_upgradeImplementation() external {
        TokenBridgeImplementation newTokenBridgeImpl = new TokenBridgeImplementation();
        
        // Test upgrade by non-admin
        vm.prank(address(1));
        vm.expectRevert(tbErrors.UnauthorizedSender.selector);
        tokenBridge.upgradeImplementation(address(newTokenBridgeImpl));

        // Test upgrade with zero address
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.upgradeImplementation(address(0));

        // Test successful upgrade
        vm.prank(ADMIN);
        tokenBridge.upgradeImplementation(address(newTokenBridgeImpl));
        assertEq(tokenBridge.getImplementationAddress(), address(newTokenBridgeImpl));
    }

    function test_Revert_initialize_When_AlreadyInitialized() external {
        TokenBridgeImplementation newTokenBridgeImpl = new TokenBridgeImplementation();
        vm.prank(ADMIN);
        ITokenBridgeService newTokenBridge = ITokenBridgeService(address(new TokenBridge(address(newTokenBridgeImpl), "")));
        newTokenBridge.initialize(address(1), address(2), address(3), address(4), address(5));

        vm.prank(ADMIN);
        vm.expectRevert();
        newTokenBridge.initialize(address(1), address(2), address(3), address(4), address(5));
    }

    function test_Revert_initialize_When_ZeroAddresses() external {
        TokenBridgeImplementation newTokenBridgeImpl = new TokenBridgeImplementation();
        vm.prank(ADMIN);
        ITokenBridgeService newTokenBridge = ITokenBridgeService(address(new TokenBridge(address(newTokenBridgeImpl), "")));

        // Test zero hypernova address
        vm.expectRevert(tbErrors.InvalidInput.selector);
        newTokenBridge.initialize(address(0), address(2), address(3), address(4), address(5));

        // Test zero admin address
        vm.expectRevert(tbErrors.InvalidInput.selector);
        newTokenBridge.initialize(address(1), address(0), address(3), address(4), address(5));

        // Test zero fee operator address
        vm.expectRevert(tbErrors.InvalidInput.selector);
        newTokenBridge.initialize(address(1), address(2), address(0), address(4), address(5));

        // Test zero vault address
        vm.expectRevert(tbErrors.InvalidInput.selector);
        newTokenBridge.initialize(address(1), address(2), address(3), address(0), address(5));

        // Test zero native token address
        vm.expectRevert(tbErrors.InvalidInput.selector);
        newTokenBridge.initialize(address(1), address(2), address(3), address(4), address(0));
    }

    function test_registerToken() external {
        vm.startPrank(ADMIN);
        uint256 min = 1;
        uint256 max = type(uint256).max;
        uint256 _globalMax = type(uint256).max;
        adminVaultSetup(min, max, _globalMax, address(weth));
        uint64 toChainId = 6;
        bool enableToChain = true;
        address tokenAddr = address(weth);
        address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        bool _register = true;
        adminTBSetup(
            toChainId, 
            enableToChain, 
            tokenAddr, 
            _uni_pool,
            _register
        );
        vm.stopPrank();

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.TokenRegistered(ADMIN, toChainId, tokenAddr, _register, _uni_pool, isBridgeTokenBaseToken);
        tokenBridge.registerToken(toChainId, tokenAddr, _uni_pool, _register);

        ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
        assertEq(tokenInfo.isRegistered, _register);
        assertEq(tokenInfo.uniswapPool, _uni_pool);
        assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
        assertEq(tokenInfo.decimalRate, 10**10);

        _register = false;
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.TokenRegistered(ADMIN, toChainId, tokenAddr, _register, _uni_pool, isBridgeTokenBaseToken);
        vm.prank(ADMIN);
        tokenBridge.registerToken(toChainId, tokenAddr, _uni_pool, _register);

        tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
        assertEq(tokenInfo.isRegistered, _register);
        assertEq(tokenInfo.uniswapPool, _uni_pool);
        assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
        assertEq(tokenInfo.decimalRate, 10**10);

        tokenAddr = address(usdc);
        _uni_pool = address(uniswapV3Pool_USDC_USDT);
        isBridgeTokenBaseToken = true;
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.TokenRegistered(ADMIN, toChainId, tokenAddr, _register, _uni_pool, isBridgeTokenBaseToken);
        vm.prank(ADMIN);
        tokenBridge.registerToken(toChainId, tokenAddr, _uni_pool, _register);

        tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
        assertEq(tokenInfo.isRegistered, _register);
        assertEq(tokenInfo.uniswapPool, _uni_pool);
        assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
        assertEq(tokenInfo.decimalRate, 1);

    }
    function test_registerToken_When_Token1IsBaseToken() external {
        vm.startPrank(ADMIN);
        uint256 min = 1;
        uint256 max = type(uint256).max;
        uint256 _globalMax = type(uint256).max;
        adminVaultSetup(min, max, _globalMax, address(weth));
        uint64 toChainId = 6;
        bool enableToChain = true;
        address tokenAddr = address(weth);
        address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool _register = true;
        adminTBSetup(
            toChainId, 
            enableToChain, 
            tokenAddr, 
            _uni_pool,
            _register
        );
        vm.stopPrank();

        // Create a mock pool where token1 is the base token
        address mockPool = address(new MockUniswapV3Pool(address(0x1), address(weth)));
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.TokenRegistered(ADMIN, toChainId, tokenAddr, _register, mockPool, false);
        tokenBridge.registerToken(toChainId, tokenAddr, mockPool, _register);

        ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
        assertEq(tokenInfo.isRegistered, _register);
        assertEq(tokenInfo.uniswapPool, mockPool);
        assertEq(tokenInfo.isBaseToken, false);
        assertEq(tokenInfo.decimalRate, 10**10);
        
    }
    function test_registerToken_Emit_Event() external {
        vm.startPrank(ADMIN);
        uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
        uint64 toChainId = 6;
        bool enableToChain = true;
        address tokenAddr = address(weth);
        address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
        bool _register = true;
        
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.ToChainRegistered(ADMIN, toChainId, enableToChain);
        tokenBridge.registerChainId(toChainId, enableToChain);

        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.TokenRegistered(ADMIN, toChainId, tokenAddr, _register, _uni_pool, isBridgeTokenBaseToken);
        tokenBridge.registerToken(toChainId, tokenAddr, _uni_pool, _register);
        vm.stopPrank();


        ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
        assertEq(tokenInfo.isRegistered, _register);
        assertEq(tokenInfo.uniswapPool, _uni_pool);
        assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
        assertEq(tokenInfo.decimalRate, 10**10);
        
    }

    function test_isTokenRegistered() external {
        vm.startPrank(ADMIN);
        uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
        uint64 toChainId = 6;
        bool enableToChain = true;
        address tokenAddr = address(weth);
        address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
        bool _register = true;
        adminTBSetup(
            toChainId, 
            enableToChain, 
            tokenAddr, 
            _uni_pool,
            _register
        );
        vm.stopPrank();

        assertTrue(tokenBridge.isTokenRegistered(toChainId, tokenAddr));
        assertFalse(tokenBridge.isTokenRegistered(toChainId, vm.addr(999)));
    }

    function test_isToChainIdRegistered() external {
        vm.startPrank(ADMIN);
        uint64 toChainId = 6;
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.ToChainRegistered(ADMIN, toChainId, true);
        tokenBridge.registerChainId(toChainId, true);
        vm.stopPrank();

        assertTrue(tokenBridge.isToChainIdRegistered(toChainId));
        assertFalse(tokenBridge.isToChainIdRegistered(999));
    }

    function test_registerChainId_When_Unregistering() external {
        uint64 toChainId = 1;
        bool registered = true;

        vm.prank(ADMIN);
        tokenBridge.registerChainId(toChainId, registered);
        assertTrue(tokenBridge.isToChainIdRegistered(toChainId));

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.ToChainRegistered(ADMIN, toChainId, false);
        tokenBridge.registerChainId(toChainId, false);

        assertFalse(tokenBridge.isToChainIdRegistered(toChainId));
    }

    function test_Revert_registerToken_When_CallerNotAdmin() external {
        vm.prank(vm.addr(1));
        vm.expectRevert(tbErrors.UnauthorizedSender.selector);
        tokenBridge.registerToken(1, vm.addr(1), vm.addr(2), true);
    }

    function test_Revert_registerToken_When_ChainIdNotRegistered() external {
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.ChainIdNotRegistered.selector);
        tokenBridge.registerToken(1, vm.addr(1), vm.addr(2), true);
    }

    function test_Revert_registerToken_When_ZeroInputs() external {
        vm.prank(ADMIN);
        tokenBridge.registerChainId(1, true);
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.registerToken(1, address(0), vm.addr(2), true);

        vm.prank(ADMIN);
        vm.expectRevert();
        tokenBridge.registerToken(1, address(1), address(0), true);

        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.ChainIdNotRegistered.selector);
        tokenBridge.registerToken(0, address(1), address(1), true);
    }

    function test_registerChainId() external {
        uint64 toChainId = 1;
        bool registered = true;

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.ToChainRegistered(ADMIN, toChainId, registered);
        tokenBridge.registerChainId(toChainId, registered);

        assertTrue(tokenBridge.isToChainIdRegistered(toChainId));
    }

    function test_Revert_registerChainId_When_CallerNotAdmin() external {
        vm.prank(vm.addr(1));
        vm.expectRevert(tbErrors.UnauthorizedSender.selector);
        tokenBridge.registerChainId(1, true);
    }

    function test_Revert_registerChainId_When_ZeroChainId() external {
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.registerChainId(0, true);
    }

    function test_Revert_registerChainId_When_AlreadyRegistered() external {
        uint64 toChainId = 1;
        vm.prank(ADMIN);
        tokenBridge.registerChainId(toChainId, true);
        
        vm.prank(ADMIN);
        vm.expectRevert(tbErrors.ChainIdAlreadyRegistered.selector);
        tokenBridge.registerChainId(toChainId, true);
    }

    function test_changeState() external {
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.TokenBridgePauseState(ADMIN, true);
        tokenBridge.changeState(true);
        assertTrue(tokenBridge.checkIsTokenBridgePaused());

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenBridgeService.TokenBridgePauseState(ADMIN, false);
        tokenBridge.changeState(false);
        assertFalse(tokenBridge.checkIsTokenBridgePaused());
    }

    function test_Revert_changeState_When_CallerNotAdmin() external {
        vm.prank(vm.addr(1));
        vm.expectRevert(tbErrors.UnauthorizedSender.selector);
        tokenBridge.changeState(true);
    }

    function test_sendTokens_WETH() external {
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
            uint256 rg = 4000000;
            uint64 rm = 5000; // 50%
            uint64 sm = 5000; // 50%
            uint64 tierMicroUSDT = 5000_000000;
            uint128 tierWhaleUSDT = 1_000_000_000000;
            uint64 tierMicroPercentage = 50; // 0.5%
            uint64 tierStandardPercentage = 30; // 0.3%
            uint64 tierWhalePercentage = 20; // 0.2 %
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            assertEq(tokenInfo.decimalRate, 10**10);
            
        }
        // Setup user with tokens
        address user = address(1);
        uint256 amount = 0.1 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(address(weth), user, amount);
        vm.startPrank(user);
        weth.approve(address(tokenBridge), amount);
        
        vm.expectEmit(true, true, true, true);
        emit IVault.Locked(tokenAddr, amount);
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);

        assertEq(address(tokenBridge).balance, 0);
        assertEq(weth.balanceOf(address(tokenBridge)), 0);
        assertEq(weth.balanceOf(user), 0);
        assertEq(weth.balanceOf(address(vault)), amount);
        assertEq(address(vault).balance, 0);
        assertEq(vault.getLockedTokenBalance(address(weth)), amount);
        // Test revert when bridge is paused
        vm.stopPrank();
        vm.prank(ADMIN);
        tokenBridge.changeState(true);
        vm.startPrank(user);
        vm.expectRevert(tbErrors.BridgePaused.selector);
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);
    }

    function test_sendTokens_WETH_max_amount() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        ITokenBridgeService.TokenInfo memory tokenInfo;
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 5000; // 10%
            uint64 _vm = 5000; // 10%
            uint64 x = 10; 

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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            assertEq(tokenInfo.decimalRate, 10**10);            
        }
        // Setup user with tokens
        address user = address(1);
        uint256 amount = 184467440737.09551615 ether; // deNormalizeDecimals(type(uint64).max ,tokenInfo.decimalRate) = 184467440737095516150000000000
        uint256 normalizedAmount = deNormalizeDecimals(normalizeDecimals(amount, tokenInfo.decimalRate),tokenInfo.decimalRate);
        uint256 dust = amount - normalizedAmount;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(address(weth), user, amount);
        vm.startPrank(user);
        weth.approve(address(tokenBridge), amount);
        
        vm.expectEmit(true, true, true, true);
        emit IVault.Locked(tokenAddr, normalizedAmount);
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId); // OutGoingBridgeAmount = 18391403841488422874 (Fee = 55340232221128741)

        assertEq(address(tokenBridge).balance, 0);
        assertEq(weth.balanceOf(address(tokenBridge)), 0);
        assertEq(weth.balanceOf(user), dust);
        assertEq(weth.balanceOf(address(vault)), normalizedAmount);
        assertEq(address(vault).balance, 0);
        assertEq(vault.getLockedTokenBalance(address(weth)), normalizedAmount);

        amount = (553402322211287410000000000 * 2) + 1; // deNormalizeDecimals(55340232221128741 ,tokenInfo.decimalRate) = 553402322211287410000000000
        weth.approve(address(tokenBridge), amount);
        deal(address(weth), user, amount);
        vm.expectRevert(); // OutGoingBridgeAmountLimitForTokenIsReached
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId); // OutGoingBridgeAmount = 18446744073709551529 + (55340232221128741 * 2) + 1 > type(uint64).max

    }

    function test_sendTokens_USDC() external {
        uint64 toChainId = 6;
        address tokenAddr = address(usdc);
        {
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, tokenAddr);
            bool enableToChain = true;
            address _uni_pool = address(uniswapV3Pool_USDC_USDT); 
            bool isBridgeTokenBaseToken = true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }
        // Setup user with tokens
        address user = address(1);
        uint256 amount = 274;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(tokenAddr, user, amount);
        vm.startPrank(user);
        usdc.approve(address(tokenBridge), amount);
        
        vm.expectEmit(true, true, true, true);
        emit IVault.Locked(tokenAddr, amount);
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);

        assertEq(address(tokenBridge).balance, 0);
        assertEq(usdc.balanceOf(address(tokenBridge)), 0);
        assertEq(usdc.balanceOf(user), 0);
        assertEq(usdc.balanceOf(address(vault)), amount);
        assertEq(address(vault).balance, 0);
        assertEq(vault.getLockedTokenBalance(tokenAddr), amount);
    }

    function test_sendTokens_USDC_max_amount() external {
        uint64 toChainId = 6;
        address tokenAddr = address(usdc);
        ITokenBridgeService.TokenInfo memory tokenInfo;
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 5000; // 10%
            uint64 _vm = 5000; // 10%
            uint64 x = 10; 

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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(usdc));
            bool enableToChain = true;
            address _uni_pool = address(uniswapV3Pool_USDC_USDT); 
            bool isBridgeTokenBaseToken = true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            assertEq(tokenInfo.decimalRate, 1);
        }
        // Setup user with tokens
        address user = address(1);
        uint256 amount = 18446744073709551615; // deNormalizeDecimals(type(uint64).max ,tokenInfo.decimalRate) = 18446744073709551615
        uint256 normalizedAmount = deNormalizeDecimals(normalizeDecimals(amount, tokenInfo.decimalRate),tokenInfo.decimalRate);
        uint256 dust = amount - normalizedAmount;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(tokenAddr, user, amount);
        vm.startPrank(user);
        usdc.approve(address(tokenBridge), amount);
        
        vm.expectEmit(true, true, true, true);
        emit IVault.Locked(tokenAddr, normalizedAmount);
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId); // OutGoingBridgeAmount = 18391403841488420567 (fee = 55340232221131048)

        assertEq(address(tokenBridge).balance, 0);
        assertEq(usdc.balanceOf(address(tokenBridge)), 0);
        assertEq(usdc.balanceOf(user), dust);
        assertEq(usdc.balanceOf(address(vault)), normalizedAmount);
        assertEq(address(vault).balance, 0);
        assertEq(vault.getLockedTokenBalance(address(usdc)), normalizedAmount);

        amount = (55340232221131048 * 2) + 1;  
        usdc.approve(address(tokenBridge), amount);
        deal(address(usdc), user, amount);
        vm.expectRevert(); // OutGoingBridgeAmountLimitForTokenIsReached
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId); // OutGoingBridgeAmount = 18391403841488420567 + (55340232221131048 * 2) + 1 > type(uint64).max
    }


    function test_Revert_sendTokens_When_InvalidInputs() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }

        // Setup user with tokens
        address user = address(1);
        uint256 amount = 0.1 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(address(weth), user, amount);
        vm.startPrank(user);
        weth.approve(address(tokenBridge), amount);

        vm.expectEmit(true, true, true, true);
        emit IVault.Locked(tokenAddr, amount);
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);

        // Test zero token address
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.sendTokens(address(0), 100, receiverAddr, bytes32(0), toChainId);

        // Test zero receiver address
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.sendTokens(tokenAddr, 100, bytes32(0), bytes32(0), toChainId);

        // Test zero amount
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.sendTokens(tokenAddr, 0, receiverAddr, bytes32(0), toChainId);

        // Test zero chain ID
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.sendTokens(tokenAddr, 100, receiverAddr, bytes32(0), 0);

        // Test unregistered chain ID
        vm.expectRevert(tbErrors.ChainIdNotRegistered.selector);
        tokenBridge.sendTokens(tokenAddr, 100, receiverAddr, bytes32(0), 999);

        // Test unregistered token
        vm.expectRevert(tbErrors.TokenNotRegistered.selector);
        tokenBridge.sendTokens(vm.addr(999), 100, receiverAddr, bytes32(0), toChainId);
    }

    function test_Revert_sendTokens_When_TokenNotApproved_Or_NotEnoughApproved() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }

        // Setup user with tokens
        address user = address(1);
        uint256 amount = 0.1 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(address(weth), user, amount);
        vm.startPrank(user);
        vm.expectRevert();
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);

        weth.approve(address(tokenBridge), amount - 1);
        vm.expectRevert();
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);
        vm.stopPrank();
    }

    function test_Revert_sendTokens_When_Vault_LockLimit_Breached() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1 ether;
            uint256 max = 2 ether;
            uint256 _globalMax = 100 ether;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }

        // Setup user with tokens
        address user = address(1);
        uint256 amount = 0.9 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(address(weth), user, amount);
        vm.startPrank(user);
        weth.approve(address(tokenBridge), amount);
        vm.expectRevert(vtErrors.LimitBreached.selector);
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);

        amount = 2.1 ether;
        deal(address(weth), user, amount);
        weth.approve(address(tokenBridge), amount);
        vm.expectRevert(vtErrors.LimitBreached.selector);
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);
        vm.stopPrank();
    }

    function test_Revert_sendTokens_When_HNConfigIsNotEnabled() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            toChainId = 9;
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            toChainId = 6;
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }

        // Setup user with tokens
        address user = address(1);
        uint256 amount = 1 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(address(weth), user, amount);
        vm.startPrank(user);
        weth.approve(address(tokenBridge), amount);
        vm.expectRevert(foErrors.HNConfigIsNotEnabled.selector);
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);
        vm.stopPrank();
    }

    function test_sendNatives() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }
        // Setup user with tokens
        address user = address(1);
        uint256 amount = 0.1 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(user, amount);
        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit IVault.Locked(tokenAddr, amount);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount, payload, toChainId);

        assertEq(user.balance, 0);
        assertEq(address(tokenBridge).balance, 0);
        assertEq(weth.balanceOf(address(tokenBridge)), 0);
        assertEq(weth.balanceOf(address(vault)), amount);
        assertEq(address(vault).balance, 0);
        assertEq(vault.getLockedTokenBalance(address(weth)), amount);
        // Test revert when bridge is paused
        vm.stopPrank();
        vm.prank(ADMIN);
        tokenBridge.changeState(true);
        vm.startPrank(user);
        deal(user, amount);
        vm.expectRevert(tbErrors.BridgePaused.selector);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount, payload, toChainId);
    }

    function test_Revert_sendNative_When_InvalidInputs() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }

        // Setup user with tokens
        address user = address(1);
        uint256 amount = 0.1 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(user, amount);
        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit IVault.Locked(tokenAddr, amount);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount, payload, toChainId);

        // Test zero receiver address
        deal(user, amount);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.sendNative{value: amount}(bytes32(0), amount, payload, toChainId);

        // Test zero amount
        deal(user, amount);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.sendNative{value: amount}(receiverAddr, 0, payload, toChainId);
        

        // Test zero chain ID
        deal(user, amount);
        vm.expectRevert(tbErrors.InvalidInput.selector);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount, payload, 0);

        // Test unregistered chain ID
        deal(user, amount);
        vm.expectRevert(tbErrors.ChainIdNotRegistered.selector);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount, payload, 999);

        // Unregistering native token
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            uint256 _supraUsdtPairIndex = 500; 
            bool _register = false;
            tokenBridge.registerToken(toChainId, tokenAddr, _uni_pool, _register);
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }
        // Test unregistered token
        deal(user, amount);
        vm.expectRevert(tbErrors.TokenNotRegistered.selector);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount, payload, toChainId);
    }

    function test_Revert_sendNative_When_IncorrectAmount() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }

        // Setup user with tokens
        address user = address(1);
        uint256 amount = 0.1 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);
        vm.startPrank(user);
        vm.deal(user, amount + 1 ether);
        vm.expectRevert(tbErrors.IncorrectAmount.selector);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount + 1, payload, toChainId);

        vm.expectRevert(tbErrors.IncorrectAmount.selector);
        tokenBridge.sendNative{value: amount + 1}(receiverAddr, amount, payload, toChainId);
    }

    function test_Revert_sendNative_When_Vault_LockLimit_Breached() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1 ether;
            uint256 max = 2 ether;
            uint256 _globalMax = 100 ether;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }

        // Setup user with tokens
        address user = address(1);
        uint256 amount = 0.9 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(user, amount);
        vm.startPrank(user);
        vm.expectRevert(vtErrors.LimitBreached.selector);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount, payload, toChainId);

        amount = 2.1 ether;
        deal(user, amount);
        vm.expectRevert(vtErrors.LimitBreached.selector);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount, payload, toChainId);
        vm.stopPrank();
    }

    function test_Revert_sendNative_When_HNConfigIsNotEnabled() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            toChainId = 9;
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 1000; // 10%
            uint64 _vm = 1000; // 10%
            uint64 x = 10; 

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
            uint256 rg = 130000;
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
        {
            toChainId = 6;
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            uint256 _supraUsdtPairIndex = 500; 
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
        }

        // Setup user with tokens
        address user = address(1);
        uint256 amount = 1 ether;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(user, amount);
        vm.startPrank(user);
        vm.expectRevert(foErrors.HNConfigIsNotEnabled.selector);
        tokenBridge.sendNative{value: amount}(receiverAddr, amount, payload, toChainId);
        vm.stopPrank();
    }

    function test_Revert_sendTokens_When_InsufficientAmount_Due_To_High_Fee_Margins() external {
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 155500;
            uint64 cm = 9999; // 99.99%
            uint64 _vm = 9999; // 99.99%
            uint64 x = 10; 

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
            uint256 rg = 130000;
            uint64 rm = 9999; // 99.99%
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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
        }

        // Setup user with tokens
        address user = address(1);
        uint256 amount = type(uint64).max - 1;
        bytes32 receiverAddr = bytes32(uint256(uint160(vm.addr(2))));
        bytes32 payload = bytes32(0);

        deal(address(weth), user, amount);
        vm.startPrank(user);
        weth.approve(address(tokenBridge), amount);

        vm.expectRevert(); //InsufficientAmount
        tokenBridge.sendTokens(tokenAddr, amount, receiverAddr, payload, toChainId);
    }

    function test_computeFeeDetails() external{
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        ITokenBridgeService.TokenInfo memory tokenInfo;
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 5000; // 10%
            uint64 _vm = 5000; // 10%
            uint64 x = 10; 

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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            assertEq(tokenInfo.decimalRate, 10**10);            
            
            uint256 amount = 1 ether;
            (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = tokenBridge.computeFeeDetails(toChainId, amount, tokenInfo);
            assertEq(amount, deNormalizeDecimals(finalAmount, tokenInfo.decimalRate) + deNormalizeDecimals(feeCutToService, tokenInfo.decimalRate) + dust);
        }
    }

    function test_computeFeeDetails_USDC() external{
        uint64 toChainId = 6;
        address tokenAddr = address(usdc);
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 5000; // 10%
            uint64 _vm = 5000; // 10%
            uint64 x = 10; 

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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, tokenAddr);
            bool enableToChain = true;
            address _uni_pool = address(uniswapV3Pool_USDC_USDT); 
            bool isBridgeTokenBaseToken = true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();
            ITokenBridgeService.TokenInfo memory tokenInfo = tokenBridge.getRegisteredTokenInfo(toChainId, tokenAddr);
            assertEq(tokenInfo.isRegistered, _register);
            assertEq(tokenInfo.uniswapPool, _uni_pool);
            assertEq(tokenInfo.isBaseToken, isBridgeTokenBaseToken);
            
            uint256 amount = 20000;
            (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = tokenBridge.computeFeeDetails(toChainId, amount, tokenInfo);
            assertEq(dust, 0);
            assertEq(amount, deNormalizeDecimals(finalAmount, tokenInfo.decimalRate) + deNormalizeDecimals(feeCutToService, tokenInfo.decimalRate) + dust);
        }
    }

    function test_Revert_computeFeeDetails() external{
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        ITokenBridgeService.TokenInfo memory tokenInfo;
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 5000; // 10%
            uint64 _vm = 5000; // 10%
            uint64 x = 10; 

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
        tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: false,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0            
        });

        uint256 amount = 1 ether;
        vm.expectRevert(foErrors.TokenNotRegistered.selector);
        tokenBridge.computeFeeDetails(toChainId, amount, tokenInfo);

        tokenInfo = ITokenBridgeService.TokenInfo({
            isRegistered: true,
            isBaseToken: isBridgeTokenBaseToken,
            uniswapPool: uni_pool,
            decimalRate: _decimalRate,
            isFixedFee: false,
            fixedServiceFee: 0,
            fixedRelayerReward: 0
        });
        vm.expectRevert(foErrors.HNConfigIsNotEnabled.selector);
        tokenBridge.computeFeeDetails(9999, amount, tokenInfo);

        vm.expectRevert(); // InsufficientAmount
        tokenBridge.computeFeeDetails(toChainId, 1, tokenInfo);
    }

    function test_getFeeForAmount() external{
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 5000; // 10%
            uint64 _vm = 5000; // 10%
            uint64 x = 10; 

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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT);
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();            
            uint256 amount = 1 ether;
            (uint64 finalAmount, uint64 feeCutToService, uint64 relayerReward, uint256 dust) = tokenBridge.getFeeForAmount(toChainId, amount, tokenAddr);
            assertEq(amount, deNormalizeDecimals(finalAmount, 10**10) + deNormalizeDecimals(feeCutToService, 10**10) + dust);
        }
    }
    function testRevert_getFeeForAmount_When_Token_Not_Registered() external{
        uint64 toChainId = 6;
        address tokenAddr = address(weth);
        {
            bool enabled = true;
            uint256 cg = 2000000;
            uint64 cm = 5000; // 10%
            uint64 _vm = 5000; // 10%
            uint64 x = 10; 

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
        {
            vm.startPrank(ADMIN);
            uint256 min = 1;
            uint256 max = type(uint256).max;
            uint256 _globalMax = type(uint256).max;
            adminVaultSetup(min, max, _globalMax, address(weth));
            bool enableToChain = true;
            address _uni_pool = block.chainid == 11155111? address(uniswapV3Pool_USDT_WETH_sepolia) : address(uniswapV3Pool_WETH_USDT); 
            bool isBridgeTokenBaseToken = block.chainid == 11155111 ? false : true;
            bool _register = true;
            adminTBSetup(
                toChainId, 
                enableToChain, 
                tokenAddr, 
                _uni_pool,
                _register
            );
            vm.stopPrank();            
            uint256 amount = 1 ether;
            vm.expectRevert(tbErrors.TokenNotRegistered.selector);
            tokenBridge.getFeeForAmount(toChainId, amount, address(0xdead));
        }
    }


    // Utils
    function normalizeDecimals(uint256 _amount, uint256 _decimalRate) internal pure returns (uint256){
        return (_amount / _decimalRate);
    }
    function deNormalizeDecimals(uint256 _amount, uint256 _decimalRate) internal pure returns (uint256){
        return (_amount * _decimalRate);
    }
}

// Mock UniswapV3Pool for testing token1 as base token
contract MockUniswapV3Pool {
    address public token0;
    address public token1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
}
