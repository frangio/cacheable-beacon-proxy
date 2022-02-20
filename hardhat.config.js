require('@nomiclabs/hardhat-ethers');
require('hardhat-gas-reporter');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.9",
  gasReporter: {
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP,
  },
};
