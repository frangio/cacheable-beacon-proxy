// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Proxy.sol";

contract TestV1 is CacheableBeaconImpl {
    string constant public version = 'v1';

    constructor(CacheableBeacon _beacon) CacheableBeaconImpl(_beacon) {}

    function test() external {}
}

contract TestV2 is CacheableBeaconImpl {
    string constant public version = 'v2';

    constructor(CacheableBeacon _beacon) CacheableBeaconImpl(_beacon) {}

    function test() external {}
}
