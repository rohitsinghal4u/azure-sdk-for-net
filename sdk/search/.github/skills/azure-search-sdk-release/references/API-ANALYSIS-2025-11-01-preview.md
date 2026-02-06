# Azure Search API Change Summary

## Metadata
- **Previous API Version**: 2025-08-01-preview
- **New API Version**: 2025-11-01-preview
- **Previous Commit**: 361cf37ae7e141472ad0a0354a55744a68ef712b
- **New Commit**: 3ed95cd4d105c1b6967ac00076a8df2eb73d7ba0
- **Track**: preview
- **Analysis Date**: 2026-01-30

---

## Summary Statistics

| Category | Added | Removed | Modified |
|----------|-------|---------|----------|
| Operations (Paths) | 3 | 2 | 0 |
| Models (searchservice.json) | 28 | 10 | 9 |
| Models (knowledgebase.json) | 47 | 22 | 0 |
| Enum Values | 8 | 0 | 0 |
| Properties (on existing models) | 15+ | 15+ | - |

---

## Breaking Changes ⚠️

### Renamed Types: KnowledgeAgent → KnowledgeBase
The entire `KnowledgeAgent` family of types has been renamed to `KnowledgeBase`:

| Old Name | New Name |
|----------|----------|
| `KnowledgeAgent` | `KnowledgeBase` |
| `KnowledgeAgentAzureOpenAIModel` | `KnowledgeBaseAzureOpenAIModel` |
| `KnowledgeAgentModel` | `KnowledgeBaseModel` |
| `KnowledgeAgentModelKind` | `KnowledgeBaseModelKind` |
| `ListKnowledgeAgentsResult` | `ListKnowledgeBasesResult` |
| `KnowledgeAgentMessage` | `KnowledgeBaseMessage` |
| `KnowledgeAgentMessageContent` | `KnowledgeBaseMessageContent` |
| `KnowledgeAgentMessageContentType` | `KnowledgeBaseMessageContentType` |
| `KnowledgeAgentMessageImageContent` | `KnowledgeBaseMessageImageContent` |
| `KnowledgeAgentMessageTextContent` | `KnowledgeBaseMessageTextContent` |
| `KnowledgeAgentRetrievalRequest` | `KnowledgeBaseRetrievalRequest` |
| `KnowledgeAgentRetrievalResponse` | `KnowledgeBaseRetrievalResponse` |
| `KnowledgeAgentReference` | `KnowledgeBaseReference` |
| `KnowledgeAgentActivityRecord` | `KnowledgeBaseActivityRecord` |
| `KnowledgeAgentAzureBlobActivityArguments` | `KnowledgeBaseAzureBlobActivityArguments` |
| `KnowledgeAgentAzureBlobActivityRecord` | `KnowledgeBaseAzureBlobActivityRecord` |
| `KnowledgeAgentAzureBlobReference` | `KnowledgeBaseAzureBlobReference` |
| `KnowledgeAgentSearchIndexActivityArguments` | `KnowledgeBaseSearchIndexActivityArguments` |
| `KnowledgeAgentSearchIndexActivityRecord` | `KnowledgeBaseSearchIndexActivityRecord` |
| `KnowledgeAgentSearchIndexReference` | `KnowledgeBaseSearchIndexReference` |
| `KnowledgeAgentWebActivityArguments` | `KnowledgeBaseWebActivityArguments` |
| `KnowledgeAgentWebActivityRecord` | `KnowledgeBaseWebActivityRecord` |
| `KnowledgeAgentWebReference` | `KnowledgeBaseWebReference` |
| `KnowledgeAgentModelAnswerSynthesisActivityRecord` | `KnowledgeBaseModelAnswerSynthesisActivityRecord` |
| `KnowledgeAgentModelQueryPlanningActivityRecord` | `KnowledgeBaseModelQueryPlanningActivityRecord` |
| `KnowledgeAgentRetrievalActivityRecord` | `KnowledgeBaseRetrievalActivityRecord` |

**SDK Impact**: 
- Rename all classes from `KnowledgeAgent*` to `KnowledgeBase*`
- Update autorest.md with rename directives
- Mark old types as `[Obsolete]` if maintaining backward compatibility
- Update all client methods referencing these types

### Removed Types (No Direct Replacement)
- `KnowledgeAgentOutputConfiguration`
- `KnowledgeAgentRequestLimits`
- `KnowledgeAgentSemanticRerankerActivityRecord`
- `WebKnowledgeSourceAllowedDomain`
- `WebKnowledgeSourceBlockedDomain`
- `WebKnowledgeSourceDomainRankingAdjustmentKind`

