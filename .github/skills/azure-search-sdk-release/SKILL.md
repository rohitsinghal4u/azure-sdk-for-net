---
name: azure-search-sdk-release
description: Generates the Azure.Search.Documents SDK with a new API version from a commit in azure-rest-api-specs. Updates autorest.md with new swagger URLs, regenerates code, adds customizations, fixes build errors, and runs tests to ensure endpoints pass. Use when updating the Search SDK to a new Azure Search API version or when regenerating the SDK from updated swagger specifications.
metadata:
  author: azure-sdk
  version: "1.0"
  service: search
---

# Azure Search SDK Release Skill

This skill helps generate the Azure.Search.Documents SDK with a new API version, add customizations, fix build errors, and run tests.

## Prerequisites

Before starting, ensure you have:
- Visual Studio 2022 (Community or higher) with .NET desktop development workload
- .NET 9.0.306 SDK or higher (within the 9.0.* band)
- Git installed
- PowerShell 7 or higher
- NodeJS 22.x.x (for code generation)
- Both `azure-sdk-for-net` and `azure-rest-api-specs` repositories cloned locally

## Workflow Overview

0. **Read API Analysis** from the azure-search-api-analyzer skill (if available)
1. **Identify the new API version** from a commit in azure-rest-api-specs
2. **Update autorest.md** with new swagger file URLs
3. **Update ServiceVersion enum** in SearchClientOptions.cs
4. **Regenerate the SDK code**
5. **Review and fix build errors** using API analysis context
6. **Add customizations** for new models/operations based on API changes
7. **Update CHANGELOG.md** using the suggested entry from API analysis
8. **Run tests** to validate the changes

---

## Step 0: Read API Analysis (Recommended)

### Goal
Retrieve and understand the API change analysis from the `azure-search-api-analyzer` skill before starting SDK implementation.

### Why This Step Matters
The API analyzer provides crucial context about:
- New operations and their expected SDK methods
- New models and properties to be generated
- Breaking changes that need careful handling
- Suggested CHANGELOG entries
- SDK implementation checklist

### Actions

1. **Check for existing analysis in references folder**:
   The API analyzer automatically outputs analysis files to this skill's references folder:
   ```powershell
   # List available API analysis files
   $refsPath = ".github\skills\azure-search-sdk-release\references"
   Get-ChildItem -Path $refsPath -Filter "API-ANALYSIS-*.md" | 
       Sort-Object LastWriteTime -Descending
   ```

2. **Read the analysis for the target API version**:
   ```powershell
   # Read the most recent analysis
   $latestAnalysis = Get-ChildItem -Path $refsPath -Filter "API-ANALYSIS-*.md" | 
       Sort-Object LastWriteTime -Descending | 
       Select-Object -First 1
   
   if ($latestAnalysis) {
       Write-Host "Found analysis: $($latestAnalysis.Name)" -ForegroundColor Green
       Get-Content $latestAnalysis.FullName
   }
   
   # Or read a specific API version's analysis
   $apiVersion = "2025-11-01-preview"
   $analysisFile = Join-Path $refsPath "API-ANALYSIS-$($apiVersion -replace '[^a-zA-Z0-9\-]', '-').md"
   if (Test-Path $analysisFile) {
       Get-Content $analysisFile
   }
   ```

