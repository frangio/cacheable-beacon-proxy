> [!WARNING]
> This pattern is no longer usable after the Cancun hard fork on Ethereum due to [EIP-6780]. See [Caveat Emptor](#caveat-emptor).

# Cacheable Beacon Proxy

**An upgradeable proxy with minimal overhead.**

[`CacheableBeaconProxy.sol`](./contracts/CacheableBeaconProxy.sol)

Cacheable Beacon Proxy is a design for upgradeable proxies that extends the
beacon proxy pattern with an efficient cache. While upgradeable proxies
generally require at least 2100 gas for a cold storage access to load the
implementation address, the cache used by this pattern has a much lower access
cost of only 100 gas.

The cache is efficient because the cached value in fact never changes, although
it can be temporarily invalidated.

On a cache miss, the proxy behaves like a regular beacon proxy: the associated
beacon contract is consulted for the current implementation address and the
function call is delegated to that address. This code path has the usual
overhead of cold storage access (2100 gas), plus the extra beacon overhead of a
call to a cold address (2600 gas).

This is not a regular beacon though, as it has the ability to deploy a clone of
the current implementation at a fixed address. This is enabled by CREATE2
redeployments, a combination of SELFDESTRUCT and CREATE2 sometimes referred to
as ["metamorphic contracts"].

["metamorphic contracts"]: https://medium.com/@0age/the-promise-and-the-peril-of-metamorphic-contracts-9eb8b8413c5e

The clone address is the value that can be immutably cached by the proxy. When
the beacon is upgraded, the clone is selfdestructed in order to invalidate the
cache. The beacon proxy considers the cache invalid if EXTCODESIZE returns 0
for the clone.

After an upgrade, the clone can be recreated by invoking the `deployCache`
function on the beacon, allowing the proxy to use the efficient code path
again.

## Comparison

The table below shows the various patterns in use (and metamorphic contracts
for comparison, though I don't think they have any real use) and how they fare
in the key metrics that cause overhead over a non-proxied contract call.

These key metrics are the number of storage slots touched and the number of
addresses touched, and they're important because each time one of these is
touched for the first time in a transaction (i.e. a cold access) they incur
significant additional cost: 2000 gas for storage and 2500 gas for addresses.

The Accesses column groups storage reads (SLOAD), "extcode" reads (EXTCODECOPY,
EXTCODESIZE), and contract calls (STATICCALL, DELEGATECALL), all of which have
a baseline cost of 100 gas.

Note: There are additional costs such as stack manipulation and memory use, but
in theory these are relatively negligible.

| Proxy            | Storage Touched | Addresses Touched | Accesses                            | Gas Overhead |
|------------------|-----------------|-------------------|-------------------------------------|--------------|
| Transparent      | 2 (admin, impl) | 1 (impl)          | 3 (sload, sload, delegatecall)      | 6800         |
| UUPS             | 1 (impl)        | 1 (impl)          | 2 (sload, delegatecall)             | 4700         |
| Beacon           | 1 (impl)        | 2 (beacon, impl)  | 3 (staticcall, sload, delegatecall) | 7300         |
| Blue-Green       | 0               | 2 (beacon, impl)  | 2 (extcodecopy, delegatecall)       | 5200         |
| Cacheable Beacon | 0               | 1 (cache)         | 2 (extcodesize, delegatecall)       | 2700         |
| Metamorphic      | 0               | 0                 | 0                                   | 0            |

The patterns that rely on metamorphic contracts as a building block, in a few
exceptional situations degrade to the following worst-case characteristics.

| Proxy            | Storage Touched | Addresses Touched            | Accesses                                         | Gas Overhead |
|------------------|-----------------|------------------------------|--------------------------------------------------|--------------|
| Blue-Green       | 0               | 3 (beacon 1, beacon 2, impl) | 3 (extcodecopy, extcodecopy, delegatecalll)      | 7800         |
| Cacheable Beacon | 1 (impl)        | 3 (cache, beacon, impl)      | 4 (extcodesize, staticcall, sload, delegatecall) | 9900         |

## Prior Art

The use of metamorphic contracts for upgradeability has [long been known], but
they're arguably not enough on their own since the proxy is left in a broken
state in the window between SELFDESTRUCT and redeployment.

[long been known]: https://medium.com/@jason.carver/defend-against-wild-magic-in-the-next-ethereum-upgrade-b008247839d2

Santiago Palladino [proposed to fix this] in a way akin to blue-green
deployments, by keeping two beacons which can be selfdestructed in turns so
that the proxy is never broken. This design works, but although it might sound
like it should have similar best-case performance than the pattern described
here, in fact it performs an additional cold address access that results in
greater cost. Worst-case performance is better, due to not using storage even
in this situation, and upgrading the proxy has significantly lower cost.
However, there is no mechanism to ensure the two beacons are in sync, or even
that they are not selfdestructed at the same time.

[proposed to fix this]: https://github.com/spalladino/ethereum-upgrade-storage-free/

The design described here adds such a mechanism, offering a clean interface to
execute upgrades that ensures the system is always kept in a consistent state.
The main downside is that the cost of an upgrade will more or less double,
given that the new implementation needs to be deployed and then cloned in order
to reenable the cache.

## Caveat Emptor

Is this a good idea? This pattern and metamorphic contracts in general rely on
SELFDESTRUCT, a quirky EVM opcode that will likely be revised in the future,
and possibly even removed. A [post on this issue by Vitalik] mentions
upgradeability as one of the use cases, and one of the two proposals continues
to allow it, while the other doesn't. Ultimately, it is unclear whether this
pattern will work in the future, but in case it breaks, it may be advisable to
include a way to permanently disable the cache and downgrade to a classic
beacon proxy.

[post on this issue by Vitalik]: https://hackmd.io/@vbuterin/selfdestruct

**Update:** [EIP-6780 SELFDESTRUCT only in same transaction][EIP-6780] has now
been included in Ethereum, starting with the Cancun hard fork.

[EIP-6780]: https://eips.ethereum.org/EIPS/eip-6780

Additionally, because this pattern relies on cloning bytecode from one contract
to another location, it will break some [Solidity patterns] that rely on the
value of `address(this)` stored in an immutable variable.

[Solidity patterns]: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.6.0/contracts/proxy/utils/UUPSUpgradeable.sol#L23-L36
