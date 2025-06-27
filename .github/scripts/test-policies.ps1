param(
    [Parameter(Mandatory = $true)]
    [string]$Endpoint,

    [Parameter(Mandatory = $true)]
    [string]$AssistantId
)

# Read all policy contents
$AllPolicyContentsJson = Get-Content -Path './allPolicyContents.json' -Raw
$AllPolicyContents = $AllPolicyContentsJson | ConvertFrom-Json

Write-Host "Number of policy files to process: $($AllPolicyContents.Count)"

Install-Module Metro.AI -Force

# Set Metro.AI Context to Foundry project
Set-MetroAIContext -Endpoint $Endpoint -ApiType Agent
# Create a single assistant for all policy tests
$Agent = Get-MetroAIAgent -AssistantId $Assistantid
if (-not $Agent) {
    break "Cannot find agent $AssistantId. Please re-create it and retry"
}
$AllResults = @()
$ProcessedFiles = 0

foreach ($PolicyInfo in $AllPolicyContents) {
    $ProcessedFiles++
    $FilePath = $PolicyInfo.FilePath
    $PolicyContent = $PolicyInfo.Content

    Write-Host "Processing policy file ($ProcessedFiles/$($AllPolicyContents.Count)): $FilePath"
    Write-Host "Policy Content Retrieved:"
    Write-Host $PolicyContent

    try {
        $Thread = Start-MetroAIThreadWithMessages -MessageContent $PolicyContent -AssistantId $AssistantId -Async

        # Retry logic to ensure we get a file to download and deploy
        $Attempts = 0
        $MaxAttempts = 4
        $PolicyDefinitionFile = $null

        do {
            $Attempts++
            Start-Sleep -Seconds 20
            Write-Host "Attempt $Attempts of $MaxAttempts to get policy definition file for $FilePath"

            # Get messages from the current thread and check for attachments
            $PolicyDefinitionFile = (Get-MetroAIMessages -ThreadID $Thread.ThreadId | Where-Object { $_.attachments }).attachments.file_id

            if (-not $PolicyDefinitionFile -and $Attempts -lt $MaxAttempts) {
                Write-Host "No policy deployment file found, requesting generation..."
                # If no file found, ask the assistant to generate a .ps1 file
                Invoke-MetroAIMessage -ThreadID $Thread.ThreadId -Message "Please generate a .ps1 for me to download"

                $null = Start-MetroAIThreadRun -ThreadID $Thread.ThreadId -AssistantId $AssistantId
            }
        } until ($PolicyDefinitionFile -or $Attempts -ge $MaxAttempts)

        if ($PolicyDefinitionFile) {
            Get-MetroAIOutputFiles -FileId $PolicyDefinitionFile -LocalFilePath "./temp_$ProcessedFiles.ps1" | Out-Null

            Write-Host "Retrieved policy definition content for $FilePath"
            $Content = Get-Content -Path "./temp_$ProcessedFiles.ps1" -Raw
            Write-Host $Content
            Write-Host "Executing the policy definition content for $FilePath"
            & "./temp_$ProcessedFiles.ps1" -Verbose

            Write-Host "Trying to fetch the response object for $FilePath"
            if (Test-Path -Path ./logging.json) {
                try {
                    $jsonContent = Get-Content -Path ./logging.json -Raw
                    $response = $jsonContent | ConvertFrom-Json

                    if ($null -ne $response) {
                        $statusCode = $response.StatusCode

                        if ($response.PSObject.Properties.Match("Content")) {
                            $responseContent = $response.Content | ConvertFrom-Json

                            if ($statusCode -like "403") {
                                $policyMessage = $responseContent.error.message
                                $policyName = $responseContent.error.additionalInfo[0].info.policyDefinitionDisplayName

                                $formattedOutput = "### ✅ Policy Test Completed Successfully for ``$FilePath``" + "`n" +
                                "The Policy '**$policyName**' successfully validated the policy." + "`n`n" +
                                "**Details:**" + "`n" +
                                "- **Status Code:** $statusCode" + "`n" +
                                "- **Message:** $policyMessage"
                            }
                            elseif ($statusCode -eq 200 -or $statusCode -eq 201 -or $statusCode -eq 202) {
                                $formattedOutput = "### 🚫 Policy Test Failed for ``$FilePath``" + "`n" +
                                "The request invalidated the policy rule." + "`n`n" +
                                "**Details:**" + "`n" +
                                "- **Status Code:** $statusCode"
                            }
                            else {
                                $formattedOutput = "### ⚠️ The command executed successfully or encountered a different error for ``$FilePath``."
                            }

                            $AllResults += $formattedOutput
                        }
                        else {
                            Write-Host "Content property not found in the response object for $FilePath."
                            $AllResults += "### ⚠️ Content property not found in response for ``$FilePath``"
                        }
                    }
                    else {
                        Write-Host "Response is null for $FilePath."
                        $AllResults += "### ⚠️ Response is null for ``$FilePath``"
                    }
                }
                catch {
                    Write-Host "Failed to read or parse the logging.json file for $FilePath."
                    Write-Host $_.Exception.Message
                    $AllResults += "### ❌ Failed to parse response for ``$FilePath``: $($_.Exception.Message)"
                }

                # Clean up logging.json for next iteration
                Remove-Item -Path ./logging.json -Force -ErrorAction SilentlyContinue
            }
            else {
                Write-Host "The logging.json file does not exist for $FilePath."
                $AllResults += "### ⚠️ No logging.json file found for ``$FilePath``"
            }

            # Clean up assistant files
            Write-Host "Removing assistant output files for $FilePath"
            # -Endpoint $Endpoint -FileId $PolicyDefinitionFile.id

            # Clean up temp script
            Remove-Item -Path "./temp_$ProcessedFiles.ps1" -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Warning "No AI files were found for $($NewAssistant.id) when processing $FilePath"
            $AllResults += "### ⚠️ No AI files generated for ``$FilePath``"
        }
    }
    catch {
        Write-Error "Error processing $FilePath : $($_.Exception.Message)"
        $AllResults += "### ❌ Error processing ``$FilePath``: $($_.Exception.Message)"
    }
}

# Combine all results
$prependMessage = "## Azure Policy Test Results"
$summaryMessage = "`n`n### Summary: Processed $ProcessedFiles policy definition(s)`n`n"
$fullResult = $prependMessage + $summaryMessage + ($AllResults -join "`n`n---`n`n")
$fullResult | Out-File -FilePath /tmp/RESULT.md -Encoding utf8
Write-Host "Results written to /tmp/RESULT.md"