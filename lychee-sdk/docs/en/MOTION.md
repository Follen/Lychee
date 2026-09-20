# Motion and window presence

[Contents](README.md) · [简体中文](../zh-CN/MOTION.md)

Motion controls ordinary alpha/translation and page height. Presence owns one mutually exclusive main-window channel. Provider pages use that Host window; do not create Presence for result rows. [Performance requirements](PERFORMANCE.md) govern activity and limits.

## Move the hierarchy together

The main background has seven texture pieces. Native root Scale previously separated pieces/children in real rendering. Presence therefore changes only the common root's SetPoint/SetAlpha, not Frame scale, font size, dimensions or child/texture anchors. Align positions to physical pixels to preserve text phase. Existing content scroll clipping remains; do not add whole-window clipping.

The search input uses window background rather than an extra local Surface. Equal-color layered backgrounds darken during fading (two 25% layers produce 43.75% opacity). Do not repair this by hiding a background midway or compensating alpha, which adds state flicker. Ordinary settings inputs keep their own Surface.

ConfigurePresence(layout,anchor,preset) uses `{point="TOP",relative=UIParent,relativePoint="TOP",x=0,y=restingY}`. Refresh the resting anchor after layout/scale changes, before playback. Presence(root,shown,finished,initialPhase,layout) starts/reverses. StopPresence(settle,complete) returns current phase q, or nil if inactive. Explicit initial phase is for Host Hide/Show continuity; ordinary reversal samples current progress.

The preset is enter=0.42 seconds, distance=64 units, enterAlpha=0.10 seconds. One timeline opens/closes: q changes by 1/enter per second; position is q(2-q); opacity is a(2-a), a=min(1,q×enter/enterAlpha). Full close reverses full open over 420 ms, reversing the fade during the final 100 ms. Midflight reversal immediately reverses direction, using only remaining travel time. Position/opacity are continuous; velocity direction flips without old-direction inertia. There is no independent exit curve.

## Logo motion

CreateBrand retains the original texture. brand:PlayMotion invokes Motion:Brand(texture,owner,size), where owner is the stationary container and size is the resting edge length. StopMotion, Motion:Cancel(texture,true) or StopBrand stop/reset. The one logo channel coalesces the same target and stops the old target before switching.

Native Scale/Translation previously moved the texture outside the header. Current geometry uses SetSize and CENTER relative to owner, following five verified poses over 1.386 seconds with bounded cubic-bezier bisection. Center x=size/2; y=size/128×(39×(scaleY−1)+upwardOffset), based on source pivot (64,103). Restores size×size and LEFT→owner.LEFT at (0,0), without UV/texture/parent changes. Click areas anchor to owner, never the moving texture.

First play creates one private short-lived driver and reusable task. No native logo animation group, new texture or timer. Each frame performs scalar math and at most one SetSize/SetPoint, skipping unchanged values. Reset the clock per play; stop removes OnUpdate, hides the driver and detaches region/parent/clock. Reduced motion/invisibility prevent start; hide/close/StopAll/SetReduced stop. Combat prohibits geometry setters and retains at most one pending reset target for a later safe call; combat end does not auto-play.

The palette plays after opening layout; settings hover plays only while interactive. See repository brand_geometry and brand_motion tests. Offline sampled poses/scales/FPS are not native frame-time or video acceptance.

## Shared lifecycle

- Reuse driver/task; no main-window native animation group. At most one SetPoint/SetAlpha per active frame, no per-frame tables/closures/Frames.
- Each play owns its clock; hidden time is excluded. Finish unbinds OnUpdate/hides driver/detaches region/layout/finished/clock, retaining bounded dormant structure.
- StopAll(except) can preserve main-window Presence for reversal while stopping ordinary animations.
- Close invalidates session/secure actions, disables input and clears focus immediately. Input:SetVisualFrozen(true) freezes appearance only, until hidden. Do not postpone business teardown until animation end.
- Combat uses secure Host hiding without protected layout changes or reopening afterward. Reduced motion settles immediately and completes exit callbacks.
- Ordinary native groups cap at 96; height/Presence each reuse one driver, idle with no per-frame work.

Repository tests: ui_motion, presence_geometry and interaction_smoke. Geometry substitutes model observed behavior using the production seven-piece theme, not a complete WoW renderer. Font appearance, clipping, combat and perceived motion at different FPS need in-game checks.