### Renamed Operations (Paths)
| Old Path | New Path |
|----------|----------|
| `/agents` | `/knowledgebases` |
| `/agents('{agentName}')` | `/knowledgebases('{knowledgeBaseName}')` |

### Property Removals on Existing Models

#### VectorSearchCompressionConfiguration
- ❌ Removed: `rerankWithOriginalVectors`
- ❌ Removed: `defaultOversampling`

#### KnowledgeSourceReference
- ❌ Removed: `includeReferences`
- ❌ Removed: `includeReferenceSourceData`
- ❌ Removed: `alwaysQuerySource`
- ❌ Removed: `maxSubQueries`
- ❌ Removed: `rerankerThreshold`

#### WebKnowledgeSourceParameters
- ❌ Removed: `identity`
- ❌ Removed: `bingResourceId`
- ❌ Removed: `language`
- ❌ Removed: `market`
- ❌ Removed: `freshness`
- ❌ Removed: `allowedDomains`
- ❌ Removed: `blockedDomains`

#### AzureBlobKnowledgeSourceParameters
- ❌ Removed: `identity`
- ❌ Removed: `embeddingModel`
- ❌ Removed: `chatCompletionModel`
- ❌ Removed: `ingestionSchedule`
- ❌ Removed: `disableImageVerbalization`

#### SearchIndexKnowledgeSourceParameters
- ❌ Removed: `sourceDataSelect`

---

## New Operations

### `GET/POST /knowledgebases`
- **Operation IDs**: `KnowledgeBases_List`, `KnowledgeBases_Create`
- **Description**: List and create knowledge bases
- **Request Body (POST)**: `KnowledgeBase`
- **Response**: `ListKnowledgeBasesResult` / `KnowledgeBase`
- **SDK Methods**: 
  - `SearchIndexClient.GetKnowledgeBases()`
  - `SearchIndexClient.CreateKnowledgeBase(KnowledgeBase)`

### `GET/PUT/DELETE /knowledgebases('{knowledgeBaseName}')`
- **Operation IDs**: `KnowledgeBases_Get`, `KnowledgeBases_CreateOrUpdate`, `KnowledgeBases_Delete`
- **Description**: CRUD operations on individual knowledge bases
- **SDK Methods**:
  - `SearchIndexClient.GetKnowledgeBase(string name)`
  - `SearchIndexClient.CreateOrUpdateKnowledgeBase(KnowledgeBase)`
  - `SearchIndexClient.DeleteKnowledgeBase(string name)`

### `GET /knowledgesources('{sourceName}')/status`
- **Operation ID**: `KnowledgeSources_GetStatus`
- **Description**: Get the status of a knowledge source
- **Response**: `KnowledgeSourceStatus`
- **SDK Method**: `SearchIndexClient.GetKnowledgeSourceStatus(string sourceName)`

---

## New Models

### Core Knowledge Base Types

#### KnowledgeBase
Represents a knowledge base for AI-powered search.
| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | The name of the knowledge base |
| `description` | string | No | A description of the knowledge base |
| `knowledgeSources` | KnowledgeSourceReference[] | Yes | References to knowledge sources |
| `models` | KnowledgeBaseModel[] | Yes | AI models used by the knowledge base |
| `retrievalReasoningEffort` | KnowledgeRetrievalReasoningEffort | No | Reasoning effort level |
| `outputMode` | KnowledgeRetrievalOutputMode | No | Output mode configuration |
| `retrievalInstructions` | string | No | Instructions for retrieval |
| `answerInstructions` | string | No | Instructions for answer generation |
| `encryptionKey` | SearchResourceEncryptionKey | No | Encryption key |
| `@odata.etag` | string | No | ETag for concurrency |

**SDK Class**: `Azure.Search.Documents.Indexes.Models.KnowledgeBase`

#### KnowledgeBaseModel
| Property | Type | Description |
|----------|------|-------------|
| (Polymorphic base for model types) | | |

**SDK Class**: `Azure.Search.Documents.Indexes.Models.KnowledgeBaseModel`

#### KnowledgeBaseAzureOpenAIModel
| Property | Type | Description |
|----------|------|-------------|
| (Inherits from KnowledgeBaseModel) | | |

**SDK Class**: `Azure.Search.Documents.Indexes.Models.KnowledgeBaseAzureOpenAIModel`

### Skill Types

#### ContentUnderstandingSkill
A skill that leverages Azure AI Content Understanding to process and extract structured insights from documents.
| Property | Type | Description |
|----------|------|-------------|
| `extractionOptions` | ContentUnderstandingSkillExtractionOptions[] | Extraction options |
| `chunkingProperties` | ContentUnderstandingSkillChunkingProperties | Chunking configuration |

