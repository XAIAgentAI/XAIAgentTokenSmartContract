const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("XAIAgentDRC20Upgradeable - TransferAndLock", function () {
    let token;
    let owner;
    let admin;
    let user1;
    let user2;
    
    beforeEach(async function () {
        [owner, admin, user1, user2] = await ethers.getSigners();
        
        const Token = await ethers.getContractFactory("XAIAgentDRC20Upgradeable");
        token = await upgrades.deployProxy(Token, [], {
            initializer: "initialize",
        });
        await token.deployed();
        
        // Enable lock functionality and set up admin wallet permission
        await token.lockTokensEnable();
        await token.connect(owner).enableLockForWallet(admin.address);
    });
    
    describe("transferAndLock", function () {
        const amount = ethers.utils.parseEther("1000");
        const lockDuration = 3600; // 1 hour
        
        beforeEach(async function () {
            // Transfer tokens to admin for testing
            await token.transfer(admin.address, amount.mul(2));
        });
        
        it("should transfer and lock tokens correctly", async function () {
            // Check initial balances
            const initialBalance = await token.balanceOf(user1.address);
            expect(initialBalance).to.equal(0);
            
            // Transfer and lock tokens
            await token.connect(admin).transferAndLock(user1.address, amount, lockDuration);
            
            // Check final balance
            const finalBalance = await token.balanceOf(user1.address);
            expect(finalBalance).to.equal(amount);
            
            // Check available balance
            const [total, available] = await token.getAvailableBalance(user1.address);
            expect(total).to.equal(amount);
            expect(available).to.equal(0); // All tokens should be locked
        });
        
        it("should prevent transfers of locked tokens", async function () {
            // Transfer and lock tokens
            await token.connect(admin).transferAndLock(user1.address, amount, lockDuration);
            
            // Attempt to transfer locked tokens
            await expect(
                token.connect(user1).transfer(user2.address, amount)
            ).to.be.revertedWith("Insufficient unlocked balance");
        });
        
        it("should allow transfers after lock period", async function () {
            // Transfer and lock tokens
            await token.connect(admin).transferAndLock(user1.address, amount, lockDuration);
            
            // Advance time past lock period
            await time.increase(lockDuration + 1);
            
            // Transfer should now succeed
            await expect(
                token.connect(user1).transfer(user2.address, amount)
            ).to.not.be.reverted;
            
            // Check balances
            expect(await token.balanceOf(user2.address)).to.equal(amount);
            expect(await token.balanceOf(user1.address)).to.equal(0);
        });
        
        it("should only allow enabled wallets to use transferAndLock", async function () {
            await expect(
                token.connect(user1).transferAndLock(user2.address, amount, lockDuration)
            ).to.be.revertedWith("Lock not enabled for this wallet");
        });
        
        it("should fail when lock functionality is disabled", async function () {
            // Disable lock functionality
            await token.lockTokensDisable();
            
            // Attempt to transfer and lock
            await expect(
                token.connect(admin).transferAndLock(user1.address, amount, lockDuration)
            ).to.be.revertedWith("Lock functionality is disabled");
        });
        
        it("should emit TransferAndLock event", async function () {
            const tx = await token.connect(admin).transferAndLock(user1.address, amount, lockDuration);
            const receipt = await tx.wait();
            
            // Find the TransferAndLock event
            const event = receipt.events?.find(e => e.event === 'TransferAndLock');
            expect(event).to.not.be.undefined;
            expect(event.args.from).to.equal(admin.address);
            expect(event.args.to).to.equal(user1.address);
            expect(event.args.value).to.equal(amount);
            expect(event.args.blockNumber).to.equal(receipt.blockNumber);
        });
        
        it("should handle multiple locks for the same user", async function () {
            const halfAmount = amount.div(2);
            
            // Create two locks
            await token.connect(admin).transferAndLock(user1.address, halfAmount, lockDuration);
            await token.connect(admin).transferAndLock(user1.address, halfAmount, lockDuration * 2);
            
            // Check total balance
            expect(await token.balanceOf(user1.address)).to.equal(amount);
            
            // Check available balance (should be 0 as all tokens are locked)
            const [total, available] = await token.getAvailableBalance(user1.address);
            expect(total).to.equal(amount);
            expect(available).to.equal(0);
            
            // Advance time past first lock
            await time.increase(lockDuration + 1);
            
            // Check available balance (should be halfAmount as first lock expired)
            const [total2, available2] = await token.getAvailableBalance(user1.address);
            expect(total2).to.equal(amount);
            expect(available2).to.equal(halfAmount);
        });
    });
});
