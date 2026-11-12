Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Providers\ForeverDBProvider.ps1')

function Invoke-ForeverDBRequest {
    param([string]$Uri, [string]$ApiToken, [int]$RequestDelayMilliseconds)
    if ($Uri -match '/disenchant$') {
        return [pscustomobject]@{
            data = @([pscustomobject]@{
                qualityId = 2; kind = 'weapon'; itemLevelMin = 1; itemLevelMax = 20
                seenInForever = [pscustomobject]@{
                    disenchants = 10
                    results = @([pscustomobject]@{
                        name = 'Dust'; itemId = 5; chancePercent = 75; min = 1; max = 2
                    })
                }
            })
            meta = [pscustomobject]@{ build = 'test' }
        }
    }
    $items = if ($Uri -match 'class=2&quality=2') {
        @([pscustomobject]@{ id = 42; classId = 2; qualityId = 2; itemLevel = 10 })
    } else { @() }
    return [pscustomobject]@{ data = @($items); meta = [pscustomobject]@{ total = @($items).Count } }
}

$previousToken = [Environment]::GetEnvironmentVariable('ForeverDB API Token', 'Process')
try {
    [Environment]::SetEnvironmentVariable('ForeverDB API Token', 'offline-test', 'Process')
    $data = Get-DisenchantProviderData -RequestDelayMilliseconds 0
    if ($data.source.mode -ne 'foreverdb' -or $data.records.Count -ne 1 `
        -or $data.records[0].itemId -ne 42 -or $data.records[0].probability -ne 0.75 `
        -or $data.records[0].sampleSize -ne 10) {
        throw 'ForeverDB fixture mapping failed.'
    }
    Write-Host 'ForeverDB provider checks passed.'
}
finally {
    [Environment]::SetEnvironmentVariable('ForeverDB API Token', $previousToken, 'Process')
}
