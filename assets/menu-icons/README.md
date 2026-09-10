# Lychee menu icon sources

## Current flat assets

`flat-atlas.png` contains generated light silver / warm ivory / lychee red artwork for a dark UI. Export the magenta matte to transparency and build 36 runtime icons with `node tools/build_flat_menu_icons.cjs` (requires `sharp`). The exporter writes 64×64 uncompressed RGBA TGA files and a dark-background preview at 28/34/48 pixels. Source and output hashes are in `docs/architecture/2026-09-10-flat-menu-icons.json`. Original skill, mount and currency game textures are unaffected.

## Previous outline assets (reference only)

34 icons from [ByteDance IconPark](https://github.com/bytedance/IconPark), npm `@icon-park/svg` **1.4.2**, Apache-2.0. The original license is in [LICENSE.txt](LICENSE.txt).

`selection.json` maps stable menu IDs to upstream export names. `upstream/*.svg` contains original geometry exported with the official renderer: outline theme, 48×48, stroke width 3, round joins/caps, black strokes. `accent` identifies existing SVG shape elements in document order (negative indices count from the end). The build recolors these elements red and the remaining elements ivory; it does not redraw paths.

Offline rebuild from repository root:

```powershell
python tools/build_menu_icons.py
```

Build dependencies: CairoSVG 2.8.2, Pillow 12.1.1, Microsoft YaHei for preview labels. CairoSVG also requires a working Cairo installation. These are development dependencies only; the addon loads prebuilt textures.

To reproduce upstream exports, extract the pinned npm tarball `https://registry.npmjs.org/@icon-park/svg/-/svg-1.4.2.tgz` outside the repository, then run:

```powershell
node tools/export_menu_icons.cjs <extracted-package-directory>
python tools/build_menu_icons.py
```

The exporter refuses any other package/version. The builder checks all 34 current menu IDs, accent indices, ivory/red presence, RGBA format, uncompressed TGA header, dimensions, and crop-safe padding. It writes the PNG/SVG previews and SHA-256 manifest under `docs/architecture`.

The current addon distributes the replacement `package/Lychee/Media/MenuIcons/*.tga` artwork and its provenance note. The legacy IconPark references and derived previews remain under Apache-2.0 in this repository; see [third-party notices](../../THIRD_PARTY_NOTICES.md). If rebuilding or distributing those legacy assets, retain their Apache license and attribution. No SVG renderer, fonts, npm package, or reference source vectors ship to the game.
