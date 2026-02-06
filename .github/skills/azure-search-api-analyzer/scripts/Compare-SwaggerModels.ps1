<#
.SYNOPSIS
    Compares swagger definitions between API versions.

.DESCRIPTION
    This script provides detailed comparison of swagger model definitions
    between two commits, including property-level differences.

.PARAMETER PreviousCommit
    The commit SHA representing the previous API version.

.PARAMETER NewCommit
    The commit SHA representing the new API version. Defaults to HEAD.

.PARAMETER ApiVersion
    The API version folder to analyze.

.PARAMETER Track
    Whether this is a "preview" or "stable" API version.

.PARAMETER ModelName
    Specific model name to compare. If not specified, compares all models.

.PARAMETER SwaggerFile
    Specific swagger file to analyze. Defaults to searchservice.json.

.PARAMETER SpecsRepoRoot
    Path to the azure-rest-api-specs repository root.

.EXAMPLE
    .\Compare-SwaggerModels.ps1 -PreviousCommit "abc123" -ApiVersion "2025-11-01-preview" -ModelName "SearchIndex"

.EXAMPLE
    .\Compare-SwaggerModels.ps1 -PreviousCommit "abc123" -ApiVersion "2025-11-01-preview"
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
    [string]$ModelName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("searchindex.json", "searchservice.json", "knowledgebase.json")]
    [string]$SwaggerFile = "searchservice.json",

    [Parameter(Mandatory = $false)]
    [string]$SpecsRepoRoot
)

$ErrorActionPreference = "Stop"

