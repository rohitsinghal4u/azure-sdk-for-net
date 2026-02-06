<#
.SYNOPSIS
    Generates a comprehensive API change summary report.

.DESCRIPTION
    This script takes the output from Analyze-ApiChanges.ps1 and generates
    a detailed markdown report suitable for passing to the SDK release skill.
    By default, outputs to the sdk-release skill's references folder for
    automatic consumption.

.PARAMETER Analysis
    The analysis object from Analyze-ApiChanges.ps1.

.PARAMETER PreviousCommit
    The previous commit SHA (used if Analysis not provided).

.PARAMETER NewCommit
    The new commit SHA (used if Analysis not provided).

.PARAMETER ApiVersion
    The API version (used if Analysis not provided).

.PARAMETER Track
    The track type (preview/stable).

.PARAMETER SpecsRepoRoot
    Path to azure-rest-api-specs repository.

.PARAMETER OutputPath
    Path to write the report. If not specified, outputs to the sdk-release
    skill's references folder as API-ANALYSIS-{ApiVersion}.md.

.PARAMETER SdkRepoRoot
    Path to azure-sdk-for-net repository. Used to locate the sdk-release
    skill's references folder.

.EXAMPLE
    $analysis = .\Analyze-ApiChanges.ps1 -PreviousCommit "abc123" -ApiVersion "2025-11-01-preview"
    .\Generate-ChangeSummary.ps1 -Analysis $analysis

.EXAMPLE
    .\Generate-ChangeSummary.ps1 -PreviousCommit "abc123" -ApiVersion "2025-11-01-preview" -OutputPath "change-summary.md"
#>
param(
    [Parameter(Mandatory = $false)]
    [hashtable]$Analysis,

    [Parameter(Mandatory = $false)]
    [string]$PreviousCommit,

    [Parameter(Mandatory = $false)]
    [string]$NewCommit = "HEAD",

    [Parameter(Mandatory = $false)]
    [string]$ApiVersion,

    [Parameter(Mandatory = $false)]
    [ValidateSet("preview", "stable")]
    [string]$Track = "preview",

    [Parameter(Mandatory = $false)]
    [string]$SpecsRepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$SdkRepoRoot
)

$ErrorActionPreference = "Stop"

