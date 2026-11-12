Set-StrictMode -Version Latest

function Get-DisenchantProviderData {
    [CmdletBinding()]
    param()

    return [pscustomobject]@{
        schemaVersion = 1
        source = [pscustomobject]@{
            name = 'Test provider'
            mode = 'test'
            url = ''
            version = 'fixture-1'
            generatedAt = '2026-11-10T00:00:00Z'
        }
        minimumSampleSize = 25
        records = @(
            [pscustomobject]@{
                itemId = 999001
                outputName = 'Mock Arcane Dust'
                outputId = 999101
                probability = 0.70
                minimumQuantity = 1
                maximumQuantity = 3
                sampleSize = 500
            }
            [pscustomobject]@{
                itemId = 999001
                outputName = 'Mock Greater Essence'
                outputId = 999102
                probability = 0.25
                minimumQuantity = 1
                maximumQuantity = 1
                sampleSize = 500
            }
            [pscustomobject]@{
                itemId = 999001
                outputName = 'Mock Brilliant Shard'
                outputId = 999103
                probability = 0.05
                minimumQuantity = 1
                maximumQuantity = 1
                sampleSize = 500
            }
        )
    }
}
