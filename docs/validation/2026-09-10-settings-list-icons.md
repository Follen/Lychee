# Settings list icons

Both provider and pinned-entry rows now include a 28-unit icon at left inset 10. The title and subtitle begin at 50, leaving a 12-unit icon-to-text gap. Existing 46-unit rows and right-hand controls are retained. Built-ins reuse the packaged menu icons; third-party providers fall back to settings. Pins prefer the resolved entry icon, then the saved pin icon, then the provider/default icon.

One texture is allocated per existing settings row on acquisition, with no extra Frame, event, timer or driver. Unchanged icons skip SetTexture; the applied key is written only after no reported failure. Unused rows clear their texture reference. No new media files or runtime lookups are needed. Live texture memory is not measured; the existing row pool bounds these additional regions by its acquired rows.

Checks cover pin icons, reorder/rebinding, provider-tab fallback and saved icons while the source is disabled, alongside the full contract suite, Lua syntax and wowdoc validation. Actual icon scaling and text alignment await in-game /reload verification.

wowdoc: wow-ui-source / retail / latest, commit 8ea15b61e45c0ed4eba01439c90757f86eb78d34; SimpleTextureBaseAPIDocumentation.lua line 600, SetTexture returns success. Returned path/line/excerpt are recorded in ../architecture/2026-09-10-settings-icons-wowdoc.json.
