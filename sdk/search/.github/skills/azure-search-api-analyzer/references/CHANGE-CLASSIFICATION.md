# Change Classification Guide

This document explains how to classify API changes for SDK implementation.

## Change Impact Levels

### Level 1: Additive (Safe)

Changes that only add new functionality without affecting existing code.

**Examples:**
- New API endpoints
- New model types
- New optional properties
- New enum values (for extensible enums)
- New optional parameters

**SDK Impact:**
- Generate new code
- No changes to existing public API
- No migration required

### Level 2: Enhancement (Non-Breaking)

Changes that improve existing functionality without breaking compatibility.

**Examples:**
- Updated descriptions/documentation
- Relaxed constraints (required → optional)
- Widened types (int32 → int64)
- Added default values
- Performance improvements (server-side)

**SDK Impact:**
- Update documentation
- Possibly regenerate with same public API
- No migration required

### Level 3: Deprecation (Soft Breaking)

Changes that mark functionality as outdated but still functional.

**Examples:**
- Properties marked deprecated
- Operations marked deprecated
- Types replaced by newer versions
- Parameters replaced by alternatives

**SDK Impact:**
- Add `[Obsolete]` attributes
- Update documentation with alternatives
- Plan for eventual removal

### Level 4: Breaking Change (Hard Breaking)

Changes that will break existing client code.

**Examples:**
- Removed endpoints
- Removed types
- Removed properties
- Changed required properties
- Changed types
- Renamed operations
- Changed response structures

**SDK Impact:**
- Requires ApiCompatBaseline entry
- Migration documentation
- CHANGELOG breaking changes section
- Careful review before release

## Classification Decision Tree

```
Is the API element new?
├── Yes → ADDITIVE (Level 1)
└── No → Was it removed?
    ├── Yes → BREAKING (Level 4)
    └── No → Was it modified?
        ├── No → No change
        └── Yes → What was modified?
            ├── Documentation only → ENHANCEMENT (Level 2)
            ├── Made optional → ENHANCEMENT (Level 2)
            ├── Made required → BREAKING (Level 4)
            ├── Type changed → BREAKING (Level 4)
            ├── Renamed → BREAKING (Level 4)
            └── Marked deprecated → DEPRECATION (Level 3)
```

## Detailed Classification Rules

### Operations

| Change | Classification | SDK Impact |
|--------|----------------|------------|
| New operation added | Additive | New method |
| Operation removed | Breaking | Remove method, migration |
| Operation renamed (operationId) | Enhancement* | May change method name |
| Parameter added (optional) | Additive | New overload or optional param |
| Parameter added (required) | Breaking | Breaking - new required param |
| Parameter removed | Breaking | Remove parameter |
| Parameter type changed | Breaking | Type mismatch |
| Response type changed | Breaking | Return type change |
| Response added (new status) | Additive | Handle new response |
| Response removed | Breaking | Missing expected response |

*Operation rename may be breaking if SDK generates method names from operationId.

### Models

| Change | Classification | SDK Impact |
|--------|----------------|------------|
| New model added | Additive | New class |
| Model removed | Breaking | Remove class |
| Model renamed | Breaking | Rename class, migration |
| Property added (optional) | Additive | New property |
| Property added (required) | Breaking | Required in constructor |
| Property removed | Breaking | Remove property |
| Property type changed | Breaking | Type mismatch |
| Property made optional | Enhancement | Nullable change |
| Property made required | Breaking | Constructor change |
| Property renamed | Breaking | Rename property |
| Property deprecated | Deprecation | Add Obsolete |

### Enums

| Change | Classification | SDK Impact |
|--------|----------------|------------|
| New enum type | Additive | New enum/struct |
| Enum removed | Breaking | Remove type |
| New enum value | Additive* | Add value |
| Enum value removed | Breaking | Remove value |
| Enum value renamed | Breaking | Rename value |
| Fixed → Extensible | Enhancement | enum → struct |
| Extensible → Fixed | Breaking | struct → enum |

*For extensible enums (modelAsString=true), adding values is always safe.

## Azure Search Specific Classifications

### Knowledge Base Rename (Example)

When `KnowledgeAgent` was renamed to `KnowledgeBase`:

| Element | Old Name | New Name | Classification |
|---------|----------|----------|----------------|
| Type | KnowledgeAgent | KnowledgeBase | Breaking |
| Type | KnowledgeAgentSource | KnowledgeBaseSource | Breaking |
| Operation | Agents_Create | KnowledgeBases_Create | Breaking |
| Path | /agents | /knowledgebases | Breaking |

**SDK Handling:**
1. Add CodeGenModel mappings
2. Create type aliases if needed
3. Document migration in CHANGELOG
4. Consider keeping old names as obsolete for transition

### Vector Search Changes (Example)

When properties moved from one type to another:

| Change | Classification | Handling |
|--------|----------------|----------|
| `rerankWithOriginalVectors` removed | Breaking | Document migration |
| `RescoringOptions` added | Additive | New type |
| `RescoringOptions.EnabledRescoring` added | Additive | Replacement property |

**SDK Handling:**
1. Mark old property as Obsolete
2. Add new type and property
3. Document migration path
4. Consider helper methods for transition

## Creating Change Classification Report

### Template

```markdown
# API Change Classification Report

## Metadata
- Previous Version: {version}
- New Version: {version}
- Analysis Date: {date}

## Summary
| Classification | Count |
|----------------|-------|
| Additive | X |
| Enhancement | Y |
| Deprecation | Z |
| Breaking | W |

## Additive Changes

### New Operations
| Operation | Path | Description |
|-----------|------|-------------|
| ... | ... | ... |

### New Models
| Model | Description | Properties |
|-------|-------------|------------|
| ... | ... | ... |

### New Properties
| Model | Property | Type | Description |
|-------|----------|------|-------------|
| ... | ... | ... | ... |

## Enhancement Changes

### Documentation Updates
| Element | Change |
|---------|--------|
| ... | ... |

### Constraint Relaxations
| Element | Old | New |
|---------|-----|-----|
| ... | ... | ... |

## Deprecation Changes

| Element | Deprecated | Replacement |
|---------|------------|-------------|
| ... | ... | ... |

## Breaking Changes

### Removed Elements
| Type | Element | Migration |
|------|---------|-----------|
| ... | ... | ... |

### Changed Elements
| Element | Old | New | Migration |
|---------|-----|-----|-----------|
| ... | ... | ... | ... |

## SDK Implementation Priority

1. **Critical (Breaking)**: {list}
2. **High (New Features)**: {list}
3. **Medium (Enhancements)**: {list}
4. **Low (Documentation)**: {list}
```

## Prioritization Guidelines

### Must Address Before Release
1. All breaking changes documented
2. ApiCompatBaseline updated
3. Migration paths documented
4. CHANGELOG updated

### Should Address Before Release
1. New features implemented
2. Deprecations marked
3. Tests updated
4. Documentation current

### Can Defer
1. Minor documentation updates
2. Internal refactoring
3. Performance optimizations
4. Additional samples