3. **Run the API analyzer if no analysis exists**:
   If no analysis file is found for your target API version:
   ```powershell
   # From azure-sdk-for-net repository root
   $analyzerScript = ".github\skills\azure-search-api-analyzer\scripts\Generate-ChangeSummary.ps1"
   
   & $analyzerScript `
       -PreviousCommit "<previous-commit-sha>" `
       -ApiVersion "<new-api-version>" `
       -SpecsRepoRoot "c:\azure-rest-api-specs"
   
   # The output will be saved to: references/API-ANALYSIS-{api-version}.md
   ```

4. **Extract key information from the analysis**:
   - **New Operations**: List of new API endpoints → will become new SDK methods
   - **New Models**: Types to be generated → may need customizations
   - **New Properties**: Added to existing models → verify generation
   - **Breaking Changes**: Removed items → need migration notes
   - **Suggested CHANGELOG**: Pre-written changelog entry to adapt

### API Analysis Files Location

Analysis files are stored in:
```
.github/skills/azure-search-sdk-release/references/
├── API-ANALYSIS-2025-11-01-preview.md   # Latest analysis
├── API-ANALYSIS-2025-05-01-preview.md   # Previous version
└── ...
```

### API Analysis Context Format

The analysis provides a structured summary:

```markdown
## Summary Statistics
| Category | Count |
|----------|-------|
| New Operations | X |
| New Models | Y |
| Breaking Changes | Z |

## SDK Implementation Checklist
- [ ] Update input-file URLs to new commit
- [ ] Add rename directives for model renames
- [ ] Add factory methods to SearchModelFactory
...
```

### Using Analysis Throughout Workflow

| Workflow Step | How Analysis Helps |
|---------------|--------------------|
| Step 2 (autorest.md) | Commit SHA and directives needed |
| Step 5 (Build Errors) | Know which new models to expect |
| Step 6 (Customizations) | Prioritize based on new features |
| Step 7 (CHANGELOG) | Use suggested entry as starting point |

### If No Analysis Available

If the API analyzer was not run, you can still proceed but will need to:
1. Manually compare swagger files between commits
2. Identify new operations/models during code generation
3. Write CHANGELOG entries from scratch

---

## Step 1: Identify the New API Version

### Goal
Locate the swagger files for the new API version in the azure-rest-api-specs repository.

### Actions

1. Navigate to the azure-rest-api-specs repository
2. Find the swagger files at:
   - `specification/search/data-plane/Azure.Search/preview/{api-version}/` (for preview versions)
   - `specification/search/data-plane/Azure.Search/stable/{api-version}/` (for stable versions)
3. The swagger files are typically:
   - `searchindex.json` - Document operations (search, autocomplete, suggest)
   - `searchservice.json` - Index/Indexer/Skillset management
   - `knowledgebase.json` - Knowledge base operations (if applicable)

### Expected Input
- **Commit SHA or branch**: The commit in azure-rest-api-specs containing the new swagger files
- **API Version**: The new API version string (e.g., `2025-11-01-preview`)

### Example
```bash
# Check the swagger files for a specific API version
ls specification/search/data-plane/Azure.Search/preview/2025-11-01-preview/
```

---

## Step 2: Update autorest.md

### Goal
Update the autorest.md file with the new swagger file URLs.

### Location
`sdk/search/Azure.Search.Documents/src/autorest.md`

### Actions

1. Open the autorest.md file
2. Locate the `input-file` section under "Swagger Source(s)"
3. Update the URLs to point to the new swagger files

### Current Format
```yaml
input-file:
 - https://github.com/Azure/azure-rest-api-specs/blob/{COMMIT_SHA}/specification/search/data-plane/Azure.Search/preview/{API_VERSION}/searchindex.json
 - https://github.com/Azure/azure-rest-api-specs/blob/{COMMIT_SHA}/specification/search/data-plane/Azure.Search/preview/{API_VERSION}/searchservice.json
 - https://github.com/Azure/azure-rest-api-specs/blob/{COMMIT_SHA}/specification/search/data-plane/Azure.Search/preview/{API_VERSION}/knowledgebase.json
```

### Example Update
Replace the commit SHA and API version in all three URLs. Use the full commit SHA from the azure-rest-api-specs repository.

---

## Step 3: Update ServiceVersion Enum

### Goal
Add the new API version to the ServiceVersion enum.

### Location
`sdk/search/Azure.Search.Documents/src/SearchClientOptions.cs`

### Actions

1. Add a new enum value for the API version in the `ServiceVersion` enum
2. Follow the naming convention: `V{YEAR}_{MONTH}_{DAY}` or `V{YEAR}_{MONTH}_{DAY}_Preview`
3. Increment the enum value number
4. Update `LatestVersion` constant if this is the newest version

### Example
```csharp
public enum ServiceVersion
{
    // ... existing versions ...

