<#
.SYNOPSIS
    Runs tests for the Azure.Search.Documents SDK.

.DESCRIPTION
    This script runs the test suite for the Azure.Search.Documents SDK.
    By default, it runs unit tests only (excluding live tests).

.PARAMETER TestMode
    The test mode to use: Playback, Record, or Live. Defaults to Playback.

.PARAMETER Filter
    Optional test filter expression. Defaults to excluding live tests.

.PARAMETER Framework
    Target framework to test. Defaults to running on all frameworks.

.PARAMETER SdkRepoRoot
    Path to the azure-sdk-for-net repository root.

.EXAMPLE
    .\Run-Tests.ps1

.EXAMPLE
    .\Run-Tests.ps1 -TestMode Record -Filter "FullyQualifiedName~SearchClientTests"

.EXAMPLE
    .\Run-Tests.ps1 -Framework net8.0
#>
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Playback", "Record", "Live")]
    [string]$TestMode = "Playback",

    [Parameter(Mandatory = $false)]
    [string]$Filter = "TestCategory!=Live",

    [Parameter(Mandatory = $false)]
    [string]$Framework,

    [Parameter(Mandatory = $false)]
    [string]$SdkRepoRoot
)

$ErrorActionPreference = "Stop"

# Determine repository root
if (-not $SdkRepoRoot) {
    $SdkRepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
}

$testPath = Join-Path $SdkRepoRoot "sdk/search/Azure.Search.Documents/tests"

if (-not (Test-Path $testPath)) {
    throw "Cannot find tests directory at: $testPath"
}

Write-Host "Running Azure.Search.Documents tests..." -ForegroundColor Cyan
Write-Host "Test mode: $TestMode" -ForegroundColor Gray
Write-Host "Filter: $Filter" -ForegroundColor Gray

# Set environment variable for test mode
$env:AZURE_TEST_MODE = $TestMode

Push-Location $testPath
try {
    $dotnetArgs = @("test")

    if ($Filter) {
        $dotnetArgs += "--filter"
        $dotnetArgs += $Filter
    }

    if ($Framework) {
        $dotnetArgs += "-f"
        $dotnetArgs += $Framework
        Write-Host "Framework: $Framework" -ForegroundColor Gray
    }

    $dotnetArgs += "--logger"
    $dotnetArgs += "console;verbosity=normal"

    Write-Host "`nRunning: dotnet $($dotnetArgs -join ' ')" -ForegroundColor Yellow
    & dotnet @dotnetArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nSome tests failed!" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host "`nAll tests passed!" -ForegroundColor Green
}
finally {
    Pop-Location
    # Clean up environment variable
    Remove-Item Env:AZURE_TEST_MODE -ErrorAction SilentlyContinue
}
