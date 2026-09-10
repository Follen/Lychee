# Multi-client and English/Chinese rollout

User requirements: Provider-declared supported clients/build ranges; official retail/Mists Classic/Titan Reforged/BC Classic Anniversary client identifiers, matching TOCs, complete Host+independently registered Provider English/Chinese resources; localized branded launcher title. Three read-only audits completed before implementation: Provider API hazards, locale fallback/data gaps, official client identity and TOC evidence.

Budgets before core changes: startup detects identity once; no new timers/events/Frames. Unsupported builtins must be filtered before Init. API 2.2 adds required scope.products and i18n; 2.1 legacy remains retail-only when unspecified. Products max4, positive build/interface bounds, independent Provider locale dictionaries max4 locales/256 keys/128KiB resources; only selected dictionary retained by runtime. No global namespace cache. Locale work on load/registration/index build, never per-frame. Existing global memory/search/UI budgets retained; allocations measured in new registration fixture and full performance suite. Builtin legacy spell scanner reuses bounded existing batch/event paths. English Bosses uses bounded CatalogProvider batches for native journal localization instead of synchronous full-catalog calls at login. Native game verification unavailable: each client load/API adapter is simulated with versioned API evidence and explicit unsupported cases; do not equate offline pass with all-client game certification.

Official evidence: wow-ui-source retail 8ea15b61e45c0ed4eba01439c90757f86eb78d34; classic ecadf9d3326fa87828cacca7f13c0ab5f41840a6; titan ba472e5e1b5580b557e3dbf02c9e5ff23b223347; anniversary d1a0a86b449c78ee352e8851ef4b011add16a2ff. FrameXMLBase_{Mainline,Mists,Wrath,TBC}.toc establish suffixes; Constants.lua Mists160-161 sets project19, Wrath121-124 project11, TBC93-97 project5. Wrath plus interface380xx is our documented Titan classification heuristic, not an invented Blizzard constant. Current interface targets 120100/50504/38002/20506. Official Chinese products: https://wow.blizzard.cn/classic/mists-of-pandaria/ , https://wow.blizzard.cn/news/24242436/ , https://wow.blizzard.cn/news/trr/20250923/43039_1260660.html . Titan Reforged English verified against NDui titan 621854838b9a0f70b4ca414a7f042c1ff6c9b658 NDui_Wrath.toc1,7; no official English marketing page claimed.


## Implemented ownership and lifecycle

Provider API 2.2 requires its own i18n and explicit products. Resources are validated and copied into a selected dictionary, isolated from the Host and other registrations. Raw third-party dictionaries are not retained by the runtime descriptor. Builtin modules retain finite, shipped resources and their translator so updates can produce localized records. There are 13 builtin namespaces; equipment/talent modules may share source resources, but register independently. Host resources stay under I.Locale. No global namespace cache grows with provider use.

Provider locale bounds: four supported locales, 256 keys per locale, 96-byte keys, 1024-byte templates, 128 KiB aggregate resources. Format plans retain at most 16 conversions per template. Text parameters <=16, strings <=1024 bytes; output <=32768 bytes with conservative preallocation bound. The 16-dictionary fixture retained 8.3 KiB including format plans. Strict key references reject extra scope/locale fields instead of silently dropping restrictions. Invalid action arrays return structured errors. Never-started providers do not run onDisable. Registration, update, disable/re-enable, unregister and stale-handle behavior are covered.

RuntimeIdentity refresh is a fixed four-client classification. Init checks client and required APIs before allocation/registration. Flavor TOCs omit retail-only providers and JournalCatalog. Unknown/mismatched project/interface pairs do not receive builtin providers. No new identity timers/events/Frames. Existing legacy API 2.1 unscoped registrations remain retail-only.

English Bosses intentionally has a distinct cost: at most one reusable CatalogProvider event frame, one scheduled timer, one coroutine, 16 records or roughly 1 ms per building batch, and a finite 214-instance name scratch table. It does not construct Blizzard journal UI to build the index. Missing native names produce localized ID placeholders and retry on the relevant Blizzard_EncounterJournal ADDON_LOADED. On completion the pending timer/job is gone; on disable subscriptions and pending work are removed. The Chinese catalogue keeps the previous static, zero-new-driver startup path. English source ordering/data availability must still be verified in game.

## Versioned evidence details

All entries below were queried with wowdoc, requestedRef=latest (no tag claimed). Paths are repository paths under Interface/AddOns unless noted.

