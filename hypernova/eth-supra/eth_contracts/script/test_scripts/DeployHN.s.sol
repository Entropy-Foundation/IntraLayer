// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "./HN.sol";
import {Script} from "../../lib/forge-std/src/Script.sol";
import {console} from "../../lib/forge-std/src/console.sol";


contract DeployHNScript is Script {

    HN public hn;
    function run() public {
        vm.startBroadcast(vm.envUint("USER_PRIVATE_KEY"));
        hn = new HN();
        console.log("HN deployed at : ", address(hn));
        vm.stopBroadcast(); 
    }
}
