# Provider expansion

## Scope and budgets established before implementation

Retail latest source: wow-ui-source, commit 8ea15b61e45c0ed4eba01439c90757f86eb78d34 (12.1.0).
Independent implementation; EasyFind code/assets are not copied.

New optional providers default off. Enabling starts one cancellable catalogue job;
events invalidate that job and coalesce a fresh snapshot. Combat cancels work and
subscribes for one resume. Disabling cancels timers, unregisters events and drops
working tables/signatures. Already-created event Frames are reused (one/provider).
No OnUpdate, polling, forced GC, or real settings controls for indexing.

Inputs: carried bag slots (maximum 1024), saved talent/equipment sets (maximum
128 each), registered Blizzard settings (maximum 4096), party (player + 4).
Over-cap data causes a diagnostic failure, never a silently truncated catalogue.
Initial planned interval was 0.05 s. Measured atomic commits created a 50 ms spike;
the final design also batches commits (16 records), with 0.01 s between batches.
Reads stop at 32 units or 1 ms. The shorter interval compensates for additional
commit batches without increasing their work budget; 512 bags schedule in 0.66–0.68 s.
One pending timer and one coroutine per provider; invalidated coroutines discarded.
Native calls and atomic index commits cannot be preempted; measure separately.
Desired offline first-enable total CPU < 50 ms per 512-entry catalogue, peak batch
< 5 ms; wall latency <= 1.5 s at 512 entries. Steady no-change reads do not submit.
Combined added 512 bag + 256 setting + 32 loadout fixture: < 4 MiB retained,
100 queries < 4 MiB allocated; repeated operations retained growth < 512 KiB.
Existing 2689-entry regression stays below 7.25 MiB / 4 MiB per 48 queries.
New disabled registration: < 128 KiB retained, zero Frames/timers/events.

Each Provider owns only change signatures; Host owns canonical search records.
Signatures and IDs have the same finite capacity as the catalogue. Each successful
chunk updates its signatures; a failure preserves dirty state. Obsolete IDs are
removed before additions to avoid transient overflow. Queries can see partial
first-load catalogues, but never half a transaction. Cancellation rebuilds from
the actual committed chunks. In-progress records never cross query callbacks.
Small party cache is scoped to current roster, removed on leaving/disable;
wire messages are validated, bounded, rate limited and never sent to chat.
Unknown teammate keys remain explicitly unknown. Teleport requires a known spell
and the existing hardware-click secure action broker. No arbitrary secure macros.

Category prefix supports ASCII/Chinese colon, source restriction before search,
empty suffix browsing, unknown prefix left as ordinary text. No unbounded parser cache.

## Baseline

Before change: fixed 2689 entries, 7145.6 KiB combined retained, 2317.0 KiB allocated
for 48 queries, 0.1 KiB retained growth, mean query 0.354 ms (one initial sample).
Raw output: analyze/provider-expansion/baseline-memory.txt (local investigation).

## Versioned evidence and compatibility

[API evidence](2026-09-10-provider-api-evidence.json) records sourceId, product,
requestedRef, resolvedCommit, path, line and excerpt. Blizzard retail commit is
listed above; Ellesmere main was synchronized to
8da5dfe182c7809e3f61b5a9ca856d16b891726f before examining its `/keys` implementation.
EllesmereUIQoL/EllesmereUIQoL_Keys.lua uses LibKeystone; EllesmereUI.lua:288–297
provides the factual 12.1 season spell/LFG IDs. We independently implement the
small wire adapter, not Ellesmere's UI or a bundled always-active library.

Protocol reference: [LibKeystone minor 11](https://github.com/BigWigsMods/LibKeystone/blob/master/LibKeystone/LibKeystone.lua),
read 2026-09-10. Prefix `LibKS`, request `R`, reply contains level/mapID/rating.
Only party requests; incoming guild data is accepted only for current members.
Full realm names are matched first; ambiguous short names are rejected.
Messages are limited to 40 bytes and bounded numeric values. One receive per
member per second and one request/reply per three seconds; no retry polling.
Repeated unrelated bag changes do not rebroadcast unchanged key/rating values.
The next query/refresh marks >90-second responses unknown. There is no periodic
expiry timer while the window is left open. A new query is needed if a peer's
addon does not broadcast changes. No guild roster scans or chat messages.

Scores come from C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit), including
per-map mapScore. Missing summaries are shown as unavailable rather than zero.
The existing row tooltip is also shown when hovering the secure teleport button,
including the score label area. No additional score Frames/OnUpdate were added.

## Verification results

Before commit: 3cd12987160fdccbfc692e1b549954f9a6e996d7.
Environment: local Windows, Lua 5.1, deterministic retail API adapters. Five
sequential runs; CPU uses os.clock (coarse for sub-ms calls), peak wall time uses
LuaSocket gettime when available. Timer latency is scheduled simulation, not
client frame latency. No game CPU/FPS claims are inferred from these tests.

| Measurement | Result |
| --- | --- |
| Five disabled Provider registrations | 35.1 KiB; 0 new Frames, events or timers |
| 512 bags + 256 settings + 32 loadouts + party fixture | 2220.3 KiB retained |
| Bag cold CPU | median 47 ms, maximum 49 ms |
| Bag batch peak wall time | median 2.66 ms, maximum 3.00 ms |
| 100 warmed category queries | 3952.3 KiB allocated; median 22 ms, maximum 24 ms |
| Query retained growth | no retained growth observed (raw near-zero/negative values preserved) |
| Existing 2689-entry regression | ~7147 KiB retained; ~1812 KiB/48 queries, versus baseline 2317 KiB |
| Existing query CPU | median 0.333 ms, maximum 0.354 ms; baseline was only one sample |

Bag name/ID remain searchable; common category words are one keyword field,
with lower priority than actual names. This is a new-source ranking decision,
not an equivalence claim about the earlier unshipped multi-alias draft.
Existing search behavior is checked independently: full-scan matching regression,
compact-versus-full hit comparisons with a fixed fuzzy clock, rendered metadata,
evidence, ordering and action IDs. Compact hits borrow the canonical index entry
only until synchronous materialization; displayed results keep scalar versions
and strong record references. Shared action descriptors are Host-read-only;
SDK action callbacks retain their copy boundary.

Passed: full check_contract suite, new provider_expansion integration suite,
wowdoc validation (44 Lua files, no diagnostics), and icon export/preview at
28/34/48 px. The integration suite covers moved/missing items, removed loadouts,
settings category/name parameters, score breakdowns, ambiguous/foreign senders,
rate limits, no-change commits, combat pause/resume, disabled cleanup, failed
commit recovery, reentrancy and unregister/re-register Frame reuse.
Raw output: [measurements](2026-09-10-provider-measurements.txt).

Client login/idle/combat/raid/nameplate-peak measurements, actual settings scrolling,
bag highlighting, talent cast completion/failure, real cross-addon party exchange,
secure teleport, taint and in-client icon appearance remain unverified acceptance
scenarios. This change adds TOC modules: restart the client after synchronization.
Rollback is a new git revert followed by the same validated runtime copy process.
