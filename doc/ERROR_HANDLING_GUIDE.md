# Error Handling Guide

> **Deprecated**: This document has been replaced by [UNIFIED_ERROR_GUIDE.md](./UNIFIED_ERROR_GUIDE.md).

Please refer to the unified error guide for the latest error handling patterns.

## Quick Summary of Changes

The new unified error guide introduces:

1. **Simplified Exception Hierarchy**: Single `AppException` sealed class with `code` + `debugMessage`
2. **No Result Pattern**: Repository returns `Future<Entity>` directly (pass-through errors)
3. **Code-based i18n**: UI converts error codes to messages using `toMessage(context)`
4. **AsyncValue.guard()**: Presentation layer automatically catches errors

## Migration

If you're using the old patterns (Result, Failure, domain-specific exceptions), see [UNIFIED_ERROR_GUIDE.md](./UNIFIED_ERROR_GUIDE.md) for migration guidance.
