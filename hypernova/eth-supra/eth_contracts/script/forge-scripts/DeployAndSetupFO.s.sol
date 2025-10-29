// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "../../lib/forge-std/src/Script.sol";
import {console} from "../../lib/forge-std/src/console.sol";
// Interface
import {IFeeOperator} from "contracts/interfaces/IFeeOperator.sol";

// Proxy contract
import {FeeOperator} from "contracts/fee-operator/FeeOperator.sol";

// Implekentation contract
import {FeeOperatorImpl} from "contracts/fee-operator/implementations/FeeOperatorImpl.sol";


contract DeployAndSetupFO is Script {
    address public constant ADMIN = 0xd2f24b047b3eaD105885a1A99eb40feCAeD66668;
    address public constant HN_CORE = 0x50888Fc24e1224E12f5C8a31310A47B98b2A7f75;
    address public constant DORA_STORAGE = 0x131918bC49Bb7de74aC7e19d61A01544242dAA80;
    uint256 SUPRA_USDT_PAIR_INDEX = 500;


    FeeOperator public feeOperatorProxy;
    FeeOperatorImpl public feeOperatorImpl;
    IFeeOperator public feeOperator;


    function run() public {
        deployFO(ADMIN, HN_CORE, DORA_STORAGE, SUPRA_USDT_PAIR_INDEX);
        
        // Comment out the following if the ADMIN is mutlisig
         vm.startBroadcast();
         address sValueFeed = address(DORA_STORAGE);
         feeOperator.setSValueFeed(sValueFeed, SUPRA_USDT_PAIR_INDEX);
         bool enabledToChainID = true;
         uint64 toChaiID = 6;
         uint64 rg = 4000000; // 4000 units * 100 Quants = 4000000
         uint64 rm = 5000; // 50% 
         uint64 sm = 5000; //50%
         uint64 tierMicroUSDT = 5000000000; // 5000 USDT
         uint128 tierWhaleUSDT = 1000000000000; // 1M USDT
         uint64 tierMicroPercentage = 50; // 0.5%
         uint64 tierStandardPercentage = 30; // 0.3%
         uint64 tierWhalePercentage = 20; // 0.2%
         adminFOSetup(
             sValueFeed,
             SUPRA_USDT_PAIR_INDEX,
             enabledToChainID,
             toChaiID,
             rg,
             rm,
             sm,
             tierMicroUSDT,
             tierWhaleUSDT,
             tierMicroPercentage,
             tierStandardPercentage,
             tierWhalePercentage
         );
         vm.stopBroadcast();
    }

    function deployFO(address _admin, address _hypernova, address _sValueFeed, uint256 _supraUsdtPairIndex) public returns (IFeeOperator){
        vm.startBroadcast();
        // Deploying implementations
        feeOperatorImpl = new FeeOperatorImpl();
        console.log("FeeOperatorImpl: %s", address(feeOperatorImpl));

        // Deploying proxy contracts
        feeOperatorProxy = new FeeOperator(address(feeOperatorImpl), abi.encodeCall(IFeeOperator.initialize, (   
            _admin,
            _hypernova,
            _sValueFeed,
            _supraUsdtPairIndex
        )));
        feeOperator = IFeeOperator(address(feeOperatorProxy));
        require(feeOperator.admin() == _admin, "Deployment Failed");
        console.log("feeOperatorProxy : ", address(feeOperator));
        vm.stopBroadcast();
        return feeOperator;
    }

    // Admin needs to do the following setup. Admin is Gnosis Multisig, so these functions are not calleable from this script but adding for the reference
    function adminFOSetup(
        address sValueFeed,
        uint256 _supraUsdtPairIndex,
        bool enabledToChainID,
        uint64 toChaiID,
        uint64 rg,
        uint64 rm,
        uint64 sm,
        uint64 tierMicroUSDT,
        uint128 tierWhaleUSDT,
        uint64 tierMicroPercentage,
        uint64 tierStandardPercentage,
        uint64 tierWhalePercentage
    ) public {
        feeOperator.setSValueFeed(sValueFeed, _supraUsdtPairIndex);
        feeOperator.addOrUpdateTBFeeConfig(
            enabledToChainID,
            toChaiID, 
            rg, 
            rm, 
            sm,
            tierMicroUSDT,
            tierWhaleUSDT,
            tierMicroPercentage,
            tierStandardPercentage,
            tierWhalePercentage
        );
    }
}
