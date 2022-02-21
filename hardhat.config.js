require('@nomiclabs/hardhat-ethers');
require('hardhat-gas-reporter');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP,
  },
};
