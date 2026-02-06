<#
.SYNOPSIS
    Compares the Azure.Search.Documents API surface between two commits.

.DESCRIPTION
    This script extracts the public API from two commits and generates a comparison
    report showing additions, removals, and changes.

.PARAMETER PreviousCommit
    The commit SHA or ref representing the previous API version.

.PARAMETER CurrentRef
    The commit SHA, ref, or "HEAD" for the current API. Defaults to HEAD.

.PARAMETER Framework
    The target framework API to compare. Defaults to "net8.0".

.PARAMETER OutputReport
    Path to write the comparison report. If not specified, outputs to console.

.PARAMETER SdkRepoRoot
    Path to the azure-sdk-for-net repository root.

.EXAMPLE
    .\Compare-SearchApi.ps1 -PreviousCommit "abc123"

.EXAMPLE
    .\Compare-SearchApi.ps1 -PreviousCommit "Azure.Search.Documents_11.7.0" -OutputReport "api-diff.md"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$PreviousCommit,

    [Parameter(Mandatory = $false)]
    [string]$CurrentRef = "HEAD",

    [Parameter(Mandatory = $false)]
    [ValidateSet("net8.0", "net10.0", "netstandard2.0")]
    [string]$Framework = "net8.0",

    [Parameter(Mandatory = $false)]
    [string]$OutputReport,

    [Parameter(Mandatory = $false)]
    [string]$SdkRepoRoot
)

$ErrorActionPreference = "Stop"

# Determine repository root
if (-not $SdkRepoRoot) {
    $SdkRepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
}

$apiFileName = "Azure.Search.Documents.$Framework.cs"
$apiRelativePath = "sdk/search/Azure.Search.Documents/api/$apiFileName"

Write-Host "=== Azure.Search.Documents API Comparison ===" -ForegroundColor Cyan
Write-Host "Previous: $PreviousCommit" -ForegroundColor Gray
Write-Host "Current: $CurrentRef" -ForegroundColor Gray
Write-Host "Framework: $Framework" -ForegroundColor Gray
Write-Host ""

Push-Location $SdkRepoRoot
try {
    # Get previous API
    Write-Host "Extracting previous API..." -ForegroundColor Yellow
    $previousApi = git show "${PreviousCommit}:${apiRelativePath}" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get API from commit $PreviousCommit. Error: $previousApi"
    }
    $previousLines = $previousApi -split "`n" | Where-Object { $_.Trim() }

    # Get current API
    Write-Host "Extracting current API..." -ForegroundColor Yellow
    if ($CurrentRef -eq "HEAD") {
        $currentApiPath = Join-Path $SdkRepoRoot $apiRelativePath
        if (-not (Test-Path $currentApiPath)) {
            throw "Current API file not found: $currentApiPath"
        }
        $currentLines = Get-Content $currentApiPath | Where-Object { $_.Trim() }
    } else {
        $currentApi = git show "${CurrentRef}:${apiRelativePath}" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get API from ref $CurrentRef. Error: $currentApi"
        }
        $currentLines = $currentApi -split "`n" | Where-Object { $_.Trim() }
    }

    # Compare
    Write-Host "Comparing APIs..." -ForegroundColor Yellow
    $comparison = Compare-Object $previousLines $currentLines -IncludeEqual

    $additions = $comparison | Where-Object { $_.SideIndicator -eq '=>' }
    $removals = $comparison | Where-Object { $_.SideIndicator -eq '<=' }

    # Filter to significant changes (types and members, not just braces)
    $significantPattern = '^\s*(public|protected|internal|private|\[|namespace|///)'

    $significantAdditions = $additions | Where-Object { $_.InputObject -match $significantPattern }
    $significantRemovals = $removals | Where-Object { $_.InputObject -match $significantPattern }

    # Categorize additions
    $newTypes = $significantAdditions | Where-Object {
        $_.InputObject -match '\s*(public|internal)\s+(partial\s+)?(class|struct|interface|enum)\s+'
    }
    $newMembers = $significantAdditions | Where-Object {
        $_.InputObject -match '\s*(public|protected)\s+.*\s+\w+\s*[\(\{]' -and
        $_.InputObject -notmatch '\s+(class|struct|interface|enum)\s+'
    }

    # Categorize removals (potential breaking changes)
    $removedTypes = $significantRemovals | Where-Object {
        $_.InputObject -match '\s*(public|internal)\s+(partial\s+)?(class|struct|interface|enum)\s+'
    }
    $removedMembers = $significantRemovals | Where-Object {
        $_.InputObject -match '\s*(public|protected)\s+.*\s+\w+\s*[\(\{]' -and
        $_.InputObject -notmatch '\s+(class|struct|interface|enum)\s+'
    }

    # Generate report
    $report = @"
# Azure.Search.Documents API Comparison Report

## Summary
- **Previous Version**: ``$PreviousCommit``
- **Current Version**: ``$CurrentRef``
- **Framework**: ``$Framework``
- **Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Statistics
- Total Additions: $($additions.Count)
- Total Removals: $($removals.Count)
- New Types: $($newTypes.Count)
- New Members: $($newMembers.Count)
- Removed Types: $($removedTypes.Count) $(if ($removedTypes.Count -gt 0) { "⚠️ BREAKING" } else { "" })
- Removed Members: $($removedMembers.Count) $(if ($removedMembers.Count -gt 0) { "⚠️ BREAKING" } else { "" })

## New Types
$(if ($newTypes.Count -eq 0) { "No new types added." } else { ($newTypes | ForEach-Object { "- ``$($_.InputObject.Trim())``" }) -join "`n" })

## New Members
$(if ($newMembers.Count -eq 0) { "No new members added." } else { ($newMembers | Select-Object -First 50 | ForEach-Object { "- ``$($_.InputObject.Trim())``" }) -join "`n" })
$(if ($newMembers.Count -gt 50) { "`n... and $($newMembers.Count - 50) more" })

## Removed Types (Breaking Changes)
$(if ($removedTypes.Count -eq 0) { "✅ No types removed." } else { ($removedTypes | ForEach-Object { "- ⚠️ ``$($_.InputObject.Trim())``" }) -join "`n" })

## Removed Members (Breaking Changes)
$(if ($removedMembers.Count -eq 0) { "✅ No members removed." } else { ($removedMembers | Select-Object -First 50 | ForEach-Object { "- ⚠️ ``$($_.InputObject.Trim())``" }) -join "`n" })
$(if ($removedMembers.Count -gt 50) { "`n... and $($removedMembers.Count - 50) more" })

## Compatibility Assessment
$(if ($removedTypes.Count -eq 0 -and $removedMembers.Count -eq 0) {
    "✅ **BACKWARDS COMPATIBLE** - No breaking changes detected."
} else {
    "⚠️ **BREAKING CHANGES DETECTED** - Review required before approval."
})

"@

    if ($OutputReport) {
        Set-Content -Path $OutputReport -Value $report
        Write-Host "`nReport written to: $OutputReport" -ForegroundColor Green
    } else {
        Write-Host $report
    }

    # Return summary for programmatic use
    return @{
        Additions = $additions.Count
        Removals = $removals.Count
        NewTypes = $newTypes.Count
        NewMembers = $newMembers.Count
        RemovedTypes = $removedTypes.Count
        RemovedMembers = $removedMembers.Count
        IsBackwardsCompatible = ($removedTypes.Count -eq 0 -and $removedMembers.Count -eq 0)
    }
}
finally {
    Pop-Location
}
