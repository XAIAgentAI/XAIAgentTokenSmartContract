require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-chai-matchers");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-verify");
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
    dbcMainnet: {
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
  },
  etherscan: {
    apiKey: {
      dbcTestnet: "no-api-key-needed",
      dbcMainnet: 'no-api-key-needed',

    },
    customChains: [
      {
        network: "dbcTestnet",
        chainId: 19850818,
        urls: {
          apiURL: "https://test.dbcscan.io/api",
          browserURL: "https://test.dbcscan.io"
        }
      },
      {
        network: "dbcMainnet",
        chainId: 19880818,
        urls: {
          apiURL: "https://www.dbcscan.io/api",
          browserURL: "https://www.dbcscan.io",
        },
      }
    ]
  }
};
