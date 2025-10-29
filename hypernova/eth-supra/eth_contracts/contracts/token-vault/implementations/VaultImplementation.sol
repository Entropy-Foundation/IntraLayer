// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2025 Supra Labs
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "contracts/token-vault/implementations/Helpers.sol";
import "contracts/interfaces/IWETH.sol";
import "contracts/interfaces/IVault.sol";


contract VaultImplementation is Initializable, Helpers {
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin,
        address _tokenBridgeService,
        uint256 _delay
    ) public initializer {
        _setTokenBridgeService(_tokenBridgeService);
        _setAdmin(_admin);
        _setAdminWithdrawDelay(_delay);
    }
    function setAdmin(address _admin) external onlyAdmin {
        _setAdmin(_admin);
        emit IVault.UpdatedAdmin(msg.sender, _admin);
    }

    function setTokenBridgeContract(address _tokenBridgeContract) external onlyAdmin isNotPaused {
        _setTokenBridgeService(_tokenBridgeContract);
    }
    function changeState(bool _isPaused) external onlyAdmin {
        isPaused = _isPaused;
    }

    function lockTokens(
        address token,
        uint256 amount
    ) external onlyBridge isNotPaused {
        uint256 totalLockedAmount = getLockedTokenBalance(token);
        uint256 newTotalLockedAmount = totalLockedAmount + amount;
        (uint256 min, uint256 max, uint256 globalMax) = getLockLimits(token);
        if (!isValidLimit(amount, min, max)) revert LimitBreached();
        if (!isValidGlobalLimit(newTotalLockedAmount, globalMax)) revert GlobaTokenLockLimitBreached();
        // @notice to reviewer : Do we need to check the token.balanceOf(this) >= lockedTokens[tokenAddr] + amount
        lockedTokens[token] = newTotalLockedAmount;
        emit IVault.Locked(token, amount);
    }

    function lockNative(
        address nativeToken,
        uint256 amount
    ) external payable onlyBridge isNotPaused {
        if (msg.value != amount) revert InvalidInput();
        uint256 totalLockedAmount = getLockedTokenBalance(nativeToken);
        uint256 newTotalLockedAmount = totalLockedAmount + amount;

        (uint256 min, uint256 max, uint256 globalMax) = getLockLimits(nativeToken);
        if (!isValidLimit(amount, min, max)) revert LimitBreached();
        if (!isValidGlobalLimit(newTotalLockedAmount, globalMax)) revert GlobaTokenLockLimitBreached();
        
        lockedTokens[nativeToken] = newTotalLockedAmount;
        IWETH(nativeToken).deposit{value: amount}();
        emit IVault.Locked(nativeToken, amount);
    }

    function release(
        address token,
        uint256 amount,
        address to
    ) external onlyBridge isNotPaused isReleaseEnabled {
        if (to == address(0) || amount == 0 || token == address(0)) revert InvalidInput();
        (uint256 min, uint256 max) = getReleaseLimits(token);
        if (!isValidLimit(amount, min, max)) revert LimitBreached();

        if (amount > getLockedTokenBalance(token)) revert InsufficientBalance();
        lockedTokens[token] -= amount;
        IERC20(token).safeTransfer(to, amount);
        emit IVault.Released(to, token, amount);
    }

    function addAdminWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyAdmin returns (bytes32) {
        if (to == address(0) || amount == 0 || token == address(0)) revert InvalidInput();
        if (amount > getLockedTokenBalance(token)) revert InsufficientBalance();

        (bytes32 id, uint256 _withdrawNonce) = _addTransfer(token, amount, to);
        emit IVault.AdminWithdrawAdded(id, token, to, amount, _withdrawNonce, block.timestamp);
        return id;
    }

    function removeAddedAdminWithdraw(bytes32 id) external onlyAdmin returns (bytes32) {
        IVault.DelayedTransfer storage transfer = adminTransfers[id];
        if (!transfer.isAdded || transfer.nonce >= getNextWithdrawNonce()) {
            revert WithdrawDoesNotExist(id);
        }
        transfer.isAdded = false;
        emit IVault.AdminWithdrawRemoved(id, transfer.token, transfer.to, transfer.amount, transfer.nonce, block.timestamp);
        return id;
    }

    function execAdminWithdraw(bytes32 id) external onlyAdmin {
        IVault.DelayedTransfer memory transfer = adminTransfers[id];
        if (!transfer.isAdded  || transfer.nonce >= getNextWithdrawNonce()) {
            revert WithdrawDoesNotExist(id);
        }

        if (block.timestamp > transfer.timestamp + adminWithdrawDelay) {
            delete adminTransfers[id];

            if (transfer.amount > getLockedTokenBalance(transfer.token)) revert InsufficientBalance();
            lockedTokens[transfer.token] -= transfer.amount;
            
            IERC20(transfer.token).safeTransfer(transfer.to, transfer.amount);
            emit IVault.AdminWithdrawExecuted(
                id,
                transfer.token,
                transfer.to,
                transfer.amount,
                transfer.nonce,
                block.timestamp
            );
        } else {
            revert TryLater();
        }
    }

    function setLockLimits(
        address[] calldata tokens,
        uint256[] calldata minLimits,
        uint256[] calldata maxLimits,
        uint256[] calldata globalMaxLimits //  globalMaxLimits == 0 means no limit 
    ) external onlyAdmin {
        if (
            tokens.length != minLimits.length ||
            tokens.length != maxLimits.length ||
            tokens.length != globalMaxLimits.length 
        ) {
            revert InvalidInput();
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0) || (minLimits[i] >= maxLimits[i])) {
                revert InvalidInput();
            }
            lockLimits[tokens[i]] = IVault.LockLimit(minLimits[i], maxLimits[i], globalMaxLimits[i]);
        }
    }

    function setReleaseLimits(
        address[] calldata tokens,
        uint256[] calldata minLimits,
        uint256[] calldata maxLimits
    ) external onlyAdmin {
        if (
            tokens.length != minLimits.length ||
            tokens.length != maxLimits.length 
        ) {
            revert InvalidInput();
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0) || (minLimits[i] >= maxLimits[i])) {
                revert InvalidInput();
            }
            releaseLimits[tokens[i]] = IVault.ReleaseLimit(minLimits[i], maxLimits[i]);
        }
    }

    function upgradeImplementation(
        address newImplementation
    ) external onlyAdmin returns (address) {
        if (newImplementation == address(0)) revert InvalidInput();
        ERC1967Utils.upgradeToAndCall(newImplementation, "");
        return newImplementation;
    }

}
