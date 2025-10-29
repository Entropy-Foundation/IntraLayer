// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "../../lib/forge-std/src/Script.sol";
import {console} from "../../lib/forge-std/src/console.sol";
// Interfaces
import {IVault} from "contracts/interfaces/IVault.sol";
import {ITokenBridgeService} from "contracts/interfaces/ITokenBridgeService.sol";

// Proxy contracts
import {TokenBridge} from "contracts/tokenBridge-service/TokenBridge.sol";
import {TokenVault} from "contracts/token-vault/TokenVault.sol";

// Implekentation contracts
import {TokenBridgeImplementation} from "contracts/tokenBridge-service/implementations/TokenBridgeImplementation.sol";
import {VaultImplementation} from "contracts/token-vault/implementations/VaultImplementation.sol";


contract DeployAndSetupTB is Script {
    uint256 public constant DELAY = 1 hours;
    address public constant HYPERNOVA_CORE = 0x50888Fc24e1224E12f5C8a31310A47B98b2A7f75;
    address public constant FEE_OPERATOR = 0xcd06057e8642613C38b938EFbe4FB44734920e2a;
    address public constant ADMIN = 0xd2f24b047b3eaD105885a1A99eb40feCAeD66668;
    address public constant WETH9 = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant SOLVBTC = 0xE33109766662932a26d978123383ff9E7bdeF346;
    address public constant WETH9_UNISWAP_POOL = 0x3289680dD4d6C10bb19b899729cda5eEF58AEfF1;
    address public constant USDC_UNISWAP_POOL = 0xfef3Ae91E2050AcCB4dA6033C6EB3b1BC4E3a1a5;


    TokenBridge public tokenBridgeProxy;
    TokenVault public tokenVaultProxy;

    TokenBridgeImplementation public tokenBridgeImplementation;
    VaultImplementation public vaultImplementation;

    ITokenBridgeService public tokenBridge;
    IVault public tokenVault;

    function run() public {
        deployTB(
            HYPERNOVA_CORE,
            ADMIN,
            FEE_OPERATOR,
            WETH9,
            DELAY
        );       


        vm.startBroadcast();

        /*
        transaction has min/max limit.
        also any token has a global limit (max deposited funds)
        */
        uint256 min_eth = 1000000000000;// min limit per transaction 0.000001 eth
        uint256 max_eth = type(uint256).max; // limit per transaction
        uint256 global_max_eth = type(uint256).max; // global limit
        // update weth
        adminVaultSetup(min_eth, max_eth, global_max_eth, address(WETH9));

        uint256 min_usdc = 10000;// min limit per transaction 0.01 usdc
        uint256 max_usdc = type(uint256).max; // limit per transaction
        uint256 global_max_usdc = type(uint256).max; // global limit
        // update usdc
        adminVaultSetup(min_usdc, max_usdc, global_max_usdc, address(USDC));

        uint256 min_btc = 1000000000000;// min limit per transaction 0.000001 solvbtc
        uint256 max_btc = type(uint256).max; // limit per transaction
        uint256 global_max_btc = type(uint256).max; // global limit
        // update solvbtc
        adminVaultSetup(min_btc, max_btc, global_max_btc, address(SOLVBTC));        

        uint64 toChainId = 6;

        registerChainId(toChainId, true);// register chain
        console.log("  registered chain : ", toChainId);

        // WETH9
        registerToken(
             toChainId, 
             WETH9, 
             WETH9_UNISWAP_POOL,
             true
         );
         console.log("  registered token : ", WETH9);

        // USDC
        registerToken(
             toChainId, 
             USDC, 
             USDC_UNISWAP_POOL,
             true
         );
         console.log("  registered token : ", USDC);

        // solvBTC
        registerFixedFeeToken(
             toChainId, 
             SOLVBTC, 
             6000000000000,// fees 0.000006 solvbtc,
             2000000000000,// relayer rewards 0.000005 solvbtc,
             true
         );
         console.log("  registered token : ", SOLVBTC);

        vm.stopBroadcast();
    }

    function deployTB(
        address _hypernova, 
        address _admin, 
        address _feeOperator,
        address _weth, 
        uint256 _delay
    ) public 
    returns (ITokenBridgeService, IVault) 
    {
        vm.startBroadcast();
        // Deploying implementations
        tokenBridgeImplementation = new TokenBridgeImplementation();
        vaultImplementation = new VaultImplementation();
        console.log("TokenBridgeImplementation: %s", address(tokenBridgeImplementation));
        console.log("VaultImplementation: %s", address(vaultImplementation));

        // Deploying proxy contracts
        tokenBridgeProxy = new TokenBridge(address(tokenBridgeImplementation), "");
        tokenVaultProxy = new TokenVault(address(vaultImplementation), "");
        tokenBridge = ITokenBridgeService(address(tokenBridgeProxy));
        tokenVault = IVault(address(tokenVaultProxy));
        require(address(tokenBridge) != address(0), "tokenBridge: Deployment Failed");
        require(address(tokenVault) != address(0), "tokenVault: Deployment Failed");

        console.log("tokenBridgeProxy : ", address(tokenBridge));
        console.log("vaultProxy : ", address(tokenVault));

        // Initializing implementations
        tokenBridge.initialize(
            _hypernova,
            _admin,
            _feeOperator,
            address(tokenVault),
            _weth
        );
        require(address(tokenBridge.admin()) == _admin, "tokenBridge: Initialise failed");
        tokenVault.initialize(
            _admin,
            address(tokenBridge),
            _delay
        );
        require(tokenVault.admin() == _admin, "tokenVault: Initialise failed");
        vm.stopBroadcast();
        return (tokenBridge, tokenVault);
    }

    function adminVaultSetup(uint256 min, uint256 max, uint256 _globalMax, address weth) public {
        address[] memory tokens = new address[](1); 
        tokens[0] = weth;

        uint256[] memory minLimit = new uint256[](1); 
        minLimit[0] = min;

        uint256[] memory maxLimit = new uint256[](1); 
        maxLimit[0] = max;

        uint256[] memory globalMax = new uint256[](1);
        globalMax[0] = _globalMax;

        tokenVault.setLockLimits(tokens, minLimit, maxLimit, globalMax);
        tokenVault.setReleaseLimits(tokens, minLimit, maxLimit);
    }


    // Admin needs to do the following setup. Admin is Gnosis Multisig, so these functions are not calleable from this script but adding for the reference
    function registerChainId(
        uint64 toChainId, 
        bool enableToChain
    ) public {
        tokenBridge.registerChainId(toChainId, enableToChain);
        require(tokenBridge.isToChainIdRegistered(toChainId) == enableToChain, "tokenBridge.registerChainId: Failed");
    }

    function registerToken(
        uint64 toChainId, 
        address tokenAddr, 
        address _uniswapPool,
        bool _register
    ) public {
        tokenBridge.registerToken(toChainId, tokenAddr, _uniswapPool, _register);
        require(tokenBridge.isTokenRegistered(toChainId, tokenAddr) == _register, "tokenBridge.registerToken: Failed");
    }

    function registerFixedFeeToken(
        uint64 toChainId, 
        address tokenAddr, 
        uint64 fixedServiceFee, uint64 fixedRelayerReward,
        bool _register
    ) public {
        tokenBridge.registerFixedFeeToken(toChainId, tokenAddr, fixedServiceFee, fixedRelayerReward, _register);
        require(tokenBridge.isTokenRegistered(toChainId, tokenAddr) == _register, "tokenBridge.registerToken: Failed");
    }    
    

}
