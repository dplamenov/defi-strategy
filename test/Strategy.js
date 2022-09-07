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
    expect(await strategy.owner()).to.be.eq(owner.address);
  });

  describe("Deposit method", function () {
    it("should revert with DepositIsLessThanMinDeposit", async function () {
      await expect(strategy.deposit({ value: 80 })).to.revertedWithCustomError(strategy, 'DepositIsLessThanMinDeposit');
    });
  });
});