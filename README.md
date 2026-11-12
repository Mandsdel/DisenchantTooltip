# Disenchant Tooltip

A World of Warcraft: Forever addon that displays ForeverDB-sourced disenchant outcomes in item tooltips.

## Status

The updater imports ForeverDB's disenchant data and maps its item-level rules to the current Forever item catalog. It uses Forever observations when available, otherwise ForeverDB's Classic rules. Tooltip data is generated locally; the addon never makes in-game network requests.

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

## Data source

Every tooltip section that displays ForeverDB-derived data will visibly credit the source as `Data from ForeverDB.net (https://foreverdb.net)`. This repository and future project documentation also include the required visible link:

<a href="https://foreverdb.net">Data from ForeverDB.net</a>
