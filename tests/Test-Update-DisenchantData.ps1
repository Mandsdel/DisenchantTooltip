[CmdletBinding()]
param(
    [string]$ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$updater = Join-Path $ProjectRoot 'Update-DisenchantData.ps1'
$mockProvider = Join-Path $ProjectRoot 'Providers\MockProvider.ps1'
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('DisenchantTooltip-test-' + [guid]::NewGuid().ToString())
$dataPath = Join-Path $testDirectory 'DisenchantData.lua'
$invalidProvider = Join-Path $testDirectory 'InvalidProvider.ps1'

try {
    New-Item -ItemType Directory -Path $testDirectory | Out-Null

    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $updater -ProviderPath $mockProvider -OutputPath $dataPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Mock provider update failed.'
    }

    $firstHash = (Get-FileHash -LiteralPath $dataPath -Algorithm SHA256).Hash
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $updater -ProviderPath $mockProvider -OutputPath $dataPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Second mock provider update failed.'
    }

    $secondHash = (Get-FileHash -LiteralPath $dataPath -Algorithm SHA256).Hash
    if ($firstHash -ne $secondHash) {
        throw 'Mock provider output is not deterministic.'
    }

    @'
function Get-DisenchantProviderData {
    [pscustomobject]@{
        schemaVersion = 1
        source = [pscustomobject]@{ name = 'Invalid test'; mode = 'mock'; url = ''; version = '1'; generatedAt = '2026-11-10T00:00:00Z' }
        minimumSampleSize = 25
        records = @([pscustomobject]@{ itemId = 999001; outputName = 'Invalid'; probability = 0.5; minimumQuantity = 1; maximumQuantity = 1; sampleSize = 1 })
    }
}
'@ | Set-Content -LiteralPath $invalidProvider -NoNewline

    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $updater -ProviderPath $invalidProvider -OutputPath $dataPath
    if ($LASTEXITCODE -eq 0) {
        throw 'Invalid provider unexpectedly succeeded.'
    }

    $thirdHash = (Get-FileHash -LiteralPath $dataPath -Algorithm SHA256).Hash
    if ($secondHash -ne $thirdHash) {
        throw 'Invalid provider changed generated data.'
    }

    Write-Host 'Updater tests passed.'
}
finally {
    if (Test-Path -LiteralPath $testDirectory) {
        Remove-Item -LiteralPath $testDirectory -Recurse -Force
    }
}
