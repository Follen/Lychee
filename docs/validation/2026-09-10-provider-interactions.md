# Provider-owned interactions and universal recent grid

## Scope

- Recent entries use a 112×96 layout slot, a 48×48 selected icon region, a 34×34 provider icon, and at most two lines of name. Missing icons use four neutral squares. The large rectangular selected tile and unused metadata font strings are removed.
- Mouse hover and keyboard navigation share one selection in results and recents. Stale hover state does not paint a second highlight.
- Esc uses canonical accent tokens in normal, hover and pressed states. Invalid `muted`/`tileHover` component tokens previously left inherited/default colors. Its tooltip is removed.
- Ordinary and secure targets register drag only when the record declares `interaction.drag`; stale pooled registrations clear when drag disappears. The host never infers drag or a primary action from presentation kind. Home tooltips reuse the result tooltip.

## Evidence and validation

WoW source: `wow-ui-source`, `retail`, requestedRef `latest`, resolvedCommit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`. Source check confirmed no update. Exact excerpts are in `2026-09-10-provider-interactions-wowdoc.json`: `SimpleFrameAPIDocumentation.lua:1053` RegisterForDrag variadic mouse buttons; `SimpleFontStringAPIDocumentation.lua:580/590/720` SetMaxLines, SetNonSpaceWrap, SetWordWrap.

- Tests failed on the previous double-selection and Esc default color, then passed after the fix.
- Mixed-source regression registers spell, panel and ordinary intent records through the existing registration pipeline. A record with `kind="spell"` and explicit panel primary opens the panel; declaring spell drag works for this ordinary entry in results and recents. A cast action without drag cannot drag. Pooled secure buttons clear prior drag registration. Missing-icon fallback, shared tooltip and single highlight are covered.
- Existing scrolling, stale-source rejection, combat cleanup and unchanged-refresh setter checks remain covered.
- No new events, timers, polling or per-frame callbacks. Four fallback textures per preallocated home tile replace unused decoration/metadata; no objects are created per hover or query. Real CPU/frame-time sampling and final visual/secure-engine behavior still need client validation.
- Independent read-only review found no blocker in this UI scope. It identified a broader SDK limitation: only spell drag is currently supported. This is recorded for the newly requested general-platform architecture audit; this change does not claim arbitrary drag support.

Delivery follows checked Git commit then runtime-only copy to the fixed retail Lychee directory, file-list and SHA256 verification, and client `/reload`. Rollback uses a new revert commit and the same copy procedure.
