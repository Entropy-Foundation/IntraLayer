// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import "contracts/fee-operator/implementations/State.sol";
import "contracts/fee-operator/implementations/Errors.sol";
import "contracts/interfaces/IHypernova.sol";
import "contracts/interfaces/ISupraSValueFeed.sol";
import "contracts/interfaces/IUniswapV3Pool.sol";

import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol"; //@dev: Library

contract Helpers is State, Errors {
    function _setAdmin(address _admin) internal {
        if (_admin != address(0)) {
            admin = _admin;
        } else revert InvalidInput();
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert UnauthorizedSender();
        }
        _;
    }

    modifier isNotPaused() {
        if (isPaused) {
            revert FeeOperatorPaused();
        }
        _;
    }
    function _setHypernova(address _hypernova) internal {
        if (checkZeroAddr(_hypernova)) revert InvalidInput();
        hypernova = _hypernova;
    }
    function getHypernova() public view returns (IHypernova){
        return IHypernova(hypernova);
    }

    function _setSValueFeed(address _sValueFeed, uint256 _supraUsdtPairIndex) internal {
        if (checkZeroAddr(_sValueFeed) || checkZeroValue(_supraUsdtPairIndex)) revert InvalidInput();
        sValueFeed = _sValueFeed;
        supraUsdtPairIndex = _supraUsdtPairIndex;
    }

    function getSValueFeed() public view returns (ISupraSValueFeed, uint256){
        return (ISupraSValueFeed(sValueFeed), supraUsdtPairIndex);
    }

    function computeRelayerReward(uint64 v, uint256 rg, uint64 rm) public pure returns (uint64) {
        if (checkZeroValue(rg) || checkZeroValue(v)) revert InvalidInput();
        if (!isValidMargin(rm)) revert InvalidMargin();
        return _computeRelayerReward(v, rg, rm);
    }
    // relayerReward will never become zero
    function _computeRelayerReward(uint64 v, uint256 rg, uint64 rm) internal pure returns (uint64 rr) {
        uint256 _rr =  FullMath.mulDiv((v + rg), PERCENTAGE_BASE, (PERCENTAGE_BASE - rm));
        if (_rr > type(uint64).max) revert InvalidRRComputation(_rr);
        rr = uint64(_rr);
    }
    function computeServiceFee(uint256 amount, uint256 tokenAmountInUsdt, uint256 relayerRewardInBridgedAsset, IFeeOperator.FeeConfig memory _tbFeeConfig) public pure returns (uint256) {
        if (!_tbFeeConfig.enabled) revert FeeConfigIsNotEnabled();
        if (checkZeroValue(amount) || checkZeroValue(tokenAmountInUsdt) || checkZeroValue(relayerRewardInBridgedAsset) ) revert InvalidInput();
        if (!isValidPercentage(_tbFeeConfig.tierMicroPercentage) || 
            !isValidPercentage(_tbFeeConfig.tierStandardPercentage) || 
            !isValidPercentage(_tbFeeConfig.tierWhalePercentage)
        ) revert InvalidPercentage();

        return _computeServiceFee(amount, tokenAmountInUsdt, relayerRewardInBridgedAsset, _tbFeeConfig);
    }

    // serviceFee will never become zero
    function _computeServiceFee(
        uint256 amount,
        uint256 tokenAmountInUsdt,
        uint256 relayerRewardInBridgedAsset,
        IFeeOperator.FeeConfig memory _tbFeeConfig
    ) internal pure returns (uint256 s) {
        uint256 tierFee;
        if (tokenAmountInUsdt <= _tbFeeConfig.tierMicroUSDT) {
            tierFee = FullMath.mulDiv(amount, _tbFeeConfig.tierMicroPercentage, PERCENTAGE_BASE);
        } else if (tokenAmountInUsdt < _tbFeeConfig.tierWhaleUSDT) {
            tierFee = FullMath.mulDiv(amount, _tbFeeConfig.tierStandardPercentage, PERCENTAGE_BASE);
        } else {
            tierFee = FullMath.mulDiv(amount, _tbFeeConfig.tierWhalePercentage, PERCENTAGE_BASE);
        }
        s = FullMath.mulDiv(relayerRewardInBridgedAsset, PERCENTAGE_BASE, (PERCENTAGE_BASE - _tbFeeConfig.sm)) + tierFee;
    }

    function getRelayerRewardInUsdt(uint64 relayerRewardInSupra) public view returns (uint256 relayerRewardInUsdt) {
        (ISupraSValueFeed _sValueFeed, uint256 _supraUsdtPairIndex) = getSValueFeed();
        ISupraSValueFeed.priceFeed memory supraPriceInUsdt = _sValueFeed.getSvalue(_supraUsdtPairIndex);
        relayerRewardInUsdt = FullMath.mulDiv(supraPriceInUsdt.price, relayerRewardInSupra, 10 ** NORMALIZED_DECIMALS);
    }

    function getAmountInUsdtAndtRelayerRewardInBridgedAsset(
        address uniPriceOracle,
        uint256 amount,
        bool isBridgeTokenBaseToken,
        uint256 relayerRewardInUsdt
    ) public view returns (uint256 tokenAmountInUsdt, uint256 relayerRewardInBridgedAsset) {
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(uniPriceOracle).slot0();
        if (amount <= type(uint128).max) {
            tokenAmountInUsdt = getQuoteAtSqrtRatioX96(sqrtPriceX96, uint128(amount), isBridgeTokenBaseToken);
        } else {
            // Expecting else part to be executed only when the amount is very high
            uint256 tmpAmount = amount;
            while (tmpAmount > type(uint128).max) {
                tokenAmountInUsdt += getQuoteAtSqrtRatioX96(sqrtPriceX96, type(uint128).max, isBridgeTokenBaseToken);
                tmpAmount -= type(uint128).max;
            }
            tokenAmountInUsdt += getQuoteAtSqrtRatioX96(sqrtPriceX96, uint128(tmpAmount), isBridgeTokenBaseToken);
        }

        if (relayerRewardInUsdt <= type(uint128).max) {
            relayerRewardInBridgedAsset = getQuoteAtSqrtRatioX96(sqrtPriceX96, uint128(relayerRewardInUsdt), !isBridgeTokenBaseToken);
        } else {
            // Expecting else part to be executed only when the relayer reward is very high in USD
            uint256 tmpReward = relayerRewardInUsdt;
            while (tmpReward > type(uint128).max) {
                relayerRewardInBridgedAsset += getQuoteAtSqrtRatioX96(sqrtPriceX96, type(uint128).max, !isBridgeTokenBaseToken);
                tmpReward -= type(uint128).max;
            }
            relayerRewardInBridgedAsset += getQuoteAtSqrtRatioX96(sqrtPriceX96, uint128(tmpReward), !isBridgeTokenBaseToken);
        }
    }

    // Copied and Modified from
    // https://github.com/Uniswap/v3-periphery/blob/0.8/contracts/libraries/OracleLibrary.sol
    /// @notice Given a sqrtRatioX96 and a token amount, calculates the amount of token received in exchange
    function getQuoteAtSqrtRatioX96(uint160 sqrtRatioX96, uint128 baseAmount, bool isBaseToken)
        internal
        pure
        returns (uint256 quoteAmount)
    {
        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = isBaseToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = isBaseToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

    function normalizeDecimals(uint256 _amount, uint256 _decimalRate) internal pure returns (uint256){
        return (_amount / _decimalRate);
    }
    function deNormalizeDecimals(uint256 _amount, uint256 _decimalRate) internal pure returns (uint256){
        return (_amount * _decimalRate);
    }

    function isSafeToCastToU64(uint256 value) internal pure returns (bool) {
        return (value <= type(uint64).max);
    }

    function checkZeroValue(uint256 value) internal pure returns (bool) {
        return value == 0;
    }

    function isValidPercentage(uint64 value) internal pure returns (bool) {
        return value <= PERCENTAGE_BASE;
    }

    function isValidMargin(uint64 value) internal pure returns (bool) {
        return value < PERCENTAGE_BASE;
    }

    function checkZeroAddr(address value) internal pure returns (bool) {
        return value == address(0);
    }


    function getImplementationAddress() public view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function upgradeImplementation(
        address newImplementation
    ) external onlyAdmin returns (address) {
        if (newImplementation == address(0)) revert InvalidInput();
        ERC1967Utils.upgradeToAndCall(newImplementation, "");
        return newImplementation;
    }
}
