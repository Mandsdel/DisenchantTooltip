# Disenchant Tooltip

A World of Warcraft: Forever addon that displays ForeverDB-sourced disenchant outcomes in item tooltips.

## Status

The updater imports ForeverDB's disenchant data and maps its item-level rules to the current Forever item catalog. It uses Forever observations when available, otherwise ForeverDB's Classic rules. Tooltip data is generated locally; the addon never makes in-game network requests.

**Options > AddOns > Disenchant Tooltip** shows usage information. There are no
configurable settings.

## Disenchant with Enchantress' Spire

Create a macro and place it on an action bar:

```text
#showtooltip Disenchant
/click DisenchantTooltipSpireButton
```

Press it once to prepare: the addon saves your current weapon slots and equips
Enchantress' Spire (item `287025`) from your bags. Wait for the ready message,
then press it again to activate the normal Disenchant cursor and select a bag
item. After the cast, or after cancelling the targeting cursor, the addon
attempts to restore your previous weapons. If the Spire is already equipped,
it remains equipped. If it is not in your bags, the same two-step action casts
normal Disenchant without changing your weapons.

The secure button must be prepared outside combat; this is a restriction of
the addon's button configuration, not a claim that weapons cannot be changed
in combat. If combat starts before restoration, the addon waits until combat
ends. If the addon warns that it cannot disable the prepared button during
combat, do not use the macro again until combat ends. A two-handed Spire may
require a free general bag slot for your off-hand. Keep the cursor clear
during equipment changes.

Weapon restore information is saved per character. If restoration fails or
was interrupted by a reload, resolve the reported problem and use
`/dtspire restore` to retry. If you have restored your weapons manually,
`/dtspire forget` discards the saved record without moving gear. The addon
does not overwrite an unexpected weapon change during restoration.

The macro, secure button, spell events, targeting cancellation and weapon
swaps require testing in the WoW Forever client; their behavior has not been
verified in-game.

## Installation

Double-click `Install Disenchant Tooltip.cmd` in this repository. It installs or updates the addon in:

```text
D:\World of Warcraft\_forever_\Interface\AddOns\DisenchantTooltip
```

Re-running the installer updates addon code, the updater, and providers while preserving the installed generated data and local configuration. The installed `Update Disenchant Data.cmd` uses the `ForeverDB API Token` user environment variable.
When upgrading an installation that still contains Classic-estimate or mock
data, run the installed updater to replace it with ForeverDB data. The addon
warns on load if it detects either obsolete data mode.

## Updating data

Double-click `Update Disenchant Data.cmd`, or run:

```powershell
.\Update-DisenchantData.ps1
```

The default ForeverDB provider generates `Data\DisenchantData.lua`. It reads `ForeverDB API Token` from your Windows user environment variables and does not store the token in the repository or addon directory. Providers are isolated behind the documented contract in [`Providers/README.md`](Providers/README.md).

Run the updater checks with:

```powershell
.\tests\Test-Update-DisenchantData.ps1
.\tests\Test-ForeverDBProvider.ps1
```

These checks use offline item-specific fixtures and simulated ForeverDB
responses; they do not make network requests. The add-on only displays records
matching the tooltip's item ID.
With a compatible Lua interpreter, run the mocked tooltip checks with
`lua .\tests\Test-Core.lua` from this directory.
The Spire workflow also has a mocked check: `lua .\tests\Test-Spire.lua`.

## Data source

Every tooltip section that displays ForeverDB-derived data will visibly credit the source as `Data from ForeverDB.net (https://foreverdb.net)`. This repository and future project documentation also include the required visible link:

<a href="https://foreverdb.net">Data from ForeverDB.net</a>
