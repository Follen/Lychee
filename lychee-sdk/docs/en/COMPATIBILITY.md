# Versions and compatibility

[Contents](README.md) · [简体中文](../zh-CN/COMPATIBILITY.md)

SDK and Provider API are both **1.0.0**. The API uses the complete version string. UI Runtime **1** is an independent UI capability identifier.

Ordinary `entries`, `handle:Update` and optional `query` are supported. Catalogs are optional. Owners control availability with `SetAvailability`; the user source switch controls search participation only. Private Extension/Command registration is not a public entry point.

The optional `LycheeAPI.lua` helper checks `Supports("1.0.0")` by default. Matching is exact; do not infer compatibility with future versions. Registration declares `apiVersion="1.0.0"`. A missing Host reports `SDK_UNAVAILABLE`; a version mismatch reports `UNSUPPORTED_API`. Examples do not access `LycheeInternal`.

Saved-data migration belongs to its data owner. Preserve the original on failure and never clear an unknown or newer database. Explicitly declare and verify each supported client range; see [client variants](CLIENT_VARIANTS.md). Availability of an API does not imply every game, language or adapter scenario has been tested.
