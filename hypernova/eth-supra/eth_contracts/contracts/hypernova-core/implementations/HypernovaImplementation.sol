// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

// import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "contracts/hypernova-core/implementations/Helpers.sol";
import "../../interfaces/IHypernova.sol";

contract HypernovaImplementation is Initializable, Helpers {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, uint256 _msgId) public initializer {
        _setAdmin(_admin);
        _setInitialMsgId(_msgId);
    }
    function setAdmin(address _admin) external onlyAdmin {
        _setAdmin(_admin);
        emit IHypernova.UpdatedAdmin(msg.sender, _admin);
    }
    function postMessage(bytes memory messageData, uint64 toChainId) external isNotPaused {
        if (!getHNConfig(toChainId).enabled) revert UnsupportedToChain();
        emit IHypernova.MessagePosted(
            msg.sender,
            msgId,
            toChainId,
            messageData
        );
        msgId++;
    }

    /** Adding a toChainID, Updating and computing fees
     * 
     * @param enabled - is toChainID is registered
     * @param toChaiID - destination chain id
     * @param cg - committee updater gas cost in $Quant : (gasUnits * gasPrice) in $Quant
     * @param cm - committee updater margin
     * @param vm - hn margin of verification fee
     * @param x - traffic to hn-core (unpredictable, add a realistic value)
     */
    function addOrUpdateHNConfig(
        bool enabled,
        uint64 toChaiID,
        uint256 cg,
        uint64 cm,
        uint64 vm,
        uint64 x
    ) public onlyAdmin {
        // Not checking cm, vm because the margins can be 0 %
        if (checkZeroValue(toChaiID) || checkZeroValue(cg) || checkZeroValue(x)) revert InvalidInput();
        if (!isValidMargin(vm) || !isValidMargin(cm) ) revert InvalidMargin();

        // cr will never become 0
        uint64 cr = _computeCUreward(cg, cm);
        // If x > cr : when computing v = cr/x ,v becomes 0. 
        if (!isValidTrafficX(x, cr)) revert XCannotBeMore();
        // v will never become 0
        uint64 v = _computeVerificationFee(cr, x, vm);

        IHypernova.HNConfig storage _hnConfig = hnConfig[toChaiID];
        _hnConfig.enabled = enabled;
        _hnConfig.cg = cg;
        _hnConfig.cm = cm;
        _hnConfig.vm = vm;
        _hnConfig.x = x;
        _hnConfig.v = v;
        _hnConfig.cr = cr;
        emit IHypernova.UpdatedHNConfig(msg.sender, _hnConfig);
    }
    
    function getHNConfig(uint64 toChainId) public view returns (IHypernova.HNConfig memory){
        return hnConfig[toChainId];
    }

    function changeState(bool _isPaused) external onlyAdmin {
        isPaused = _isPaused;
        emit IHypernova.HNBridgePauseState(msg.sender, _isPaused);
    }

    function checkIsHypernovaPaused() public view returns(bool) {
        return isPaused;
    }
}