# Determine repository root
if (-not $SpecsRepoRoot) {
    $possiblePaths = @(
        "c:\azure-rest-api-specs",
        (Join-Path (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName "..\azure-rest-api-specs")
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

$filePath = "specification/search/data-plane/Azure.Search/$Track/$ApiVersion/$SwaggerFile"

Write-Host "=== Swagger Model Comparison ===" -ForegroundColor Cyan
Write-Host "File: $SwaggerFile" -ForegroundColor Gray
Write-Host "Previous: $PreviousCommit" -ForegroundColor Gray
Write-Host "New: $NewCommit" -ForegroundColor Gray
if ($ModelName) { Write-Host "Model: $ModelName" -ForegroundColor Gray }
Write-Host ""

Push-Location $SpecsRepoRoot
try {
    # Get previous version
    $previousContent = git show "${PreviousCommit}:${filePath}" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get file from previous commit: $previousContent"
    }
    $previous = $previousContent | ConvertFrom-Json

    # Get new version
    if ($NewCommit -eq "HEAD") {
        $newFilePath = Join-Path $SpecsRepoRoot $filePath
        if (-not (Test-Path $newFilePath)) {
            throw "File not found: $newFilePath"
        }
        $new = Get-Content $newFilePath -Raw | ConvertFrom-Json
    } else {
        $newContent = git show "${NewCommit}:${filePath}" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get file from new commit: $newContent"
        }
        $new = $newContent | ConvertFrom-Json
    }

    # Get models to compare
    $modelsToCompare = @()
    if ($ModelName) {
        $modelsToCompare = @($ModelName)
    } else {
        # Get all common models
        $prevModels = $previous.definitions.PSObject.Properties.Name
        $newModels = $new.definitions.PSObject.Properties.Name
        $modelsToCompare = $prevModels | Where-Object { $_ -in $newModels }
    }

    foreach ($model in $modelsToCompare) {
        $prevModel = $previous.definitions.$model
        $newModel = $new.definitions.$model

        if (-not $prevModel -or -not $newModel) { continue }

        # Check for property changes
        $prevProps = @{}
        $newProps = @{}

        if ($prevModel.properties) {
            $prevModel.properties.PSObject.Properties | ForEach-Object {
                $prevProps[$_.Name] = $_.Value
            }
        }

        if ($newModel.properties) {
            $newModel.properties.PSObject.Properties | ForEach-Object {
                $newProps[$_.Name] = $_.Value
            }
        }

        $added = $newProps.Keys | Where-Object { $_ -notin $prevProps.Keys }
        $removed = $prevProps.Keys | Where-Object { $_ -notin $newProps.Keys }
        $common = $newProps.Keys | Where-Object { $_ -in $prevProps.Keys }

        if ($added.Count -eq 0 -and $removed.Count -eq 0) {
            if (-not $ModelName) { continue }  # Skip unchanged models in full comparison
        }

        Write-Host "Model: $model" -ForegroundColor Yellow
        Write-Host "  Description: $($newModel.description)" -ForegroundColor Gray

        if ($added.Count -gt 0) {
            Write-Host "  Added Properties:" -ForegroundColor Green
            foreach ($prop in $added) {
                $p = $newProps[$prop]
                $type = if ($p.'$ref') { $p.'$ref'.Split('/')[-1] } else { $p.type }
                $req = if ($prop -in $newModel.required) { "[required]" } else { "[optional]" }
                Write-Host "    + $prop ($type) $req" -ForegroundColor Green
                if ($p.description) {
                    Write-Host "      $($p.description)" -ForegroundColor DarkGray
                }
            }
        }

        if ($removed.Count -gt 0) {
            Write-Host "  Removed Properties:" -ForegroundColor Red
            foreach ($prop in $removed) {
                $p = $prevProps[$prop]
                $type = if ($p.'$ref') { $p.'$ref'.Split('/')[-1] } else { $p.type }
                Write-Host "    - $prop ($type)" -ForegroundColor Red
            }
        }

        # Check for type changes in common properties
        foreach ($prop in $common) {
            $prevP = $prevProps[$prop]
            $newP = $newProps[$prop]

            $prevType = if ($prevP.'$ref') { $prevP.'$ref' } else { $prevP.type }
            $newType = if ($newP.'$ref') { $newP.'$ref' } else { $newP.type }

            if ($prevType -ne $newType) {
                Write-Host "  Changed Property Type:" -ForegroundColor DarkYellow
                Write-Host "    ~ $prop : $prevType -> $newType" -ForegroundColor DarkYellow
            }

            # Check required changes
            $wasRequired = $prop -in $prevModel.required
            $isRequired = $prop -in $newModel.required

            if ($wasRequired -and -not $isRequired) {
                Write-Host "  Relaxed Constraint:" -ForegroundColor Blue
                Write-Host "    ~ $prop : required -> optional" -ForegroundColor Blue
            } elseif (-not $wasRequired -and $isRequired) {
                Write-Host "  Tightened Constraint (Breaking):" -ForegroundColor Red
                Write-Host "    ~ $prop : optional -> required" -ForegroundColor Red
            }
        }

        Write-Host ""
    }

    # Show new models not in previous
    if (-not $ModelName) {
        $newOnlyModels = $new.definitions.PSObject.Properties.Name |
            Where-Object { $_ -notin $previous.definitions.PSObject.Properties.Name }

        if ($newOnlyModels.Count -gt 0) {
            Write-Host "=== New Models (not in previous) ===" -ForegroundColor Green
            foreach ($model in $newOnlyModels) {
                $m = $new.definitions.$model
                Write-Host "  + $model" -ForegroundColor Green
                if ($m.description) {
                    Write-Host "    $($m.description)" -ForegroundColor DarkGray
                }
            }
            Write-Host ""
        }

        # Show removed models
        $removedModels = $previous.definitions.PSObject.Properties.Name |
            Where-Object { $_ -notin $new.definitions.PSObject.Properties.Name }

        if ($removedModels.Count -gt 0) {
            Write-Host "=== Removed Models (Breaking) ===" -ForegroundColor Red
            foreach ($model in $removedModels) {
                Write-Host "  - $model" -ForegroundColor Red
            }
            Write-Host ""
        }
    }
}
finally {
    Pop-Location
}
