const { expect } = require("chai");

describe("Strategy contract", function () {
  it("Test", async function () {
    const [owner] = await ethers.getSigners();

    const Strategy = await ethers.getContractFactory("Strategy");
    const strategy = await Strategy.deploy();

    console.log('Deployed at: ' + strategy.address);

    await strategy.connect(owner).deposit({ value: 100000000000000 });
  });
});