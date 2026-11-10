# Provider contract

An updater provider is a local PowerShell script that defines `Get-DisenchantProviderData`. It must make no in-game network requests. The updater validates all returned values before it writes `Data\DisenchantData.lua`.

The function must return an object with:

- `schemaVersion`: currently `1`.
- `source`: `name`, `mode`, `url`, `version`, and ISO-8601 `generatedAt` strings. Set `mode` to `mock` only for test data.
- `minimumSampleSize`: positive integer confidence threshold.
- `records`: item-specific records with positive integer `itemId`, non-empty `outputName`, optional positive integer `outputId`, `probability` from `0` to `1`, positive integer `minimumQuantity` and `maximumQuantity`, and positive integer `sampleSize`.

`ForeverDBProvider.ps1` reads the `ForeverDB API Token` Windows user environment variable, calls ForeverDB during local data updates, and returns this contract. It sets `source.name` to `ForeverDB.net`; the addon then shows its required visible in-tooltip attribution. The token is never written to generated data, the addon directory, or the repository.

Mock mode is temporary test behavior: `Core.lua` uses `mockEntries` for every item tooltip and labels the section `Disenchanting (mock data)`. A real provider must use a mode other than `mock`, omit `mockEntries`, and supply item-specific records through `items`.
