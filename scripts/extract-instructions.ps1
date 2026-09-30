#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reverse-engineers readable Markdown and JSON templates from built agent instruction JSON files.

.DESCRIPTION
    For each agent type, reads <type>PolicyAgentInstructions.json from the current directory, converts
    the escaped instruction text back into a readable <type>PolicyAgent.md file, and writes a
    <type>PolicyAgent.template.json template with the instructions replaced by a placeholder. Run this
    from the agentInstructions directory. This is a manual developer utility; run build-instructions.ps1
    afterwards to rebuild the JSON files from any edited Markdown.

.NOTES
    Takes no parameters. Processes the deny, dine and modify agent types.
#>

$agents = @("deny", "dine", "modify")

foreach ($agent in $agents) {
    $jsonFile = "${agent}PolicyAgentInstructions.json"
    
    if (Test-Path $jsonFile) {
        Write-Host "Extracting instructions from $jsonFile" -ForegroundColor Yellow
        
        try {
            $json = Get-Content $jsonFile -Raw | ConvertFrom-Json
            
            # Convert escaped instructions back to readable format
            $instructions = $json.instructions -replace '\\n', "`r`n" -replace '\\"', '"' -replace '\\\\', '\'
            
            # Create markdown file
            $markdownFile = "${agent}PolicyAgent.md"
            $instructions | Out-File -FilePath $markdownFile -Encoding UTF8
            Write-Host "✓ Created $markdownFile" -ForegroundColor Green
            
            # Create template file
            $templateFile = "${agent}PolicyAgent.template.json"
            $template = [ordered]@{
                id              = $json.id
                object          = $json.object
                created_at      = $json.created_at
                name            = $json.name
                description     = $json.description
                model           = $json.model
                instructions    = "{{INSTRUCTIONS_CONTENT}}"
                tools           = $json.tools
                tool_resources  = $json.tool_resources
                metadata        = $json.metadata
                response_format = $json.response_format
            }
            
            $template | ConvertTo-Json -Depth 10 | Out-File -FilePath $templateFile -Encoding UTF8
            Write-Host "✓ Created $templateFile" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to process $jsonFile : $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "File not found: $jsonFile"
    }
}

Write-Host "\n🎉 Extraction complete! You now have readable markdown files and templates." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Edit the .md files to modify instructions" -ForegroundColor Yellow
Write-Host "2. Run .\build-instructions.ps1 to rebuild JSON files" -ForegroundColor Yellow
Write-Host "3. Deploy agents using the existing workflow" -ForegroundColor Yellow