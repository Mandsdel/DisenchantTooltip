[CmdletBinding()]
param(
    [string]$AddOnsPath = 'D:\World of Warcraft\_forever_\Interface\AddOns'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path -LiteralPath $AddOnsPath -PathType Container)) {
        throw "WoW AddOns directory was not found: $AddOnsPath"
    }

    $destination = Join-Path $AddOnsPath 'DisenchantTooltip'
    if (-not (Test-Path -LiteralPath $destination -PathType Container)) {
        New-Item -ItemType Directory -Path $destination | Out-Null
    }

    foreach ($file in 'DisenchantTooltip.toc', 'Core.lua', 'Update-DisenchantData.ps1', 'Update Disenchant Data.cmd', 'README.md') {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $destination $file) -Force
    }

    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Providers') -Destination $destination -Recurse -Force

    $destinationData = Join-Path $destination 'Data'
    if (-not (Test-Path -LiteralPath $destinationData -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationData | Out-Null
    }

    $destinationDataFile = Join-Path $destinationData 'DisenchantData.lua'
    if (-not (Test-Path -LiteralPath $destinationDataFile -PathType Leaf)) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Data\DisenchantData.lua') -Destination $destinationDataFile
    }

    $configurationDirectory = Join-Path $destination 'Config'
    if (-not (Test-Path -LiteralPath $configurationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $configurationDirectory | Out-Null
    }

    Write-Host "Installed successfully to $destination"
    Write-Host 'Existing generated data and local configuration were preserved.'
    Write-Host 'If upgrading from Classic estimates or mock data, run Update Disenchant Data.cmd in the installed addon directory.'
}
catch {
    Write-Error "Installation failed. $($_.Exception.Message)"
    exit 1
}