| sourceId / product / resolvedCommit | path and line | excerpt / design implication |
|---|---|---|
| wow-ui-source / retail / 8ea15b61e45c0ed4eba01439c90757f86eb78d34 | Blizzard_FrameXMLBase/Blizzard_FrameXMLBase_Mainline.toc | Mainline TOC suffix |
| wow-ui-source / classic / ecadf9d3326fa87828cacca7f13c0ab5f41840a6 | Blizzard_FrameXMLBase/Mists/Constants.lua:160–161 | WOW_PROJECT_MISTS_CLASSIC = 19; WOW_PROJECT_ID = WOW_PROJECT_MISTS_CLASSIC |
| wow-ui-source / titan / ba472e5e1b5580b557e3dbf02c9e5ff23b223347 | Blizzard_FrameXMLBase/Wrath/Constants.lua:121–124 | WOW_PROJECT_WRATH_CLASSIC = 11; Wrath project combined with 380xx interface identifies this supported branch |
| wow-ui-source / anniversary / d1a0a86b449c78ee352e8851ef4b011add16a2ff | Blizzard_FrameXMLBase/TBC/Constants.lua:93,97 | WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5 |
| wow-ui-source / anniversary / d1a0a86b449c78ee352e8851ef4b011add16a2ff | Blizzard_UIPanels_Game/Classic/SpellBookFrame.lua:58 | ToggleSpellBook(bookType) |
| wow-ui-source / classic / ecadf9d3326fa87828cacca7f13c0ab5f41840a6 | Blizzard_UIParent/Cata/UIParent.lua:471 | SetCollectionsJournalShown(shown, tabIndex) |
| wow-ui-source / classic / ecadf9d3326fa87828cacca7f13c0ab5f41840a6 | Blizzard_ChatFrameBase/Classic/ChatFrameUtilOverrides.lua:1 | ChatFrameUtil.InsertLink(text) |
| wow-ui-source / anniversary / d1a0a86b449c78ee352e8851ef4b011add16a2ff | Blizzard_APIDocumentationGenerated/InputDocumentation.lua:30 | GetMouseFoci |
| wow-ui-source / retail / 8ea15b61e45c0ed4eba01439c90757f86eb78d34 | Blizzard_WeeklyRewards/Blizzard_WeeklyRewards.lua:701–702 | EJ_GetEncounterInfo(encounterID); EJ_GetInstanceInfo(instanceID) |
| ndui / titan / 621854838b9a0f70b4ca414a7f042c1ff6c9b658 | Interface/AddOns/NDui/NDui_Wrath.toc:1,7 | Interface: 38002; X-Support: Titan Reforged |

Flavor manifests: Blizzard_FrameXMLBase_Mists.toc, _Wrath.toc, _TBC.toc use AllowLoadGameType mists/wrath/tbc internally. Lychee uses their suffixes, not Blizzard-internal load restrictions. Localized Title/Notes metadata are included and statically accepted; wowdoc did not return a source excerpt for Title-zhCN itself, so actual addon-list localization remains an explicit in-game check.

## Validation and performance

Environment: Windows, Lua 5.1 offline fixtures, source baseline fe4732a. Archived baseline keeps its original fixtures; current fixtures add new dependency loading and explicit client metadata without changing the 2689-entry workload. Raw output: multiclient-baseline.txt and multiclient-comparison.txt alongside this record.

Three alternating baseline/current memory runs:

| Metric | Baseline | Current |
|---|---:|---:|
| Fixed entries | 2689 | 2689 |
| Post-GC retained KiB | 7151.8 | 7233.3 |
| Allocation across 48 queries KiB | 1812.2 | 1812.2 |
| Repeated-query retained growth KiB | 0.1 | 0.1 |
| Query mean ms, median of three runs | 0.354 | 0.354 |
| Max run mean ms (not a tail percentile) | 0.375 | 0.354 |

The 81.5 KiB increase is finite bilingual resources and metadata; the 7.25 MiB existing gate is unchanged. No FPS improvement is claimed. Search normalization retains its 626.1 KiB/2048-call allocation. UI fixed 400-height/1000-source workload retains eight rows and 324 mock objects, refresh20 allocation37.4 KiB, zero pool growth; recent100 open/scroll/close cycles have zero new Frames. These are Lua/mock results, not renderer/texture memory.

Full tests/check_contract.ps1 passes, including new language isolation/format limits, 7 identities ×4 locales registration matrix, 4 TOCs ×2 locales load order, builtin legacy spellbook/menus/settings/native journal, and all existing secure/actions/cache/search/animation regressions. Runtime Lua syntax and XML parsing pass. wowdoc validate reports valid=true, checkedLua=51, diagnostics=null for retail/classic/titan/anniversary. This static tool result does not replace per-client API/secure-action runtime validation.

Game checks still required: restart each relevant client for new TOCs, addon-list name/description and English layout, Alt+Space/search/home/Settings, supported spell and bag hardware clicks, classic talent/collection entry points, English journal first load/recovery, combat/taint, idle/single-target/raid/nameplate CPU/frame-time profiles. No in-game readings or approvals are fabricated. Deployment is only to the authorized retail AddOns/Lychee directory. Revert via a new git revert commit and the same verification/sync process.

English journal lifecycle fixture (`tests/bosses_locale.lua`): real SDK/CatalogProvider with first65 shipped encounters;43 batches,17ms total CPU,2ms max batch,2822.8KiB cumulative allocation,137.3KiB retained after GC,1 feature Frame peak,1 active timer peak and0 at exit. Covers name fallback/recovery, unrelated events, cancellation, late callbacks and reenable reuse. Deterministic batch clock, not game measurements.