**SDK Class**: `Azure.Search.Documents.Indexes.Models.ContentUnderstandingSkill`

#### ContentUnderstandingSkillChunkingProperties
| Property | Type | Description |
|----------|------|-------------|
| (Chunking configuration) | | |

#### ContentUnderstandingSkillExtractionOptions
| Property | Type | Description |
|----------|------|-------------|
| (Extraction options) | | |

### Indexer Runtime Types

#### IndexerRuntime
Represents the indexer's cumulative runtime consumption in the service.
| Property | Type | Description |
|----------|------|-------------|
| `usedSeconds` | integer | Seconds used |
| `remainingSeconds` | integer | Seconds remaining |
| `beginningTime` | string (datetime) | Start of measurement period |
| `endingTime` | string (datetime) | End of measurement period |

**SDK Class**: `Azure.Search.Documents.Indexes.Models.IndexerRuntime`

#### ServiceIndexersRuntime
Represents service level indexers runtime information.
| Property | Type | Description |
|----------|------|-------------|
| `usedSeconds` | integer | Seconds used |
| `remainingSeconds` | integer | Seconds remaining |
| `beginningTime` | string (datetime) | Start of measurement period |
| `endingTime` | string (datetime) | End of measurement period |

**SDK Class**: `Azure.Search.Documents.Indexes.Models.ServiceIndexersRuntime`

### Synchronization Types

#### SynchronizationState
Represents the current state of an ongoing synchronization that spans multiple indexer runs.
| Property | Type | Description |
|----------|------|-------------|
| `startTime` | string (datetime) | When synchronization started |
| `itemsUpdatesProcessed` | integer | Number of items processed |
| `itemsUpdatesFailed` | integer | Number of items that failed |
| `itemsSkipped` | integer | Number of items skipped |

**SDK Class**: `Azure.Search.Documents.Indexes.Models.SynchronizationState`

#### CompletedSynchronizationState
| Property | Type | Description |
|----------|------|-------------|
| (Completed sync state details) | | |

### Knowledge Source Types

#### IndexedOneLakeKnowledgeSource
| Property | Type | Description |
|----------|------|-------------|
| (OneLake knowledge source configuration) | | |

#### IndexedOneLakeKnowledgeSourceParameters
| Property | Type | Description |
|----------|------|-------------|
| (OneLake parameters) | | |

#### IndexedSharePointKnowledgeSource
| Property | Type | Description |
|----------|------|-------------|
| (Indexed SharePoint source configuration) | | |

#### IndexedSharePointKnowledgeSourceParameters
| Property | Type | Description |
|----------|------|-------------|
| (Indexed SharePoint parameters) | | |

#### RemoteSharePointKnowledgeSource
| Property | Type | Description |
|----------|------|-------------|
| (Remote SharePoint source configuration) | | |

#### RemoteSharePointKnowledgeSourceParameters
| Property | Type | Description |
|----------|------|-------------|
| (Remote SharePoint parameters) | | |

#### KnowledgeSourceStatus
| Property | Type | Description |
|----------|------|-------------|
| (Knowledge source status details) | | |

#### KnowledgeSourceStatistics
| Property | Type | Description |
|----------|------|-------------|
| (Knowledge source statistics) | | |

#### KnowledgeSourceIngestionParameters
| Property | Type | Description |
|----------|------|-------------|
| (Ingestion parameters) | | |

#### KnowledgeSourceVectorizer
| Property | Type | Description |
|----------|------|-------------|
| (Vectorizer configuration) | | |

#### KnowledgeSourceAzureOpenAIVectorizer
| Property | Type | Description |
|----------|------|-------------|
| (Azure OpenAI vectorizer) | | |

### Knowledge Retrieval Types (from knowledgebase.json)

#### KnowledgeRetrievalReasoningEffort (Polymorphic)
| Type | Description |
|------|-------------|
| `KnowledgeRetrievalMinimalReasoningEffort` | Minimal reasoning |
| `KnowledgeRetrievalLowReasoningEffort` | Low reasoning |
| `KnowledgeRetrievalMediumReasoningEffort` | Medium reasoning |

#### KnowledgeRetrievalIntent
| Property | Type | Description |
|----------|------|-------------|
| (Intent configuration) | | |

#### KnowledgeRetrievalSemanticIntent
| Property | Type | Description |
|----------|------|-------------|
| (Semantic intent) | | |

### Activity Record Types (from knowledgebase.json)

