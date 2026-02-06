# Testing Guide for Azure.Search.Documents

This document provides detailed guidance on testing the Azure.Search.Documents SDK.

## Test Framework Overview

The SDK uses:
- **NUnit 3** as the testing framework
- **Azure.Core.TestFramework** for recording/playback and test infrastructure
- **Moq** for mocking (when needed)

## Test Project Structure

```
tests/
├── Azure.Search.Documents.Tests.csproj
├── SearchClientTests.cs
├── SearchIndexClientTests.cs
├── SearchIndexerClientTests.cs
├── Batching/
│   └── BatchingTests.cs
├── DocumentOperations/
│   └── GetDocumentTests.cs
├── Models/
│   └── ModelTests.cs
├── Samples/
│   └── README.md
├── Serialization/
│   └── SerializationTests.cs
└── Utilities/
    └── UtilityTests.cs
```

## Test Base Classes

### SearchTestBase

All Search tests inherit from `SearchTestBase`:

```csharp
public class MyTests : SearchTestBase
{
    public MyTests(bool async, SearchClientOptions.ServiceVersion serviceVersion)
        : base(async, serviceVersion, null /* RecordedTestMode.Record */)
    {
    }

    [Test]
    public async Task MyTest()
    {
        await using SearchResources resources = await SearchResources.GetSharedHotelsIndexAsync(this);
        SearchClient client = resources.GetSearchClient();

        // Test code here
    }
}
```

### Test Modes

| Mode | Description |
|------|-------------|
| `Playback` | Replay recorded responses (default for CI) |
| `Record` | Record new responses from live service |
| `Live` | Execute against live service without recording |

Set the mode via environment variable:
```powershell
$env:AZURE_TEST_MODE = "Record"
```

## SearchResources Helper

The `SearchResources` class provides test fixtures:

```csharp
// Get shared hotels index (faster, shared across tests)
await using var resources = await SearchResources.GetSharedHotelsIndexAsync(this);

// Create dedicated index (isolated, cleaned up after test)
await using var resources = await SearchResources.CreateWithHotelsIndexAsync(this);

// Get clients
SearchClient searchClient = resources.GetSearchClient();
SearchIndexClient indexClient = resources.GetIndexClient();
SearchIndexerClient indexerClient = resources.GetIndexerClient();
```

## Sync/Async Testing

Tests are automatically run in both sync and async modes:

```csharp
[Test]
public async Task SearchDocuments()
{
    // This test runs twice:
    // - Once with async methods (True)
    // - Once with sync methods (False)

    SearchClient client = InstrumentClient(new SearchClient(...));
    Response<SearchResults<Hotel>> response = await client.SearchAsync<Hotel>("*");
}
```

The `InstrumentClient` method wraps the client to:
- Redirect async calls to sync calls when running sync tests
- Record/playback HTTP traffic

## Recording Best Practices

### Use Deterministic Values

```csharp
// Good - reproducible across runs
string indexName = Recording.GenerateId("index");
DateTimeOffset timestamp = Recording.UtcNow;

// Bad - different each run
string indexName = Guid.NewGuid().ToString();
DateTimeOffset timestamp = DateTimeOffset.UtcNow;
```

### Sanitize Sensitive Data

Sensitive data is automatically sanitized. Add custom sanitizers if needed:

```csharp
public class MyTests : SearchTestBase
{
    public MyTests(bool async, ServiceVersion version)
        : base(async, version)
    {
        SanitizedHeaders.Add("x-custom-header");
    }
}
```

## Running Tests

### Command Line

```powershell
# All tests (playback mode)
dotnet test sdk/search/Azure.Search.Documents/tests

# Skip live tests
dotnet test --filter "TestCategory!=Live"

# Specific test class
dotnet test --filter "FullyQualifiedName~SearchClientTests"

# Specific test method
dotnet test --filter "Name=GetDocumentCount"

# Specific framework
dotnet test -f net8.0
```

### Visual Studio

1. Open the solution
2. Build the test project
3. Open Test Explorer (Test > Test Explorer)
4. Run or debug selected tests

## Live Test Resources

### Creating Resources

Before running live tests, create Azure resources:

```powershell
# From repository root
eng/common/TestResources/New-TestResources.ps1 -ServiceDirectory search
```

This creates:
- Azure AI Search service
- Storage account (for indexer tests)
- Sets environment variables

### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `SEARCH_ENDPOINT` | Search service endpoint URL |
| `SEARCH_API_KEY` | Admin API key |
| `SEARCH_STORAGE_CONNECTION_STRING` | Storage connection (for indexers) |

### Cleaning Up

```powershell
eng/common/TestResources/Remove-TestResources.ps1 -ServiceDirectory search
```

## Writing New Tests

### Basic Test Structure

```csharp
[Test]
public async Task NewFeatureTest()
{
    // Arrange
    await using SearchResources resources = await SearchResources.GetSharedHotelsIndexAsync(this);
    SearchClient client = resources.GetSearchClient();

    // Act
    Response<SearchResults<Hotel>> response = await client.SearchAsync<Hotel>(
        "luxury",
        new SearchOptions
        {
            Filter = "Rating ge 4",
            Size = 10
        });

    // Assert
    Assert.AreEqual(200, response.GetRawResponse().Status);
    Assert.IsNotNull(response.Value);

    await foreach (SearchResult<Hotel> result in response.Value.GetResultsAsync())
    {
        Assert.GreaterOrEqual(result.Document.Rating, 4);
    }
}
```

### Testing New API Features

1. Add test methods that exercise the new feature
2. Verify correct serialization/deserialization
3. Test edge cases and error conditions
4. Add sample code to the Samples folder

### Test Naming Conventions

```csharp
// Good names - descriptive and specific
[Test] public async Task Search_WithFilter_ReturnsFilteredResults() { }
[Test] public async Task CreateIndex_WithVectorField_Succeeds() { }
[Test] public async Task GetDocument_NotFound_ThrowsException() { }

// Bad names - vague
[Test] public async Task Test1() { }
[Test] public async Task SearchWorks() { }
```

## Troubleshooting Tests

### Recording Mismatch

If tests fail with recording mismatches after API changes:

1. Delete existing recordings in `SessionRecords/`
2. Set `AZURE_TEST_MODE=Record`
3. Run the failing tests
4. Commit the new recordings

### Flaky Tests

For timing-dependent tests:
- Use `Recording.UtcNow` instead of `DateTimeOffset.UtcNow`
- Add polling/retry logic for eventual consistency
- Avoid fixed delays; use exponential backoff

### Test Isolation

Each test should:
- Create its own resources or use shared read-only resources
- Clean up any resources it creates
- Not depend on other tests running first
