// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol"; //@dev: Library
/**
 * @title Hypernova
 * @dev A proxy contract that follows the ERC1967 standard, allowing for upgradeable smart contracts.
 * @notice This contract extends the ERC1967Proxy, initializing the proxy with an implementation contract
 * and optionally passing initialization data.
 */
contract Hypernova is ERC1967Proxy {
    event ProxyInitialized(address indexed implementationAddr);
    /**
     * @notice Constructs the Hypernova contract and initializes the proxy.
     * @param _implementationAddr The address of the implementation contract to delegate calls to.
     * @param _data Optional initialization data to be passed to the implementation contract.
     * @dev The constructor sets up the proxy by calling the ERC1967Proxy constructor with the implementation
     * address and initialization data. This sets up the contract to delegate calls to the specified implementation.
     */
    constructor(
        address _implementationAddr,
        bytes memory _data
    ) ERC1967Proxy(_implementationAddr, _data) {
        emit ProxyInitialized(_implementationAddr);
    }
}
