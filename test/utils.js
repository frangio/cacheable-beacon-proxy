const { ethers } = require('hardhat');
const { lazyObject } = require('hardhat/plugins');
const { hexlify, keccak256, RLP } = require('ethers/lib/utils');

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

async function computeBeaconAddress({ deployer, nonce } = {}) {
  deployer ??= (await ethers.getSigners())[0];
  nonce ??= (await deployer.getTransactionCount()) + 1;
  return computeContractAddress(deployer.address, nonce);
}

function computeContractAddress(deployerAddress, nonce) {
  const hexNonce = hexlify(nonce);
  return "0x" + keccak256(RLP.encode([deployerAddress, hexNonce])).slice(26);
}

module.exports = {
  factory,
  computeContractAddress,
  computeBeaconAddress,
};
