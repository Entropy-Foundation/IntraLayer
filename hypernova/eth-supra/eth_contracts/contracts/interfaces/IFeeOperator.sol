// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import "./ITokenBridgeService.sol";
import "./ISupraSValueFeed.sol";
interface IFeeOperator {
    struct FeeConfig {
        bool enabled;
        // GasCost in Quants = gas_used * gas_unit_price => u64 * u64 => uint128 is enough. But In percentage calculaiton it might get oeverflowed. So, using u256
        uint256 rg;
        uint64 rm;
        uint64 sm;
        
        uint64 tierMicroUSDT;
        // In between is tierStandard
        uint128 tierWhaleUSDT;

        uint64 tierMicroPercentage;
        uint64 tierStandardPercentage;
        uint64 tierWhalePercentage;
    }
    event FeeOperatorPauseState(address indexed owner, bool paused);
    event UpdatedTBFeeConfig(address indexed admin, FeeConfig);
    event UpdatedAdmin(address indexed owner,address admin);
    event UpdatedHypernova(address indexed owner,address hypernova);
    event UpdatedSValueFeed(address indexed owner, address sValueFeed, uint256 supraUsdtPairIndex);

    function initialize(
        address _admin,
        address _hypernova,
        address _sValueFeed,
        uint256 supraUsdtPairIndex
    ) external;
    function setAdmin(address _admin) external;
    function changeState(bool _isPaused) external;
    function setHypernova(address _hypernova) external;
    function setSValueFeed(address _sValueFeed, uint256 supraUsdtPairIndex) external;
    function addOrUpdateTBFeeConfig(
        bool enabled,
        uint64 toChaiID, 
        uint256 rg, 
        uint64 rm, 
        uint64 sm,
        uint64 tierMicroUSDT,
        uint128 tierWhaleUSDT,
        uint64 tierMicroPercentage,
        uint64 tierStandardPercentage,
        uint64 tierWhalePercentage
    ) external;
    
    function getTBFeeConfig(uint64 toChainId) external view returns (IFeeOperator.FeeConfig memory);
    function getFeeDetails(uint64 toChainId, uint256 amount, ITokenBridgeService.TokenInfo memory _tokenInfo) external view returns (uint64 finalAmount, uint64 feeCutToService, uint64 relayerRewardInBridgedAsset, uint256 dust);
    function computeRelayerReward(uint64 v, uint256 rg, uint64 rm) external pure returns (uint64);
    function computeServiceFee(uint256 amount, uint256 tokenAmountInUsdt, uint256 relayerRewardInBridgedAsset, FeeConfig memory _tbFeeConfig) external pure returns (uint256);
    function getHypernova() external view returns (IHypernova);
    function getSValueFeed() external view returns (ISupraSValueFeed, uint256 supraUsdtPairIndex);
    function upgradeImplementation(address newImplementation) external returns (address);
    function getImplementationAddress() external view returns (address);
    function PERCENTAGE_BASE() external view returns (uint64);
    function NORMALIZED_DECIMALS() external view returns (uint64);
    function getRelayerRewardInUsdt(uint64 relayerRewardInSupra) external view returns (uint256 relayerRewardInUsdt);
    function getAmountInUsdtAndtRelayerRewardInBridgedAsset(address uniPriceOracle, uint256 amount, bool isBridgeTokenBaseToken, uint256 relayerRewardInUsdt) external view returns (uint256 tokenAmountInUsdt, uint256 relayerRewardInBridgedAsset);
    function checkIsFeeOperatorPaused() external view returns(bool);
    function admin() external view returns(address);

}