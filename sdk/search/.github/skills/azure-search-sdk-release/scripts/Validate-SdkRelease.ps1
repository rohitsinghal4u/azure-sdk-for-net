<#
.SYNOPSIS
    Validates the Search SDK is ready for a pull request.

.DESCRIPTION
    This script performs a comprehensive validation of the Azure.Search.Documents SDK
    to ensure it's ready for a pull request. It checks:
    - Project builds successfully
    - No files in Generated/ were manually edited (via git status)
    - Unit tests pass
    - CHANGELOG.md is updated

.PARAMETER SdkRepoRoot
    Path to the azure-sdk-for-net repository root.

.PARAMETER SkipTests
    Skip running tests (useful for quick validation).

.EXAMPLE
    .\Validate-SdkRelease.ps1

.EXAMPLE
    .\Validate-SdkRelease.ps1 -SkipTests
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$SdkRepoRoot,

    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

# Determine repository root
if (-not $SdkRepoRoot) {
    $SdkRepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
}

$searchSdkPath = Join-Path $SdkRepoRoot "sdk/search/Azure.Search.Documents"

if (-not (Test-Path $searchSdkPath)) {
    throw "Cannot find Azure.Search.Documents at: $searchSdkPath"
}

$validationResults = @()
$hasErrors = $false

function Add-ValidationResult {
    param($Name, $Status, $Message)

    $script:validationResults += [PSCustomObject]@{
        Check = $Name
        Status = $Status
        Message = $Message
    }

    if ($Status -eq "FAIL") {
        $script:hasErrors = $true
    }
}

Write-Host "=== Azure.Search.Documents SDK Validation ===" -ForegroundColor Cyan
Write-Host "Repository: $SdkRepoRoot" -ForegroundColor Gray
Write-Host ""

# Check 1: Build the project
Write-Host "Checking: Project builds..." -ForegroundColor Yellow
Push-Location $searchSdkPath
try {
    $buildOutput = & dotnet build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Add-ValidationResult "Build" "PASS" "Project builds successfully"
    } else {
        Add-ValidationResult "Build" "FAIL" "Build failed - check errors above"
        $buildOutput | Write-Host
    }
}
finally {
    Pop-Location
}

# Check 2: CHANGELOG.md has unreleased section
Write-Host "Checking: CHANGELOG.md..." -ForegroundColor Yellow
$changelogPath = Join-Path $searchSdkPath "CHANGELOG.md"
if (Test-Path $changelogPath) {
    $changelog = Get-Content $changelogPath -Raw
    if ($changelog -match "## \d+\.\d+\.\d+.*\(Unreleased\)") {
        Add-ValidationResult "Changelog" "PASS" "CHANGELOG.md has unreleased section"
    } else {
        Add-ValidationResult "Changelog" "WARN" "No unreleased section found in CHANGELOG.md"
    }
} else {
    Add-ValidationResult "Changelog" "FAIL" "CHANGELOG.md not found"
}

# Check 3: No manual edits to Generated folder
Write-Host "Checking: Generated folder integrity..." -ForegroundColor Yellow
Push-Location $SdkRepoRoot
try {
    $generatedPath = "sdk/search/Azure.Search.Documents/src/Generated"
    $gitStatus = & git status --porcelain $generatedPath 2>&1

    # Check if there are modified (not just added) generated files
    $modifiedGenerated = $gitStatus | Where-Object { $_ -match "^\s*M\s+" }

    if ($modifiedGenerated) {
        Add-ValidationResult "Generated" "WARN" "Modified files in Generated/ - ensure these are from code generation only"
    } else {
        Add-ValidationResult "Generated" "PASS" "No manual edits detected in Generated/"
    }
}
finally {
    Pop-Location
}

# Check 4: Run tests (unless skipped)
if (-not $SkipTests) {
    Write-Host "Checking: Unit tests..." -ForegroundColor Yellow
    $testPath = Join-Path $searchSdkPath "tests"
    Push-Location $testPath
    try {
        $env:AZURE_TEST_MODE = "Playback"
        & dotnet test --filter "TestCategory!=Live" --no-build -q 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Add-ValidationResult "Tests" "PASS" "All unit tests pass"
        } else {
            Add-ValidationResult "Tests" "FAIL" "Some tests failed - run tests manually for details"
        }
    }
    finally {
        Pop-Location
        Remove-Item Env:AZURE_TEST_MODE -ErrorAction SilentlyContinue
    }
} else {
    Add-ValidationResult "Tests" "SKIP" "Tests skipped"
}

# Check 5: API compatibility
Write-Host "Checking: API compatibility baseline..." -ForegroundColor Yellow
$apiCompatPath = Join-Path $searchSdkPath "src/ApiCompatBaseline.txt"
if (Test-Path $apiCompatPath) {
    Add-ValidationResult "API Compat" "INFO" "ApiCompatBaseline.txt exists - review for intentional breaking changes"
} else {
    Add-ValidationResult "API Compat" "PASS" "No API compatibility baseline (no known breaking changes)"
}

# Display results
Write-Host ""
Write-Host "=== Validation Results ===" -ForegroundColor Cyan
Write-Host ""

foreach ($result in $validationResults) {
    $color = switch ($result.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        "SKIP" { "Gray" }
        "INFO" { "Cyan" }
        default { "White" }
    }

    $statusIcon = switch ($result.Status) {
        "PASS" { "[✓]" }
        "FAIL" { "[✗]" }
        "WARN" { "[!]" }
        "SKIP" { "[-]" }
        "INFO" { "[i]" }
        default { "[?]" }
    }

    Write-Host "$statusIcon " -ForegroundColor $color -NoNewline
    Write-Host "$($result.Check): " -NoNewline
    Write-Host $result.Message -ForegroundColor $color
}

Write-Host ""

if ($hasErrors) {
    Write-Host "Validation FAILED - please fix the issues above before creating a PR" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Validation PASSED - SDK is ready for pull request!" -ForegroundColor Green
    exit 0
}
