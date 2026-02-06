<#
.SYNOPSIS
    Analyzes API changes between two commits in azure-rest-api-specs.

.DESCRIPTION
    This script compares swagger specifications between two commits to identify
    API changes including new operations, models, properties, and breaking changes.

.PARAMETER PreviousCommit
    The commit SHA representing the previous API version.

.PARAMETER NewCommit
    The commit SHA representing the new API version. Defaults to HEAD.

.PARAMETER ApiVersion
    The API version folder to analyze (e.g., "2025-11-01-preview").

.PARAMETER Track
    Whether this is a "preview" or "stable" API version.

.PARAMETER SpecsRepoRoot
    Path to the azure-rest-api-specs repository root.

.PARAMETER OutputPath
    Path to write the analysis report. If not specified, outputs to console.

.EXAMPLE
    .\Analyze-ApiChanges.ps1 -PreviousCommit "abc123" -ApiVersion "2025-11-01-preview"

.EXAMPLE
    .\Analyze-ApiChanges.ps1 -PreviousCommit "abc123" -NewCommit "def456" -ApiVersion "2025-11-01-preview" -OutputPath "api-analysis.md"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$PreviousCommit,

    [Parameter(Mandatory = $false)]
    [string]$NewCommit = "HEAD",

    [Parameter(Mandatory = $true)]
    [string]$ApiVersion,

    [Parameter(Mandatory = $false)]
    [ValidateSet("preview", "stable")]
    [string]$Track = "preview",

    [Parameter(Mandatory = $false)]
    [string]$SpecsRepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

# Determine repository root
if (-not $SpecsRepoRoot) {
    # Try to find azure-rest-api-specs in common locations
    $possiblePaths = @(
        "c:\azure-rest-api-specs",
        (Join-Path (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName "..\azure-rest-api-specs"),
        (Join-Path $env:USERPROFILE "source\repos\azure-rest-api-specs")
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $SpecsRepoRoot = (Resolve-Path $path).Path
            break
        }
    }

    if (-not $SpecsRepoRoot) {
        throw "Cannot find azure-rest-api-specs repository. Please specify -SpecsRepoRoot."
    }
}

$basePath = "specification/search/data-plane/Azure.Search/$Track/$ApiVersion"
$swaggerFiles = @("searchindex.json", "searchservice.json", "knowledgebase.json")

Write-Host "=== Azure Search API Change Analysis ===" -ForegroundColor Cyan
Write-Host "Previous Commit: $PreviousCommit" -ForegroundColor Gray
Write-Host "New Commit: $NewCommit" -ForegroundColor Gray
Write-Host "API Version: $ApiVersion" -ForegroundColor Gray
Write-Host "Track: $Track" -ForegroundColor Gray
Write-Host ""

