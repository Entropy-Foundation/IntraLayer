// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "../../lib/forge-std/src/Script.sol";
import {console} from "../../lib/forge-std/src/console.sol";
// Interface
import {IHypernova} from "contracts/interfaces/IHypernova.sol";
// Proxy contract
import {Hypernova} from "contracts/hypernova-core/Hypernova.sol";
// Implementation contracts
import {HypernovaImplementation} from "contracts/hypernova-core/implementations/HypernovaImplementation.sol";

contract DeployAndSetupHN is Script {
    address public constant ADMIN = 0x6C027e024FA9a869F331279816b121d3d3C95491;
    uint256 public constant MSG_ID = 0;
    Hypernova public hypernovaProxy;
    HypernovaImplementation public hypernovaImplementation;
    IHypernova public hypernova;

    function run() public {
        deployHN(ADMIN);

        // Comment out the following if the ADMIN is mutlisig
        // vm.startBroadcast();
        // bool enabled = true;
        // uint64 toChaiID = 6;
        // uint256 cg = 2000000;// 20000 units * 100 price = 2000000
        // uint64 cm = 9990; // 99.90%
        // uint64 _vm = 2000; // 20%
        // uint64 x = 20; 
        // adminHNSetup(
        //     enabled,
        //     toChaiID,
        //     cg,
        //     cm,
        //     _vm,
        //     x
        // );
        // vm.stopBroadcast();
    }

    function deployHN(address _admin) public returns (IHypernova){
        vm.startBroadcast();
        // Deploying implementation
        hypernovaImplementation = new HypernovaImplementation();
        console.log("HypernovaImplementation: %s", address(hypernovaImplementation));
        // Deploying proxy contract
        hypernovaProxy = new Hypernova(address(hypernovaImplementation), abi.encodeCall(IHypernova.initialize, (_admin, MSG_ID)));
        hypernova = IHypernova(address(hypernovaProxy));
        require(hypernova.admin() == _admin, "Deployment Failed");
        console.log("hypernovaProxy : ", address(hypernova));
        vm.stopBroadcast();
        return hypernova;
    }
    
    // Admin needs to do the following setup. Admin is Gnosis Multisig, so these functions are not calleable from this script but adding for the reference
    function adminHNSetup(        
        bool enabled,
        uint64 toChaiID,
        uint256 cg,
        uint64 cm,
        uint64 _vm,
        uint64 x
    ) public {
        hypernova.addOrUpdateHNConfig(
            enabled,
            toChaiID,
            cg,
            cm,
            _vm,
            x
        );
    }
}
