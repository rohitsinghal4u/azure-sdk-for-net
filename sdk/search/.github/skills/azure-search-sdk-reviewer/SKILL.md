---
name: azure-search-sdk-reviewer
description: Reviews changes made by the azure-search-sdk-release agent before PR submission. Validates C# coding standards, compares exported APIs between versions, ensures backwards compatibility within the same track (stable/preview), and approves changes for GitHub PR submission. Use when reviewing Search SDK changes before release.
metadata:
  author: azure-sdk
  version: "1.0"
  service: search
---

# Azure Search SDK Reviewer Skill

This skill reviews changes made by the SDK release agent to ensure quality, backwards compatibility, and conformance to standards before approving for PR submission.

## Prerequisites

- Git installed and configured
- Both `azure-sdk-for-net` and `azure-rest-api-specs` repositories cloned locally
- PowerShell 7 or higher
- .NET 9.0 SDK or higher

## Review Workflow Overview

1. **Gather context** - Identify the changes and previous commit for comparison
2. **Review C# coding standards** - Check code quality and style conformance
3. **Compare exported APIs** - Diff the API surface between versions
4. **Validate backwards compatibility** - Ensure no unintended breaking changes
5. **Generate review report** - Summarize findings
6. **Approve or request changes** - Make final decision for PR submission

---

## Step 1: Gather Context

### Goal
Identify the scope of changes and establish baseline for comparison.

### Required Information
- **Previous commit SHA**: The commit representing the previous API version (same track)
- **Current branch**: The branch with SDK changes to review
- **Track type**: Whether this is a `stable` or `preview` release

### Actions

1. Get the list of changed files:
   ```powershell
   git diff --name-only <previous-commit> HEAD -- sdk/search/Azure.Search.Documents/
   ```

2. Identify the API version track:
   - Check `SearchClientOptions.cs` for `ServiceVersion` enum
   - Preview versions end with `-preview` (e.g., `2025-11-01-preview`)
   - Stable versions don't have suffix (e.g., `2025-09-01`)

3. Get the previous API export files:
   ```powershell
   git show <previous-commit>:sdk/search/Azure.Search.Documents/api/Azure.Search.Documents.net8.0.cs > previous-api.cs
   ```

---

## Step 2: Review C# Coding Standards

### Goal
Ensure all code changes conform to C# quality and Azure SDK coding standards.

### Checklist

#### Naming Conventions
- [ ] Classes, methods, and properties use PascalCase
- [ ] Parameters and local variables use camelCase
- [ ] Private fields use `_camelCase` prefix
- [ ] Async methods end with `Async` suffix
- [ ] Boolean properties/methods use `Is`, `Has`, `Can` prefixes where appropriate

#### Azure SDK Guidelines
- [ ] All public types have XML documentation comments
- [ ] Nullable reference types are properly annotated
- [ ] `CancellationToken` is the last parameter in async methods
- [ ] `Response<T>` is returned from service operations
- [ ] Both sync and async variants exist for service methods

#### Code Quality
- [ ] No compiler warnings (treat warnings as errors)
- [ ] No unused `using` statements
- [ ] Proper exception handling with `RequestFailedException`
- [ ] Model classes are immutable where appropriate
- [ ] Factory methods exist for testability (`SearchModelFactory`)

#### Generated Code
- [ ] Files in `Generated/` folder are NOT manually edited
- [ ] Customizations are in separate partial class files
- [ ] `[CodeGenModel]` attributes map correctly to generated types

### Common Issues to Flag

```csharp
// BAD: Missing XML documentation
public class NewFeature { }

// GOOD: Proper documentation
/// <summary>
/// Represents a new feature for search operations.
/// </summary>
public class NewFeature { }

// BAD: Inconsistent async pattern
public Task<Response<T>> GetData(CancellationToken token) { }

// GOOD: Proper async naming
public Task<Response<T>> GetDataAsync(CancellationToken cancellationToken = default) { }
```

---

## Step 3: Compare Exported APIs

### Goal
Generate a diff of the public API surface between versions.

### API Export Files Location
```
sdk/search/Azure.Search.Documents/api/
├── Azure.Search.Documents.net8.0.cs
├── Azure.Search.Documents.net10.0.cs
└── Azure.Search.Documents.netstandard2.0.cs
```

### Actions

1. Export current API (if not already done):
   ```powershell
   cd sdk/search/Azure.Search.Documents/src
   dotnet build /t:ExportApi /p:Configuration=Release
   ```

2. Get previous API from commit:
   ```powershell
   git show <previous-commit>:sdk/search/Azure.Search.Documents/api/Azure.Search.Documents.net8.0.cs > previous-api.cs
   ```

3. Compare APIs:
   ```powershell
   # Use the Compare-SearchApi.ps1 script or manual diff
   git diff --no-index previous-api.cs sdk/search/Azure.Search.Documents/api/Azure.Search.Documents.net8.0.cs
   ```

### What to Look For

