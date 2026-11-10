# Disenchant Tooltip

A World of Warcraft: Forever addon that will display verified disenchant outcomes in item tooltips.

## Status

The updater now defaults to a temporary Classic estimate provider while ForeverDB access is pending. It derives outcomes locally from item quality, class, and level. Original-Classic uncommon armor and weapons at item levels 1–65 are labeled `Classic estimate`; other uncommon ranges and rare/epic equipment are visibly labeled `item-level guess`. Fish, consumables, and other non-equipment remain suppressed. None of these are verified Forever results.

## Installation

Double-click `Install Disenchant Tooltip.cmd` in this repository. It installs or updates the addon in:

```text
D:\World of Warcraft\_forever_\Interface\AddOns\DisenchantTooltip
```

Re-running the installer updates addon code, the updater, and providers while preserving the installed generated data and local configuration. The installed `Update Disenchant Data.cmd` selects the temporary Classic estimate provider.

## Local test update

Double-click `Update Disenchant Data.cmd`, or run:

```powershell
.\Update-DisenchantData.ps1
```

The default mock provider generates `Data\DisenchantData.lua`. Providers are isolated behind the documented contract in [`Providers/README.md`](Providers/README.md), so a future ForeverDB or alternative source only needs to return the same canonical record shape.

Run the updater checks with:

```powershell
.\tests\Test-Update-DisenchantData.ps1
```

## Data source

The planned updater will use ForeverDB only through a user-owned API key stored locally with Windows DPAPI. No API keys or generated local credentials are committed to this repository.

Every tooltip section that displays ForeverDB-derived data will visibly credit the source as `Data from ForeverDB.net (https://foreverdb.net)`. This repository and future project documentation also include the required visible link:

<a href="https://foreverdb.net">Data from ForeverDB.net</a>
