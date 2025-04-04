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
      accounts: ['a67e478b3157fe8f554e58621c12364ac47050d3c6cfb7efb1bc9d18d0d31e98'],
      // gas: 8000000
    },
    u2uMainnet: {
      url: "https://rpc-mainnet.uniultra.xyz",
      accounts: ['a67e478b3157fe8f554e58621c12364ac47050d3c6cfb7efb1bc9d18d0d31e98'],
    },
    ancient8Testnet: {
      url: "https://rpcv2-testnet.ancient8.gg/Q3uPPzhZWKvT8rANT8U58DVJMBQCLzHNi",
      accounts: ['a67e478b3157fe8f554e58621c12364ac47050d3c6cfb7efb1bc9d18d0d31e98'],
    }
  },
  etherscan: {
    apiKey: {
      u2uTestnet: "hi",
      u2uMainnet: "hi",
      ancient8Testnet: "hi"
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
      },
      {
        network: "ancient8Testnet",
        chainId: 28122024,
        urls: {
          apiURL: "https://explorer-ancient-8-celestia-wib77nnwsq.t.conduit.xyz/api",
          browserURL: "https://scanv2-testnet.ancient8.gg/"
        }
      },
    ]
  },
};