New activity record types for different knowledge sources:
- `KnowledgeBaseAgenticReasoningActivityRecord`
- `KnowledgeBaseIndexedOneLakeActivityRecord`
- `KnowledgeBaseIndexedOneLakeActivityArguments`
- `KnowledgeBaseIndexedSharePointActivityRecord`
- `KnowledgeBaseIndexedSharePointActivityArguments`
- `KnowledgeBaseRemoteSharePointActivityRecord`
- `KnowledgeBaseRemoteSharePointActivityArguments`

### Reference Types (from knowledgebase.json)

- `KnowledgeBaseIndexedOneLakeReference`
- `KnowledgeBaseIndexedSharePointReference`
- `KnowledgeBaseRemoteSharePointReference`
- `SharePointSensitivityLabelInfo`

### Other New Types

#### AIServices
| Property | Type | Description |
|----------|------|-------------|
| (AI Services configuration) | | |

#### WebKnowledgeSourceDomain
| Property | Type | Description |
|----------|------|-------------|
| (Web domain configuration) | | |

#### WebKnowledgeSourceDomains
| Property | Type | Description |
|----------|------|-------------|
| (Collection of web domains) | | |

#### SearchIndexFieldReference
| Property | Type | Description |
|----------|------|-------------|
| (Field reference) | | |

---

## Modified Models (Property Changes)

### SearchIndex
- ✅ Added: `purviewEnabled` (boolean) - Enable Purview integration

### SearchField
- ✅ Added: `sensitivityLabel` (string) - Sensitivity label for the field

### SearchIndexerStatus
- ✅ Added: `runtime` (IndexerRuntime) - Runtime consumption information

### ServiceStatistics
- ✅ Added: `indexersRuntime` (ServiceIndexersRuntime) - Service-level indexer runtime info

### ServiceLimits
- ✅ Added: `maxCumulativeIndexerRuntimeSeconds` (integer) - Maximum cumulative indexer runtime

### SearchIndexKnowledgeSourceParameters
- ✅ Added: `sourceDataFields` (string[]) - Source data fields
- ✅ Added: `searchFields` (string[]) - Search fields
- ✅ Added: `semanticConfigurationName` (string) - Semantic configuration name
- ❌ Removed: `sourceDataSelect`

### WebKnowledgeSourceParameters
- ✅ Added: `domains` (WebKnowledgeSourceDomains) - Domain configuration (replaces allowedDomains/blockedDomains)

### AzureBlobKnowledgeSourceParameters
- ✅ Added: `isADLSGen2` (boolean) - Whether source is ADLS Gen2
- ✅ Added: `ingestionParameters` (KnowledgeSourceIngestionParameters) - Ingestion parameters

---

## New Enums

### KnowledgeSourceKind (New Values)
- ✅ `remoteSharePoint` - Remote SharePoint knowledge source
- ✅ `indexedSharePoint` - Indexed SharePoint knowledge source
- ✅ `indexedOneLake` - Indexed OneLake knowledge source

### AzureOpenAIModelName (New Values)
- ✅ `gpt-5` - GPT-5 model
- ✅ `gpt-5-mini` - GPT-5 mini model
- ✅ `gpt-5-nano` - GPT-5 nano model

### SearchIndexerDataSourceType (New Values)
- ✅ `sharepoint` - SharePoint data source type

### ScoringFunctionAggregation (New Values)
- ✅ `product` - Product aggregation function

### New Enum Types
- `ContentUnderstandingSkillChunkingUnit`
- `KnowledgeBaseModelKind`
- `KnowledgeBaseMessageContentType`
- `KnowledgeRetrievalIntentType`
- `KnowledgeRetrievalReasoningEffortKind`
- `KnowledgeRetrievalOutputMode`

---

## SDK Implementation Checklist

### autorest.md Updates
- [ ] Update `input-file` URLs to new commit `3ed95cd4d105c1b6967ac00076a8df2eb73d7ba0`
- [ ] Update API version to `2025-11-01-preview`
- [ ] Add rename directives for `KnowledgeAgent*` → `KnowledgeBase*` types
- [ ] Add suppress directives for new abstract/polymorphic classes
- [ ] Update `knowledgeagent.json` reference to `knowledgebase.json`

### New Types to Generate
- [ ] `KnowledgeBase` and related types
- [ ] `ContentUnderstandingSkill` and related types
- [ ] `IndexerRuntime` and `ServiceIndexersRuntime`
- [ ] `SynchronizationState` and `CompletedSynchronizationState`
- [ ] `IndexedOneLakeKnowledgeSource` and parameters
- [ ] `IndexedSharePointKnowledgeSource` and parameters
- [ ] `RemoteSharePointKnowledgeSource` and parameters
- [ ] `KnowledgeSourceStatus` and `KnowledgeSourceStatistics`
- [ ] All `KnowledgeBase*ActivityRecord` types
- [ ] All `KnowledgeRetrieval*` types

