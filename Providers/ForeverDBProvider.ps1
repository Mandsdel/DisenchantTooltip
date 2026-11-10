Set-StrictMode -Version Latest

$script:LastRequestAt = $null

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Invoke-ForeverDBRequest {
    param(
        [string]$Uri,
        [string]$ApiToken,
        [int]$RequestDelayMilliseconds
    )

    if ($null -ne $script:LastRequestAt) {
        $elapsed = ((Get-Date) - $script:LastRequestAt).TotalMilliseconds
        $remainingDelay = $RequestDelayMilliseconds - $elapsed
        if ($remainingDelay -gt 0) {
            Start-Sleep -Milliseconds ([int][math]::Ceiling($remainingDelay))
        }
    }

    $script:LastRequestAt = Get-Date
    return Invoke-RestMethod -Uri $Uri -Headers @{ 'X-API-Key' = $ApiToken } -Method Get
}

function Get-RuleResults {
    param([object]$Rule)

    $observed = Get-PropertyValue $Rule 'seenInForever'
    if ($null -ne $observed) {
        $observedResults = @(Get-PropertyValue $observed 'results')
        if ($observedResults.Count -gt 0) {
            return [pscustomobject]@{
                results = $observedResults
                sampleSize = [int](Get-PropertyValue $observed 'disenchants')
            }
        }
    }

    $classic = Get-PropertyValue $Rule 'classic'
    return [pscustomobject]@{
        results = @(Get-PropertyValue $classic 'results')
        sampleSize = 1
    }
}

function Get-DisenchantProviderData {
    [CmdletBinding()]
    param(
        [string]$ApiBaseUri = 'https://foreverdb.net/api/v1',
        [int]$RequestDelayMilliseconds = 1050
    )

    $apiToken = [Environment]::GetEnvironmentVariable('ForeverDB API Token', 'User')
    if ([string]::IsNullOrWhiteSpace($apiToken)) {
        $apiToken = [Environment]::GetEnvironmentVariable('ForeverDB API Token', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($apiToken)) {
        throw "The 'ForeverDB API Token' user environment variable is not set."
    }
    if ($RequestDelayMilliseconds -lt 0) {
        throw 'RequestDelayMilliseconds must not be negative.'
    }

    $script:LastRequestAt = $null
    Write-Host 'Fetching ForeverDB disenchant rules...'
    $disenchantResponse = Invoke-ForeverDBRequest `
        -Uri "$ApiBaseUri/disenchant" `
        -ApiToken $apiToken `
        -RequestDelayMilliseconds $RequestDelayMilliseconds
    $rules = @($disenchantResponse.data)
    if ($rules.Count -eq 0) {
        throw 'ForeverDB returned no disenchant rules.'
    }

    $items = @()
    foreach ($classId in 2, 4) {
        foreach ($qualityId in 2, 3, 4) {
            $itemType = if ($classId -eq 2) { 'weapons' } else { 'armor' }
            $offset = 0
            do {
                $response = Invoke-ForeverDBRequest `
                    -Uri "$ApiBaseUri/items?class=$classId&quality=$qualityId&limit=100&offset=$offset" `
                    -ApiToken $apiToken `
                    -RequestDelayMilliseconds $RequestDelayMilliseconds
                $page = @($response.data)
                $items += $page
                $offset += $page.Count
                $total = [int](Get-PropertyValue $response.meta 'total')
                Write-Host "Fetched $itemType (quality $qualityId): $offset of $total items."
            } while ($page.Count -gt 0 -and $offset -lt $total)
        }
    }

    Write-Host "Mapping $($items.Count) items to ForeverDB disenchant rules..."
    $records = foreach ($item in $items) {
        $kind = if ([int]$item.classId -eq 2) { 'weapon' } else { 'armor' }
        $matchingRule = @($rules | Where-Object {
            $_.qualityId -eq $item.qualityId `
                -and $_.kind -eq $kind `
                -and $item.itemLevel -ge $_.itemLevelMin `
                -and $item.itemLevel -le $_.itemLevelMax
        }) | Select-Object -First 1
        if ($null -eq $matchingRule) {
            continue
        }

        $ruleData = Get-RuleResults $matchingRule
        foreach ($result in $ruleData.results) {
            $chancePercent = [double](Get-PropertyValue $result 'chancePercent')
            if ($chancePercent -lt 0 -or $chancePercent -gt 100) {
                throw "ForeverDB returned an invalid chance for item $($item.id)."
            }

            [pscustomobject]@{
                itemId = [int]$item.id
                outputName = [string](Get-PropertyValue $result 'name')
                outputId = [int](Get-PropertyValue $result 'itemId')
                probability = $chancePercent / 100
                minimumQuantity = [int](Get-PropertyValue $result 'min')
                maximumQuantity = [int](Get-PropertyValue $result 'max')
                sampleSize = $ruleData.sampleSize
            }
        }
    }

    if (@($records).Count -eq 0) {
        throw 'ForeverDB returned no matching item-specific disenchant records.'
    }

    return [pscustomobject]@{
        schemaVersion = 1
        source = [pscustomobject]@{
            name = 'ForeverDB.net'
            mode = 'foreverdb'
            url = 'https://foreverdb.net'
            version = [string](Get-PropertyValue $disenchantResponse.meta 'build')
            generatedAt = [datetime]::UtcNow.ToString('o')
        }
        minimumSampleSize = 1
        records = @($records)
    }
}
