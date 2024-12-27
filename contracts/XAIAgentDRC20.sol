// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title XAIAgentDRC20
 * @dev Implementation of the XAIAgent DRC-20 token for DeepBrainChain
 * Features:
 * - 72-hour investment window
 * - Token distribution with specific allocations and lock periods
 * - Automatic token distribution after investment period
 */
/**
 * @title XAA Token
 * @dev Implementation of the XAA token on DeepBrainChain
 */
contract XAIAgentDRC20 is ERC20, ERC20Burnable, ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    // Time constants
    uint256 public constant INVESTMENT_DURATION = 72 hours;
    uint256 public constant PERMANENT_LOCK_DURATION = 1000 * 365 days;

    // Contract state variables
    uint256 public investmentStartTime;
    bool public investmentOpen;
    uint256 public totalDBCInvested;
    uint256 public initialTokenPrice;  // Price in DBC per token
    uint256 public investmentEndTime;
    bool public tokensDistributed;

    // DBC token interface
    IERC20 public dbcToken;
    
    // Investment state and token allocations
    uint256 public constant TARGET_DBC_VALUE = 25000 * 10**18; // $25,000 worth of DBC
    uint256 public constant MIN_MARKET_VALUE = 75000 * 10**18; // $75,000 minimum market value
    uint256 public constant INITIAL_MARKET_VALUE = 100000 * 10**18; // $100,000 initial market value
    uint256 public constant CREATOR_LOCK_DURATION = 30 days;
    uint256 public constant ECOSYSTEM_LOCK_DURATION = 180 days;
    
    // Token allocation percentages (in basis points, 100 = 1%)
    uint256 public constant CREATOR_ALLOCATION = 1000; // 10%
    uint256 public constant XAA_POOL_ALLOCATION = 500; // 5%
    uint256 public constant ECOSYSTEM_ALLOCATION = 1000; // 10%
    uint256 public constant DBC_POOL_PERMANENT = 5000; // 50% permanent reserve
    uint256 public constant DBC_POOL_INVESTOR = 2500; // 25% for investors
    
    // Addresses
    address public xaaPoolAddress;
    address public ecosystemAddress;
    address public creatorAddress;
    address[] private investors;
    
    // Token locking mechanism
    struct LockInfo {
        uint256 lockedAt;
        uint256 lockedAmount;
        uint256 unlockAt;
    }

    // Pool tracking
    struct Pool {
        address tokenAddress;
        uint256 tokenAmount;
        uint256 dbcAmount;
        bool isLocked;
    }

    // Events
    event InvestmentStarted(uint256 startTime, uint256 endTime);
    event InvestmentEnded(uint256 totalInvested);
    event TokensDistributed(address indexed investor, uint256 amount);
    event InvestmentReceived(address indexed investor, uint256 amount);
    event DBCRefunded(address indexed investor, uint256 amount);
    event PoolCreated(address indexed tokenAddress, uint256 tokenAmount, uint256 dbcAmount);
    event PoolLocked(address indexed tokenAddress, uint256 lockedAmount);
    event TokensLocked(address indexed wallet, uint256 amount, uint256 unlockTime);

    // Mappings
    mapping(address => uint256) public investments;
    mapping(address => LockInfo[]) private walletLockTimestamp;
    
    // Pools
    Pool public xaaPool;
    Pool public dbcPool;
    constructor(
        uint256 _initialTokenPrice,
        address _dbcTokenAddress,
        address _xaaPoolAddress,
        address _ecosystemAddress,
        address _creatorAddress
    ) ERC20("XAA Token", "XAA") {
        require(_dbcTokenAddress != address(0), "Invalid DBC token address");
        require(_xaaPoolAddress != address(0), "Invalid XAA pool address");
        require(_ecosystemAddress != address(0), "Invalid ecosystem address");
        require(_creatorAddress != address(0), "Invalid creator address");
        
        dbcToken = IERC20(_dbcTokenAddress);
        initialTokenPrice = _initialTokenPrice;
        xaaPoolAddress = _xaaPoolAddress;
        ecosystemAddress = _ecosystemAddress;
        creatorAddress = _creatorAddress;
        
        // Set initial state
        investmentOpen = false;
        _mint(address(this), 1000_000_000_000 * 10**decimals()); // 1000 billion tokens
    }

    /**
     * @dev Start the 72-hour investment window
     */
    function startInvestment() external onlyOwner {
        require(!investmentOpen, "Investment already started");
        
        investmentStartTime = block.timestamp;
        investmentEndTime = investmentStartTime + INVESTMENT_DURATION;
        investmentOpen = true;
        
        emit InvestmentStarted(investmentStartTime, investmentEndTime);
    }

    /**
     * @dev Allow investors to invest DBC tokens during the investment window
     * @param amount Amount of DBC tokens to invest
     */
    function invest(uint256 amount) external nonReentrant {
        require(investmentOpen, "Investment not open");
        require(block.timestamp < investmentEndTime, "Investment period ended");
        require(amount > 0, "Amount must be positive");
        
        // Transfer DBC tokens from investor to contract
        require(dbcToken.transferFrom(msg.sender, address(this), amount), "DBC transfer failed");
        
        // Check if this is a new investor
        if (investments[msg.sender] == 0) {
            investors.push(msg.sender);
        }

        // Record investment
        investments[msg.sender] = investments[msg.sender].add(amount);
        totalDBCInvested = totalDBCInvested.add(amount);
        
        emit InvestmentReceived(msg.sender, amount);
        
        // Auto-close investment if time is up
        if (block.timestamp >= investmentEndTime) {
            endInvestment();
        }
    }

    /**
     * @dev End investment period and distribute tokens
     */
    function endInvestment() public {
        require(investmentOpen, "Investment not open");
        require(block.timestamp >= investmentEndTime, "Investment period not ended");
        require(!tokensDistributed, "Tokens already distributed");
        
        investmentOpen = false;
        tokensDistributed = true;
        
        // Calculate token allocations based on initial market value
        uint256 totalTokenSupply = INITIAL_MARKET_VALUE;
        
        uint256 creatorTokens = totalTokenSupply.mul(CREATOR_ALLOCATION).div(10000);
        uint256 xaaPoolTokens = totalTokenSupply.mul(XAA_POOL_ALLOCATION).div(10000);
        uint256 ecosystemTokens = totalTokenSupply.mul(ECOSYSTEM_ALLOCATION).div(10000);
        uint256 dbcPoolPermanent = totalTokenSupply.mul(DBC_POOL_PERMANENT).div(10000);
        uint256 dbcPoolInvestor = totalTokenSupply.mul(DBC_POOL_INVESTOR).div(10000);
        
        // Calculate initial supply for distribution
        
        // Mint and lock tokens for different allocations
        // Creator allocation - 30 day lock
        _mint(creatorAddress, creatorTokens);
        lockTokens(creatorAddress, creatorTokens, CREATOR_LOCK_DURATION);
        emit TokensDistributed(creatorAddress, creatorTokens);
        
        // XAA Pool - permanent lock
        _mint(xaaPoolAddress, xaaPoolTokens);
        lockTokens(xaaPoolAddress, xaaPoolTokens, PERMANENT_LOCK_DURATION);
        xaaPool = Pool({
            tokenAddress: address(this),
            tokenAmount: xaaPoolTokens,
            dbcAmount: 0,
            isLocked: true
        });
        emit TokensDistributed(xaaPoolAddress, xaaPoolTokens);
        emit PoolCreated(address(this), xaaPoolTokens, 0);
        
        // Ecosystem allocation - 180 day lock
        _mint(ecosystemAddress, ecosystemTokens);
        lockTokens(ecosystemAddress, ecosystemTokens, ECOSYSTEM_LOCK_DURATION);
        emit TokensDistributed(ecosystemAddress, ecosystemTokens);
        
        // Calculate token distribution based on DBC investment
        uint256 totalInvestorTokens = 0;
        
        if (totalDBCInvested > 0) {
            uint256 dbcValueInUSD = getDBCValueInUSD(totalDBCInvested);
            uint256 distributionRatio;
            
            if (dbcValueInUSD >= TARGET_DBC_VALUE) {
                // Full distribution if target met
                distributionRatio = 1e18;
            } else {
                // Proportional distribution based on investment
                distributionRatio = dbcValueInUSD.mul(1e18).div(TARGET_DBC_VALUE);
            }
            
            // Calculate tokens to distribute
            totalInvestorTokens = dbcPoolInvestor.mul(distributionRatio).div(1e18);
            
            // Distribute tokens to investors
            for (uint256 i = 0; i < investors.length; i++) {
                address investor = investors[i];
                uint256 investorShare = totalInvestorTokens.mul(investments[investor]).div(totalDBCInvested);
                
                if (investorShare > 0) {
                    _mint(investor, investorShare);
                    emit TokensDistributed(investor, investorShare);
                }
            }
        }
        
        // Create DBC pool with permanent reserve
        uint256 permanentTokens = dbcPoolPermanent.add(dbcPoolInvestor.sub(totalInvestorTokens)); // Permanent + undistributed
        dbcPool = Pool({
            tokenAddress: address(this),
            tokenAmount: permanentTokens,
            dbcAmount: totalDBCInvested,
            isLocked: true
        });
        emit PoolCreated(address(this), dbcPool.tokenAmount, totalDBCInvested);
        emit PoolLocked(address(this), permanentTokens);
        
        // Calculate and distribute any refunds if needed
        if (totalDBCInvested > TARGET_DBC_VALUE) {
            uint256 refundRatio = totalDBCInvested.sub(TARGET_DBC_VALUE).mul(1e18).div(totalDBCInvested);
            for (uint256 i = 0; i < investors.length; i++) {
                address investor = investors[i];
                uint256 refundAmount = investments[investor].mul(refundRatio).div(1e18);
                if (refundAmount > 0) {
                    require(dbcToken.transfer(investor, refundAmount), "DBC refund failed");
                    emit DBCRefunded(investor, refundAmount);
                }
            }
        }
        
        emit InvestmentEnded(totalDBCInvested);
    }

    /**
     * @dev Get number of investors
     * @return Number of unique investors
     */
    function getInvestorCount() external view returns (uint256) {
        return investors.length;
    }

    /**
     * @dev Get investment amount for an address
     * @param investor Address to check
     * @return Amount invested in DBC
     */
    function getInvestmentAmount(address investor) external view returns (uint256) {
        return investments[investor];
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

    /**
     * @dev Calculate the USD value of DBC tokens
     * @param amount Amount of DBC tokens
     * @return USD value
     */
    function getDBCValueInUSD(uint256 amount) internal pure returns (uint256) {
        // For demonstration, using a fixed rate
        // In production, this should use an oracle
        return amount;
    }
}
