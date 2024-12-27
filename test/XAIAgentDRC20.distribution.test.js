const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("XAIAgentDRC20 Distribution Tests", function () {
  let XAIAgentDRC20;
  let MockDBC;
  let token;
  let dbc;
  let owner;
  let investor1;
  let investor2;
  
  const TOTAL_SUPPLY = ethers.utils.parseEther("100000000000"); // 100 billion
  const TARGET_DBC = ethers.utils.parseEther("25000"); // $25,000 worth of DBC
  const MIN_FDV = ethers.utils.parseEther("75000"); // $75,000 minimum FDV

  beforeEach(async function () {
    [owner, investor1, investor2] = await ethers.getSigners();

    MockDBC = await ethers.getContractFactory("MockDBC");
    dbc = await MockDBC.deploy();
    await dbc.deployed();

    XAIAgentDRC20 = await ethers.getContractFactory("XAIAgentDRC20");
    token = await XAIAgentDRC20.deploy("Test Token", "TEST", dbc.address);
    await token.deployed();

    // Mint DBC to investors
    await dbc.mint(investor1.address, ethers.utils.parseEther("20000"));
    await dbc.mint(investor2.address, ethers.utils.parseEther("10000"));
    
    // Initialize pool
    await token.initializePool();
  });

  it("Should distribute tokens proportionally when under target", async function () {
    const investAmount = ethers.utils.parseEther("10000"); // $10,000 worth of DBC
    await dbc.connect(investor1).approve(token.address, investAmount);
    await token.connect(investor1).investDBC(investAmount);

    // Fast forward 72 hours
    await ethers.provider.send("evm_increaseTime", [72 * 3600]);
    await ethers.provider.send("evm_mine");

    await token.distributeTokens();

    // Should get 40% of the 25% allocation (10k/25k = 0.4)
    const expectedTokens = TOTAL_SUPPLY.mul(25).div(100).mul(40).div(100);
    expect(await token.balanceOf(investor1.address)).to.equal(expectedTokens);
  });

  it("Should distribute full allocation when target met", async function () {
    const investAmount = ethers.utils.parseEther("25000"); // $25,000 worth of DBC
    await dbc.connect(investor1).approve(token.address, investAmount);
    await token.connect(investor1).investDBC(investAmount);

    // Fast forward 72 hours
    await ethers.provider.send("evm_increaseTime", [72 * 3600]);
    await ethers.provider.send("evm_mine");

    await token.distributeTokens();

    // Should get full 25% allocation
    const expectedTokens = TOTAL_SUPPLY.mul(25).div(100);
    expect(await token.balanceOf(investor1.address)).to.equal(expectedTokens);
  });

  it("Should maintain 50% permanent reserve", async function () {
    const investAmount = ethers.utils.parseEther("25000");
    await dbc.connect(investor1).approve(token.address, investAmount);
    await token.connect(investor1).investDBC(investAmount);

    // Fast forward 72 hours
    await ethers.provider.send("evm_increaseTime", [72 * 3600]);
    await ethers.provider.send("evm_mine");

    await token.distributeTokens();

    const pool = await token.dbcPool();
    expect(pool.tokenAmount).to.be.at.least(TOTAL_SUPPLY.mul(50).div(100));
  });


  it("Should enforce 72-hour distribution delay", async function () {
    const investAmount = ethers.utils.parseEther("25000");
    await dbc.connect(investor1).approve(token.address, investAmount);
    await token.connect(investor1).investDBC(investAmount);

    // Try to distribute before 72 hours
    await ethers.provider.send("evm_increaseTime", [71 * 3600]);
    await ethers.provider.send("evm_mine");

    await expect(token.distributeTokens())
      .to.be.revertedWith("Investment period not ended");

    // Fast forward remaining time
    await ethers.provider.send("evm_increaseTime", [2 * 3600]);
    await ethers.provider.send("evm_mine");

    // Now distribution should work
    await token.distributeTokens();
    expect(await token.balanceOf(investor1.address)).to.equal(TOTAL_SUPPLY.mul(25).div(100));
  });

  it("Should maintain minimum FDV when no DBC investment", async function () {
    // Fast forward 72 hours
    await ethers.provider.send("evm_increaseTime", [72 * 3600]);
    await ethers.provider.send("evm_mine");

    await token.distributeTokens();
    
    const pool = await token.dbcPool();
    expect(pool.tokenAmount).to.be.at.least(MIN_FDV);
  });

  it("Should handle multiple investors correctly", async function () {
    const amount1 = ethers.utils.parseEther("15000");
    const amount2 = ethers.utils.parseEther("10000");

    await dbc.connect(investor1).approve(token.address, amount1);
    await dbc.connect(investor2).approve(token.address, amount2);

    await token.connect(investor1).investDBC(amount1);
    await token.connect(investor2).investDBC(amount2);

    // Fast forward 72 hours
    await ethers.provider.send("evm_increaseTime", [72 * 3600]);
    await ethers.provider.send("evm_mine");

    await token.distributeTokens();

    // Total investment is $25,000, so full allocation should be distributed
    const totalAllocation = TOTAL_SUPPLY.mul(25).div(100);
    const investor1Share = totalAllocation.mul(15000).div(25000);
    const investor2Share = totalAllocation.mul(10000).div(25000);

    expect(await token.balanceOf(investor1.address)).to.equal(investor1Share);
    expect(await token.balanceOf(investor2.address)).to.equal(investor2Share);
  });
});
