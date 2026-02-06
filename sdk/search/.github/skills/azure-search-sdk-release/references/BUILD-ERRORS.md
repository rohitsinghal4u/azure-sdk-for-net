# Common Build Errors and Fixes

This document provides solutions for common build errors encountered when updating the Azure.Search.Documents SDK.

## CS0260: Missing partial modifier on declaration

**Error:**
```
error CS0260: Missing partial modifier on declaration of type 'TypeName'; another partial declaration of this type exists
```

**Cause:** A customization file exists that declares the type as partial, but the generated type doesn't match.

**Fix:** Check the autorest.md for proper type mapping or add the generated type to the appropriate customization file.

---

## CS0101: Namespace already contains a definition

**Error:**
```
error CS0101: The namespace 'Azure.Search.Documents.Models' already contains a definition for 'TypeName'
```

**Cause:** A type is being generated that conflicts with a custom implementation.

**Fix:**
1. Add a `remove-model` directive in autorest.md:
   ```yaml
   directive:
     - remove-model: TypeName
   ```
2. Or rename the generated type:
   ```yaml
   directive:
   - from: "searchservice.json"
     where: $.definitions.TypeName
     transform: $["x-ms-client-name"] = "InternalTypeName";
   ```

---

## CS0534: Does not implement inherited abstract member

**Error:**
```
error CS0534: 'DerivedType' does not implement inherited abstract member 'BaseType.AbstractMethod()'
```

**Cause:** A new abstract method was added to a base class in the swagger.

**Fix:** Add the abstract base class to `suppress-abstract-base-class` in autorest.md:
```yaml
suppress-abstract-base-class:
- BaseTypeName
```

---

## CS0246: Type or namespace could not be found

**Error:**
```
error CS0246: The type or namespace name 'NewTypeName' could not be found
```

**Cause:** A new type is referenced but not generated or imported.

**Fix:**
1. Check if the type is defined in the swagger
2. Ensure the type isn't removed by a directive
3. Add a using statement if it's in a different namespace
4. Create the type manually if it's a custom type

---

## CS0029: Cannot implicitly convert type

**Error:**
```
error CS0029: Cannot implicitly convert type 'OldType' to 'NewType'
```

**Cause:** A property type changed in the swagger.

**Fix:**
1. Check if a CodeGenModel mapping needs updating
2. Add explicit conversion operators if needed
3. Update the customization to match the new type

---

## CS1503: Argument type mismatch

**Error:**
```
error CS1503: Argument 1: cannot convert from 'TypeA' to 'TypeB'
```

**Cause:** Method signatures changed in the generated code.

**Fix:**
1. Update custom code to use new signatures
2. Check if wrapper methods need updating
3. Verify CodeGenModel mappings are correct

---

## CS0111: Type already defines a member with same parameter types

**Error:**
```
error CS0111: Type 'TypeName' already defines a member called 'MethodName' with the same parameter types
```

**Cause:** A custom method conflicts with a newly generated method.

**Fix:**
1. Remove the custom method if the generated one is sufficient
2. Use a `remove-operation` directive to remove the generated method
3. Rename one of the methods

---

## Swagger-related Errors

### Missing discriminator

**Error:**
```
warning: Type 'BaseType' is missing a discriminator
```

**Fix:** Add discriminator in autorest.md:
```yaml
directive:
  from: swagger-document
  where: $.definitions.BaseType
  transform: >
    $["discriminator"] = "@odata.type";
```

### Missing type definition

**Error:**
```
warning: Type definition missing for 'TypeName'
```

**Fix:** Add explicit type in autorest.md:
```yaml
directive:
- from: swagger-document
  where: $.definitions.*
  transform: >
    if (typeof $.type === "undefined") {
        $.type = "object";
    }
```

---

## Test Compilation Errors

### Missing test utilities

**Error:**
```
error CS0246: The type or namespace name 'SearchResources' could not be found
```

**Fix:** Ensure the test project references Azure.Core.TestFramework and the test utilities are properly included.

### Recording file issues

**Error:**
```
TestPlaybackMismatchException: Request URI doesn't match
```

**Fix:**
1. Re-record the affected tests with `AZURE_TEST_MODE=Record`
2. Update sanitizers if new sensitive data is being logged
3. Check if API paths changed

---

## Runtime Errors in Tests

### Deserialization failures

**Error:**
```
System.Text.Json.JsonException: The JSON value could not be converted to TypeName
```

**Fix:**
1. Check if new required properties were added
2. Verify enum values match between swagger and SDK
3. Update test data to include new required fields

### Null reference exceptions

**Error:**
```
System.NullReferenceException: Object reference not set to an instance of an object
```

**Fix:**
1. Check if nullable annotations changed
2. Add null checks in custom code
3. Verify model factory methods initialize all required properties
