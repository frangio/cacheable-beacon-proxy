# Cacheable Beacon Proxy

**An upgradeable proxy with minimal overhead.**

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
cache. The beacon proxy considers the cache invalid if `EXTCODESIZE` returns 0
for the clone.

After an upgrade, the clone can be recreated by invoking the `deployCache`
function on the beacon, allowing the proxy to use the efficient code path
again.

---

The use of metamorphic contracts for upgradeability has [long been known], but
on its own is not acceptable because it leaves the proxy in a broken state in
the window between SELFDESTRUCT and redeployment.

[long been known]: https://medium.com/@jason.carver/defend-against-wild-magic-in-the-next-ethereum-upgrade-b008247839d2

Santiago Palladino [proposed to fix this] in a way akin to blue-green
deployments, by keeping two beacons which can be selfdestructed in turns so
that the proxy is never broken. This design works and has similar best-case
performance than the pattern described here. It even has better worst-case
performance, and significantly lower deployment costs (clones are expensive).
However, there is no mechanism to ensure the two beacons are in sync, or even
that they are not selfdestructed at the same time.

[proposed to fix this]: https://github.com/spalladino/ethereum-upgrade-storage-free/

The design described here adds such a mechanism, offering a clean interface to
execute upgrades that ensures the system is always kept in a consistent state.
The main downside is that the cost of an upgrade will more or less double,
given that the new implementation needs to be deployed and then cloned in order
to reenable the cache.
