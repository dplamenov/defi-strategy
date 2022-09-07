require("@nomicfoundation/hardhat-toolbox");
const ALCHEMY_API_KEY = "8oNdhDDuQxdj6kKFvoHWDSDAcUiuvMXG";
const GOERLI_PRIVATE_KEY = "c8efccf7330e2f2a19c5a296ac551d757985512894ed2d3bdb44bcfdcb164bd5";


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.10",
  defaultNetwork: "goerli",
  networks: {
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
      accounts: [GOERLI_PRIVATE_KEY]
    }
  }
};
