// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.22;

// import "./HN.sol";
// import {Script} from "../../lib/forge-std/src/Script.sol";

// contract HNEmitEvent is Script {

//     HN public hn = HN(0xC4AE54a3d371aAB074C5584d91487d1e7bae1a87);
//     function run() public {
//         vm.startBroadcast(vm.envUint("USER_PRIVATE_KEY"));

//         ITokenBridgeService.MessageData memory _messageData = ITokenBridgeService.MessageData({
//             senderAddr: bytes32(uint256(uint160(msg.sender))),
//             tokenAddress: bytes32(uint256(uint160(msg.sender))),
//             sourceChainId: 1,
//             payload: bytes32("nothing"),
//             amount: 0.001 ether,
//             currentFee: 0 ether,
//             receiverAddr: bytes32(0x199ee3899db632d8146b2be8c5335beddb7a6aee078cba6dba9c5128534496f0)
//         });
//         bytes memory messageData = abi.encode(_messageData);
//         for(uint i; i< 1; i++) {
//             hn.postMessage(messageData);
//         }
//         vm.stopBroadcast();
//     }
// }
