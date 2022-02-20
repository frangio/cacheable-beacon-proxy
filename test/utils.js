const { ethers } = require('hardhat');
const { lazyObject } = require('hardhat/plugins');

function factory(name) {
  let f;

  before(`load factory (${name})`, async function () {
    f = await ethers.getContractFactory(name);
  });

  return lazyObject(() => {
    if (f === undefined) {
      throw Error('Used factory outside of test');
    }
    return f;
  });
}

module.exports = {
  factory,
};
