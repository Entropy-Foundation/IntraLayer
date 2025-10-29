// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;
import {ITokenBridgeService} from "../../contracts/interfaces/ITokenBridgeService.sol";
import {IHypernova} from "../../contracts/interfaces/IHypernova.sol";


contract HN{
    uint256 public msgID;

    function postMessage(bytes memory messageData) public {
        emit IHypernova.MessagePosted(msg.sender, msgID++, 6, messageData);
    }
}