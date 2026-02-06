<#
.SYNOPSIS
    Performs a comprehensive review of Azure.Search.Documents SDK changes.

.DESCRIPTION
    This script performs automated checks for SDK review including:
    - C# coding standards validation
    - API comparison with previous version
    - Breaking change detection
    - Documentation completeness check

.PARAMETER PreviousCommit
    The commit SHA representing the previous API version for comparison.

.PARAMETER Track
    Whether this is a "stable" or "preview" release track.

.PARAMETER SdkRepoRoot
    Path to the azure-sdk-for-net repository root.

.PARAMETER GenerateReport
    If specified, generates a markdown report file.

.EXAMPLE
    .\Review-SdkChanges.ps1 -PreviousCommit "abc123" -Track "preview"

.EXAMPLE
    .\Review-SdkChanges.ps1 -PreviousCommit "Azure.Search.Documents_11.7.0" -Track "stable" -GenerateReport
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$PreviousCommit,

    [Parameter(Mandatory = $false)]
    [ValidateSet("stable", "preview")]
    [string]$Track = "preview",

    [Parameter(Mandatory = $false)]
    [string]$SdkRepoRoot,

    [switch]$GenerateReport
)

$ErrorActionPreference = "Stop"

# Determine repository root
if (-not $SdkRepoRoot) {
    $SdkRepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
}

$searchSdkPath = Join-Path $SdkRepoRoot "sdk/search/Azure.Search.Documents"

# Review results collection
$reviewResults = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    PreviousCommit = $PreviousCommit
    Track = $Track
    Checks = @()
    OverallStatus = "PENDING"
    Recommendation = "PENDING"
}

function Add-ReviewCheck {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Message,
        [array]$Details = @()
    )

    $script:reviewResults.Checks += @{
        Name = $Name
        Status = $Status
        Message = $Message
        Details = $Details
    }
}

Write-Host "=== Azure.Search.Documents SDK Review ===" -ForegroundColor Cyan
Write-Host "Previous Commit: $PreviousCommit" -ForegroundColor Gray
Write-Host "Track: $Track" -ForegroundColor Gray
Write-Host ""

# Check 1: Build succeeds
Write-Host "Check 1: Building SDK..." -ForegroundColor Yellow
Push-Location $searchSdkPath
try {
    $buildOutput = & dotnet build --nologo -v q 2>&1
    if ($LASTEXITCODE -eq 0) {
        Add-ReviewCheck "Build" "PASS" "SDK builds successfully"
    } else {
        Add-ReviewCheck "Build" "FAIL" "Build failed" @($buildOutput | Select-Object -Last 10)
    }
}
finally {
    Pop-Location
}

# Check 2: No compiler warnings
Write-Host "Check 2: Checking for compiler warnings..." -ForegroundColor Yellow
Push-Location $searchSdkPath
try {
    $buildOutput = & dotnet build --nologo -v n 2>&1
    $warnings = $buildOutput | Where-Object { $_ -match "warning CS\d+" }
    if ($warnings.Count -eq 0) {
        Add-ReviewCheck "Warnings" "PASS" "No compiler warnings"
    } else {
        Add-ReviewCheck "Warnings" "WARN" "Compiler warnings found: $($warnings.Count)" @($warnings | Select-Object -First 10)
    }
}
finally {
    Pop-Location
}

# Check 3: Documentation completeness
Write-Host "Check 3: Checking XML documentation..." -ForegroundColor Yellow
$srcPath = Join-Path $searchSdkPath "src"
$csFiles = Get-ChildItem -Path $srcPath -Filter "*.cs" -Recurse |
    Where-Object { $_.FullName -notmatch "\\Generated\\" -and $_.FullName -notmatch "\\obj\\" }

$publicWithoutDocs = @()
foreach ($file in $csFiles) {
    $content = Get-Content $file.FullName -Raw
    # Find public members without preceding /// comments
    $matches = [regex]::Matches($content, '(?<!///[^\n]*\n\s*)public\s+(partial\s+)?(class|struct|interface|enum|void|async|virtual|static|override)\s+\w+')
    if ($matches.Count -gt 0) {
        $publicWithoutDocs += @{
            File = $file.Name
            Count = $matches.Count
        }
    }
}

if ($publicWithoutDocs.Count -eq 0) {
    Add-ReviewCheck "Documentation" "PASS" "All public APIs appear documented"
} else {
    $totalMissing = ($publicWithoutDocs | Measure-Object -Property Count -Sum).Sum
    Add-ReviewCheck "Documentation" "WARN" "Potential missing documentation: $totalMissing items" @(
        $publicWithoutDocs | ForEach-Object { "$($_.File): $($_.Count) items" }
    )
}

# Check 4: API comparison
Write-Host "Check 4: Comparing APIs..." -ForegroundColor Yellow
try {
    $compareScript = Join-Path $PSScriptRoot "Compare-SearchApi.ps1"
    $apiResult = & $compareScript -PreviousCommit $PreviousCommit -SdkRepoRoot $SdkRepoRoot

    if ($apiResult.IsBackwardsCompatible) {
        Add-ReviewCheck "API Compatibility" "PASS" "No breaking changes detected" @(
            "New types: $($apiResult.NewTypes)",
            "New members: $($apiResult.NewMembers)"
        )
    } else {
        $severity = if ($Track -eq "stable") { "FAIL" } else { "WARN" }
        Add-ReviewCheck "API Compatibility" $severity "Breaking changes detected" @(
            "Removed types: $($apiResult.RemovedTypes)",
            "Removed members: $($apiResult.RemovedMembers)"
        )
    }
}
catch {
    Add-ReviewCheck "API Compatibility" "WARN" "Could not compare APIs: $($_.Exception.Message)"
}

