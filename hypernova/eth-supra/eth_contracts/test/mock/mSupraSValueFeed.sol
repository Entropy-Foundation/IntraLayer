// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import {ISupraSValueFeed} from "contracts/interfaces/ISupraSValueFeed.sol";

contract MockSupraSValueFeed is ISupraSValueFeed {

    // Term "pair ID" and "Pair index" both refer to the same, pair index mentioned in our data pairs list.
    // Function to retrieve the data for a single data pair
    function getSvalue(uint256 _pairIndex)
        external 
        view
        returns (ISupraSValueFeed.priceFeed memory) {
            // Values at 10 June 2025, Sepolia : 0x131918bC49Bb7de74aC7e19d61A01544242dAA80
            return ISupraSValueFeed.priceFeed({
                round: 1749550216000,
                decimals: 18,
                time: 1749550216058,
                price: 4130000000000000
            });
        }
}