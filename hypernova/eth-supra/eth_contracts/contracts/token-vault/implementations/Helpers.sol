// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "contracts/token-vault/implementations/Errors.sol";
import "contracts/token-vault/implementations/State.sol";
import "contracts/interfaces/IVault.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";


contract Helpers is State, Errors {

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert UnauthorizedSender();
        }
        _;
    }
    modifier isNotPaused() {
        if (isPaused) {
            revert VaultPaused();
        }
        _;
    }

    modifier onlyBridge() {
        if (msg.sender != tokenBridgeContract) {
            revert UnauthorizedSender();
        }
        _;
    }

    modifier isReleaseEnabled() {
        if (!releaseEnabled) {
            revert ReleaseDisabled();
        }
        _;
    }
    function _setAdmin(address _admin) internal {
        if (_admin != address(0)) {
            admin = _admin;
        } else revert InvalidInput();
    }
    function _setTokenBridgeService(address _tokenBridgeContract) internal {
        if (_tokenBridgeContract != address(0)) {
            tokenBridgeContract = _tokenBridgeContract;
        } else revert InvalidInput();
    }

    function _setAdminWithdrawDelay(uint256 _delay) internal {
        if (_delay != 0) {
            adminWithdrawDelay = _delay;
        } else revert InvalidInput();
    }

    function changeReleaseState(bool _releaseEnabled) external onlyAdmin {
        releaseEnabled = _releaseEnabled;
    }
    function _addTransfer(address token, uint256 amount, address to ) internal returns (bytes32, uint256) {
        uint256 _withdrawNonce = getNextWithdrawNonce(); 
        bytes32 id = getId(token, amount, to, _withdrawNonce);
        adminTransfers[id] = IVault.DelayedTransfer({
            amount: amount,
            to: to,
            token: token,
            nonce: _withdrawNonce,
            timestamp: block.timestamp,
            isAdded: true
        });

        withdrawNonce = _withdrawNonce + 1;
        return (id, _withdrawNonce);
    }
    function getId(address token, uint256 amount, address to, uint256 _withdrawNonce) public view returns (bytes32 id) {
        id = keccak256(
            abi.encodePacked(token, amount, to, _withdrawNonce, block.timestamp)
        );
    }

    function getNextWithdrawNonce() public view returns (uint256){
        return withdrawNonce;
    }

    function getLockLimits(
        address token
    ) public view returns (uint256, uint256, uint256) {
        IVault.LockLimit memory lockLimit= lockLimits[token];
        return (lockLimit.min, lockLimit.max, lockLimit.globalMax);
    }

    function getReleaseLimits(
        address token
    ) public view returns (uint256, uint256) {
        IVault.ReleaseLimit memory releaseLimit= releaseLimits[token];
        return (releaseLimit.min, releaseLimit.max);
    }

    function isValidLimit(uint256 amount, uint256 min, uint256 max) internal pure returns (bool) {
        return (amount >= min && amount <= max);
    }
    function isValidGlobalLimit(uint256 amount, uint256 globalMax) internal pure returns (bool) {
        return (amount < globalMax || globalMax == 0);
    }

    function getTokenBridgeContract() public view returns (address) {
        return tokenBridgeContract;
    }

    function getLockedTokenBalance(address token) public view returns (uint256) {
        return lockedTokens[token];
    }

    function getAdminTransfers(bytes32 id) public view returns (IVault.DelayedTransfer memory) {
        return adminTransfers[id];
    }

    function getAdminWithdrawDelay() public view returns (uint256) {
        return adminWithdrawDelay;
    }

    function checkIsVaultPaused() external view returns(bool){
        return isPaused;
    }
    function getImplementationAddress() public view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
