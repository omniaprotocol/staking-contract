require("@nomicfoundation/hardhat-foundry");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-ethers");
require("hardhat-contract-sizer");

const testnetPrivateKey = '0x00...'; // TODO replace this with your private key

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    local: {
      url: "http://0.0.0.0:8548",
    },
    sepolia: {
      url: "https://sepolia.gateway.tenderly.co", 
      chainId: 11155111,
      accounts: [testnetPrivateKey],
    },
    goerli: {
      url: "https://ethereum-goerli.publicnode.com	",
      chainId: 5,
      accounts: [testnetPrivateKey],
    },
  },
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
};
