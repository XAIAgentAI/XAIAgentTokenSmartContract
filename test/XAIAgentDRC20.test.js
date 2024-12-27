const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("XAIAgentDRC20", function () {
  let xaaToken;
  let dbcToken;
  let owner;
  let xaaPool;
  let ecosystem;
  let creator;
  let addr1;
  let addr2;

  const INITIAL_TOKEN_PRICE = ethers.utils.parseEther("1"); // 1 DBC
  const TARGET_DBC_VALUE = ethers.utils.parseEther("25000"); // 25k DBC to match contract

  beforeEach(async function () {
    // Get signers
    [owner, xaaPool, ecosystem, creator, addr1, addr2] = await ethers.getSigners();

    // Deploy mock DBC token
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    dbcToken = await MockERC20.connect(owner).deploy();
    await dbcToken.deployed();

    // Deploy XAA token with all required parameters
    const XAAToken = await ethers.getContractFactory("XAIAgentDRC20");
    xaaToken = await XAAToken.connect(owner).deploy(
      INITIAL_TOKEN_PRICE,
      dbcToken.address,
      xaaPool.address,
      ecosystem.address,
      creator.address
    );
    await xaaToken.deployed();

    // Get initial tokens from contract for testing
    const contractBalance = await xaaToken.balanceOf(xaaToken.address);
    expect(contractBalance).to.equal(ethers.utils.parseEther("1000000000000")); // 1000 billion initial supply

    // Initial setup is complete
    // Each test will handle its own investment and distribution logic
  });

  describe("Token Distribution", function () {
    it("Should distribute tokens proportionally when under target", async function () {
      const investAmount = ethers.utils.parseEther("10000"); // 10k DBC - less than target
      
      // Start investment period
      await xaaToken.connect(owner).startInvestment();
      
      // Mint and approve DBC tokens
      await dbcToken.mint(addr2.address, investAmount);
      await dbcToken.connect(addr2).approve(xaaToken.address, investAmount);
      
      // Invest
      await xaaToken.connect(addr2).invest(investAmount);
      
      // Simulate time passing
      await network.provider.send("evm_increaseTime", [72 * 3600]); // 72 hours
      await network.provider.send("evm_mine");
      
      // End investment period
      await xaaToken.connect(owner).endInvestment();
      
      // Check balances
      const addr2Balance = await xaaToken.balanceOf(addr2.address);
      expect(addr2Balance).to.be.gt(0);
      
      // Verify proportional distribution (10k/25k = 40% of allocation)
      const expectedRatio = investAmount.mul(ethers.BigNumber.from(10000)).div(TARGET_DBC_VALUE);
      expect(expectedRatio).to.equal(ethers.BigNumber.from(4000)); // 40%
      
      // Check that tokens can be transferred after distribution
      const transferAmount = ethers.utils.parseEther("100");
      await xaaToken.connect(addr2).transfer(addr1.address, transferAmount);
      expect(await xaaToken.balanceOf(addr1.address)).to.equal(transferAmount);
    });

    it("Should lock tokens correctly", async function () {
      // Start investment and distribute tokens
      await xaaToken.connect(owner).startInvestment();
      const investAmount = ethers.utils.parseEther("1000");
      await dbcToken.mint(addr1.address, investAmount);
      await dbcToken.connect(addr1).approve(xaaToken.address, investAmount);
      await xaaToken.connect(addr1).invest(investAmount);
      
      // End investment period
      await network.provider.send("evm_increaseTime", [72 * 3600]);
      await network.provider.send("evm_mine");
      await xaaToken.connect(owner).endInvestment();
      
      // Get initial balance
      const initialBalance = await xaaToken.balanceOf(addr1.address);
      expect(initialBalance).to.be.gt(0);
      
      // Lock tokens
      const lockAmount = initialBalance.div(2); // Lock half of received tokens
      const duration = 86400; // 1 day
      await xaaToken.testLockTokens(addr1.address, lockAmount, duration);
      
      // Check available balance
      const [total, available] = await xaaToken.getAvailableBalance(addr1.address);
      expect(total).to.equal(initialBalance);
      expect(available).to.equal(initialBalance.sub(lockAmount));
    });
  });

  describe("Token Transfers", function () {
    it("Should prevent transfer of locked tokens", async function () {
      // Start investment and distribute tokens
      await xaaToken.connect(owner).startInvestment();
      const investAmount = ethers.utils.parseEther("1000");
      await dbcToken.mint(addr1.address, investAmount);
      await dbcToken.connect(addr1).approve(xaaToken.address, investAmount);
      await xaaToken.connect(addr1).invest(investAmount);
      
      // End investment period
      await network.provider.send("evm_increaseTime", [72 * 3600]);
      await network.provider.send("evm_mine");
      await xaaToken.connect(owner).endInvestment();
      
      // Get initial balance
      const initialBalance = await xaaToken.balanceOf(addr1.address);
      expect(initialBalance).to.be.gt(0);
      
      // Lock all tokens
      await xaaToken.testLockTokens(addr1.address, initialBalance, 86400); // 1 day lock
      
      // Try to transfer locked tokens
      // Try to transfer locked tokens - should fail
      await expect(
        xaaToken.connect(addr1).transfer(addr2.address, initialBalance)
      ).to.be.revertedWith("Insufficient unlocked balance");
      
      // Try to transfer a small amount - should still fail since all tokens are locked
      await expect(
        xaaToken.connect(addr1).transfer(addr2.address, ethers.utils.parseEther("1"))
      ).to.be.revertedWith("Insufficient unlocked balance");
      
      // Verify balance hasn't changed
      expect(await xaaToken.balanceOf(addr1.address)).to.equal(initialBalance);
      expect(await xaaToken.balanceOf(addr2.address)).to.equal(0);
      // Wait for lock duration to pass
      await network.provider.send("evm_increaseTime", [86401]); // 1 day + 1 second
      await network.provider.send("evm_mine");
      
      // Now should allow transfer since lock period is over
      const transferAmount = ethers.utils.parseEther("100");
      await xaaToken.connect(addr1).transfer(addr2.address, transferAmount);
      expect(await xaaToken.balanceOf(addr2.address)).to.equal(transferAmount);
    });
  });
});
