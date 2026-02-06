<#
.SYNOPSIS
    Updates the autorest.md file with new swagger URLs for a given API version.

.DESCRIPTION
    This script updates the input-file section in autorest.md to point to new swagger files
    from the azure-rest-api-specs repository for a specified API version and commit.

.PARAMETER ApiVersion
    The API version string (e.g., "2025-11-01-preview")

.PARAMETER CommitSha
    The full commit SHA from the azure-rest-api-specs repository

.PARAMETER VersionType
    Whether this is a "preview" or "stable" API version. Defaults to "preview".

.PARAMETER SdkRepoRoot
    Path to the azure-sdk-for-net repository root. Defaults to the script's great-great-grandparent directory.

.EXAMPLE
    .\Update-AutorestMd.ps1 -ApiVersion "2025-11-01-preview" -CommitSha "abc123def456..."

.EXAMPLE
    .\Update-AutorestMd.ps1 -ApiVersion "2025-09-01" -CommitSha "abc123..." -VersionType "stable"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiVersion,

    [Parameter(Mandatory = $true)]
    [string]$CommitSha,

    [Parameter(Mandatory = $false)]
    [ValidateSet("preview", "stable")]
    [string]$VersionType = "preview",

    [Parameter(Mandatory = $false)]
    [string]$SdkRepoRoot
)

$ErrorActionPreference = "Stop"

# Determine repository root
if (-not $SdkRepoRoot) {
    $SdkRepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.Parent.FullName
}

$autorestPath = Join-Path $SdkRepoRoot "sdk/search/Azure.Search.Documents/src/autorest.md"

if (-not (Test-Path $autorestPath)) {
    throw "Cannot find autorest.md at: $autorestPath"
}

Write-Host "Updating autorest.md with API version: $ApiVersion" -ForegroundColor Cyan
Write-Host "Commit SHA: $CommitSha" -ForegroundColor Cyan
Write-Host "Version type: $VersionType" -ForegroundColor Cyan

# Read the current file
$content = Get-Content $autorestPath -Raw

# Build the new swagger URLs
$baseUrl = "https://github.com/Azure/azure-rest-api-specs/blob/$CommitSha/specification/search/data-plane/Azure.Search/$VersionType/$ApiVersion"
$searchIndexUrl = "$baseUrl/searchindex.json"
$searchServiceUrl = "$baseUrl/searchservice.json"
$knowledgeBaseUrl = "$baseUrl/knowledgebase.json"

# Pattern to match the input-file section
$pattern = '(?s)(input-file:\s*\n)(.*?)(\ngeneration1-convenience-client)'

# Build replacement
$replacement = @"
input-file:
 - $searchIndexUrl
 - $searchServiceUrl
 - $knowledgeBaseUrl
generation1-convenience-client
"@

if ($content -match $pattern) {
    $newContent = $content -replace $pattern, $replacement
    Set-Content $autorestPath -Value $newContent -NoNewline
    Write-Host "`nSuccessfully updated autorest.md!" -ForegroundColor Green
    Write-Host "`nNew swagger URLs:" -ForegroundColor Yellow
    Write-Host "  - $searchIndexUrl"
    Write-Host "  - $searchServiceUrl"
    Write-Host "  - $knowledgeBaseUrl"
} else {
    throw "Could not find input-file section in autorest.md. The file format may have changed."
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Update ServiceVersion enum in SearchClientOptions.cs"
Write-Host "2. Run: cd sdk/search/Azure.Search.Documents/src && dotnet build /t:GenerateCode"
Write-Host "3. Build and fix any errors: dotnet build"
Write-Host "4. Run tests: dotnet test --filter TestCategory!=Live"
