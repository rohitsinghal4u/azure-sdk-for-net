# Breaking Changes Guide

This document explains how to identify, document, and handle breaking changes in the Azure.Search.Documents SDK.

## What Is a Breaking Change?

A breaking change is any modification to the public API that could cause existing client code to:
- Fail to compile (source breaking)
- Fail at runtime (binary breaking)
- Behave differently (behavioral breaking)

## Types of Breaking Changes

### Binary Breaking Changes

These prevent compiled code from running against the new version:

| Change | Example |
|--------|---------|
| Remove public type | Deleted `SearchFeature` class |
| Remove public member | Deleted `SearchClient.OldMethod()` |
| Change method signature | `Method(int x)` → `Method(int x, int y)` |
| Change return type | `Response<T>` → `Response<U>` |
| Change inheritance | Remove base class/interface |
| Change type kind | Class → Struct |
| Seal unsealed type | `class` → `sealed class` |
| Make concrete type abstract | `class` → `abstract class` |
| Add abstract member | New abstract method in base class |

### Source Breaking Changes

These require code changes to recompile:

| Change | Example |
|--------|---------|
| Add required parameter | `Method(int x)` → `Method(int x, int y)` |
| Remove optional parameter | `Method(int x = 0)` → `Method()` |
| Change parameter name | `Method(int old)` → `Method(int new)` |
| Change generic constraints | `where T : class` → `where T : struct` |
| Reduce member visibility | `public` → `protected` |
| Add type constraint | `<T>` → `<T> where T : new()` |

### Behavioral Breaking Changes

These change runtime behavior without compilation errors:

| Change | Example |
|--------|---------|
| Change default value | `Size = 50` → `Size = 100` |
| Change exception type | `ArgumentException` → `InvalidOperationException` |
| Change error conditions | Previously succeeded, now throws |
| Change serialization format | JSON property names change |
| Change ordering | Results returned in different order |

## Track-Based Compatibility Rules

### Stable to Stable (Strict)

Between stable versions (e.g., `11.7.0` → `11.8.0`):
- **No binary breaking changes allowed**
- **No source breaking changes allowed**
- Additive changes only
- Must maintain full backwards compatibility

### Preview to Preview (Flexible)

Between preview versions (e.g., `11.8.0-beta.1` → `11.8.0-beta.2`):
- Breaking changes are **discouraged but allowed**
- All breaking changes must be documented
- CHANGELOG must clearly list changes

### Preview to Stable (Reset)

When promoting preview to stable (e.g., `11.8.0-beta.2` → `11.8.0`):
- Breaking changes from preview APIs are **expected**
- Only changes from last stable need compatibility
- Preview APIs are explicitly experimental

## Detecting Breaking Changes

### Using ApiCompatBaseline

The SDK uses API compatibility checking during build:

```powershell
# Run API compat check
dotnet build /p:RunApiCompat=true
```

If breaking changes exist and are intentional, document in:
```
sdk/search/Azure.Search.Documents/src/ApiCompatBaseline.txt
```

### Format of ApiCompatBaseline.txt

```
# Comment explaining why this breaking change is acceptable
RuleId : Detailed message from API compat tool

# Example entries:
# SearchResults<T> needs to be abstract for proper extensibility
CannotMakeTypeAbstract : Type 'Azure.Search.Documents.Models.SearchResults<T>' is abstract in the implementation but is not abstract in the contract.

# Removed obsolete API that was deprecated 2 versions ago
MembersMustExist : Member 'Azure.Search.Documents.SearchClient.OldMethod()' does not exist in the implementation but it does exist in the contract.
```

### Manual API Comparison

```powershell
# Get previous API
git show <previous-commit>:sdk/search/Azure.Search.Documents/api/Azure.Search.Documents.net8.0.cs > previous.cs

# Get current API
$current = "sdk/search/Azure.Search.Documents/api/Azure.Search.Documents.net8.0.cs"

# Compare
git diff --no-index previous.cs $current

# Or use PowerShell
Compare-Object (Get-Content previous.cs) (Get-Content $current) |
    Where-Object { $_.SideIndicator -eq '<=' } |  # Removed lines
    ForEach-Object { Write-Host "REMOVED: $($_.InputObject)" -ForegroundColor Red }
```

## Documenting Breaking Changes

### In CHANGELOG.md

```markdown
## 11.8.0 (2025-12-01)

### Breaking Changes
- Removed `SearchClient.DeprecatedMethod()`. Use `SearchClient.NewMethod()` instead.
- `SearchOptions.OldProperty` has been renamed to `SearchOptions.NewProperty`.
- `IndexingResult.StatusCode` type changed from `int` to `int?` to handle unknown status codes.
```

### In Migration Guide

For significant changes, update `MigrationGuide.md`:

```markdown
## Migrating from 11.7.x to 11.8.x

### SearchOptions Changes

The `OldProperty` has been renamed to `NewProperty` for clarity:

```csharp
// Before (11.7.x)
var options = new SearchOptions { OldProperty = "value" };

// After (11.8.x)
var options = new SearchOptions { NewProperty = "value" };
```
```

## Handling Breaking Changes in Reviews

### Review Checklist

For each identified breaking change:

1. **Is it necessary?**
   - Can the change be made additively instead?
   - Can the old API be deprecated rather than removed?

2. **Is it documented?**
   - [ ] Entry in CHANGELOG.md
   - [ ] Entry in ApiCompatBaseline.txt (if applicable)
   - [ ] Migration guidance provided

3. **Is it justified?**
   - Security fix
   - Critical bug fix
   - API design improvement
   - Removing long-deprecated API

4. **Is it minimized?**
   - Only necessary changes made
   - No collateral breaking changes

### Approval Requirements

| Track | Requirements |
|-------|--------------|
| Stable | Architecture review required for any breaking change |
| Preview | Team lead approval required |
| Major version | Breaking changes expected and allowed |

## Avoiding Breaking Changes

### Use Additive Patterns

```csharp
// Instead of changing existing method
// BAD: Change Method(int x) to Method(int x, int y)

// Add new overload
// GOOD: Keep Method(int x), add Method(int x, int y)
public void Method(int x) => Method(x, defaultY);
public void Method(int x, int y) { /* implementation */ }
```

### Use Obsolete Attribute

```csharp
// Mark old API as obsolete before removal
[Obsolete("Use NewMethod instead. This will be removed in a future version.")]
public void OldMethod() { }

// Then remove in next major version
```

### Use Optional Parameters

```csharp
// Instead of changing signature
// BAD: Method(int x) → Method(int x, int y)

// Add optional parameter
// GOOD: Method(int x) → Method(int x, int y = 0)
public void Method(int x, int y = 0) { }
```

### Use Extension Methods for New Features

```csharp
// Add functionality without changing type
public static class SearchClientExtensions
{
    public static Response<T> NewFeature<T>(this SearchClient client, ...)
    {
        // Implementation using existing public API
    }
}
```

## Breaking Change Review Template

```markdown
## Breaking Change Review

### Change Description
[Describe what changed]

### Justification
[Why is this change necessary?]

### Impact Assessment
- **Binary Breaking**: Yes/No
- **Source Breaking**: Yes/No
- **Behavioral Breaking**: Yes/No

### Affected APIs
- `Namespace.Type.Member`
- `Namespace.Type2`

### Migration Path
[How should users update their code?]

### Documentation Updates
- [ ] CHANGELOG.md
- [ ] ApiCompatBaseline.txt
- [ ] MigrationGuide.md (if significant)

### Approval
- [ ] Justified and necessary
- [ ] Properly documented
- [ ] Migration path is clear
```
