// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "contracts/fee-operator/implementations/Helpers.sol";
import "../../interfaces/IFeeOperator.sol";
import "../../interfaces/ITokenBridgeService.sol";

/*  
    CUR = CUG / (1 - CUM)
    V = (CUR / X)  / (1 - VM) 
    RR = (V + RG) / (1 - RM)
    S = RR / (1 - SM)
    
    CUG and RG to absolute values.
    Compute CUR, V, RR and S using CUM = 10%, RM = 20%, VM = 10%
*/
contract FeeOperatorImpl is Initializable, Helpers {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _hypernova, address _sValueFeed, uint256 _supraUsdtPairIndex)
        public
        initializer
    {
        _setAdmin(_admin);
        _setHypernova(_hypernova);
        _setSValueFeed(_sValueFeed, _supraUsdtPairIndex);
    }

    function setAdmin(address _admin) external onlyAdmin {
        _setAdmin(_admin);
        emit IFeeOperator.UpdatedAdmin(msg.sender, _admin);
    }

    function setHypernova(address _hypernova) external onlyAdmin {
        _setHypernova(_hypernova);
        emit IFeeOperator.UpdatedHypernova(msg.sender, _hypernova);
    }

    function setSValueFeed(address _sValueFeed, uint256 _supraUsdtPairIndex) external onlyAdmin {
        _setSValueFeed(_sValueFeed, _supraUsdtPairIndex);
        emit IFeeOperator.UpdatedSValueFeed(msg.sender, _sValueFeed, _supraUsdtPairIndex);
    }

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
    ) public onlyAdmin {
        // Not checking rm, sm because the margins can be 0
        if (
            checkZeroValue(toChaiID) || checkZeroValue(rg) || checkZeroValue(tierMicroUSDT)
                || checkZeroValue(tierWhaleUSDT)
        ) revert InvalidInput();
        if (!isValidMargin(rm) || !isValidMargin(sm)) revert InvalidMargin();
        if (
            !isValidPercentage(tierMicroPercentage) || !isValidPercentage(tierStandardPercentage)
                || !isValidPercentage(tierWhalePercentage)
        ) revert InvalidPercentage();

        IFeeOperator.FeeConfig storage feeConfig = feeConfigs[toChaiID];
        feeConfig.enabled = enabled;
        feeConfig.rg = rg;
        feeConfig.rm = rm;
        feeConfig.sm = sm;
        feeConfig.tierMicroUSDT = tierMicroUSDT;
        feeConfig.tierWhaleUSDT = tierWhaleUSDT;
        feeConfig.tierMicroPercentage = tierMicroPercentage;
        feeConfig.tierStandardPercentage = tierStandardPercentage;
        feeConfig.tierWhalePercentage = tierWhalePercentage;

        emit IFeeOperator.UpdatedTBFeeConfig(msg.sender, feeConfig);
    }

    function getTBFeeConfig(uint64 toChainId) public view isNotPaused returns (IFeeOperator.FeeConfig memory) {
        return feeConfigs[toChainId];
    }
    // Casting all the return values to `uint64` in the respectve internal functions. According to https://aptos.dev/en/build/smart-contracts/fungible-asset standard the destination mint amount is u64
    // uint64 finalAmount, uint64 feeCutToService, uint64 relayerRewardInBridgedAsset - are the values going to be minted on transferred on supra chain where the FA asset or Coin transfers happen in `u64`.
    // See Issue : https://github.com/Entropy-Foundation/supra-interoperability-solutions/issues/460 for more info
    function getFeeDetails(uint64 toChainId, uint256 amount, ITokenBridgeService.TokenInfo memory _tokenInfo) public view isNotPaused returns (uint64 finalAmount, uint64 feeCutToService, uint64 relayerRewardInBridgedAsset, uint256 dust)
    {
        if (checkZeroValue(amount)) revert InvalidInput();
        if (!_tokenInfo.isRegistered) revert TokenNotRegistered();

        IHypernova.HNConfig memory hypernovaConfig = getHypernova().getHNConfig(toChainId);
        IFeeOperator.FeeConfig memory tbFeeConfig = getTBFeeConfig(toChainId);
        // No need to check all the values of hypernovaConfig, because the checks were done in the addOrUpdateHNConfig() while adding
        if (!hypernovaConfig.enabled) revert HNConfigIsNotEnabled();
        // No need to check all the values of tbFeeConfig, because the checks were done in the addOrUpdateTBFeeConfig() while adding
        if (!tbFeeConfig.enabled) revert FeeConfigIsNotEnabled();
        // Calling the internal function diretly, cause all the checks were done while adding the config
        uint64 relayerRewardInSupra = _computeRelayerReward(hypernovaConfig.v, tbFeeConfig.rg, tbFeeConfig.rm);
        uint256 relayerRewardInUsdt = getRelayerRewardInUsdt(relayerRewardInSupra);

        uint256 serviceFeesAsset;
        uint256 relayerFeesAsset;
        if (_tokenInfo.isFixedFee) {
            // fixed fee model
            serviceFeesAsset = _tokenInfo.fixedServiceFee;
            relayerFeesAsset = _tokenInfo.fixedRelayerReward;
        }else {
            (uint256 tokenAmountInUsdt, uint256 _relayerRewardInBridgedAsset) = getAmountInUsdtAndtRelayerRewardInBridgedAsset(_tokenInfo.uniswapPool, amount, _tokenInfo.isBaseToken, relayerRewardInUsdt);
            serviceFeesAsset = _computeServiceFee(amount, tokenAmountInUsdt, _relayerRewardInBridgedAsset, tbFeeConfig);
            relayerFeesAsset = _relayerRewardInBridgedAsset;
        }

        // Calling the internal function diretly, cause all the checks were done while adding the config
        // normalizing and casting to u64 : normalizedFeeCutToService is supra wrapped asset amount which is having different decimals than the original
        uint256 normalizedFeeCutToService = normalizeDecimals(serviceFeesAsset, _tokenInfo.decimalRate);
        if (!isSafeToCastToU64(normalizedFeeCutToService)) revert InvalidSValue(normalizedFeeCutToService); // "Service fee is too higher than the wrapped bridged asset supply (u64)")
        feeCutToService = uint64(normalizedFeeCutToService);

        // normalizing and casting to u64 : normalizedRelayerRewardInBridgedAsset is supra wrapped asset amount which is having different decimals than the original
        uint256 normalizedRelayerRewardInBridgedAsset = normalizeDecimals(relayerFeesAsset, _tokenInfo.decimalRate);
        if (!isSafeToCastToU64(normalizedRelayerRewardInBridgedAsset)) revert InvalidRRinBridgedAssetValue(normalizedRelayerRewardInBridgedAsset); //"Relayer reward is too higher than the wrapped bridged asset supply (u64)")
        relayerRewardInBridgedAsset = uint64(normalizedRelayerRewardInBridgedAsset);

        // Enough fee check
        uint256 normalizedAmount = normalizeDecimals(amount, _tokenInfo.decimalRate);
        if (normalizedFeeCutToService >= normalizedAmount) revert InsufficientAmount(normalizedAmount, normalizedFeeCutToService, normalizedRelayerRewardInBridgedAsset);

        // normalizing and casting to u64 : normalizedFinalAmount is supra wrapped asset amount which is having different decimals than the original
        uint256 normalizedFinalAmount = normalizedAmount - normalizedFeeCutToService;
        if (!isSafeToCastToU64(normalizedFinalAmount)) revert InvalidAmountValue(normalizedFinalAmount); // "bridge amount is too higher than the wrapped bridged asset supply (u64)")
        finalAmount = uint64(normalizedFinalAmount);

        dust = amount - deNormalizeDecimals(normalizedAmount, _tokenInfo.decimalRate);
    }

    function changeState(bool _isPaused) external onlyAdmin {
        isPaused = _isPaused;
        emit IFeeOperator.FeeOperatorPauseState(msg.sender, _isPaused);
    }

    function checkIsFeeOperatorPaused() public view returns (bool) {
        return isPaused;
    }
}