3# AzResourceTest PowerShell Module

Azure resource configuration tests using Pester and Azure Resource Graph.

## Generating Help Files for `AzResourceTest`

To generate help files for the `AzResourceTest` module, run the following command:

1. Install the `Microsoft.PowerSShell.PlatyPS` module:

```powershell
Install-Module -Name Microsoft.PowerShell.PlatyPS -Scope CurrentUser -force
```

2. Generate markdown help files using `Microsoft.PowerSShell.PlatyPS`:

```powershell
import-module ./AzResourceTest.psd1
$params = @{
  ModuleInfo = Get-Module AzResourceTest
  OutputFolder = './docs'
  HelpVersion = '2.0.0'
  WithModulePage = $true
}
New-MarkdownCommandHelp @params
```

3. Manually update the generated Markdown files and ensure there are no errors flagged by the markdown linter `markdownlint`.

4. Generate the XML help file:

```powershell
$mdfiles = Measure-PlatyPSMarkdown -Path ./docs/AzResourceTest/*.md
$mdfiles | Where-Object Filetype -match 'CommandHelp' | Import-MarkdownCommandHelp -Path {$_.FilePath} | Export-MamlCommandHelp -OutputFolder $pwd

```
