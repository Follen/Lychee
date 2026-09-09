# Result label alignment

The result icon uses a 12-unit left inset. Type labels now use a matching 12-unit right inset, moving 30 units right from their previous fixed 42-unit inset. When a selected row exposes a secondary button, its label retains the 42-unit inset to avoid overlap. The existing row-state renderer updates the anchor only when the inset changes; no new frames, timers, or idle callbacks are added.

Pre-edit wowdoc source check: sourceId `wow-ui-source`, product `retail`, requestedRef `latest`, local and remote resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`. Exact-symbol query `SetPoint`: `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua:135`, excerpt `Name = "SetPoint"`; lines 143–147 specify point, relativeTo, relativePoint, offsetX and offsetY. Existing own-frame anchors are reused.

Validation: contract suites including result-list spacing/secondary-action checks, Lua parsing, XML/TOC checks, wowdoc validation and git diff check. Live screenshot confirmation and in-game performance sampling are unavailable; use `/reload` to check alignment in the client.
