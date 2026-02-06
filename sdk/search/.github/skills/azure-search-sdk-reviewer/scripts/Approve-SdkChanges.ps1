<#
.SYNOPSIS
    Approves SDK changes and prepares for GitHub PR submission.

.DESCRIPTION
    This script performs final validation before approving SDK changes for PR submission.
    It verifies all review checks pass and generates an approval summary.

.PARAMETER ReviewReportPath
    Path to a previous review report to validate. If not provided, runs a new review.

.PARAMETER PreviousCommit
    The commit SHA for API comparison (required if no ReviewReportPath).

.PARAMETER SdkRepoRoot
    Path to the azure-sdk-for-net repository root.

.PARAMETER Force
    Force approval even with warnings (not recommended for stable track).

.EXAMPLE
    .\Approve-SdkChanges.ps1 -PreviousCommit "abc123"

.EXAMPLE
    .\Approve-SdkChanges.ps1 -ReviewReportPath "./REVIEW-REPORT.md" -Force
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$ReviewReportPath,

    [Parameter(Mandatory = $false)]
    [string]$PreviousCommit,

    [Parameter(Mandatory = $false)]
    [string]$SdkRepoRoot,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Determine repository root
if (-not $SdkRepoRoot) {
    $SdkRepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
}

$searchSdkPath = Join-Path $SdkRepoRoot "sdk/search/Azure.Search.Documents"

Write-Host "=== Azure.Search.Documents SDK Approval ===" -ForegroundColor Cyan
Write-Host ""

# Run or load review
$reviewResult = $null

if ($ReviewReportPath -and (Test-Path $ReviewReportPath)) {
    Write-Host "Loading existing review report..." -ForegroundColor Yellow
    # Parse the review report (simplified - checks for key indicators)
    $reportContent = Get-Content $ReviewReportPath -Raw

    if ($reportContent -match "Overall Status:\s*\*\*(\w+)\*\*") {
        $status = $Matches[1]
    } elseif ($reportContent -match "Overall Status:\s*(\w+)") {
        $status = $Matches[1]
    } else {
        $status = "UNKNOWN"
    }

    $reviewResult = @{
        OverallStatus = $status
        FromReport = $true
    }
} elseif ($PreviousCommit) {
    Write-Host "Running new review..." -ForegroundColor Yellow
    $reviewScript = Join-Path $PSScriptRoot "Review-SdkChanges.ps1"
    $reviewResult = & $reviewScript -PreviousCommit $PreviousCommit -SdkRepoRoot $SdkRepoRoot
} else {
    throw "Either -ReviewReportPath or -PreviousCommit must be provided"
}

# Determine if we can approve
$canApprove = $false
$approvalStatus = "REJECTED"
$approvalMessage = ""

switch ($reviewResult.OverallStatus) {
    "PASS" {
        $canApprove = $true
        $approvalStatus = "APPROVED"
        $approvalMessage = "All checks passed. SDK is ready for PR submission."
    }
    "WARN" {
        if ($Force) {
            $canApprove = $true
            $approvalStatus = "APPROVED_WITH_WARNINGS"
            $approvalMessage = "Approved with warnings (forced). Review warnings before merging."
        } else {
            $canApprove = $false
            $approvalStatus = "NEEDS_REVIEW"
            $approvalMessage = "Warnings detected. Use -Force to approve anyway, or address warnings first."
        }
    }
    "FAIL" {
        $canApprove = $false
        $approvalStatus = "REJECTED"
        $approvalMessage = "Critical issues detected. Cannot approve until issues are resolved."
    }
    default {
        $canApprove = $false
        $approvalStatus = "UNKNOWN"
        $approvalMessage = "Could not determine review status."
    }
}

# Display result
Write-Host ""
$color = switch ($approvalStatus) {
    "APPROVED" { "Green" }
    "APPROVED_WITH_WARNINGS" { "Yellow" }
    "NEEDS_REVIEW" { "Yellow" }
    "REJECTED" { "Red" }
    default { "White" }
}

$icon = switch ($approvalStatus) {
    "APPROVED" { "✅" }
    "APPROVED_WITH_WARNINGS" { "⚠️" }
    "NEEDS_REVIEW" { "🔍" }
    "REJECTED" { "❌" }
    default { "❓" }
}

Write-Host "$icon Approval Status: $approvalStatus" -ForegroundColor $color
Write-Host $approvalMessage
Write-Host ""

if ($canApprove) {
    # Generate approval summary
    $approvalSummary = @"
# SDK Approval Summary

**Package**: Azure.Search.Documents
**Approved At**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
**Approval Status**: $approvalStatus

## Pre-PR Checklist

Before creating the PR, verify:
- [ ] All changes are committed to the feature branch
- [ ] Branch is up to date with main
- [ ] No merge conflicts exist

## PR Creation Steps

1. Push your branch to origin:
   ``````powershell
   git push origin <branch-name>
   ``````

2. Create the PR via GitHub CLI:
   ``````powershell
   gh pr create --title "Azure.Search.Documents: Update to API version XXXX-XX-XX" --body-file CHANGELOG.md
   ``````

3. Or create via GitHub web UI:
   - Navigate to: https://github.com/Azure/azure-sdk-for-net/compare
   - Select your branch
   - Fill in PR details

## PR Description Template

``````markdown
## Description

This PR updates Azure.Search.Documents to support the XXXX-XX-XX API version.

## Changes

- Updated swagger references to new API version
- Added support for new features: [list features]
- Updated CHANGELOG.md

## Testing

- [x] Unit tests pass
- [x] API compatibility verified
- [ ] Live tests verified (if applicable)

## Related

- API Spec PR: [link if applicable]
- Release Plan: [link if applicable]
``````

## Approval Signature

Approved for PR submission by automated review.
Review Status: $($reviewResult.OverallStatus)
"@

    $summaryPath = Join-Path $searchSdkPath "APPROVAL-SUMMARY.md"
    Set-Content -Path $summaryPath -Value $approvalSummary
    Write-Host "Approval summary written to: $summaryPath" -ForegroundColor Green

    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Review the approval summary"
    Write-Host "2. Commit any final changes"
    Write-Host "3. Push branch and create PR"
    Write-Host "4. Request code review from team members"
} else {
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Address the issues identified in the review"
    Write-Host "2. Run the review again"
    Write-Host "3. Once all checks pass, run approval again"
}

# Return result for programmatic use
return @{
    CanApprove = $canApprove
    ApprovalStatus = $approvalStatus
    Message = $approvalMessage
}
