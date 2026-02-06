<#
.SYNOPSIS
    Generates SDK code from the swagger files defined in autorest.md.

.DESCRIPTION
    This script runs the code generation process for the Azure.Search.Documents SDK.
    It navigates to the src directory and runs `dotnet build /t:GenerateCode`.

.PARAMETER SdkRepoRoot
    Path to the azure-sdk-for-net repository root. Defaults to the script's great-great-grandparent directory.

.EXAMPLE
    .\Generate-SdkCode.ps1

.EXAMPLE
    .\Generate-SdkCode.ps1 -SdkRepoRoot "C:\repos\azure-sdk-for-net"
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$SdkRepoRoot
)

$ErrorActionPreference = "Stop"

# Determine repository root
if (-not $SdkRepoRoot) {
    $SdkRepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
}

$srcPath = Join-Path $SdkRepoRoot "sdk/search/Azure.Search.Documents/src"

if (-not (Test-Path $srcPath)) {
    throw "Cannot find src directory at: $srcPath"
}

Write-Host "Generating SDK code from swagger files..." -ForegroundColor Cyan
Write-Host "Source path: $srcPath" -ForegroundColor Gray

Push-Location $srcPath
try {
    Write-Host "`nRunning: dotnet build /t:GenerateCode" -ForegroundColor Yellow
    & dotnet build /t:GenerateCode

    if ($LASTEXITCODE -ne 0) {
        throw "Code generation failed with exit code: $LASTEXITCODE"
    }

    Write-Host "`nCode generation completed successfully!" -ForegroundColor Green

    # Show what was generated
    $generatedPath = Join-Path $srcPath "Generated"
    if (Test-Path $generatedPath) {
        $files = Get-ChildItem $generatedPath -Recurse -File | Measure-Object
        Write-Host "`nGenerated files: $($files.Count) files in Generated/ folder" -ForegroundColor Cyan
    }

    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Build the project: dotnet build"
    Write-Host "2. Fix any compilation errors"
    Write-Host "3. Run tests: dotnet test --filter TestCategory!=Live"
}
finally {
    Pop-Location
}
