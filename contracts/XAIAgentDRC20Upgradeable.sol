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

    // Upgrade control
    address public canUpgradeAddress;
    bool public disableUpgrade;

    // Lock management
    bool public isLockActive;
    mapping(address => bool) public walletLockPermission;
    mapping(address => LockInfo[]) private walletLockTimestamp;
    
    // Token locking mechanism
    struct LockInfo {
        uint256 lockedAt;
        uint256 lockedAmount;
        uint256 unlockAt;
    }

    // Events
    event TransferAndLock(address indexed from, address indexed to, uint256 value, uint256 blockNumber);
    event LockDisabled(uint256 timestamp, uint256 blockNumber);
    event LockEnabled(uint256 timestamp, uint256 blockNumber);
    event LockPermissionEnabled(address indexed wallet);
    event LockPermissionDisabled(address indexed wallet);
    event AuthorizedUpgradeSelf(address indexed upgradeAddress);
    event DisableContractUpgrade(uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("XAIAgent", "XAA");
        __ERC20Burnable_init();
        __ERC20Permit_init("XAIAgent");
        __ReentrancyGuard_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        
        _mint(msg.sender, 100_000_000_000 * 10**decimals()); // 100 billion tokens
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        require(!disableUpgrade, "Contract upgrade is disabled");
        require(canUpgradeAddress != address(0), "No upgrade permission set");
        require(msg.sender == canUpgradeAddress, "Only canUpgradeAddress can upgrade");
        require(newImplementation != address(0), "Invalid implementation address");
        canUpgradeAddress = address(0);
    }

    /**
     * @dev Set the address that can perform the next upgrade
     * @param _canUpgradeAddress Address that will be authorized to upgrade
     */
    function setUpgradePermission(address _canUpgradeAddress) external onlyOwner {
        canUpgradeAddress = _canUpgradeAddress;
        emit AuthorizedUpgradeSelf(_canUpgradeAddress);
    }

    /**
     * @dev Disable contract upgradeability permanently
     */
    function disableContractUpgrade() external onlyOwner {
        disableUpgrade = true;
        emit DisableContractUpgrade(block.timestamp);
    }

    /**
     * @dev Returns the current version of the contract
     * @return uint256 The version number
     */
    function version() external pure returns (uint256) {
        return 1;
    }

    /**
     * @dev Enable token locking functionality
     */
    function lockTokensEnable() external onlyOwner {
        isLockActive = true;
        emit LockEnabled(block.timestamp, block.number);
    }

    /**
     * @dev Disable token locking functionality
     */
    function lockTokensDisable() external onlyOwner {
        isLockActive = false;
        emit LockDisabled(block.timestamp, block.number);
    }

    /**
     * @dev Enable lock functionality for a specific wallet
     * @param wallet Address to enable locking for
     */
    function enableLockForWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        walletLockPermission[wallet] = true;
        emit LockPermissionEnabled(wallet);
    }

    /**
     * @dev Disable lock functionality for a specific wallet
     * @param wallet Address to disable locking for
     */
    function disableLockForWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        walletLockPermission[wallet] = false;
        emit LockPermissionDisabled(wallet);
    }

    /**
     * @dev Transfer and lock tokens in one transaction
     * @param to Recipient address
     * @param value Amount to transfer and lock
     * @param lockSeconds Duration of the lock in seconds
     */
    function transferAndLock(address to, uint256 value, uint256 lockSeconds) external {
        require(walletLockPermission[msg.sender], "Lock not enabled for this wallet");
        require(to != address(0), "Invalid recipient");
        require(value > 0, "Invalid amount");
        require(lockSeconds > 0, "Invalid lock duration");
        require(isLockActive, "Lock functionality is disabled");
        
        bool success = super.transfer(to, value);
        require(success, "Transfer failed");
        
        lockTokens(to, value, lockSeconds);
    }

    /**
     * @dev Internal function to lock tokens after transfer
     * @param wallet Address of the wallet to lock tokens for
     * @param amount Amount of tokens to lock
     * @param duration Duration of the lock in seconds
     */
    function lockTokens(address wallet, uint256 amount, uint256 duration) private {
        require(wallet != address(0), "Invalid wallet address");
        require(amount > 0, "Invalid amount");
        require(duration > 0, "Invalid lock duration");
        
        uint256 lockedAt = block.timestamp;
        uint256 unlockAt = lockedAt + duration;
        
        walletLockTimestamp[wallet].push(LockInfo({
            lockedAt: lockedAt,
            lockedAmount: amount,
            unlockAt: unlockAt
        }));
        
        emit TransferAndLock(msg.sender, wallet, amount, block.number);
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
    function canTransferAmount(address from, uint256 transferAmount) public view returns (bool) {
        if (!isLockActive) {
            return true;
        }
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
        
        if (isLockActive && walletLockTimestamp[msg.sender].length > 0) {
            bool canTransfer = canTransferAmount(msg.sender, amount);
            require(canTransfer, "Insufficient unlocked balance");
        }
        bool success = super.transfer(to, amount);
        require(success, "Transfer failed");
        return true;
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
        
        if (isLockActive && walletLockTimestamp[from].length > 0) {
            bool canTransfer = canTransferAmount(from, amount);
            require(canTransfer, "Insufficient unlocked balance");
        }
        bool success = super.transferFrom(from, to, amount);
        require(success, "Transfer failed");
        return true;
    }
}
