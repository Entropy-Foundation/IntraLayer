// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs

pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint amount) external;
}