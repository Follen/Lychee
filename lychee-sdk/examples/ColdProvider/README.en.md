# Independent cold-loading example

[简体中文](README.md) · [English](README.en.md)

This is a complete Retail AddOn using SDK / Provider API 1.0.0. Copy this entire directory to `Interface/AddOns/ColdProvider`, alongside Lychee, then restart the client. Do not rename the directory without updating both TOC names and `X-Lychee-Package`.

The `X-Lychee-*` TOC fields are the discovery declaration; there is no Lua manifest to execute before loading. This example uses a public game file ID and its own `ColdProviderDB` SavedVariables. It reads no Host internals or private media. No SDK helper file needs to be copied into this simple example.

## Expected flow

1. Enable both addons in the native addon list. `ColdProvider` is load-on-demand; ordinary login does not run its Lua.
2. Enter `cold:` or `coldexample` in Lychee. The default is prefix/keyword-only, so unrelated general searches should not load it. User route overrides may change that policy.
3. Lychee reads the TOC declaration, loads the package, and checks registration. `RegisterReady` and `WhenSavedVariablesReady` may complete synchronously; the code handles either order without reading SV early.
4. The result is “Test cold-loaded action” in English or “测试冷加载动作” in Chinese. Opening or searching does not execute it. Clicking records `acknowledged=true` in this example's own SV and prints a confirmation.
5. Pin the entry, close and reopen the palette, and confirm it restores. Turning off participation in search hides its search results but must not make a valid explicit pin unavailable. Native disabling is different and requires a reload/restart to affect package loading.

The package stays loaded after closing Lychee: WoW does not unload its Lua/SavedVariables. To test a genuinely cold load again, restart or reload without a visible saved reference to this example; a visible pin can legitimately load its owner. Test cancellation while a separate slow fixture is preparing; this minimal example intentionally creates no artificial timer.

## Scope and verification

Only Retail interface 120100–120199 is declared. Other products require their own verified TOCs, capability checks and tests; do not merely widen this example's range. The broad build range is an example contract for this interface family, not a claim of testing every build.

From the repository root, run `lua tests/sdk/cold_example.lua`. It runs this actual TOC and Lua through the Host registration boundary with mocked native addon loading in English and Chinese, including readiness ordering, explicit actions, invalid SV preservation, and rejection of renamed/mismatched declarations. Offline evidence does not prove native loading/UI behavior; record in-game cold/reopen/disabled-source results separately.

For your own code, replace the example provider ID, routes, labels, SV name and action together. Keep the cold declaration and loaded registration consistent. Add optional preparation only when your own business data requires it; loading, preparation and action execution are separate stages. See [loading contract](../../docs/en/LOADING.md), [Invocation](../../docs/en/INVOCATIONS.md) and [Catalog](../../docs/en/CATALOG.md).
