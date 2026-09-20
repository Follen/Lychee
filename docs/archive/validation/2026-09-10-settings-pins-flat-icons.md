# Settings, pins and flat icons — 2026-09-10

## Delivered behavior

- Clicking the Lychee logo or searching 设置 / 荔枝设置 opens the same in-window settings page. Returning resumes the current search. Search work and secure action overlays are suspended while settings is open.
- Built-in and third-party Provider switches persist independently of the owner's switch. Pending registrations re-read saved preferences when published after login. Disabled providers stop their existing query/lifecycle work; settings itself remains accessible.
- Right-click exposes pin/unpin after the declared actions. Home shows seven compact pin columns (81×76, 28 px icons, 4 px horizontal gap) followed by up to five full-width recent rows (46 px high). The pinned heading links to management.
- Pins use qualified provider/entry references. Settings supports drag reorder, up/down, remove/undo and returning to search to add a pin. Disabled or missing entries retain removable placeholders. Maximum 64 pins; no silent eviction.
- Native context menus use 132–280 px width, 28 px rows and four-pixel inset.
- 36 generated flat icons use light silver, warm ivory and red for the dark panel. Game skill, mount and currency textures remain native. The Great Vault has its own icon. The generated magenta matte is converted to alpha during export; it is absent from shipped textures.

## Evidence and checks

- `tests/check_contract.ps1`: all 12 existing suites pass, including extended settings/pins interaction and persistent Provider preference scenarios. Checks include saved disable before publication, owner/user independence, repeat toggle, re-registration, disabled placeholder, reorder/undo, settings search entry, session suspension and close/reopen.
- All runtime Lua files parse with Lua 5.1 `luac -p`; Bindings XML parses; TOC references resolve; `git diff --check` passes.
- `wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref latest`: valid, 39 Lua files, no diagnostics. Evidence: `docs/archive/design/2026-09-10-settings-pins-validate.json`.
- Pre-edit source evidence: `wow-ui-source`, retail, requestedRef `latest`, resolved commit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`. Exact paths, lines and excerpts for setters/drag/special-frame behavior are retained in `docs/archive/design/2026-09-10-settings-pins-wowdoc.json`.
- Reproducible icon export: `tests/build_flat_menu_icons.cjs`; source/output SHA-256 manifest and dark-background 28/34/48 px preview are under `docs/archive/design/2026-09-10-flat-menu-icons.*`. Visual review confirmed all silhouettes remain visible on #101012 and that no image background ships.

## Performance and remaining client verification

Settings creates its frame and reusable rows on first open. It has no OnUpdate, animation driver, polling timer or permanent event subscription. Refresh occurs on user operations or one coalesced source change while visible; hidden settings are not refreshed. Pin resolution is bounded to 64 entries and occurs on home invalidation/open. Existing idle and secure-button tests continue to pass; unchanged home refresh skips native geometry setters.

Offline fixtures in this run: 1,154 bosses initialize in 120 ms, retain about 8,058 KiB, alternating query mean 4.34 ms; 1,500 mounts initialize in 120 ms, retain about 6,692 KiB, alternating query mean 5.13 ms. These are synthetic Lua measurements, not real-client frame time or a before/after performance comparison.

Real login, combat, raid/nameplate peaks, taint, actual drag hit testing and screen-scaled appearance still require client verification. New TOC entries require a client restart for the delivery check. No live WoW performance claim is made.
