# Secure spell preparation cleanup

The secure subsystem adapts declared actions to WoW's protected hardware-click buttons. It validates combat configuration, current result identity, spell knowledge/passive status and collected mount fallback. It does not scan the spellbook or check cooldown/resource usability. These checks are distinct from the game's protected execution restrictions.

Changes:
- Prefer current `C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player)` and `C_Spell.IsSpellPassive(spellID)`, retaining legacy fallback when unavailable. Results remain live, without persistent caches.
- Secondary secure actions validate availability once in Broker.Prepare, removing the executor's duplicate call. Primary scripted execution and dragging retain their checks.
- Remove the consecutive duplicate combat check after Policy.Check; there is no yield between these operations.
- Release returns immediately for already-free pooled buttons, avoiding repeated Hide/SetAttribute calls and unnecessary combat cleanup dirtiness.

Measured offline baselines from `lua tests/interaction_smoke.lua`: secondary action knowledge checks 2 before, 1 after; ReleaseAll on 8 already-released buttons wrote 16 attributes before, 0 after. Both regression assertions failed before their corresponding fix and pass afterward. This measures API call counts, not in-game FPS/CPU gains. Full contract tests include combat cleanup, secure click routing, stale result rejection and mount ownership. Additional coverage checks modern APIs, passive rejection and live knowledge changes.

Pre-edit wowdoc evidence: sourceId `wow-ui-source`, product `retail`, requestedRef `latest`, resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`; local/remote source checks match. Exact paths, lines and excerpts are in `docs/archive/design/2026-09-10-secure-policy-wowdoc.json`: SpellBookDocumentation.lua:684 (`IsSpellKnown`), SpellDocumentation.lua:896 (`IsSpellPassive`), SecureTemplates.lua:805 (`SecureActionButton_OnClick`). Deprecated_SpellBook.lua:11 confirms IsPlayerSpell wraps IsSpellKnown with the Player bank.

Validation: full contract suites, Lua parsing, XML/TOC validation, wowdoc and git diff checks. No new frames, polling or resident callbacks; no game profiling instrumentation was added. Live idle/combat/raid/nameplate CPU, memory and frame-time sampling was unavailable. Runtime verification after `/reload`: ordinary spell, passive rejection, collected mount, secondary spell arming, combat entry/exit and repeated window close. Revert the delivery commit and resync runtime to roll back.