# Check 5: CHANGELOG updated
Write-Host "Check 5: Checking CHANGELOG.md..." -ForegroundColor Yellow
$changelogPath = Join-Path $searchSdkPath "CHANGELOG.md"
if (Test-Path $changelogPath) {
    $changelog = Get-Content $changelogPath -Raw
    if ($changelog -match "## \d+\.\d+\.\d+.*\(Unreleased\)") {
        Add-ReviewCheck "Changelog" "PASS" "CHANGELOG.md has unreleased section"
    } else {
        Add-ReviewCheck "Changelog" "WARN" "No unreleased section found in CHANGELOG.md"
    }
} else {
    Add-ReviewCheck "Changelog" "FAIL" "CHANGELOG.md not found"
}

# Check 6: Generated folder integrity
Write-Host "Check 6: Checking Generated folder..." -ForegroundColor Yellow
Push-Location $SdkRepoRoot
try {
    $generatedPath = "sdk/search/Azure.Search.Documents/src/Generated"
    $gitStatus = git diff --name-only $PreviousCommit HEAD -- $generatedPath 2>&1

    if ($LASTEXITCODE -eq 0 -and $gitStatus) {
        $generatedChanges = $gitStatus -split "`n" | Where-Object { $_ }
        Add-ReviewCheck "Generated Code" "INFO" "Generated files changed: $($generatedChanges.Count) files" @(
            "Ensure these are from code generation only"
        )
    } else {
        Add-ReviewCheck "Generated Code" "PASS" "No changes to generated code"
    }
}
finally {
    Pop-Location
}

# Check 7: Tests pass
Write-Host "Check 7: Running unit tests..." -ForegroundColor Yellow
$testPath = Join-Path $searchSdkPath "tests"
Push-Location $testPath
try {
    $env:AZURE_TEST_MODE = "Playback"
    $testOutput = & dotnet test --filter "TestCategory!=Live" --no-build -v q --nologo 2>&1
    if ($LASTEXITCODE -eq 0) {
        Add-ReviewCheck "Tests" "PASS" "All unit tests pass"
    } else {
        $failures = $testOutput | Where-Object { $_ -match "Failed" }
        Add-ReviewCheck "Tests" "FAIL" "Some tests failed" @($failures | Select-Object -First 5)
    }
}
catch {
    Add-ReviewCheck "Tests" "WARN" "Could not run tests: $($_.Exception.Message)"
}
finally {
    Pop-Location
    Remove-Item Env:AZURE_TEST_MODE -ErrorAction SilentlyContinue
}

# Determine overall status
$failCount = ($reviewResults.Checks | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = ($reviewResults.Checks | Where-Object { $_.Status -eq "WARN" }).Count

if ($failCount -gt 0) {
    $reviewResults.OverallStatus = "FAIL"
    $reviewResults.Recommendation = "REQUEST_CHANGES"
} elseif ($warnCount -gt 0) {
    $reviewResults.OverallStatus = "WARN"
    $reviewResults.Recommendation = "APPROVE_WITH_COMMENTS"
} else {
    $reviewResults.OverallStatus = "PASS"
    $reviewResults.Recommendation = "APPROVE"
}

# Display results
Write-Host ""
Write-Host "=== Review Results ===" -ForegroundColor Cyan
Write-Host ""

foreach ($check in $reviewResults.Checks) {
    $color = switch ($check.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }

    $icon = switch ($check.Status) {
        "PASS" { "[✓]" }
        "FAIL" { "[✗]" }
        "WARN" { "[!]" }
        "INFO" { "[i]" }
        default { "[?]" }
    }

    Write-Host "$icon $($check.Name): " -ForegroundColor $color -NoNewline
    Write-Host $check.Message

    foreach ($detail in $check.Details) {
        Write-Host "    - $detail" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Overall Status: $($reviewResults.OverallStatus)" -ForegroundColor $(
    switch ($reviewResults.OverallStatus) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
    }
)
Write-Host "Recommendation: $($reviewResults.Recommendation)" -ForegroundColor Cyan

# Generate report if requested
if ($GenerateReport) {
    $reportPath = Join-Path $SdkRepoRoot "sdk/search/Azure.Search.Documents/REVIEW-REPORT.md"

    $report = @"
# Azure.Search.Documents SDK Review Report

**Generated**: $($reviewResults.Timestamp)
**Previous Commit**: ``$PreviousCommit``
**Track**: $Track
**Overall Status**: $($reviewResults.OverallStatus)
**Recommendation**: $($reviewResults.Recommendation)

## Checks

| Check | Status | Message |
|-------|--------|---------|
$(($reviewResults.Checks | ForEach-Object {
    $icon = switch ($_.Status) { "PASS" { "✅" } "FAIL" { "❌" } "WARN" { "⚠️" } "INFO" { "ℹ️" } }
    "| $($_.Name) | $icon $($_.Status) | $($_.Message) |"
}) -join "`n")

## Details

$($reviewResults.Checks | Where-Object { $_.Details.Count -gt 0 } | ForEach-Object {
    "### $($_.Name)`n" + ($_.Details | ForEach-Object { "- $_" }) -join "`n" + "`n"
})

## Recommendation

$(switch ($reviewResults.Recommendation) {
    "APPROVE" { "✅ **APPROVE** - All checks passed. Ready for PR submission." }
    "APPROVE_WITH_COMMENTS" { "⚠️ **APPROVE WITH COMMENTS** - Minor issues detected. Review warnings before proceeding." }
    "REQUEST_CHANGES" { "❌ **REQUEST CHANGES** - Critical issues must be addressed before approval." }
})
"@

    Set-Content -Path $reportPath -Value $report
    Write-Host "`nReport written to: $reportPath" -ForegroundColor Green
}

# Return results for programmatic use
return $reviewResults
