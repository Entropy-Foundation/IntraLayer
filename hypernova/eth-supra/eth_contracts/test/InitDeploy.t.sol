// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockToken} from "test/mock/mERC20.sol";
import {MockWETH} from "test/mock/mWETH.sol";
import {MockUSDC} from "test/mock/mUSDC.sol";
import {MockSupraSValueFeed} from "test/mock/mSupraSValueFeed.sol";
import {MockUniswapV3Pool_WETH_USDT} from "test/mock/mUniswapV3Pool_WETH_USDT.sol";
import {MockUniswapV3Pool_USDC_USDT} from "test/mock/mUniswapV3Pool_USDC_USDT.sol";

import {IHypernova} from "contracts/interfaces/IHypernova.sol";
import {IFeeOperator} from "contracts/interfaces/IFeeOperator.sol";
import {ITokenBridgeService} from "contracts/interfaces/ITokenBridgeService.sol";
import {IVault} from "contracts/interfaces/IVault.sol";
import {IWETH} from "contracts/interfaces/IWETH.sol";
import {ISupraSValueFeed} from "contracts/interfaces/ISupraSValueFeed.sol";
import {IUniswapV3Pool} from "contracts/interfaces/IUniswapV3Pool.sol";

import {DeployAndSetupHN} from "script/forge-scripts/DeployAndSetupHN.s.sol";
import {DeployAndSetupFO} from "script/forge-scripts/DeployAndSetupFO.s.sol";
import {DeployAndSetupTB} from "script/forge-scripts/DeployAndSetupTB.s.sol";