# Results collection
$analysis = @{
    Metadata = @{
        PreviousCommit = $PreviousCommit
        NewCommit = $NewCommit
        ApiVersion = $ApiVersion
        Track = $Track
        AnalysisDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    Operations = @{
        Added = @()
        Removed = @()
        Modified = @()
    }
    Models = @{
        Added = @()
        Removed = @()
        Modified = @()
    }
    Properties = @{
        Added = @()
        Removed = @()
    }
    Enums = @{
        Added = @()
        Removed = @()
        ValuesAdded = @()
        ValuesRemoved = @()
    }
    Summary = @{
        TotalChanges = 0
        BreakingChanges = 0
        NewFeatures = 0
    }
}

Push-Location $SpecsRepoRoot
try {
    foreach ($swaggerFile in $swaggerFiles) {
        $filePath = "$basePath/$swaggerFile"

        Write-Host "Analyzing: $swaggerFile" -ForegroundColor Yellow

        # Get previous version
        $previousContent = git show "${PreviousCommit}:${filePath}" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Skipping (not found in previous commit)" -ForegroundColor Gray
            continue
        }
        $previous = $previousContent | ConvertFrom-Json

        # Get new version
        if ($NewCommit -eq "HEAD") {
            $newFilePath = Join-Path $SpecsRepoRoot $filePath
            if (-not (Test-Path $newFilePath)) {
                Write-Host "  Skipping (not found in current)" -ForegroundColor Gray
                continue
            }
            $new = Get-Content $newFilePath -Raw | ConvertFrom-Json
        } else {
            $newContent = git show "${NewCommit}:${filePath}" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  Skipping (not found in new commit)" -ForegroundColor Gray
                continue
            }
            $new = $newContent | ConvertFrom-Json
        }

        # Compare Operations (Paths)
        Write-Host "  Comparing operations..." -ForegroundColor Gray
        $prevPaths = @{}
        $previous.paths.PSObject.Properties | ForEach-Object {
            $path = $_.Name
            $_.Value.PSObject.Properties |
                Where-Object { $_.Name -match '^(get|post|put|delete|patch)$' } |
                ForEach-Object {
                    $key = "$($_.Name.ToUpper()) $path"
                    $prevPaths[$key] = @{
                        OperationId = $_.Value.operationId
                        Description = $_.Value.description
                        Parameters = $_.Value.parameters
                    }
                }
        }

        $newPaths = @{}
        $new.paths.PSObject.Properties | ForEach-Object {
            $path = $_.Name
            $_.Value.PSObject.Properties |
                Where-Object { $_.Name -match '^(get|post|put|delete|patch)$' } |
                ForEach-Object {
                    $key = "$($_.Name.ToUpper()) $path"
                    $newPaths[$key] = @{
                        OperationId = $_.Value.operationId
                        Description = $_.Value.description
                        Parameters = $_.Value.parameters
                    }
                }
        }

        # Find added operations
        $newPaths.Keys | Where-Object { $_ -notin $prevPaths.Keys } | ForEach-Object {
            $analysis.Operations.Added += @{
                Operation = $_
                OperationId = $newPaths[$_].OperationId
                Description = $newPaths[$_].Description
                File = $swaggerFile
            }
        }

        # Find removed operations
        $prevPaths.Keys | Where-Object { $_ -notin $newPaths.Keys } | ForEach-Object {
            $analysis.Operations.Removed += @{
                Operation = $_
                OperationId = $prevPaths[$_].OperationId
                File = $swaggerFile
            }
        }

        # Compare Definitions (Models)
        Write-Host "  Comparing models..." -ForegroundColor Gray
        $prevDefs = @{}
        if ($previous.definitions) {
            $previous.definitions.PSObject.Properties | ForEach-Object {
                $prevDefs[$_.Name] = $_. Value
            }
        }

        $newDefs = @{}
        if ($new.definitions) {
            $new.definitions.PSObject.Properties | ForEach-Object {
                $newDefs[$_.Name] = $_.Value
            }
        }

        # Find added models
        $newDefs.Keys | Where-Object { $_ -notin $prevDefs.Keys } | ForEach-Object {
            $model = $newDefs[$_]
            $props = if ($model.properties) {
                $model.properties.PSObject.Properties.Name -join ", "
            } else { "" }

            $analysis.Models.Added += @{
                Name = $_
                Description = $model.description
                Properties = $props
                File = $swaggerFile
                IsEnum = $null -ne $model.enum
            }
        }

        # Find removed models
        $prevDefs.Keys | Where-Object { $_ -notin $newDefs.Keys } | ForEach-Object {
            $analysis.Models.Removed += @{
                Name = $_
                File = $swaggerFile
            }
        }

        # Compare properties of common models
        $prevDefs.Keys | Where-Object { $_ -in $newDefs.Keys } | ForEach-Object {
            $modelName = $_
            $prevModel = $prevDefs[$modelName]
            $newModel = $newDefs[$modelName]

            if ($prevModel.properties -and $newModel.properties) {
                $prevProps = $prevModel.properties.PSObject.Properties.Name
                $newProps = $newModel.properties.PSObject.Properties.Name

                # Added properties
                $newProps | Where-Object { $_ -notin $prevProps } | ForEach-Object {
                    $prop = $newModel.properties.$_
                    $analysis.Properties.Added += @{
                        Model = $modelName
                        Property = $_
                        Type = if ($prop.'$ref') { $prop.'$ref'.Split('/')[-1] } else { $prop.type }
                        Description = $prop.description
                        Required = $_ -in $newModel.required
                        File = $swaggerFile
                    }
                }

                # Removed properties
                $prevProps | Where-Object { $_ -notin $newProps } | ForEach-Object {
                    $analysis.Properties.Removed += @{
                        Model = $modelName
                        Property = $_
                        File = $swaggerFile
                    }
                }
            }

            # Compare enum values
            if ($prevModel.enum -and $newModel.enum) {
                $addedValues = $newModel.enum | Where-Object { $_ -notin $prevModel.enum }
                $removedValues = $prevModel.enum | Where-Object { $_ -notin $newModel.enum }

                if ($addedValues) {
                    $analysis.Enums.ValuesAdded += @{
                        Enum = $modelName
                        Values = $addedValues
                        File = $swaggerFile
                    }
                }
                if ($removedValues) {
                    $analysis.Enums.ValuesRemoved += @{
                        Enum = $modelName
                        Values = $removedValues
                        File = $swaggerFile
                    }
                }
            }
        }
    }

    # Calculate summary
    $analysis.Summary.NewFeatures = $analysis.Operations.Added.Count + $analysis.Models.Added.Count + $analysis.Properties.Added.Count
    $analysis.Summary.BreakingChanges = $analysis.Operations.Removed.Count + $analysis.Models.Removed.Count + $analysis.Properties.Removed.Count + $analysis.Enums.ValuesRemoved.Count
    $analysis.Summary.TotalChanges = $analysis.Summary.NewFeatures + $analysis.Summary.BreakingChanges

    # Generate report
    Write-Host ""
    Write-Host "=== Analysis Complete ===" -ForegroundColor Cyan
    Write-Host "New Features: $($analysis.Summary.NewFeatures)" -ForegroundColor Green
    Write-Host "Breaking Changes: $($analysis.Summary.BreakingChanges)" -ForegroundColor $(if ($analysis.Summary.BreakingChanges -gt 0) { "Red" } else { "Green" })

    # Return the analysis object
    return $analysis
}
finally {
    Pop-Location
}
