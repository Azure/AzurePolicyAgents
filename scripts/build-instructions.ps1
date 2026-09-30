#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds agent instruction JSON files from readable Markdown files and JSON templates.

.DESCRIPTION
    This script combines human-readable Markdown instruction files with JSON templates
    to generate the final JSON files that can be consumed by the deployment script.
    
    The Markdown files contain the actual instructions in a readable format,
    while the templates contain the JSON structure with a placeholder for instructions.

.PARAMETER AgentType
    Specific agent type to build. If not specified, builds all agents.

.PARAMETER OutputPath
    Directory to output the built JSON files. Defaults to current directory.

.PARAMETER CleanOutput
    Remove any existing JSON files before building new ones.

.EXAMPLE
    .\build-instructions.ps1
    # Builds all agent instruction files

.EXAMPLE
    .\build-instructions.ps1 -AgentType "audit" -OutputPath "./built"
    # Builds only the audit agent instructions to the ./built directory
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("audit", "deny", "dine", "modify", "instructionsAgent", "all")]
    [string] $AgentType = "all",
    
    [Parameter(Mandatory = $false)]
    [string] $OutputPath = "../agentInstructions",

    [Parameter(Mandatory = $false)]
    [switch] $CleanOutput
)

# Determine paths relative to script location
$agentInstructionsPath = Join-Path $PSScriptRoot "../agentInstructions"
$templatesPath = Join-Path $agentInstructionsPath "templates"

# Use provided output path or default to agentInstructions directory
if ($OutputPath -eq "../agentInstructions") {
    $OutputPath = $agentInstructionsPath
}

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Cyan
}

# Agent configuration mapping with correct paths
$agentConfig = @{
    "audit"             = @{
        MarkdownFile = Join-Path $agentInstructionsPath "auditPolicyAgent.md"
        TemplateFile = Join-Path $templatesPath "auditPolicyAgent.template.json"
        OutputFile   = "auditPolicyAgentInstructions.json"
    }
    "deny"              = @{
        MarkdownFile = Join-Path $agentInstructionsPath "denyPolicyAgent.md"
        TemplateFile = Join-Path $templatesPath "denyPolicyAgent.template.json"
        OutputFile   = "denyPolicyAgentInstructions.json"
    }
    "dine"              = @{
        MarkdownFile = Join-Path $agentInstructionsPath "dinePolicyAgent.md"
        TemplateFile = Join-Path $templatesPath "dinePolicyAgent.template.json"
        OutputFile   = "dinePolicyAgentInstructions.json"
    }
    "modify"            = @{
        MarkdownFile = Join-Path $agentInstructionsPath "modifyPolicyAgent.md"
        TemplateFile = Join-Path $templatesPath "modifyPolicyAgent.template.json"
        OutputFile   = "modifyPolicyAgentInstructions.json"
    }
    "instructionsAgent" = @{
        MarkdownFile = Join-Path $agentInstructionsPath "instructionsAgent.md"
        TemplateFile = Join-Path $templatesPath "instructionsAgent.template.json"
        OutputFile   = "instructionsAgentInstructions.json"
    }
}

function Build-AgentInstructions {
    param(
        [string] $AgentName,
        [hashtable] $Config
    )
    
    $markdownPath = $Config.MarkdownFile
    $templatePath = $Config.TemplateFile
    $outputPath = Join-Path $OutputPath $Config.OutputFile
    
    Write-Host "Building $AgentName agent instructions..." -ForegroundColor Yellow
    Write-Host "  Markdown: $markdownPath" -ForegroundColor Gray
    Write-Host "  Template: $templatePath" -ForegroundColor Gray
    Write-Host "  Output: $outputPath" -ForegroundColor Gray
    
    # Verify input files exist
    if (-not (Test-Path $markdownPath)) {
        Write-Error "Markdown file not found: $markdownPath"
        return $false
    }
    
    if (-not (Test-Path $templatePath)) {
        Write-Error "Template file not found: $templatePath"
        return $false
    }
    
    try {
        # Read the markdown content
        $instructionsContent = Get-Content $markdownPath -Raw -Encoding UTF8
        
        # Read the template first to create the complete object structure
        $templateContent = Get-Content $templatePath -Raw -Encoding UTF8
        $templateObject = $templateContent | ConvertFrom-Json
        
        # Set the instructions content directly on the object
        $templateObject.instructions = $instructionsContent
        
        # Convert the complete object back to JSON with proper formatting
        $finalJson = $templateObject | ConvertTo-Json -Depth 10
        
        # Validate JSON structure
        try {
            $jsonObj = $finalJson | ConvertFrom-Json
            Write-Host "  ✓ JSON validation successful" -ForegroundColor Green
        }
        catch {
            Write-Error "  ✗ JSON validation failed: $($_.Exception.Message)"
            return $false
        }
        
        # Write the final JSON file
        $finalJson | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline
        
        # Get file size
        $fileSize = (Get-Item $outputPath).Length
        $fileSizeKB = [Math]::Round($fileSize / 1KB, 2)
        
        Write-Host "  ✓ Built successfully: $outputPath ($fileSizeKB KB)" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Error "Failed to build $AgentName agent: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
try {
    Write-Host "=== Agent Instructions Builder ===" -ForegroundColor Green
    Write-Host "Output Path: $OutputPath"
    
    if ($CleanOutput) {
        Write-Host "Cleaning existing output files..." -ForegroundColor Magenta
        Get-ChildItem -Path $OutputPath -Filter "*AgentInstructions.json" | Remove-Item -Force
    }
    
    $success = $true
    $builtCount = 0
    
    if ($AgentType -eq "all") {
        # Build all agents
        foreach ($agent in $agentConfig.Keys) {
            $result = Build-AgentInstructions -AgentName $agent -Config $agentConfig[$agent]
            if ($result) { $builtCount++ } else { $success = $false }
        }
    }
    else {
        # Build specific agent
        if ($agentConfig.ContainsKey($AgentType)) {
            $result = Build-AgentInstructions -AgentName $AgentType -Config $agentConfig[$AgentType]
            if ($result) { $builtCount++ } else { $success = $false }
        }
        else {
            Write-Error "Unknown agent type: $AgentType"
            $success = $false
        }
    }
    
    Write-Host "\n=== Build Summary ===" -ForegroundColor Green
    Write-Host "Built: $builtCount agent instruction files" -ForegroundColor Cyan
    
    if ($success) {
        Write-Host "✅ All builds completed successfully!" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "❌ Some builds failed. Check errors above." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Error "Build script failed: $($_.Exception.Message)"
    exit 1
}