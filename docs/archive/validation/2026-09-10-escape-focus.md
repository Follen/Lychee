# Escape after input focus loss

Root cause: Palette handled Escape only through the EditBox OnEscapePressed script. Once focus moved away, Blizzard's Escape dispatcher did not know about LycheePalette. Register the named frame in UISpecialFrames during its idempotent creation. Native Hide invokes the existing OnHide cleanup; no keyboard handler, polling, new frame or combat-time layout work is added.

Pre-edit wowdoc source check confirmed retail latest at `8ea15b61e45c0ed4eba01439c90757f86eb78d34` locally and remotely. Evidence: `docs/archive/design/2026-09-10-escape-focus-wowdoc.json`, sourceId `wow-ui-source`, product `retail`, requestedRef `latest`, path `Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:1038`. Excerpt: `for index, value in pairs(UISpecialFrames) do`; lines 1041–1044 resolve each global frame, test IsShown, call Hide and mark the key handled.

Regression command: `lua tests/interaction_smoke.lua`. Before the fix it failed with `Escape closes palette after EditBox loses focus`. The fixture opens the actual palette controller, clears focus and reproduces native CloseSpecialWindows dispatch, including OnHide. After the fix it passes, checks controller/frame closure and event cleanup, and confirms Create does not duplicate registration. Existing secure combat cleanup tests also pass.

Full contract suites, Lua/XML/TOC checks, wowdoc validation and diff checks pass. No live client keyboard/taint or performance sampling was available. After copying, `/reload`; open Lychee, click outside the input to clear focus, press Esc, and confirm closure. Existing combat state driver continues hiding the protected hierarchy upon combat entry.
