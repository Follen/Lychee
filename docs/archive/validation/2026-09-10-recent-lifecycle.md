# Recent row lifecycle regression

Baseline: 7c42d8e. Offline Lua 5.1 interaction harness calls the real Provider runtime, input OnTextChanged, search session, Palette and executor. Before runtime edits, typing R → Re → R → empty fails: `backspace to empty: missing recent row 1`.

Ranked hypotheses: (1) dynamic query invalidates saved home records without rebinding; reproduced. (2) repeated resolution of one identity replaces another live home record; confirmed by direct real Resolve calls and pin/recent regression. (3) native scrolling/alpha clipping; cannot establish from screenshots alone, no engine simulation used as proof.

Pre-change budget: existing fixed homepage pool (64 pins + 5 recent maximum), zero extra Frame/Region/timer/event/idle work; at most one resolve/rebind pass when current home identities become stale, not per ordinary keystroke. Weak resolved membership owns no record strongly and is reset on query replacement/Provider disable. Cold/warm lifecycle measurement uses the same three-entry mixed fixture, 100 input/clear cycles; target <5 ms maximum cycle, <512 KiB retained growth, no Frame growth. Existing global performance budgets remain unchanged. Arbitrary third-party resolver time cannot be preempted.

No client API additions. Existing IsShown contract checked with wowdoc retail/latest; native pixel/secure combat behavior requires client verification. UI behavior changes only outside combat. Idle/combat/nameplate performance scenarios are not affected by a new driver because none is introduced.

## Fix and results

- PrepareHome refreshes expired saved identities before action preparation can hide individual rows. Rebinding gets one pass; unresolved/disabled pins preserve their existing disabled treatment. No recursive retry loop. A previously rejected row can recover from its section identity.
- Provider resolved membership uses weak record keys. Two live snapshots of the same ID no longer overwrite each other. Strong UI/action references keep records valid through GC; dropped snapshots disappear. Query epoch, Provider revision, ownership and current-source checks remain enforced.
- Normal regression fails on original code with `backspace to empty: missing recent row 1`, passes on changed code. Covers synchronous input, delayed/cancelled scheduler callbacks, duplicate pin/recent identity, GC, 100 consecutive query/clear cycles, close/reopen, rejected row recovery, Provider update, disable/re-enable, and release of 200 discarded snapshots.
- Baseline measurement wrapper loaded HEAD runtime files from a temporary directory and continued only the known failed identity/display assertions to finish the identical measured operation sequence. Its printed PASS lines do NOT mean baseline correctness passed: 825 assertion failures were counted. Ordinary regression has no suppressed assertions.
- Offline Lua 5.1, same 3 recent + 1 pinned fixture: baseline 100 cycles 69 ms total, 2 ms maximum, 4345.4 KiB cumulative temporary allocation; fixed samples 80–83 ms total, 2–3 ms maximum, 5689.1 KiB allocation. Both retained growth 15.9 KiB and zero new Frames. Added ~13.4 KiB per query/clear cycle restores the actual rows instead of retaining blank slots. These tiny timer-resolution samples are not evidence of client FPS improvement.
- Full contract suite passes, including secure combat, motion, search lifecycle, shared achievement cache and all existing memory budgets. wowdoc validation succeeds. No native scrolling or animation APIs were changed; no new events, timers, frame callbacks or media. Current query work remains cancelled by the existing lifecycle.
- Game rendering, /reload then Alt-Space, actual protected clicks and rapid backspace with the installed addon mix remain client verification items. The offline test proves the concrete missing-row logic, not that every possible native rendering defect has been eliminated.

API evidence: wow-ui-source / retail / requestedRef latest / resolvedCommit 8ea15b61e45c0ed4eba01439c90757f86eb78d34; exact IsShown declaration path/line/excerpt retained in recent-lifecycle-wowdoc.json. No API compatibility fallback added.