    /// <summary>
    /// The 2025-11-01-preview version of the Azure Cognitive Search service.
    /// </summary>
    V2025_11_01_Preview = 5,
}

// Update LatestVersion if needed
internal const ServiceVersion LatestVersion = ServiceVersion.V2025_11_01_Preview;
```

---

## Step 4: Regenerate SDK Code

### Goal
Regenerate the SDK code from the updated swagger files.

### Actions

1. Navigate to the src directory:
   ```powershell
   cd sdk/search/Azure.Search.Documents/src
   ```

2. Run the code generation:
   ```powershell
   dotnet build /t:GenerateCode
   ```

3. Review the generated files in the `Generated/` folder

### Important Notes
- Do NOT edit files in the `Generated/` folder directly
- All customizations should be done in separate partial class files
- The generator uses AutoRest with customizations defined in autorest.md

---

## Step 5: Build and Fix Errors

### Goal
Build the SDK and fix any compilation errors, using API analysis context to anticipate issues.

### Actions

1. **Review expected changes from API analysis** (if available):
   - Check the "New Models" section for types that will be generated
   - Check the "New Properties" section for additions to existing models
   - Note any breaking changes that may affect compilation

2. Build the SDK:
   ```powershell
   cd sdk/search/Azure.Search.Documents
   dotnet build
   ```

3. Common issues and fixes:

#### Missing Model Customizations
If a new model needs customization, create a partial class:
```csharp
// In src/Models/ or src/Indexes/Models/
namespace Azure.Search.Documents.Models
{
    public partial class NewModelName
    {
        // Add custom properties or methods
    }
}
```

#### CodeGenModel Mapping
If a generated model needs to be hidden and replaced:
```csharp
// Hide the generated model
[CodeGenModel("GeneratedModelName")]
internal partial class GeneratedModelName { }

// Create the public replacement
public class CustomModelName<T>
{
    // Custom implementation
}
```

#### Suppressing Abstract Base Classes
Add to autorest.md if needed:
```yaml
suppress-abstract-base-class:
- NewAbstractModelName
```

---

## Step 6: Add Customizations

### Goal
Add necessary customizations for new features, prioritizing based on API analysis.

### Using API Analysis for Customization Priorities

If you have API analysis available, use it to guide customizations:

1. **New Operations** → May need extension methods or client method wrappers
2. **New Models** → Check if any need:
   - Rename directives (if names are awkward)
   - Internal accessibility (for implementation details)
   - Partial class customizations (for additional methods)
3. **New Enums** → Add to appropriate namespace
4. **Breaking Changes** → Document in ApiCompatBaseline.txt if intentional

### Common Customization Patterns

#### 1. Rename Models (in autorest.md)
```yaml
directive:
- from: "searchservice.json"
  where: $.definitions.OldName
  transform: $["x-ms-client-name"] = "NewName";
```

#### 2. Make Types Internal (in autorest.md)
```yaml
directive:
- from: searchservice.json
  where: $.definitions.InternalTypeName
  transform: $["x-accessibility"] = "internal"
```

#### 3. Add Extension Methods
Create extension methods in `SearchExtensions.cs` or new files as needed.

#### 4. Update SearchModelFactory
Add factory methods for new models to support testing.

### Files to Review/Update
- `src/Models/` - Custom model implementations
- `src/Indexes/Models/` - Index-related model customizations
- `src/Options/` - Search/Suggest/Autocomplete options
- `src/autorest.md` - Generator directives and renaming

---

## Step 7: Update CHANGELOG.md

### Goal
Document the changes for the new version, using the API analysis suggested entry as a starting point.

### Location
`sdk/search/Azure.Search.Documents/CHANGELOG.md`

### Using API Analysis Suggested Entry

If you have API analysis from Step 0, it includes a **Suggested CHANGELOG Entry** section. Use this as your starting point:

1. Copy the suggested entry from the analysis
2. Verify each item against actual generated code
3. Add any additional changes discovered during implementation
4. Adjust wording to match existing CHANGELOG style

### Format
```markdown
## {VERSION} (Unreleased)

