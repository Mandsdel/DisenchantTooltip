[CmdletBinding()]
param(
    [string]$ProviderPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProviderPath)) {
    $ProviderPath = Join-Path $PSScriptRoot 'Providers\MockProvider.ps1'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot 'Data\DisenchantData.lua'
}

function Assert-PositiveInteger {
    param(
        [object]$Value,
        [string]$Name
    )

    if ($Value -isnot [ValueType] -or [double]$Value -le 0 -or [double]$Value -ne [math]::Floor([double]$Value)) {
        throw "$Name must be a positive integer."
    }
}

function Assert-String {
    param(
        [object]$Value,
        [string]$Name,
        [switch]$AllowEmpty
    )

    if ($Value -isnot [string] -or (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($Value))) {
        throw "$Name must be a non-empty string."
    }
}

function ConvertTo-LuaString {
    param([string]$Value)

    return '"' + $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n') + '"'
}

function ConvertTo-LuaNumber {
    param([double]$Value)

    return $Value.ToString('0.################', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-LuaRecord {
    param([object]$Record)

    $outputId = if ($null -eq $Record.outputId) { '' } else { " outputId = $($Record.outputId)," }
    return "{ name = $(ConvertTo-LuaString $Record.outputName),$outputId probability = $(ConvertTo-LuaNumber $Record.probability), minQuantity = $($Record.minimumQuantity), maxQuantity = $($Record.maximumQuantity), sampleSize = $($Record.sampleSize) },"
}

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name,
        [switch]$Required
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        if ($Required) {
            throw "Missing required property '$Name'."
        }
        return $null
    }

    return $property.Value
}

function Normalize-Record {
    param(
        [object]$Record,
        [int]$MinimumSampleSize
    )

    $itemId = Get-PropertyValue $Record 'itemId' -Required
    $outputName = Get-PropertyValue $Record 'outputName' -Required
    $probability = Get-PropertyValue $Record 'probability' -Required
    $minimumQuantity = Get-PropertyValue $Record 'minimumQuantity' -Required
    $maximumQuantity = Get-PropertyValue $Record 'maximumQuantity' -Required
    $sampleSize = Get-PropertyValue $Record 'sampleSize' -Required
    $outputId = Get-PropertyValue $Record 'outputId'

    Assert-PositiveInteger $itemId 'itemId'
    Assert-String $outputName 'outputName'
    Assert-PositiveInteger $minimumQuantity 'minimumQuantity'
    Assert-PositiveInteger $maximumQuantity 'maximumQuantity'
    Assert-PositiveInteger $sampleSize 'sampleSize'
    if ([double]$probability -lt 0 -or [double]$probability -gt 1) {
        throw 'probability must be between 0 and 1.'
    }
    if ([int]$maximumQuantity -lt [int]$minimumQuantity) {
        throw 'maximumQuantity must not be less than minimumQuantity.'
    }
    if ([int]$sampleSize -lt $MinimumSampleSize) {
        throw "sampleSize must be at least $MinimumSampleSize."
    }
    if ($null -ne $outputId) {
        Assert-PositiveInteger $outputId 'outputId'
    }

    return [pscustomobject]@{
        itemId = [int]$itemId
        outputName = [string]$outputName
        outputId = if ($null -eq $outputId) { $null } else { [int]$outputId }
        probability = [double]$probability
        minimumQuantity = [int]$minimumQuantity
        maximumQuantity = [int]$maximumQuantity
        sampleSize = [int]$sampleSize
    }
}

try {
    if (-not (Test-Path -LiteralPath $ProviderPath -PathType Leaf)) {
        throw "Provider script was not found: $ProviderPath"
    }

    . $ProviderPath
    if (-not (Get-Command Get-DisenchantProviderData -CommandType Function -ErrorAction SilentlyContinue)) {
        throw "Provider '$ProviderPath' must define Get-DisenchantProviderData."
    }

    $providerData = Get-DisenchantProviderData
    if ($null -eq $providerData) {
        throw 'Provider returned no data.'
    }
    if ((Get-PropertyValue $providerData 'schemaVersion' -Required) -ne 1) {
        throw 'Unsupported provider schema version.'
    }

    $source = Get-PropertyValue $providerData 'source' -Required
    foreach ($name in 'name', 'mode', 'version', 'generatedAt') {
        Assert-String (Get-PropertyValue $source $name -Required) "source.$name"
    }
    Assert-String (Get-PropertyValue $source 'url' -Required) 'source.url' -AllowEmpty
    $generatedAt = [datetime]::MinValue
    if (-not [datetime]::TryParse((Get-PropertyValue $source 'generatedAt'), [ref]$generatedAt)) {
        throw 'source.generatedAt must be ISO-8601.'
    }

    $minimumSampleSize = Get-PropertyValue $providerData 'minimumSampleSize' -Required
    Assert-PositiveInteger $minimumSampleSize 'minimumSampleSize'
    $minimumSampleSize = [int]$minimumSampleSize

    $records = @(Get-PropertyValue $providerData 'records' -Required)
    if ($records.Count -eq 0) {
        throw 'Provider returned no records.'
    }

    $normalizedRecords = foreach ($record in $records) {
        Normalize-Record $record $minimumSampleSize
    }

    $deduplicatedRecords = $normalizedRecords |
        Sort-Object `
            @{ Expression = { $_.itemId }; Ascending = $true }, `
            @{ Expression = { $_.outputName }; Ascending = $true }, `
            @{ Expression = { $_.probability }; Descending = $true }, `
            @{ Expression = { $_.sampleSize }; Descending = $true } |
        Group-Object itemId, outputName |
        ForEach-Object { $_.Group[0] } |
        Sort-Object `
            @{ Expression = { $_.itemId }; Ascending = $true }, `
            @{ Expression = { $_.probability }; Descending = $true }, `
            @{ Expression = { $_.outputName }; Ascending = $true }

    $lines = @(
        '-- Generated by Update-DisenchantData.ps1. Do not edit by hand.'
        'DisenchantTooltipData = {'
        '    schemaVersion = 1,'
        "    minimumSampleSize = $minimumSampleSize,"
        '    source = {'
        "        name = $(ConvertTo-LuaString ([string]$source.name)),"
        "        mode = $(ConvertTo-LuaString ([string]$source.mode)),"
        "        url = $(ConvertTo-LuaString ([string]$source.url)),"
        "        version = $(ConvertTo-LuaString ([string]$source.version)),"
        "        generatedAt = $(ConvertTo-LuaString ([string]$source.generatedAt)),"
        '    },'
    )

    if ([string]$source.mode -eq 'mock') {
        $lines += '    mockEntries = {'
        foreach ($record in $deduplicatedRecords) {
            $lines += "        $(ConvertTo-LuaRecord $record)"
        }
        $lines += '    },'
    }

    $lines += '    items = {'
    foreach ($itemGroup in ($deduplicatedRecords | Group-Object itemId | Sort-Object { [int]$_.Name })) {
        $lines += "        [$($itemGroup.Name)] = {"
        foreach ($record in $itemGroup.Group) {
            $lines += "            $(ConvertTo-LuaRecord $record)"
        }
        $lines += '        },'
    }

    $lines += @(
        '    },'
        '}'
        ''
    )

    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    $temporaryPath = "$OutputPath.tmp"
    [IO.File]::WriteAllText($temporaryPath, ($lines -join "`n"), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryPath -Destination $OutputPath -Force

    Write-Host "Updated successfully. Source: $($source.name) $($source.version); imported $($deduplicatedRecords.Count) item-output records."
}
catch {
    Write-Error "Update failed. Existing data preserved. $($_.Exception.Message)"
    exit 1
}
