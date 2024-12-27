require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    dbc: {
      url: process.env.DBC_RPC_URL || "https://rpc.dbcwallet.io",
      chainId: 19880818,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    },
    dbcTestnet: {
      url: "https://rpc-testnet.dbcwallet.io",
      chainId: 19850818,
      accounts: process.env.DBC_TEST_PRIVATE_KEY ? [process.env.DBC_TEST_PRIVATE_KEY] : []
    },
    hardhat: {
      chainId: 31337
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};
