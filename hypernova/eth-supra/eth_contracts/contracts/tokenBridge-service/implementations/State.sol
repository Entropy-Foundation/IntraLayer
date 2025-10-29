// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {ITokenBridgeService} from "../../interfaces/ITokenBridgeService.sol";

contract State {
    uint8 public constant MAX_ALLOWED_SUPRA_WRAPPED_FA_DECIMALS = 8;
    address public admin;
    address hypernova;
    address feeOperatorContract;
    address vault;
    address nativeToken;
    bool isPaused;
    mapping(uint64 _toChainId => mapping(address => ITokenBridgeService.TokenInfo)) public supportedTokens;
    mapping(uint64 => bool) public supportedChains;
    mapping(uint64 _toChainId => mapping(address tokenAddr=> uint256)) public bridgedAmountPerToken;
}
