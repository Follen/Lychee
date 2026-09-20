# Lychee Provider SDK

[简体中文](README.md) · [English](README.en.md)

SDK **1.0.0** / Provider API **1.0.0** / UI Runtime **1**. This is a standalone development package, not an installable game addon. Third parties own their AddOn, data and media.

## Getting started

- [Tutorial](docs/en/GETTING_STARTED.md)
- [Protocol reference](docs/en/PROTOCOLS.md)
- [Versions](docs/en/COMPATIBILITY.md)

## Search and actions

- [Discovery and loading](docs/en/LOADING.md)
- [Catalogs and ranking](docs/en/CATALOG.md)
- [Invocations and history](docs/en/INVOCATIONS.md)

## Data and lifetimes

- [Owned storage](docs/en/STORAGE.md)
- [Optional compact storage](docs/en/COMPACT_STORAGE.md)
- [Resources and caches](docs/en/MANAGED_RESOURCES.md)
- [Runtime lifetimes](docs/en/RUNTIME_LIFECYCLE.md)

## Views and adapters

- [View lifecycle](docs/en/VIEW_LIFECYCLE.md)
- [UI library](docs/en/UI_LIBRARY.md)
- [Motion](docs/en/MOTION.md)
- [Client/build variants](docs/en/CLIENT_VARIANTS.md)
- [Third-party adapters](docs/en/ADAPTER_COMPATIBILITY.md)

## Validation and delivery

- [Performance requirements](docs/en/PERFORMANCE.md)
- [SDK delivery](docs/en/DELIVERY.md)

## Examples and files

[Examples](examples/README.en.md): ordinary registration, cold loading, managed work and reusable views.

[LycheeAPI.lua](LycheeAPI.lua) is an optional version/error helper; [ApiStubs.lua](ApiStubs.lua) is editor-only. Embed [Storage.lua](Storage.lua) or [CompactStore.lua](CompactStore.lua) only when needed. Never access LycheeInternal or copy the full SDK into AddOns.
