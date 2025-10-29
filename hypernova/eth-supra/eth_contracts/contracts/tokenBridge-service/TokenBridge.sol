// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol"; //@dev: Library

contract TokenBridge is ERC1967Proxy {
    constructor(address _implementationAddr, bytes memory _data) 
    ERC1967Proxy(_implementationAddr, _data)
    {}
}