### Customizations Needed
- [ ] Add `[CodeGenModel]` attributes for renamed types
- [ ] Update `SearchModelFactory` with new factory methods
- [ ] Add extension methods for new operations
- [ ] Handle polymorphic type serialization for reasoning effort types

### Client Updates
- [ ] Add `GetKnowledgeBases()` method
- [ ] Add `CreateKnowledgeBase()` method
- [ ] Add `GetKnowledgeBase(string name)` method
- [ ] Add `CreateOrUpdateKnowledgeBase()` method
- [ ] Add `DeleteKnowledgeBase(string name)` method
- [ ] Add `GetKnowledgeSourceStatus(string sourceName)` method
- [ ] Remove/deprecate `KnowledgeAgent*` methods

### Tests to Add/Update
- [ ] `KnowledgeBaseClientTests` - new test class
- [ ] `ContentUnderstandingSkillTests` - new skill tests
- [ ] `IndexerRuntimeTests` - new runtime tests
- [ ] Update existing tests for renamed types
- [ ] Add tests for new enum values

### Documentation
- [ ] CHANGELOG.md entries for all changes
- [ ] README.md updates for new features
- [ ] XML documentation for all new types
- [ ] Migration guide for KnowledgeAgent → KnowledgeBase rename

---

## Suggested CHANGELOG Entry

```markdown
## 11.X.0-beta.X (Unreleased)

### Features Added
- Added support for `2025-11-01-preview` service version.
- Added `KnowledgeBase` types replacing the previous `KnowledgeAgent` types.
- Added `ContentUnderstandingSkill` for Azure AI Content Understanding integration.
- Added `IndexerRuntime` and `ServiceIndexersRuntime` for tracking indexer runtime consumption.
- Added `SynchronizationState` for tracking long-running synchronization operations.
- Added support for SharePoint and OneLake as knowledge sources:
  - `IndexedSharePointKnowledgeSource`
  - `RemoteSharePointKnowledgeSource`
  - `IndexedOneLakeKnowledgeSource`
- Added `GetKnowledgeSourceStatus()` method to retrieve knowledge source status.
- Added `SearchIndex.PurviewEnabled` property for Microsoft Purview integration.
- Added `SearchField.SensitivityLabel` property for data classification.
- Added `ServiceLimits.MaxCumulativeIndexerRuntimeSeconds` property.
- Added new `AzureOpenAIModelName` values: `Gpt5`, `Gpt5Mini`, `Gpt5Nano`.
- Added `SharePoint` as a `SearchIndexerDataSourceType`.
- Added `Product` as a `ScoringFunctionAggregation` option.

### Breaking Changes
- Renamed all `KnowledgeAgent*` types to `KnowledgeBase*`. Previous types are marked as obsolete.
- Removed `VectorSearchCompressionConfiguration.RerankWithOriginalVectors` property.
- Removed `VectorSearchCompressionConfiguration.DefaultOversampling` property.
- Changed `WebKnowledgeSourceParameters` structure: replaced `AllowedDomains`/`BlockedDomains` with `Domains` property.
- Removed several properties from `KnowledgeSourceReference`: `IncludeReferences`, `IncludeReferenceSourceData`, `AlwaysQuerySource`, `MaxSubQueries`, `RerankerThreshold`.
- Removed several properties from `AzureBlobKnowledgeSourceParameters`: `Identity`, `EmbeddingModel`, `ChatCompletionModel`, `IngestionSchedule`, `DisableImageVerbalization`. Use `IngestionParameters` instead.
```

---

## Files Changed Summary

| File | Changes |
|------|---------|
| `searchservice.json` | +28 models, -10 models, +3 paths, -2 paths, property changes |
| `searchindex.json` | No changes |
| `knowledgebase.json` | +47 models, -22 models (renamed from knowledgeagent.json) |

---

## Next Steps

1. **Review this analysis** - Verify all changes are accurately captured
2. **Run SDK-release skill** - Use this analysis as context for SDK implementation
3. **Prioritize breaking changes** - Handle KnowledgeAgent → KnowledgeBase rename first
4. **Generate code** - Run autorest with updated configuration
5. **Add customizations** - Apply necessary code generation customizations
6. **Write tests** - Add/update tests for all changes
7. **Update documentation** - Write CHANGELOG and update README
