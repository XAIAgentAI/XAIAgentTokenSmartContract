// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Removed IERC20 import as it's no longer needed
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title XAIAgentDRC20
 * @dev Implementation of the XAIAgent DRC-20 token for DeepBrainChain
 * Features:
 * - Token locking mechanism
 * - Burnable tokens
 * - Transfer restrictions based on locked amounts
 */
contract XAIAgentDRC20 is ERC20, ERC20Burnable, ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    // Constants
    uint256 public constant PERMANENT_LOCK_DURATION = 1000 * 365 days;
    
    // Token locking mechanism
    struct LockInfo {
        uint256 lockedAt;
        uint256 lockedAmount;
        uint256 unlockAt;
    }
    
    mapping(address => LockInfo[]) private walletLockTimestamp;
    
    // Events
    event TokensLocked(address indexed wallet, uint256 amount, uint256 unlockTime);
    constructor() ERC20("XAA Token", "XAA") {
        _mint(msg.sender, 1000_000_000_000 * 10**decimals()); // 1000 billion tokens
    }


    /**
     * @dev Lock tokens for a specified duration
     * @param to Address to lock tokens for
     * @param amount Amount of tokens to lock
     * @param lockDuration Duration of the lock in seconds
     */
    function lockTokens(
        address to,
        uint256 amount,
        uint256 lockDuration
    ) internal {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Amount must be positive");
        require(lockDuration > 0, "Lock duration must be positive");

        LockInfo[] storage infos = walletLockTimestamp[to];
        require(infos.length < 100, "Too many lock entries");

        uint256 lockedAt = block.timestamp;
        uint256 unlockAt = lockedAt + lockDuration;

        infos.push(LockInfo(lockedAt, amount, unlockAt));
        emit TokensLocked(to, amount, unlockAt);
    }

    /**
     * @dev Calculate total locked amount for an address
     * @param from Address to check locked amount for
     * @return Total amount of locked tokens
     */
    function calculateLockedAmount(address from) public view returns (uint256) {
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
     * @return Whether the transfer is allowed
     */
    function canTransferAmount(address from, uint256 transferAmount) internal view returns (bool) {
        uint256 lockedAmount = calculateLockedAmount(from);
        uint256 availableAmount = balanceOf(from).sub(lockedAmount);
        return availableAmount >= transferAmount;
    }

    /**
     * @dev Get total and available balance for an address
     * @param account Address to check
     * @return total Total balance
     * @return available Available (unlocked) balance
     */
    function getAvailableBalance(address account) external view returns (uint256 total, uint256 available) {
        total = balanceOf(account);
        uint256 lockedAmount = calculateLockedAmount(account);
        available = total.sub(lockedAmount);
        return (total, available);
    }

    /**
     * @dev Override transfer function to check locked amounts
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(to != address(0), "ERC20: transfer to zero address");
        require(amount > 0, "Transfer amount must be positive");
        
        if (walletLockTimestamp[_msgSender()].length > 0) {
            require(canTransferAmount(_msgSender(), amount), "Insufficient unlocked balance");
        }

        return super.transfer(to, amount);
    }

    /**
     * @dev Override transferFrom function to check locked amounts
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        require(to != address(0), "ERC20: transfer to zero address");
        require(amount > 0, "Transfer amount must be positive");
        
        if (walletLockTimestamp[from].length > 0) {
            require(canTransferAmount(from, amount), "Insufficient unlocked balance");
        }

        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Public wrapper for lockTokens - only for testing
     * @param to Address to lock tokens for
     * @param amount Amount of tokens to lock
     * @param duration Duration of the lock in seconds
     */
    function testLockTokens(address to, uint256 amount, uint256 duration) public {
        lockTokens(to, amount, duration);
    }

}
