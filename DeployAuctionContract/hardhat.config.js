require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");

const { API_URL, PRIVATE_KEY } = process.env;

module.exports = {
  solidity: "0.8.20",
  defaultNetwork: "polygonAmoy",
  sourcify: {
    enabled: false,
  },
  networks: {
    hardhat: {},
    polygonAmoy: {
      url: API_URL,
      accounts: [`0x${PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.SEPOLIA_API,
      goerli: process.env.GOERLI_API,
      polygonAmoy: process.env.AMOY_API,
    },
  },
};