contract InitDeploy is Test {
    address public constant ADMIN = address(0xADADAD);
    uint256 public constant MSG_ID = 0;
    IHypernova public hypernova;
    IFeeOperator public feeOperator;
    ITokenBridgeService public tokenBridge;
    IVault public vault;
    IWETH public weth;
    IERC20 public usdc;
    MockToken public mockERC20;
    MockWETH public mockweth;
    ISupraSValueFeed public sValueFeed;
    uint256 public supraUsdtPairIndex;
    IUniswapV3Pool public uniswapV3Pool_WETH_USDT;
    IUniswapV3Pool public uniswapV3Pool_USDC_USDT;
    IUniswapV3Pool public uniswapV3Pool_USDT_WETH_sepolia;

    function init() public {
        _init();

        DeployAndSetupHN hnDeployer = new DeployAndSetupHN();
        hypernova = hnDeployer.deployHN(ADMIN);

        DeployAndSetupFO foDeployer = new DeployAndSetupFO();
        feeOperator = foDeployer.deployFO(ADMIN, address(hypernova), address(sValueFeed), supraUsdtPairIndex);

        uint256 _delay = 3600;
        DeployAndSetupTB tbDeployer = new DeployAndSetupTB();
        (tokenBridge, vault) = tbDeployer.deployTB(address(hypernova), ADMIN, address(feeOperator), address(weth), _delay);
    }

    function _init() internal {
        mockERC20 = new MockToken();
        if (block.chainid == 1 ) { // Mainnet
            weth = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
            usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
            sValueFeed = ISupraSValueFeed(0xD02cc7a670047b6b012556A88e275c685d25e0c9);
            supraUsdtPairIndex = 500;
            uniswapV3Pool_WETH_USDT = IUniswapV3Pool(0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36);
            uniswapV3Pool_USDC_USDT = IUniswapV3Pool(0x3416cF6C708Da44DB2624D63ea0AAef7113527C6);
            // Need to update the pull oracle on mainnet, cause no one yet used the DORA on mainnet for price feed SUPRA_USDT (500)
            // The following only works in mainnet fork test
            _updateMainnetDORAPullOracle();
        } else if (block.chainid == 11155111) { // Sepolia
            weth = IWETH(payable(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14));
            usdc = IERC20(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
            sValueFeed = ISupraSValueFeed(0x131918bC49Bb7de74aC7e19d61A01544242dAA80);
            supraUsdtPairIndex = 500;
            uniswapV3Pool_USDT_WETH_sepolia = IUniswapV3Pool(0x3289680dD4d6C10bb19b899729cda5eEF58AEfF1);
            uniswapV3Pool_USDC_USDT = IUniswapV3Pool(0xfef3Ae91E2050AcCB4dA6033C6EB3b1BC4E3a1a5);
        } else { // Local
            weth = IWETH(address(new MockWETH()));
            usdc = IERC20(address(new MockUSDC()));
            sValueFeed = ISupraSValueFeed(address(new MockSupraSValueFeed()));
            supraUsdtPairIndex = 500;
            uniswapV3Pool_WETH_USDT = IUniswapV3Pool(address(new MockUniswapV3Pool_WETH_USDT(address(weth), address(0xffffffffff))));
            uniswapV3Pool_USDC_USDT = IUniswapV3Pool(address(new MockUniswapV3Pool_USDC_USDT(address(usdc), address(0xffffffffff))));
        }
    }
    function _updateMainnetDORAPullOracle() internal {
        ISupraPullOracleForTest.PriceData memory data = ISupraPullOracleForTest(0x2FA6DbFe4291136Cf272E1A3294362b6651e8517).verifyOracleProof(hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000c5df7fb8576ca2b06ff76123054122b86893169a80c35fe184b2f3720cf9b57b28e76f59c435e2dfc4046f31af2fa9b9012080404bcc5a783b71f548d984620c136e885d10cf739b60f68ccfa7e9f1892856f65ec3d0d9709b521f3cde9ffa3900000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001f4000000000000000000000000000000000000000000000000000eaef10cdb50000000000000000000000000000000000000000000000000000000019759c6ae2700000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000019759c6ac900000000000000000000000000000000000000000000000000000000000000009a849bca156eb0c23c315367f5a93dff18af5a6084fe6305833a65017fbbf19dc80595c600e226306df55d2fedacae5f9fe8e4c3dadfd478ddcf6ae3eb4c22050d9d35d8d822620840e5272a7649b87da2cce6e80de7a27a9b309d905b129629d606701355999e43fd940fdd5ad52092c1463b8f5ddf09c915efb4ec482e05c94bfda5040cb6dd9d6ff4e514f91ed45288dd8fdbaaa92df9d658da7c30eae6c831be1c915e295ee4f31928e69dd452244fbd4d3a94a33902f3efcfb660c66525d0d71eabcaa0e4588557687e6133dc1a5ac70e755c035e1952f27e144c4aae0154e9e3ac104970e334d9ec4adf17d64d589e1591be6ee0c4603cb44e98eefe08e6662d62c5e21f6bb329c57593e82144762a6683399833f45df0a83c6117945a90000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
        // PriceData({ pairs: [500], prices: [4133000000000000 [4.133e15]], decimal: [18] })
        require(data.pairs.length == 1);
    }
    function adminHNSetup(
        bool enabled,
        uint64 toChaiID,
        uint256 cg,
        uint64 cm,
        uint64 _vm,
        uint64 x
    ) public {
        hypernova.addOrUpdateHNConfig(
            enabled,
            toChaiID,
            cg,
            cm,
            _vm,
            x
        );
    }
    function adminFOSetup(
        address _sValueFeed,
        uint256 _supraUsdtPairIndex,
        bool enabledToChainID,
        uint64 toChaiID,
        uint256 rg,
        uint64 rm,
        uint64 sm,
        uint64 tierMicroUSDT,
        uint128 tierWhaleUSDT,
        uint64 tierMicroPercentage,
        uint64 tierStandardPercentage,
        uint64 tierWhalePercentage
    ) public {
        feeOperator.setSValueFeed(_sValueFeed, _supraUsdtPairIndex);
        feeOperator.addOrUpdateTBFeeConfig(
            enabledToChainID,
            toChaiID, 
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

    function adminVaultSetup(uint256 min, uint256 max, uint256 _globalMax, address _tokenAddr) public {
        address[] memory tokens = new address[](1); 
        tokens[0] = _tokenAddr;

        uint256[] memory minLimit = new uint256[](1); 
        minLimit[0] = min;

        uint256[] memory maxLimit = new uint256[](1); 
        maxLimit[0] = max;
        
        uint256[] memory globalMax = new uint256[](1);
        globalMax[0] = _globalMax;

        vault.setLockLimits(tokens, minLimit, maxLimit, globalMax);
        vault.setReleaseLimits(tokens, minLimit, maxLimit);
    }

    function adminTBSetup(
        uint64 toChainId, 
        bool enableToChain, 
        address tokenAddr, 
        address _uniswapPool,
        bool _register
    ) public {
        tokenBridge.registerChainId(toChainId, enableToChain);
        require(tokenBridge.isToChainIdRegistered(toChainId) == enableToChain, "tokenBridge.registerChainId: Failed");
        tokenBridge.registerToken(toChainId, tokenAddr, _uniswapPool, _register);
        require(tokenBridge.isTokenRegistered(toChainId, tokenAddr) == _register, "tokenBridge.registerToken: Failed");
    }
}
interface ISupraPullOracleForTest {
    /// @notice Verified price data
    struct PriceData {
        // List of pairs
        uint256[] pairs;
        // List of prices
        // prices[i] is the price of pairs[i]
        uint256[] prices;
        // List of decimals
        // decimals[i] is the decimals of pairs[i]
        uint256[] decimal;
    }
    function verifyOracleProof(bytes calldata _bytesProof) external returns (PriceData memory);
}