<div align="center">

<img src="addon/Lychee/Media/lychee-logo.png" width="88" alt="Lychee logo">

# Lychee Launcher

**Spells, items, settings. One place to find them.**

Press <kbd>Alt</kbd> + <kbd>Space</kbd>. Type what you need.

[简体中文](README.md) · [English](README.en.md)

[![Version](https://img.shields.io/badge/version-0.2.0-d53c49?style=flat-square)](addon/Lychee/Lychee.toc)
[![Lua](https://img.shields.io/badge/Lua-5.1-2c2d72?style=flat-square&logo=lua&logoColor=white)](addon/Lychee)
[![Languages](https://img.shields.io/badge/languages-English%20%2F%20中文-526b5d?style=flat-square)](#clients)
[![Clients](https://img.shields.io/badge/WoW-4%20clients-6d587c?style=flat-square)](#clients)

[![Provider SDK](https://img.shields.io/badge/Provider%20SDK-API%202%20r7-536b85?style=flat-square)](lychee-sdk/docs/GETTING_STARTED.md)
[![License](https://img.shields.io/badge/license-noncommercial%20·%20attribution-d53c49?style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/Follen/Lychee?style=flat-square&color=b79857)](https://github.com/Follen/Lychee/stargazers)
[![Issues](https://img.shields.io/github/issues/Follen/Lychee?style=flat-square&color=687581)](https://github.com/Follen/Lychee/issues)

[Install](#install) · [Try a search](#search) · [Addon settings](#integrations) · [Build a Provider](#developers)

<img src="docs/media/search-spells.png" width="960" alt="In-game screenshot: an Arcane search showing matching spells with their matching text highlighted in lychee red.">

<sub>Captured in-game on a Chinese client · English interface also available</sub>

</div>

You remember a spell's name, but not which action bar it is on. You know which setting you want, but not which menu contains it. Lychee starts with **the name**: find it, then cast, use, switch, or open the relevant page.

<a id="search"></a>

## Try a search

| You want to… | Type… | Then… |
| :--- | :--- | :--- |
| Find a spell your character knows | `Polymorph` | Click to cast, or drag it onto an action bar |
| Find something in your bags | `Hearthstone` | Click to use; right-click for bag location actions |
| Open a game panel | `Heirlooms` | Open the heirloom collection directly |
| Share an achievement | `Ahead of the Curve` | Shift + left-click the result to insert its link into chat |
| Check the group's keys | `key` | See group keystones and scores (Retail) |
| Search only your spells | `spell: Polymorph` | See matching player spells without other sources |

Spell, bag and achievement results depend on your character and client. While the initial achievement catalog is being prepared, Lychee shows “Searching” and refreshes the results when ready.

### Keep the useful things close

- **Pins** put frequent actions on the search home screen. Leave the search box empty to see them.
- **Aliases** give individual results a name you choose. Right-click a portal, call it `home`, and manage your aliases in settings.
- **Remembered choices** favor the result you previously selected for the same query.
- **Match highlighting** marks matching Chinese and English text so you can scan the results.

### Choose where searches go

Open **Settings → Providers → select a provider** to adjust these independently:

| Setting | What it does |
| :--- | :--- |
| General search | Includes this provider when you type a content name |
| Search prefixes | `spell: Polymorph` searches only player spells |
| Shortcut keywords | Assign `abc`; typing exactly `abc` shows that provider's results |

All three can coexist. **An alias names one result; a shortcut keyword opens a provider's results.** For example, `home` can find one portal, while `key` shows group keystones.

<table>
<tr>
<td width="50%" align="center"><a href="docs/media/search-achievements.png"><img src="docs/media/search-achievements.png" alt="In-game achievement results showing completion status and the Shift-click sharing hint."></a></td>
<td width="50%" align="center"><a href="docs/media/provider-settings.png"><img src="docs/media/provider-settings.png" alt="In-game provider management with individual enable switches and settings."></a></td>
</tr>
<tr>
<td align="center"><strong>Find an achievement. Share it.</strong><br>Completion status and chat sharing beside the result</td>
<td align="center"><strong>Choose what belongs in your search.</strong><br>Enable providers and customize their search entries</td>
</tr>
</table>

<sub>Chinese client screenshots. Click either image for the full-size original.</sub>

<a id="integrations"></a>

## Jump into addon settings

On Retail, install the relevant addon and enable its integration in Providers. Then search with a prefix:

| Addon | Example | Destination |
| :--- | :--- | :--- |
| **Ellesmere UI** | `EUI: <setting name>` | An indexed settings page; a section or control when navigation data is available |
| **Ellesmere UI** | `EUI: unlock` | Unlock mode |
| **Exwind** | `EX: <setting name>` | The relevant settings page in registered modules such as ExwindTools and ExBoss |
| **Exwind** | `EX: unlock` | Edit mode |

Both integrations use prefix-only search by default. Prefixes are case-insensitive and accept either `:` or `：`.

The catalog comes from the installed addon's registered data. Settings that have not been built or publicly registered may be missing; these integrations do not promise access to every option.

**Wondering which addon owns a frame?** Search `Addon inspector`. Point at a frame to see its source, or a best guess, in a floating panel that follows the cursor. Hold <kbd>Shift</kbd> for details; press <kbd>Esc</kbd> to leave.

<a id="install"></a>

## Install

1. [Download the repository ZIP](https://github.com/Follen/Lychee/archive/refs/heads/main.zip) and extract it.
2. Copy the entire **`addon/Lychee` folder** into your client's `Interface/AddOns/` directory.
3. Restart the game, enable **Lychee Launcher** in the addon list, and press <kbd>Alt</kbd> + <kbd>Space</kbd>.

Your folder structure should look like this:

```text
Interface/
└── AddOns/
    └── Lychee/
        ├── Lychee.toc
        ├── Lychee_Mainline.toc
        ├── Bootstrap.lua
        └── …
```

**Do not put the entire repository in AddOns.** Players do not need `lychee-sdk`, `docs`, or `assets`. The repository ZIP contains the current development version.

If another binding already uses Alt + Space, Lychee leaves it alone. Assign a different shortcut in the game's key bindings.

| Action | Input |
| :--- | :--- |
| Open search | <kbd>Alt</kbd> + <kbd>Space</kbd> by default |
| Select a result | <kbd>↑</kbd> / <kbd>↓</kbd> |
| Run an ordinary action | <kbd>Enter</kbd> or left-click |
| Open result actions | Right-click |
| Close | <kbd>Esc</kbd> |

Game security rules apply: search cannot open in combat, and protected actions such as casting a spell require a real mouse click.

<a id="clients"></a>

## Clients and languages

One installation includes four client load lists. Each client gets the features it can use.

| Client | Shared features¹ | Mounts · Equipment sets · Achievements | Retail features² |
| :--- | :---: | :---: | :---: |
| **World of Warcraft** | ✓ | ✓ | ✓ |
| **Mists of Pandaria Classic** | ✓ | ✓ | — |
| **Titan Reforged** | ✓ | ✓ | — |
| **Burning Crusade Classic Anniversary Edition** | ✓ | — | — |

¹ Spells, bags, game menus, Blizzard settings and addon inspection. Bag location supports the default Blizzard UI, ElvUI, NDUI and Ellesmere bag interfaces.

² Crests, the Great Vault, talent loadouts, boss journal entries, group keystones, and Ellesmere UI / Exwind integrations.

This is the declared compatibility scope, **not a claim that every client has completed in-game testing**. Entries also check for the required client APIs. See [development documentation](docs/guides/DEVELOPMENT.md) for version baselines.

The interface supports **English and Simplified Chinese**, following the game locale. Traditional Chinese clients currently use Simplified Chinese interface text. Game content keeps the names supplied by the client.

<a id="developers"></a>

## Make your addon searchable

A Provider supplies content and actions; Lychee handles searching, ranking and display. Declare your supported clients, register your own English and Chinese text, and use different implementations where clients differ.

**[Start with the SDK →](lychee-sdk/docs/GETTING_STARTED.md)** · [Protocol reference](lychee-sdk/docs/PROTOCOLS.md) · [Examples and type definitions](lychee-sdk/README.md)

<details>
<summary><strong>Maintenance and verification</strong></summary>

- [Project structure](docs/guides/PROJECT_STRUCTURE.md): runtime, SDK, tools and documentation.
- [Architecture](docs/ARCHITECTURE.md): the boundary between search and Providers.
- [Development](docs/guides/DEVELOPMENT.md): setup, checks and in-game validation.
- [Design](DESIGN.md) · [Performance requirements](PERFORMANCE.md).

Run `pwsh -File tests/check_contract.ps1` at the repository root. Lua 5.1, Python and ripgrep are required. Offline tests do not replace in-game combat, protected-action or visual checks. Most developer documentation is currently in Chinese.

`analyze/` holds local research and is ignored by Git. It is not part of the repository or addon distribution.

</details>

## Feedback and permission

[Report a problem or suggest a change](https://github.com/Follen/Lychee/issues). Include your client, Lychee version and steps to reproduce. For integrations, include the other addon's version too. If there is a Lua error, paste the complete error text.

**Free to use. Credit required for complete, unchanged redistribution. No commercial use. No passing it off as your own.** Publishing modified versions requires written permission, except clearly labeled contribution forks as specified in the license.

Lychee uses a [custom Non-Commercial Attribution License](LICENSE). It is source-available, not open-source licensed. The full license controls; [third-party materials](THIRD_PARTY_NOTICES.md) retain their own terms.

Redistribution credit: **Lychee Launcher — Follen · https://github.com/Follen/Lychee**
