Set-StrictMode -Version Latest

function Get-DisenchantProviderData {
    [CmdletBinding()]
    param()

    return [pscustomobject]@{
        schemaVersion = 1
        source = [pscustomobject]@{
            name = 'Classic disenchant estimate'
            mode = 'classic-estimate'
            url = 'https://warcraft.wiki.gg/wiki/Disenchanting_tables'
            version = 'classic-uncommon-ilevel-1-65'
            generatedAt = '2026-11-10T00:00:00Z'
        }
        minimumSampleSize = 1
        records = @()
    }
}
