// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

// depending on the requirement, you may build one or more data structures given below. 

interface ISupraSValueFeed {
    // Data structure to hold the pair data
    struct priceFeed {
        uint256 round;
        uint256 decimals;
        uint256 time;
        uint256 price;
    }
   
    /// Below functions enable you to retrieve different flavours of S-Value

    // Term "pair ID" and "Pair index" both refer to the same, pair index mentioned in our data pairs list.
    // Function to retrieve the data for a single data pair
    function getSvalue(uint256 _pairIndex)
        external 
        view
        returns (priceFeed memory);
}