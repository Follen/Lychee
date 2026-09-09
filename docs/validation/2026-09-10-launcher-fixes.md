# Launcher screenshot corrections

## Findings and changes

- User reported flat tooltip content and clarified that the misplaced element was the “最近使用” title. Tooltip previously joined type, description, match diagnostics, source and all actions into one AddLine. Now title, subdued type, body and primary action are separated; search diagnostics are omitted.
- Screenshot spacing was consistent with the scroll child losing its preset offset, but no live child coordinates were captured. Title and tile padding now live in their own anchors, independent of child positioning. Home height includes its internal padding once.
- User initially reported silent spell clicks. A read-only live sample returned `1 spell 393256 false false true` (button, type, spell, useOnKeyDown, pendingCast, OnClick exists). This proves configuration and script presence, not that a physical click reached the button or that casting succeeded. User then reported clicks working before any spell code change. Intermittent cause remains unconfirmed; no speculative secure-action changes were made.

## Versioned source evidence

Source `wow-ui-source`, product `retail`, requestedRef `latest`, resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34` (checked against current retail source before edits).

- `Interface/AddOns/Blizzard_AddOnList/AddonList.lua:848`: `AddonTooltip:AddLine(notes, 1.0, 1.0, 1.0, true);` demonstrates a separate wrapped description; line 857 inserts a blank line before another content group. Exact wowdoc output is saved in `2026-09-10-launcher-fixes-wowdoc.json`.
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPITooltipDocumentation.lua`, SetText definition: arguments are text, colorR/G/B, alpha, wrap. Inspected with wowdoc and read from the same immutable source mirror.
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua:91`: SetScrollChild uses a SimpleFrame and checks parent changes. This does not document engine anchor-reset behavior; the fix avoids depending on it.
- Independent reviewer checked `Interface/AddOns/Blizzard_SharedXML/SharedTooltipTemplates.xml:95`, `frameStrata="TOOLTIP"`, inherited by `Blizzard_GameTooltip/Mainline/GameTooltip.xml:4`. No tooltip strata mutation is needed.

## Validation

- Before the fix, new regression assertions failed: tooltip had no separate sections; title horizontal offset was 0 rather than 12.
- After the fix, `tests/check_contract.ps1` passed all six Lua suites and contract checks. Tests cover title anchors, tooltip grouping and unchanged-refresh setter guards.
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`: valid, 29 Lua files, no diagnostics. JSON result is saved alongside this record.
- Independent read-only UI review passed with no confirmed code blocker.
- No new events, timers, per-frame callbacks or frames. Work remains limited to existing hover and home-layout triggers. No in-game CPU/frame-time measurements were performed; this is not a measured performance claim.
- Real font rendering, tooltip skins and final title spacing require `/reload` and visual inspection. Actual spell recovery is user-reported; intermittent failure is not marked resolved.

## Delivery and rollback

Commit the related runtime, tests and documentation after checks, then copy runtime files only to `D:\Game\World of Warcraft\_retail_\Interface\AddOns\Lychee`, with file-list and SHA256 verification. Do not delete destination extras. Rollback uses a new `git revert` commit and the same validated copy procedure.
