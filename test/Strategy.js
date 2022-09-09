const { ethers } = require("hardhat");
const { expect } = require("chai");

// await (await strategy.deposit({ value: 100000000000000 })).wait();
// await (await strategy.withdraw()).wait();

describe("Strategy contract", function () {
  this.timeout(0);

  let strategy;

  before(async () => {
    const Strategy = await ethers.getContractFactory("Strategy");
    strategy = await Strategy.deploy(100, 1);
  });

  it("Properties", async function () {
    const [owner] = await ethers.getSigners();
    expect(await strategy.minDeposit()).to.be.eq(100);
    expect(await strategy.feePercentage()).to.be.eq(1);
    expect(await strategy.admin()).to.be.eq(owner.address);
  });

  describe("Deposit ETH method", function () {
    it("should revert with DepositIsLessThanMinDeposit", async function () {
      await expect(strategy.deposit({ value: 80 })).to.revertedWithCustomError(strategy, 'DepositIsLessThanMinDeposit');
    });

    it("Should register deposit", async function () {
      expect(await strategy.getUDSC()).to.be.eq(0);
      expect(await (await strategy.deposit({ value: 100000000000000 })).wait()).to.emit(strategy, 'Deposit');
      expect((await strategy.getUDSC()).toNumber()).to.be.greaterThan(0);
      expect((await strategy.getUDSC()).toNumber()).to.be.equal((await strategy.totalUSDCTokens()).toNumber());
    });
  });

  describe('Withdraw method', async () => {
    it("should revert with InsufficientBalance", async function () {
      await expect(strategy.withdraw(1000000000000000, 1)).to.revertedWithCustomError(strategy, 'InsufficientBalance');
    });

    it("Should emit Withdraw", async function () {
      await (await strategy.deposit({ value: 100000000000000 })).wait();
      expect(await strategy.withdraw(100000000, 10)).to.emit(strategy, 'Withdraw');
    });
  });
});