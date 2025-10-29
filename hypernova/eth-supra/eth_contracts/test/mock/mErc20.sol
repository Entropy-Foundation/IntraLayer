// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20{
    constructor() ERC20("MockT", "MT") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}