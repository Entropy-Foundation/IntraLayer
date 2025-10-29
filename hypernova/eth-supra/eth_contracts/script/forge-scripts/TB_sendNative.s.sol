// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITokenBridgeService} from "../../contracts/interfaces/ITokenBridgeService.sol";
import {IWETH} from "contracts/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "../../lib/forge-std/src/Script.sol";

contract TBsendNative is Script {

    ITokenBridgeService public tb = ITokenBridgeService(0xf44E604DC44B2f8ccce22037B2727F0E93d12197);
    function run() public {
        vm.startBroadcast();
        address WETH9 = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        address USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        bytes32 receiverAddr = bytes32(0xfb9ef42d99820de4b351b526d735ab76cccc6e0e5b42216afa947c61a18f0084);
        bytes32 payload = bytes32("Hello!");
        uint64 supraChaiId = 6;
        uint256 amount = 100000;
        for (uint i = 0; i<1; i++) {
            // Sending ETH
            // tb.sendNative{value: amount}(receiverAddr, amount, payload, supraChaiId);

            // Sending WETH
            // IWETH(WETH9).approve(address(tb), amount);
            // tb.sendTokens(WETH9, amount, receiverAddr, payload, supraChaiId);

            // Sending USDC
            IWETH(USDC).approve(address(tb), amount);
            tb.sendTokens(USDC, amount, receiverAddr, payload, supraChaiId);
            // revert();
        }
        vm.stopBroadcast();
    }
}
