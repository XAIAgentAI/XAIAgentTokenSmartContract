// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// Removed IERC20 import as it's no longer needed
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * @title XAIAgentDRC20Upgradeable
 * @dev Implementation of the XAIAgent DRC-20 token for DeepBrainChain with upgrade capability
 * Features:
 * - Token locking mechanism
 * - Burnable tokens
 * - Transfer restrictions based on locked amounts
 * - Upgradeable contract pattern
 */
contract XAIAgentDRC20Upgradeable is 
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeMathUpgradeable for uint256;

    // Time constants
    uint256 public constant PERMANENT_LOCK_DURATION = 1000 * 365 days;
    
    // Token locking mechanism
    mapping(address => LockInfo[]) private walletLockTimestamp;
    
    // Token locking mechanism
    struct LockInfo {
        uint256 lockedAt;
        uint256 lockedAmount;
        uint256 unlockAt;
    }

    // Events
    event TokensLocked(address indexed wallet, uint256 amount, uint256 unlockTime);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("XAA Token", "XAA");
        __ERC20Burnable_init();
        __ERC20Permit_init("XAA Token");
        __ReentrancyGuard_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        
        _mint(msg.sender, 1000_000_000_000 * 10**decimals()); // 1000 billion tokens
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // Add any additional upgrade authorization logic here if needed
    }

    /**
     * @dev Lock tokens for a specified duration
     * @param wallet Address of the wallet to lock tokens for
     * @param amount Amount of tokens to lock
     * @param duration Duration of the lock in seconds
     */
    function lockTokens(address wallet, uint256 amount, uint256 duration) internal {
        uint256 lockedAt = block.timestamp;
        uint256 unlockAt = lockedAt + duration;
        
        walletLockTimestamp[wallet].push(LockInfo({
            lockedAt: lockedAt,
            lockedAmount: amount,
            unlockAt: unlockAt
        }));
        
        emit TokensLocked(wallet, amount, unlockAt);
    }

    /**
     * @dev Calculate the total locked amount for a wallet
     * @param from Address of the wallet
     * @return Total locked amount
     */
    function calculateLockedAmount(address from) internal view returns (uint256) {
        LockInfo[] storage lockInfos = walletLockTimestamp[from];
        uint256 lockedAmount = 0;

        for (uint256 i = 0; i < lockInfos.length; i++) {
            if (block.timestamp < lockInfos[i].unlockAt) {
                lockedAmount = lockedAmount.add(lockInfos[i].lockedAmount);
            }
        }

        return lockedAmount;
    }

    /**
     * @dev Check if an address can transfer a specific amount
     * @param from Address to check
     * @param transferAmount Amount to transfer
     * @return Whether the transfer is possible
     */
    function canTransferAmount(address from, uint256 transferAmount) internal view returns (bool) {
        uint256 lockedAmount = calculateLockedAmount(from);
        uint256 availableAmount = balanceOf(from).sub(lockedAmount);
        return availableAmount >= transferAmount;
    }

    /**
     * @dev Get the total and available amounts for a wallet
     * @param caller Address to check
     * @return total Total balance
     * @return available Available (unlocked) balance
     */
    function getAvailableBalance(address caller) public view returns (uint256 total, uint256 available) {
        uint256 lockedAmount = calculateLockedAmount(caller);
        total = balanceOf(caller);
        available = total.sub(lockedAmount);
        return (total, available);
    }

    /**
     * @dev Get lock info for a specific entry
     * @param caller Address to check
     * @param index Index of the lock entry
     * @return amount Locked amount
     * @return unlockTime Unlock timestamp
     */
    function getLockAmountAndUnlockAt(address caller, uint16 index) public view returns (uint256 amount, uint256 unlockTime) {
        require(index < walletLockTimestamp[caller].length, "Index out of range");
        LockInfo memory lockInfo = walletLockTimestamp[caller][index];
        return (lockInfo.lockedAmount, lockInfo.unlockAt);
    }

    /**
     * @dev Override transfer function to check for locked tokens
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        if (to == address(0) || amount == 0) {
            return super.transfer(to, amount);
        }
        require(canTransferAmount(msg.sender, amount), "Transfer amount exceeds unlocked balance");
        return super.transfer(to, amount);
    }

    /**
     * @dev Override transferFrom function to check for locked tokens
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        if (to == address(0) || amount == 0) {
            return super.transferFrom(from, to, amount);
        }
        require(canTransferAmount(from, amount), "Transfer amount exceeds unlocked balance");
        return super.transferFrom(from, to, amount);
    }
}
