# SDK delivery

[Contents](README.md) · [简体中文](../zh-CN/DELIVERY.md)

SDK and public API are **1.0.0**, with `API_VERSION="1.0.0"`. The helper checks that exact string. Editor declarations in `ApiStubs.lua` do not belong in a game TOC.

The development ZIP can be extracted independently. Documentation links stay inside the package or explicitly point to remote sources. `LycheeAPI.lua` is an optional capability helper. Embed `Storage.lua` or `CompactStore.lua` in your addon and load them before your business code. Do not install the entire SDK directory into AddOns.

In the full source repository, `tools/sdk_contract.json` owns versions, error codes and the complete file inventory. Run `python tools/build_sdk.py --write` to regenerate declarations, the manifest and the Chinese performance-policy copy; `--check` is read-only. The release builder produces separate `Lychee.zip` and `lychee-sdk.zip`, verifying paths, inventories, SHA-256 and reproducible contents. These tools are not included in the standalone SDK.

`docs/zh-CN` and `docs/en` contain corresponding topic pages; `README.md` and `README.en.md` are the language entry points. Examples have paired language instructions. Both language trees must ship in the SDK, not in the game addon. The Chinese performance policy is generated from the repository policy; the English companion explains SDK integration requirements and links to that complete policy.

Host `SDK/CompactStore.lua` and the development copy must match byte for byte. Test independently corrupted Host declarations, types, helper, documents, inventory and version contract. A version-string search alone cannot prove delivery consistency.