### Features Added
- Added support for `{API_VERSION}` service version.
- {List new models from API analysis "New Models" section}
- {List new properties from API analysis "New Properties" section}

### Breaking Changes
- {Copy from API analysis "Breaking Changes" sections}
- {Include any removed models, operations, or properties}

### Bugs Fixed
- {List any bug fixes}

### Other Changes
- {List any other changes}
```

### Example Using API Analysis

From an API analysis with:
- New model: `VectorSearchOptions`
- New property: `SearchIndex.VectorSearch`
- Removed: `SearchIndex.LegacyScoring`

```markdown
## 12.0.0-beta.1 (Unreleased)

### Features Added
- Added support for `2025-11-01-preview` service version.
- Added `VectorSearchOptions` for configuring vector search behavior.
- Added `VectorSearch` property to `SearchIndex`.

### Breaking Changes
- Removed `LegacyScoring` property from `SearchIndex`.
```

---

## Step 8: Run Tests

### Goal
Validate the SDK changes with unit and integration tests.

### Actions

1. Run unit tests (no Azure resources needed):
   ```powershell
   cd sdk/search/Azure.Search.Documents
   dotnet test --filter TestCategory!=Live
   ```

2. For live tests (requires Azure resources):
   ```powershell
   # First, create test resources
   # See: eng/common/TestResources/README.md

   # Set test mode
   $env:AZURE_TEST_MODE = "Record"  # or "Live" or "Playback"

   dotnet test
   ```

3. Run specific test classes:
   ```powershell
   dotnet test --filter FullyQualifiedName~SearchClientTests
   dotnet test --filter FullyQualifiedName~SearchIndexClientTests
   dotnet test --filter FullyQualifiedName~SearchIndexerClientTests
   ```

### Test Framework Notes
- Tests use NUnit 3
- Tests support both sync and async via `InstrumentClient`
- Recorded tests can be replayed without Azure resources
- Use `this.Recording.Random` for reproducible random values

---

## Validation Checklist

Before submitting a PR, verify:

- [ ] `autorest.md` updated with correct swagger URLs
- [ ] `SearchClientOptions.ServiceVersion` updated with new version
- [ ] Code regenerated successfully (`dotnet build /t:GenerateCode`)
- [ ] Project builds without errors (`dotnet build`)
- [ ] All unit tests pass (`dotnet test --filter TestCategory!=Live`)
- [ ] CHANGELOG.md updated with new features
- [ ] No files in `Generated/` folder were manually edited
- [ ] API review completed for public API changes

---

## Troubleshooting

### Code Generation Fails
1. Ensure NodeJS 22.x is installed
2. Run `npm install` in the repository root if needed
3. Check autorest.md syntax for YAML errors

### Build Errors After Generation
1. Check for missing `CodeGenModel` attributes on replaced models
2. Verify all abstract base classes are listed in `suppress-abstract-base-class`
3. Look for type mismatches in customized models

### Test Failures
1. Check if new API features need test updates
2. Verify test recordings are up to date for the new API version
3. For live tests, ensure Azure resources support the new API version

---

## References

- [Azure.Search.Documents README](sdk/search/Azure.Search.Documents/README.md)
- [Search SDK CONTRIBUTING guide](sdk/search/CONTRIBUTING.md)
- [Azure SDK CONTRIBUTING guide](CONTRIBUTING.md)
- [Azure SDK Design Guidelines for .NET](https://azure.github.io/azure-sdk/dotnet_introduction.html)
- [Azure.Core.TestFramework](sdk/core/Azure.Core.TestFramework/README.md)