# Reorder button state and presentation

The supplied screenshot shows the pinned-list up/down controls. The reproduction uses the real SettingsView buttons and Components mouse handlers: enter, press, leave, release outside. Before the fix, `lua tests/interaction_smoke.lua` fails with `release outside must not leave reorder button highlighted` because OnMouseUp unconditionally selects hover. Disabled buttons also accepted hover/normal state changes, and settings provided no distinct disabled text style.

Components now resolves release/refresh against the actual pointer, gives disabled state precedence, rejects disabled clicks, and clears hover on hide. Repeated enable values do not repeat native Enable/Disable. The list continues to reuse the same rows. Additional checks exercise real reorder clicks, refresh boundary states, disabled mouse events, disabled clicks and hide cleanup.

Replace the font-dependent arrow glyphs with explicit 12-unit `上移` / `下移` text in 40-by-28 controls, with 4-unit gaps before adjacent controls. Disabled actions use the disabled text token and transparent background. The existing return-search control is outside this screenshot's scope.

No frames, textures, events, timers or per-frame drivers are added. Pointer checks run only on release or button enable refresh. Existing color/state change guards remain. Full contract suite, Lua syntax, wowdoc validation and diff checks cover the change; live client rendering and event ordering still require /reload verification. No live CPU, memory or frame-time result is claimed.

API evidence: wow-ui-source / retail / latest at 8ea15b61e45c0ed4eba01439c90757f86eb78d34; Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua line 470, IsMouseOver returns a boolean and supports zero-offset defaults. These are Lychee-owned controls anchored to its own non-secret UI. Returned source metadata and excerpt are saved in ../architecture/2026-09-10-button-state-wowdoc.json.
