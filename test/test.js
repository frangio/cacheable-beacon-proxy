const { ethers } = require('hardhat');
const { factory, computeBeaconAddress } = require('./utils');
const assert = require('assert');

const TestV1 = factory('TestV1');
const TestV2 = factory('TestV2');
const CacheableBeacon = factory('CacheableBeacon');
const CacheableBeaconProxy = factory('CacheableBeaconProxy');

let beacon, proxy, test;

beforeEach('deploying beacon', async function () {
  const implV1 = await TestV1.deploy(await computeBeaconAddress());
  beacon = await CacheableBeacon.deploy(implV1.address);
});

beforeEach('deploying proxy', async function () {
  proxy = await CacheableBeaconProxy.deploy(beacon.address);
  test = TestV1.attach(proxy.address);
});

it('works without cache', async function () {
  assert.equal(await test.version(), 'v1');
  await test.test();
});

describe('with cache', function () {
  beforeEach('deploying cache', async function () {
    await beacon.deployCache();
  });

  it('works', async function () {
    assert.equal(await test.version(), 'v1');
    await test.test();
  });

  it('upgrade', async function () {
    const implV2 = await TestV2.deploy(beacon.address);
    await beacon.upgradeTo(implV2.address);
    assert.equal(await test.version(), 'v2');
    await test.test();
    await beacon.deployCache();
    assert.equal(await test.version(), 'v2');
    await test.test();
  });
});
