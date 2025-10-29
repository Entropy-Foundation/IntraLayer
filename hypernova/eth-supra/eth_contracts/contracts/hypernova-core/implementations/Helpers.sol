// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import "contracts/hypernova-core/implementations/State.sol";
import "contracts/hypernova-core/implementations/Errors.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol"; //@dev: Library
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";

contract Helpers is State, Errors {
    function _setAdmin(address _admin) internal {
        if (_admin != address(0)) {
            admin = _admin;
        } else revert InvalidInput();
    }
    function _setInitialMsgId(uint256 _msgId) internal {
        msgId = _msgId;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert UnauthorizedSender();
        }
        _;
    }
    modifier isNotPaused() {
        if (isPaused) {
            revert HNBridgePaused();
        }
        _;
    }
    /**  V = (CUR / X)  / (1 - VM) 
     * 
     * @param cr - committee updater rewards in Quants
     * @param x - traffic to hn-core (unpredictable, add a realistic value)
     * @param vm - hn margin of verification fee
     *      
     *   V = (CUR / X)  / (1 - VM)
     *      CUR = CUR_in_quants
     *      X = HN traffic in one sync period 
     *        => X = 10
     *      VM = (V - CUR)/V
     *         => VM = 10% => 0.1
     * 
     * returns - 
     */
    function computeVerificationFee(uint64 cr, uint64 x, uint64 vm) public pure returns (uint64) {
        if (checkZeroValue(cr) || checkZeroValue(x)) revert InvalidInput();
        if (!isValidMargin(vm)) revert InvalidMargin();
        // If x > cr : when computing v = cr/x ,v becomes 0. 
        if (!isValidTrafficX(x, cr)) revert XCannotBeMore();
        return _computeVerificationFee(cr, x, vm);
    }
    function _computeVerificationFee(uint64 cr, uint64 x, uint64 vm) internal pure returns (uint64 v) {
        // Up casting for calculation without overflow
        uint256 _v = FullMath.mulDiv((cr / x), PERCENTAGE_BASE, (PERCENTAGE_BASE - vm));
        if (_v > type(uint64).max) revert InvalidVComputation(_v);
        v = uint64(_v);
    }
    /** CUR = CUG / (1 - CUM)
     * 
     * @param cg - committee updater gas cost in Quants: (gasUnits * gasPrice) in $Quants (8 decimals)
     * @param cm - committee updater margin
     *      CUG = Gas Units * Gas Price => CUG in Quants => CUG in Quants
     *      Gas Units = 558 + 139 + 858 = 1555
     *      Gas Price = 100 quants
     *      CUG in Quants = 155500 quants
     *     
     *       CUR = CUG / (1 - CUM)
     *       CUG = CUG_in_supra
     *       CUM = (CUR - CUG)/CUR 
     *           => CUM = 10% => 0.1
     * returns - CUR in $Quants (8 decimals)
     */
    function computeCUreward(uint256 cg, uint64 cm) public pure returns (uint64) {
        if (checkZeroValue(cg)) revert InvalidInput();
        if (!isValidMargin(cm)) revert InvalidMargin();
        return _computeCUreward(cg, cm);
    }
    function _computeCUreward(uint256 cg, uint64 cm) internal pure returns (uint64 cr) {
        uint256 _cr = FullMath.mulDiv(cg, PERCENTAGE_BASE, (PERCENTAGE_BASE - cm));
        if (_cr > type(uint64).max) revert InvalidCRComputation(_cr);
        cr = uint64(_cr);
    }

    function getImplementationAddress() public view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function upgradeImplementation(
        address newImplementation
    ) external onlyAdmin returns (address) {
        if (newImplementation == address(0)) revert InvalidInput();
        ERC1967Utils.upgradeToAndCall(newImplementation, "");
        return newImplementation;
    }
    function getNextMsgId() external view returns (uint256) {
       return msgId;
    }

    function checkZeroValue(uint256 value) internal pure returns (bool) {
        return value == 0;
    }

    function isValidMargin(uint64 value) internal pure returns (bool) {
        return value < PERCENTAGE_BASE;
    }

    function isValidTrafficX(uint64 x, uint256 cr) internal pure returns (bool) {
        return x <= cr; 
        
    }
}