| Change Type | Action |
|-------------|--------|
| New public types | ✅ Review naming and documentation |
| New public members | ✅ Verify they follow patterns |
| Removed public types | ⚠️ Breaking change - needs justification |
| Removed public members | ⚠️ Breaking change - needs justification |
| Changed signatures | ⚠️ Breaking change - needs justification |
| Changed return types | ⚠️ Breaking change - needs justification |

---

## Step 4: Validate Backwards Compatibility

### Goal
Ensure all features from the previous API version (same track) exist in the current version unless explicitly removed with justification.

### Compatibility Rules

#### Same Track Requirements
- **Preview → Preview**: All public APIs from previous preview must exist
- **Stable → Stable**: All public APIs from previous stable must exist
- **Preview → Stable**: Breaking changes allowed (preview is experimental)

#### Breaking Change Categories

1. **Binary Breaking** (blocks existing compiled code):
   - Removing public types/members
   - Changing method signatures
   - Changing type inheritance

2. **Source Breaking** (requires code changes to compile):
   - Adding required parameters
   - Changing parameter types
   - Removing optional parameters

3. **Behavioral Breaking** (changes runtime behavior):
   - Changing default values
   - Changing exception types
   - Changing serialization format

### ApiCompatBaseline.txt

If breaking changes are intentional, they must be documented in:
```
sdk/search/Azure.Search.Documents/src/ApiCompatBaseline.txt
```

Example format:
```
# Explanation of why this breaking change is acceptable
CannotMakeTypeAbstract : Type 'Azure.Search.Documents.Models.SearchResults<T>' is abstract in the implementation but is not abstract in the contract.
```

### Validation Actions

1. Build with API compatibility check:
   ```powershell
   dotnet build /p:RunApiCompat=true
   ```

2. Review any compatibility errors
3. For each breaking change:
   - [ ] Is it documented in ApiCompatBaseline.txt?
   - [ ] Is there a clear justification?
   - [ ] Is it noted in CHANGELOG.md under "Breaking Changes"?

---

## Step 5: Generate Review Report

### Goal
Create a comprehensive review report summarizing findings.

### Report Template

```markdown
# Azure.Search.Documents SDK Review Report

## Summary
- **Previous Commit**: `<sha>`
- **Current Branch**: `<branch>`
- **Track**: `<stable|preview>`
- **API Version**: `<version>`

## Code Quality
- [ ] Naming conventions: PASS/FAIL
- [ ] Documentation: PASS/FAIL
- [ ] Azure SDK patterns: PASS/FAIL
- [ ] No manual Generated/ edits: PASS/FAIL

## API Changes
### New Types
- `Namespace.NewType1`
- `Namespace.NewType2`

### New Members
- `ExistingType.NewMethod()`
- `ExistingType.NewProperty`

### Removed (Breaking Changes)
- `Namespace.RemovedType` - Justification: <reason>
- `ExistingType.RemovedMethod()` - Justification: <reason>

## Backwards Compatibility
- [ ] All previous APIs present: PASS/FAIL
- [ ] Breaking changes documented: PASS/FAIL
- [ ] CHANGELOG updated: PASS/FAIL

## Recommendation
- [ ] **APPROVE** - Ready for PR submission
- [ ] **REQUEST CHANGES** - Issues must be addressed

## Notes
<Additional observations or concerns>
```

---

## Step 6: Approve or Request Changes

### Approval Criteria

All of the following must be true to approve:

1. **Code Quality**: No critical issues
2. **API Compatibility**: No undocumented breaking changes
3. **Documentation**: All public APIs documented
4. **Tests**: All tests pass
5. **CHANGELOG**: Updated with new features and any breaking changes

### Approve for PR

If all criteria are met:
1. Mark review as **APPROVED**
2. Confirm ready for GitHub PR submission
3. Note any minor suggestions for future improvement

### Request Changes

If issues are found:
1. Mark review as **CHANGES REQUESTED**
2. List specific issues that must be addressed
3. Provide guidance on how to fix each issue
4. Re-review after changes are made

---

## Quick Reference: API Comparison Patterns

### Identifying Added APIs
```powershell
# Find lines only in new API
diff (Get-Content previous-api.cs) (Get-Content current-api.cs) |
    Where-Object { $_.SideIndicator -eq '=>' }
```

### Identifying Removed APIs
```powershell
# Find lines only in previous API
diff (Get-Content previous-api.cs) (Get-Content current-api.cs) |
    Where-Object { $_.SideIndicator -eq '<=' }
```

### Checking ServiceVersion
```powershell
# Verify version enum is updated
Select-String -Path "src/SearchClientOptions.cs" -Pattern "V\d{4}_\d{2}_\d{2}"
```

---

## References

- [API Comparison Guide](references/API-COMPARISON.md)
- [C# Coding Standards](references/CSHARP-STANDARDS.md)
- [Breaking Changes Guide](references/BREAKING-CHANGES.md)
- [Azure SDK Design Guidelines](https://azure.github.io/azure-sdk/dotnet_introduction.html)