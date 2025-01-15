require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require('dotenv').config();
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  // paths: {
  //   sources: "./contracts/RoyaltiesRegistry.sol"
  // },
  networks: {
    u2uTestnet: {
      url: "https://rpc-nebulas-testnet.uniultra.xyz",
      accounts: ['47d0cdc110d9f88adaabd4e42186b007c650b083a54be583ca86796afee30f22'],
      // gas: 8000000
    },
    u2uMainnet: {
      url: "https://rpc-mainnet.uniultra.xyz",
      accounts: ['47d0cdc110d9f88adaabd4e42186b007c650b083a54be583ca86796afee30f22'],
    }
  },
  etherscan: {
    apiKey: {
      u2uTestnet: "hi",
      u2uMainnet: "hi"
    },
    customChains: [
      {
        network: "u2uTestnet",
        chainId: 2484,
        urls: {
          apiURL: "https://testnet.u2uscan.xyz/api",
          browserURL: "https://testnet.u2uscan.xyz/"
        }
      },
      {
        network: "u2uMainnet",
        chainId: 39,
        urls: {
          apiURL: "https://u2uscan.xyz/api",
          browserURL: "https://u2uscan.xyz/"
        }
      }
    ]
  },
};