# Determine SDK repo root for default output location
if (-not $SdkRepoRoot) {
    $possiblePaths = @(
        "c:\azure-sdk-for-net",
        (Join-Path (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName ""),
        (Join-Path $env:USERPROFILE "source\repos\azure-sdk-for-net")
    )
    
    foreach ($path in $possiblePaths) {
        if ((Test-Path $path) -and (Test-Path (Join-Path $path ".github\skills\azure-search-sdk-release"))) {
            $SdkRepoRoot = (Resolve-Path $path).Path
            break
        }
    }
}

# Run analysis if not provided
if (-not $Analysis) {
    if (-not $PreviousCommit -or -not $ApiVersion) {
        throw "Either -Analysis or both -PreviousCommit and -ApiVersion must be provided"
    }

    $analyzeScript = Join-Path $PSScriptRoot "Analyze-ApiChanges.ps1"
    $params = @{
        PreviousCommit = $PreviousCommit
        NewCommit = $NewCommit
        ApiVersion = $ApiVersion
        Track = $Track
    }
    if ($SpecsRepoRoot) { $params.SpecsRepoRoot = $SpecsRepoRoot }

    $Analysis = & $analyzeScript @params
}

# Determine output path if not specified
if (-not $OutputPath -and $SdkRepoRoot) {
    $sdkReleaseRefsPath = Join-Path $SdkRepoRoot ".github\skills\azure-search-sdk-release\references"
    
    # Create references directory if it doesn't exist
    if (-not (Test-Path $sdkReleaseRefsPath)) {
        New-Item -ItemType Directory -Path $sdkReleaseRefsPath -Force | Out-Null
    }
    
    # Generate filename based on API version
    $safeApiVersion = $Analysis.Metadata.ApiVersion -replace '[^a-zA-Z0-9\-]', '-'
    $OutputPath = Join-Path $sdkReleaseRefsPath "API-ANALYSIS-$safeApiVersion.md"
    
    Write-Host "Output will be written to: $OutputPath" -ForegroundColor Cyan
}

Write-Host "Generating change summary report..." -ForegroundColor Cyan

# Build the report
$report = @"
# Azure Search API Change Summary

## Metadata
- **Previous Commit**: ``$($Analysis.Metadata.PreviousCommit)``
- **New Commit**: ``$($Analysis.Metadata.NewCommit)``
- **API Version**: ``$($Analysis.Metadata.ApiVersion)``
- **Track**: ``$($Analysis.Metadata.Track)``
- **Analysis Date**: $($Analysis.Metadata.AnalysisDate)

## Summary Statistics

| Category | Count |
|----------|-------|
| New Operations | $($Analysis.Operations.Added.Count) |
| Removed Operations | $($Analysis.Operations.Removed.Count) |
| New Models | $($Analysis.Models.Added.Count) |
| Removed Models | $($Analysis.Models.Removed.Count) |
| New Properties | $($Analysis.Properties.Added.Count) |
| Removed Properties | $($Analysis.Properties.Removed.Count) |
| **Total New Features** | **$($Analysis.Summary.NewFeatures)** |
| **Total Breaking Changes** | **$($Analysis.Summary.BreakingChanges)** |

---

## New Operations

"@

if ($Analysis.Operations.Added.Count -eq 0) {
    $report += "No new operations added.`n`n"
} else {
    foreach ($op in $Analysis.Operations.Added) {
        $report += @"
### ``$($op.Operation)``
- **Operation ID**: $($op.OperationId)
- **Description**: $($op.Description)
- **File**: $($op.File)
- **SDK Method**: _To be determined based on client organization_

"@
    }
}

$report += @"
---

## Removed Operations (Breaking Changes)

"@

if ($Analysis.Operations.Removed.Count -eq 0) {
    $report += "✅ No operations removed.`n`n"
} else {
    $report += "⚠️ **These are breaking changes that require migration documentation.**`n`n"
    foreach ($op in $Analysis.Operations.Removed) {
        $report += "- ❌ ``$($op.Operation)`` ($($op.OperationId)) - File: $($op.File)`n"
    }
    $report += "`n"
}

$report += @"
---

## New Models

"@

if ($Analysis.Models.Added.Count -eq 0) {
    $report += "No new models added.`n`n"
} else {
    $nonEnumModels = $Analysis.Models.Added | Where-Object { -not $_.IsEnum }
    $enumModels = $Analysis.Models.Added | Where-Object { $_.IsEnum }

    if ($nonEnumModels.Count -gt 0) {
        $report += "### Classes/Types`n`n"
        foreach ($model in $nonEnumModels) {
            $report += @"
#### $($model.Name)
- **Description**: $($model.Description)
- **Properties**: $($model.Properties)
- **File**: $($model.File)
- **SDK Class**: ``Azure.Search.Documents.[Indexes.]Models.$($model.Name)``

"@
        }
    }

    if ($enumModels.Count -gt 0) {
        $report += "### Enums`n`n"
        foreach ($model in $enumModels) {
            $report += "- **$($model.Name)** - $($model.Description) (File: $($model.File))`n"
        }
        $report += "`n"
    }
}

$report += @"
---

## Removed Models (Breaking Changes)

"@

if ($Analysis.Models.Removed.Count -eq 0) {
    $report += "✅ No models removed.`n`n"
} else {
    $report += "⚠️ **These are breaking changes.**`n`n"
    foreach ($model in $Analysis.Models.Removed) {
        $report += "- ❌ ``$($model.Name)`` - File: $($model.File)`n"
    }
    $report += "`n"
}

$report += @"
---

## New Properties

"@

if ($Analysis.Properties.Added.Count -eq 0) {
    $report += "No new properties added.`n`n"
} else {
    # Group by model
    $byModel = $Analysis.Properties.Added | Group-Object -Property Model

    foreach ($group in $byModel) {
        $report += "### $($group.Name)`n`n"
        foreach ($prop in $group.Group) {
            $reqText = if ($prop.Required) { " (required)" } else { " (optional)" }
            $report += "- ``$($prop.Property)`` ($($prop.Type))$reqText - $($prop.Description)`n"
        }
        $report += "`n"
    }
}

$report += @"
---

## Removed Properties (Breaking Changes)

"@

if ($Analysis.Properties.Removed.Count -eq 0) {
    $report += "✅ No properties removed.`n`n"
} else {
    $report += "⚠️ **These are breaking changes.**`n`n"
    $byModel = $Analysis.Properties.Removed | Group-Object -Property Model

    foreach ($group in $byModel) {
        $report += "### $($group.Name)`n`n"
        foreach ($prop in $group.Group) {
            $report += "- ❌ ``$($prop.Property)```n"
        }
        $report += "`n"
    }
}

$report += @"
---

## Enum Value Changes

"@

if ($Analysis.Enums.ValuesAdded.Count -eq 0 -and $Analysis.Enums.ValuesRemoved.Count -eq 0) {
    $report += "No enum value changes.`n`n"
} else {
    if ($Analysis.Enums.ValuesAdded.Count -gt 0) {
        $report += "### Added Values`n`n"
        foreach ($enum in $Analysis.Enums.ValuesAdded) {
            $report += "- **$($enum.Enum)**: $($enum.Values -join ', ')`n"
        }
        $report += "`n"
    }

    if ($Analysis.Enums.ValuesRemoved.Count -gt 0) {
        $report += "### Removed Values (Breaking)`n`n"
        foreach ($enum in $Analysis.Enums.ValuesRemoved) {
            $report += "- ❌ **$($enum.Enum)**: $($enum.Values -join ', ')`n"
        }
        $report += "`n"
    }
}

$report += @"
---

## SDK Implementation Checklist

### autorest.md Updates
- [ ] Update input-file URLs to new commit: ``$($Analysis.Metadata.NewCommit)``
- [ ] Add rename directives for any model renames
- [ ] Add suppress-abstract-base-class for new abstract types
- [ ] Add x-accessibility: internal for internal types

### New Types to Generate
"@

foreach ($model in $Analysis.Models.Added) {
    $report += "- [ ] ``$($model.Name)``"
    if ($model.IsEnum) { $report += " (enum)" }
    $report += "`n"
}

$report += @"

### Customizations Needed
- [ ] Review CodeGenModel mappings for renamed types
- [ ] Add factory methods to SearchModelFactory
- [ ] Add extension methods for new operations
- [ ] Review namespace organization for new types

### Tests to Add/Update
"@

foreach ($op in $Analysis.Operations.Added) {
    $testName = $op.OperationId -replace '_', ''
    $report += "- [ ] Test for $testName`n"
}

$report += @"

### Documentation Updates
- [ ] Update CHANGELOG.md with new features
- [ ] Update CHANGELOG.md with breaking changes (if any)
- [ ] Add XML documentation for all new public types
- [ ] Update README.md if significant new features

---

## Suggested CHANGELOG Entry

``````markdown
## X.Y.Z (Unreleased)

### Features Added
- Added support for ``$($Analysis.Metadata.ApiVersion)`` service version.
"@

foreach ($model in ($Analysis.Models.Added | Where-Object { -not $_.IsEnum } | Select-Object -First 5)) {
    $report += "- Added ``$($model.Name)`` for $($model.Description -replace '\.$', '').`n"
}

if ($Analysis.Properties.Added.Count -gt 0) {
    $propGroups = $Analysis.Properties.Added | Group-Object -Property Model | Select-Object -First 3
    foreach ($group in $propGroups) {
        $props = $group.Group.Property -join '``, ``'
        $report += "- Added ``$props`` to ``$($group.Name)``.`n"
    }
}

$report += @"

### Breaking Changes
"@

if ($Analysis.Summary.BreakingChanges -eq 0) {
    $report += "_No breaking changes._`n"
} else {
    foreach ($model in $Analysis.Models.Removed) {
        $report += "- Removed ``$($model.Name)``.`n"
    }
    foreach ($op in $Analysis.Operations.Removed) {
        $report += "- Removed operation ``$($op.OperationId)``.`n"
    }
    foreach ($prop in $Analysis.Properties.Removed) {
        $report += "- Removed ``$($prop.Model).$($prop.Property)``.`n"
    }
}

$report += @"
``````

---

## Handoff to SDK Release Skill

This analysis is ready to be passed to the **azure-search-sdk-release** skill with the following context:

1. **Commit Information**:
   - Previous: ``$($Analysis.Metadata.PreviousCommit)``
   - New: ``$($Analysis.Metadata.NewCommit)``
   - API Version: ``$($Analysis.Metadata.ApiVersion)``

2. **Priority Items**:
   - Breaking changes: $($Analysis.Summary.BreakingChanges)
   - New features: $($Analysis.Summary.NewFeatures)

3. **Next Steps**:
   - Run azure-search-sdk-release skill
   - Pass this document as context
   - Follow SDK generation workflow
"@

# Output or save report
if ($OutputPath) {
    Set-Content -Path $OutputPath -Value $report
    Write-Host "Report written to: $OutputPath" -ForegroundColor Green
} else {
    Write-Host $report
}

# Return the report content
return $report
