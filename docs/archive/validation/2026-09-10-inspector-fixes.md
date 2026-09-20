# Inspector attribution and cursor avoidance

Baseline 80100a9. Real Analyze/Poll/Place offline regressions fail before runtime edits: Blizzard template must not override dynamic addon parent evidence; cursor entering inspector must move it aside.

Hypotheses confirmed: native creation path suppresses parent evidence; own-popup focus returns before positioning; placement measures only target overlap. No hardcoded addon prefixes or local-installed-addon index is added.

Reference: installed WTFisThisAddon 1.1.0, WTFisThisAddon.lua lines 70–94 dynamically enumerate installed metadata; lines 147–197 inspect creation source and ancestor contributors. Its main-source classification still treats Blizzard code as native, so that inference is not copied. Ellesmere versioned source query documents why a SecureGroupHeader can have a Blizzard-created child; it is evidence only, never a runtime mapping.

Budget before changes: reuse 8 Frames/26 Regions and the existing active-only 10 Hz timer. At most 16 ancestor reads, 1 ms analysis guard, four fixed corner candidates; no new events, caches, hooks, target mutations or idle work. Same-target polls do not repeat attribution. Existing 100-cycle workload budgets remain <1 MiB cumulative allocations, <64 KiB retained growth, zero new controls. Cursor coordinates normalized to UIParent scale. Shift/copy pause positioning so controls stay accessible; leaving combat never resumes inspection.

Client source remains wow-ui-source retail latest 8ea15b61e45c0ed4eba01439c90757f86eb78d34; API and Ellesmere evidence JSON files preserve paths, lines, excerpts and resolved commits. Actual game rendering and screenshot target parent chain remain pending client verification.

## Verification

Both original failing assertions now pass. Regression also covers a completely different addon folder and arbitrary generated frame names, multiple native helper ancestors, insufficient attribution evidence, stable corner after cursor avoidance, Shift pausing both target and positioning, copy/Esc, secret values, combat stop, stale callbacks, small viewport and disabled idle.

No runtime addon name/abbreviation map added. Direct third-party creation remains strongest; otherwise nearest third-party parent provides an explicitly uncertain association. Only Blizzard creation code with no stronger evidence displays ownership unconfirmed. This does not identify all addons that later hook or skin a frame.

Before (previous inspector fixture): 100 cycles ~3–5 ms, 559.5 KiB allocations, 1.1 KiB retained growth, 8 Frames/26 Regions. After (same cycle workload): 3–4 ms, 559.5 KiB allocations, 1.1 KiB growth, 8/26 unchanged; initial retained 29.1 KiB. Timer precision makes these timing differences insignificant. Same-target attribution reads remain zero; no new idle driver. Full contract and wowdoc validation pass. Native visual/taint validation remains pending in game.

Installed WTFisThisAddon.lua SHA256: 7eb510e72dd36fbffc328c09d3d272f0088e716dd6c73742bd3c662894d7d854 . Local file evidence is read-only; no upstream code is copied. Source indexes built by wowdoc are development evidence only and are never shipped in the addon.
