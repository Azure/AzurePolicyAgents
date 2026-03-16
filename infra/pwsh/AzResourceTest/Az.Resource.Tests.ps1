[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true)][object[]]$tests,
  [Parameter(Mandatory = $true)][string]$testTitle,
  [Parameter(Mandatory = $true)][string]$contextTitle
)
$testResults = @()
$script:contextName = $contextTitle
Foreach ($t in $tests) {
  Write-verbose "[$(getCurrentUTCString)]: Test: $($t.testName)" -Verbose
  $result = compareResourceConfiguration $t -verbose

  Write-Verbose "[$(getCurrentUTCString)]: Passed Test: $result" -Verbose
  Write-Verbose "------------------------" -Verbose
  Write-Verbose "" -Verbose
  $testResults += [ordered]@{
    name   = $t.testName
    result = $result
  }
}

Describe $testTitle {
  Write-Verbose "Test count: $($testResults.count)" -Verbose
  Context $script:contextName {
    foreach ($t in $testResults) {
      $testCase = @{
        name       = $t.name
        testResult = $t.result
      }
      It "[<name>]" -testCases $testCase {
        param(
          [bool]$testResult
        )
        $testResult | should -Be $true
      }
    }
  }
}

