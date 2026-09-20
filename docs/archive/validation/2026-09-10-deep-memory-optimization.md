# Deep memory and search optimization — 2026-09-10

## Symptom and reference

The user reported 55.83 MB attributed to Lychee in the live client. That screenshot does not distinguish reachable memory from garbage awaiting collection. The offline workload reproduced excessive retained directory data and search allocation, but it does not reproduce the engine's exact attribution counter.

Reviewed EllesmereUI at commit `8da5dfe182c7809e3f61b5a9ca856d16b891726f` (2026-09-09):

- [Contribution criteria](https://github.com/EllesmereGaming/EllesmereUI/blob/8da5dfe182c7809e3f61b5a9ca856d16b891726f/.github/CONTRIBUTING.md#L26-L39): lazy creation, disabled features doing no work, event-driven activity and restrained allocation.
- [Shared ticker](https://github.com/EllesmereGaming/EllesmereUI/blob/8da5dfe182c7809e3f61b5a9ca856d16b891726f/EllesmereUI_Ticker.lua#L62-L120): dense subscribers, swap removal and a hidden driver at zero subscribers. Lychee's existing shared scheduler already follows this pattern; no additional ticker was introduced.
- [Global search](https://github.com/EllesmereGaming/EllesmereUI/blob/8da5dfe182c7809e3f61b5a9ca856d16b891726f/EllesmereUI_GlobalSearch.lua#L685-L724): expensive preparation is deferred out of typing handlers and paused during combat. Its search UI is also created on demand and reuses rows. This review used the implementation as reference, not as a memory benchmark for equivalent functionality.

## Reproduction and attribution

`lua tests/performance_memory.lua --check` initially failed on combined retained memory. The same harness loads real Provider, Registry, Normalizer, StaticIndex and built-in code. Data consists of 1,154 actual journal bosses, game menu/crest entries and 1,500 deterministic simulated mounts (2,689 entries total). `--stress` adds 1,000 synthetic secure-spell SDK entries (3,689 total); it is not a claim about the number of spells on a real character.

The benchmark collects before retained-memory samples, warms the query workload, stops GC only while measuring the bytes allocated by 48 queries, then restarts and collects. Allocated bytes are cumulative transient allocation, **not instantaneous peak usage**. GC control is confined to tests; runtime code adds no forced collection.

Destructive offline attribution on the original combined workload released approximately 3,724 KiB from character fragments, 1,752 KiB from prefixes, 311 KiB from exact keys, 313 KiB from tokens, 1,163 KiB from compiled fields, and 2,802 KiB from Provider record copies. Categories overlap in ownership, so these are diagnostic estimates rather than an additive breakdown.

## Changes

1. Removed the unconditional CJK directory scan. Literal/token candidates come from intersection of UTF-8 character postings, beginning with the smallest set. All literal candidates are retained for scoring; fuzzy candidates remain separately bounded to 48 and the existing 1.5 ms budget. Previous-prefix reuse is only used when its complete candidate set is smaller.
2. Replaced redundant whole-term, prefix and two/three-character indexes with one character index. Posting sets track cardinality, retain a scalar for one entry, and collapse on removal. Full phrase, prefix, substring and cross-field token checks remain in scoring.
3. Scoring reads compiled normalized strings and returns scalar values. Failed comparisons allocate no options/evidence tables. Ranking keeps at most 20 output records and reuses their slots during the query; it does not construct every match before sorting/truncating.
4. Bounded edit distance skips common prefixes/suffixes and uses a narrow dynamic-programming band with two reusable, at-most-65-column buffers. The legacy byte-distance semantics are preserved and independently checked.
5. Provider maps adopt the Registry/index's canonical validated records. Registration avoids an intermediate full copy of the entries array. External input and action callback copies remain isolated, including on delta and replacement updates.
6. Source disable removes compiled fields and postings. Canonical records remain for re-enable, history/pin identity and static SDK behavior; a disabled static provider is not a full data unload.
7. Normalized-text caching is capped at 1,024 keys. Resolved dynamic records use weak values: current results retain their records, unused entries are collectible.
8. Palette construction moves to the first out-of-combat open. The UI harness measures 56 deferred Frame creations, excluding textures/font strings. Subsequent opens reuse the same hierarchy. Secure broker binding and combat rejection remain intact.

## Before / after

Same machine, Windows Lua 5.1, baseline commit `85bfec6`, identical harness and input. Raw output: [measurements](../design/2026-09-10-deep-memory-measurements.json). Times are wall-clock samples, not in-game CPU/frame-time measurements.

| Workload / metric | Before | After |
|---|---:|---:|
| 2,689 entries, retained | 15,265.1 KiB | 7,827.0 KiB |
| 48 queries, cumulative allocation | 59,129.2 KiB | 2,315.5 KiB |
| Average query | 5.146 ms | 0.375 ms |
| 3,689 entries, retained | 21,503.0 KiB | 10,584.3 KiB |
| Stress workload, 48-query allocation | 79,602.8 KiB | 2,318.8 KiB |
| Stress workload, average query | 7.250 ms | 0.354 ms |
| Repeated-query retained growth | 0.1 KiB | 0.1 KiB |
| Combined workload after disabling mounts | 15,268.9 KiB | 7,303.8 KiB |
| After re-enabling mounts | 15,269.2 KiB | 7,833.6 KiB |

The original growth test did not indicate a repeated-query leak. The main gains are reduced retained structures and greatly reduced temporary allocation. Normalizer and resolved-record bounds separately address longer-session retention risks.

## Verification

- All 14 suites in `tests/check_contract.ps1` pass, including memory budgets, existing SDK/secure/combat/drag/view/scroll/settings tests.
- Independent quadratic edit-distance oracle: 8,836 input pairs, including long common prefixes and Chinese bytes.
- Full-scan ranking oracle over 651 records: broad Chinese/English queries, more than 200 matches, short-to-long input, cross-field words, source filters, priorities and stable ordering.
- Disabled records have no compiled fields/postings; re-enable and subsequent deltas restore search; removing the final sources leaves no character postings.
- SDK external-mutation isolation remains tested. Resolved records referenced by visible results survive GC; 500 unreferenced resolved records are collectible.
- 10,000 distinct normalization requests remain within 1,024 cache entries.
- Regression budgets: combined retained memory below 9 MiB, 48-query allocation below 4 MiB, repeated-query retained growth below 512 KiB.
- Lua 5.1 syntax, XML/TOC references, `git diff --check`, and versioned wowdoc validation are required before delivery. API evidence uses `wow-ui-source` / retail / latest at `8ea15b61e45c0ed4eba01439c90757f86eb78d34`, with paths/lines/excerpts in [wowdoc evidence](../design/2026-09-10-deep-memory-wowdoc.json).

## Client follow-up and limitations

After syncing the committed runtime, `/reload`, repeat the same searches and settings open/close cycle, and record memory both before and after the meter's manual GC action. Compare the same collection size and duration. Check idle, single-target combat, raid/nameplate peaks and actual secure spell clicks/dragging for errors and frame-time changes. These live scenarios were not run from this environment, so the screenshot's 55.83 MB is not presented as having fallen to an offline benchmark value.

Exact/literal and token ranking are checked against an exhaustive oracle. Approximate fuzzy matches remain budgeted and may differ from the old unbounded CJK fallback's candidate order. Static records are deliberately retained while a provider is disabled; this preserves the SDK contract. Revert the delivered commit and resync its verified runtime to roll back; no SavedVariables schema or user settings migration is introduced.
