// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// Creation code that clones the address returned by msg.sender.implementation()
function beaconImplCloner() pure returns (bytes memory) {
    return
    /* 00 */    hex"635c60da1b"     // push4 0x5c60da1b     | implementation()
    /* 05 */    hex"6000"           // push1 0              | 0 implementation()
    /* 07 */    hex"52"             // mstore               |
    /* 08 */    hex"6020"           // push1 32             | 32
    /* 0a */    hex"6000"           // push1 0              | 0 32
    /* 0c */    hex"6004"           // push1 4              | 4 0 32
    /* 0e */    hex"601c"           // push1 28             | 28 4 0 32
    /* 10 */    hex"82"             // dup3                 | 0 28 4 0 32
    /* 11 */    hex"33"             // caller               | beacon 0 28 4 0 32
    /* 12 */    hex"5a"             // gas                  | gas beacon 0 28 4 0 32
    /* 13 */    hex"f1"             // call                 | status
    /* 14 */    hex"601b"           // push1 1b             | <ifok> status
    /* 16 */    hex"57"             // jumpi                |
    /* 17 */    hex"6000"           // push1 0              | 0
    /* 19 */    hex"80"             // dup1                 | 0 0
    /* 1a */    hex"fd"             // revert               |
    /* 1b */    hex"5b"             // jumpdest <ifok>      |
    /* 1c */    hex"6000"           // push1 0              | 0
    /* 1e */    hex"51"             // mload                | impl
    /* 1f */    hex"6000"           // push1 0              | 0 impl
    /* 21 */    hex"81"             // dup2                 | impl 0 impl
    /* 22 */    hex"3b"             // extcodesize          | size 0 impl
    /* 23 */    hex"81"             // dup2                 | 0 size 0 impl
    /* 24 */    hex"80"             // dup1                 | 0 0 size 0 impl
    /* 25 */    hex"82"             // dup3                 | size 0 0 size 0 impl
    /* 26 */    hex"94"             // swap5                | impl 0 0 size 0 size
    /* 27 */    hex"3c"             // extcodecopy          | 0 size
    /* 28 */    hex"f3"             // return
    ;
}

error WillNotSelfDestruct();

contract CacheableBeacon is Ownable {
    bytes32 constant SALT = 0;

    address public implementation;
    address public immutable cache;

    constructor() {
        cache = Create2.computeAddress(SALT, keccak256(beaconImplCloner()));
    }

    function deployCache() external {
        Create2.deploy(0, 0, beaconImplCloner());
    }

    function upgradeTo(address newImplementation) public onlyOwner {
        _validateImplementation(newImplementation);
        if (cache.code.length > 0) {
            CacheableBeaconImpl(cache).selfDestructIfCache();
        }
        implementation = newImplementation;
    }

    function _validateImplementation(address impl) internal {
        CacheableBeaconImpl beaconImpl = CacheableBeaconImpl(impl);
        require(beaconImpl.beacon() == this);
        try beaconImpl.selfDestructIfCache() {} catch (bytes memory error) {
            require(bytes4(error) == WillNotSelfDestruct.selector);
        }
    }
}

contract CacheableBeaconImpl {
    CacheableBeacon public immutable beacon;

    constructor(CacheableBeacon _beacon) {
        beacon = _beacon;
    }

    function selfDestructIfCache() external {
        if (msg.sender == address(beacon) && address(this) == beacon.cache()) {
            selfdestruct(payable(msg.sender));
        } else {
            revert WillNotSelfDestruct();
        }
    }
}

contract CacheableBeaconProxy {
    CacheableBeacon immutable beacon;
    address immutable cache;

    constructor(CacheableBeacon _beacon) {
        beacon = _beacon;
        cache = _beacon.cache();
    }

    fallback() external {
        address impl = cache.code.length > 0 ? cache : beacon.implementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
