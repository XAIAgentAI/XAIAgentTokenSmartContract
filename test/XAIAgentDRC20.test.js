const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("XAIAgentDRC20", function () {
  let xaaToken;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    // Get signers
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy XAA token
    const XAAToken = await ethers.getContractFactory("XAIAgentDRC20");
    xaaToken = await XAAToken.connect(owner).deploy();
    await xaaToken.deployed();

    // Verify initial supply
    const totalSupply = await xaaToken.totalSupply();
    expect(totalSupply).to.equal(ethers.utils.parseEther("1000000000000")); // 1000 billion initial supply
  });

  describe("Core Token Functionality", function () {
    it("Should handle basic transfers", async function () {
      const transferAmount = ethers.utils.parseEther("1000");
      await xaaToken.connect(owner).transfer(addr1.address, transferAmount);
      expect(await xaaToken.balanceOf(addr1.address)).to.equal(transferAmount);
    });

    it("Should handle token burning", async function () {
      const burnAmount = ethers.utils.parseEther("1000");
      const initialSupply = await xaaToken.totalSupply();
      
      await xaaToken.connect(owner).burn(burnAmount);
      
      const finalSupply = await xaaToken.totalSupply();
      expect(finalSupply).to.equal(initialSupply.sub(burnAmount));
    });

    it("Should lock tokens correctly", async function () {
      // Transfer some tokens to test with
      const transferAmount = ethers.utils.parseEther("1000");
      await xaaToken.connect(owner).transfer(addr1.address, transferAmount);
      
      // Lock half of the tokens
      const lockAmount = transferAmount.div(2);
      const duration = 86400; // 1 day
      await xaaToken.testLockTokens(addr1.address, lockAmount, duration);
      
      // Check available balance
      const [total, available] = await xaaToken.getAvailableBalance(addr1.address);
      expect(total).to.equal(transferAmount);
      expect(available).to.equal(transferAmount.sub(lockAmount));
    });
  });

  describe("Token Locking", function () {
    it("Should prevent transfer of locked tokens", async function () {
      // Transfer tokens to test with
      const initialBalance = ethers.utils.parseEther("1000");
      await xaaToken.connect(owner).transfer(addr1.address, initialBalance);
      
      // Lock all tokens
      await xaaToken.testLockTokens(addr1.address, initialBalance, 86400); // 1 day lock
      
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

    it("Should handle multiple token locks", async function () {
      const initialBalance = ethers.utils.parseEther("1000");
      await xaaToken.connect(owner).transfer(addr1.address, initialBalance);
      
      // Create two locks
      const lockAmount1 = ethers.utils.parseEther("300");
      const lockAmount2 = ethers.utils.parseEther("400");
      await xaaToken.testLockTokens(addr1.address, lockAmount1, 86400); // 1 day
      await xaaToken.testLockTokens(addr1.address, lockAmount2, 172800); // 2 days
      
      // Check available balance
      const [total, available] = await xaaToken.getAvailableBalance(addr1.address);
      expect(total).to.equal(initialBalance);
      expect(available).to.equal(initialBalance.sub(lockAmount1).sub(lockAmount2));
      
      // Should only be able to transfer unlocked amount
      const transferAmount = available;
      await xaaToken.connect(addr1).transfer(addr2.address, transferAmount);
      expect(await xaaToken.balanceOf(addr2.address)).to.equal(transferAmount);
    });
  });

  describe("Lock Management", function () {
    it("Should enable and disable lock functionality", async function () {
      const transferAmount = ethers.utils.parseEther("1000");
      await xaaToken.connect(owner).transfer(addr1.address, transferAmount);
      
      // Lock tokens
      await xaaToken.testLockTokens(addr1.address, transferAmount, 86400);
      
      // Disable lock - transfer should work even with locked tokens
      await xaaToken.connect(owner).lockTokensDisable();
      await xaaToken.connect(addr1).transfer(addr2.address, transferAmount);
      
      // Enable lock - transfer should fail
      await xaaToken.connect(owner).lockTokensEnable();
      await expect(
        xaaToken.connect(addr1).transfer(addr2.address, transferAmount)
      ).to.be.revertedWith("Transfer amount exceeds unlocked balance");
    });

    it("Should manage lock transfer admins correctly", async function () {
      await xaaToken.connect(owner).addLockTransferAdmin(addr1.address);
      expect(await xaaToken.lockTransferAdmins(addr1.address)).to.be.true;
      
      await xaaToken.connect(owner).removeLockTransferAdmin(addr1.address);
      expect(await xaaToken.lockTransferAdmins(addr1.address)).to.be.false;
    });

    it("Should enforce lock entry limits", async function () {
      const amount = ethers.utils.parseEther("1");
      await xaaToken.connect(owner).transfer(addr1.address, amount.mul(101));
      
      // Add 99 locks
      for (let i = 0; i < 99; i++) {
        await xaaToken.testLockTokens(addr1.address, amount, 86400);
      }
      
      // 100th lock should succeed
      await xaaToken.testLockTokens(addr1.address, amount, 86400);
      
      // 101st lock should fail
      await expect(
        xaaToken.testLockTokens(addr1.address, amount, 86400)
      ).to.be.revertedWith("Too many lock entries");
    });
  });

  describe("Upgrade Control", function () {
    it("Should manage upgrade permissions correctly", async function () {
      const newImplementation = addr2.address; // Mock implementation address
      
      // Should fail without permission
      await expect(
        xaaToken.connect(owner)._authorizeUpgrade(newImplementation)
      ).to.be.revertedWith("Only canUpgradeAddress can upgrade");
      
      // Set upgrade permission
      await xaaToken.connect(owner).setUpgradePermission(owner.address);
      expect(await xaaToken.canUpgradeAddress()).to.equal(owner.address);
      
      // Should succeed with permission
      await xaaToken.connect(owner)._authorizeUpgrade(newImplementation);
      
      // Permission should be consumed
      expect(await xaaToken.canUpgradeAddress()).to.equal(ethers.constants.AddressZero);
    });

    it("Should disable upgrades permanently", async function () {
      await xaaToken.connect(owner).disableContractUpgrade();
      expect(await xaaToken.disableUpgrade()).to.be.true;
      
      await expect(
        xaaToken.connect(owner)._authorizeUpgrade(addr2.address)
      ).to.be.revertedWith("Contract upgrade is disabled");
    });
  });

  describe("Version Control", function () {
    it("Should return correct version", async function () {
      expect(await xaaToken.version()).to.equal(1);
    });
  });

  describe("Access Control", function () {
    it("Should enforce owner-only functions", async function () {
      await expect(
        xaaToken.connect(addr1).lockTokensEnable()
      ).to.be.revertedWith("Ownable: caller is not the owner");
      
      await expect(
        xaaToken.connect(addr1).addLockTransferAdmin(addr2.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      
      await expect(
        xaaToken.connect(addr1).setUpgradePermission(addr2.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should enforce lock transfer admin functions", async function () {
      const amount = ethers.utils.parseEther("1000");
      await xaaToken.connect(owner).transfer(addr1.address, amount);
      
      await expect(
        xaaToken.connect(addr1).transferAndLock(addr2.address, amount, 86400)
      ).to.be.revertedWith("Not lock transfer admin");
      
      await xaaToken.connect(owner).addLockTransferAdmin(addr1.address);
      await xaaToken.connect(addr1).transferAndLock(addr2.address, amount, 86400);
    });
  });
});
