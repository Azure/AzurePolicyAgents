param(
    [Parameter(Mandatory = $true)]
    [string]$JsonFiles,

    [Parameter(Mandatory = $true)]
    [string]$JsonFilesCount
)

Write-Host "JSON files changed: $JsonFiles"
Write-Host "Number of JSON files: $JsonFilesCount"

if ([string]::IsNullOrWhiteSpace($JsonFiles) -or $JsonFilesCount -eq "0") {
    Write-Warning "No JSON files found in the 'policyDefinitions' directory"
    Write-Output "::set-output name=policyContentBase64::"
    exit 0
}

$JsonFilesList = $JsonFiles -split " " | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$AllPolicyContents = @()
$DeploymentResults = @()

foreach ($JsonFile in $JsonFilesList) {
    Write-Host "Processing policy definition file: $JsonFile"

    try {
        # Deploy each policy definition
        ./utilities/policyAgent/deployDef.ps1 `
            -PolicyDefinitionFilePath $JsonFile `
            -BicepFilePath './utilities/policyAgent/policyDef.bicep' `
            -ParameterFilePath './utilities/policyAgent/policyDef.parameters.json' `
            -Verbose

        Write-Host "Policy definition deployment complete for: $JsonFile"

        # Read and store policy content
        $PolicyContent = Get-Content -Path $JsonFile -Raw
        $PolicyContentInfo = @{
            FilePath      = $JsonFile
            Content       = $PolicyContent
            Base64Content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($PolicyContent))
        }

        $AllPolicyContents += $PolicyContentInfo
        $DeploymentResults += "✅ Successfully deployed: $JsonFile"

        Write-Host "Policy Content Length for ${JsonFile}: $($PolicyContent.Length)"

    }
    catch {
        Write-Error "Failed to deploy policy definition for: $JsonFile - $($_.Exception.Message)"
        $DeploymentResults += "❌ Failed to deploy: $JsonFile - $($_.Exception.Message)"
    }
}

# Convert all policy contents to JSON and then to Base64 for passing to next job
$AllPolicyContentsJson = $AllPolicyContents | ConvertTo-Json -Depth 10 -Compress
$AllPolicyContentsBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($AllPolicyContentsJson))

Write-Host "Deployment Summary:"
$DeploymentResults | ForEach-Object { Write-Host $_ }

Write-Output "::set-output name=policyContentBase64::$AllPolicyContentsBase64"
Write-Output "::set-output name=processedFilesCount::$($AllPolicyContents.Count)"