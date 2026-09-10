# Settings return control

The screenshot showed a gold, heavy-looking return label inherited from GameFontNormal. The control now explicitly uses the existing 12-unit body font without inherited shadow, textMuted at rest and text on hover/press. A static two-stroke chevron introduces the return direction; the 90-by-28 hit area separates the icon and label and remains clear of Esc.

The existing button state guards and click callback are unchanged. Two textures are created once with the lazily created palette; no frames, events, timers, subscriptions, or per-frame work are added. No search or combat logic changes. Only button state transitions update colors. Live CPU/memory measurements are not claimed for this small visual change.

wowdoc evidence: wow-ui-source / retail / latest, resolved commit 8ea15b61e45c0ed4eba01439c90757f86eb78d34, SimpleTextureBaseAPIDocumentation.lua line 524: SetRotation accepts radians and an optional normalizedRotationPoint. The adjacent JSON records the returned path, line and excerpt. The offline UI fixture now represents this supported texture method.

Verification: full contract suite, Lua syntax, wowdoc runtime validation and diff whitespace checks. Actual font rasterization, chevron direction and antialiasing at the player's UI scale, hover appearance and return interaction require in-game /reload verification; the supplied screenshot is the before state, not evidence of the updated rendering.
