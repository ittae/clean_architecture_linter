# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.2] - 2026-06-25

### Changed

- `riverpod_ref_after_async_gap`: narrowed the tracked `ref` members to `read`, `watch`, and `listen`. `ref.invalidate` and `ref.refresh` after an `await` are no longer reported — they are the idiomatic "mutate then re-fetch" trigger that is expected to run after the await and cannot be resolved by the rule's capture-before-await guidance, so flagging them only produced noise.

### Fixed

- `riverpod_ref_after_async_gap`: broadened control-flow detection so `ref` usage after an `await` that lives in a control-flow header is no longer missed — `await`s in `if`/`while` conditions, `for` conditions, and `for-in` iterables are now counted as preceding gaps for the dependent body, while an `await` confined to a `for` updater is not. This closes false negatives left by the ancestor-block walk. (ITT-914, ITT-919)

## [2.1.1] - 2026-06-25

### Fixed

- `riverpod_ref_after_async_gap`: removed control-flow false positives. The previous implementation collected every `await` in a function body into a flat offset list and flagged any tracked `ref` call positioned after it, which incorrectly reported `ref` usage in mutually exclusive sibling branches (an `else` branch flagged because of an `await` in the `if` branch, or a `switch` case flagged because of an `await` in another case). Detection now walks the ref call's ancestor blocks and only counts `await`s that sequentially precede it on its own execution path; `await`s in a `try` body are still counted for `ref` usage in the matching `catch`/`finally`, and nested function bodies are treated as separate scopes.

## [2.1.0] - 2026-06-24

### Added

- `riverpod_ref_after_async_gap`: advisory INFO lint for `ref.read`, `ref.watch`, `ref.listen`, `ref.invalidate`, and `ref.refresh` after `await` in public Riverpod provider/notifier methods and async callbacks. The first version is intentionally narrow to reduce false positives: it only scans `lib/**/presentation/**/providers/**`, skips generated/test files and private helpers, and does not report `state = ...` after `await`.
- Package-named public library entrypoint `lib/clean_architecture_linter.dart` exporting `CleanArchitectureUtils`, so the package keeps a conventional importable library alongside the analyzer plugin `lib/main.dart` entrypoint.

## [2.0.1] - 2026-06-06

### Fixed

- **Consumer CI hang (`flutter analyze` never returns).** Capped `analysis_server_plugin` to `>=0.3.4 <0.3.15` and `analyzer` to `>=9.0.0 <13.0.0`. Root-caused via a controlled experiment: a consumer resolving the plugin against **asp 0.3.16 / analyzer 13.1** intermittently **hangs during plugin-isolate load/analysis** (shard never completes, 20 min+), while the same code on **asp 0.3.14 / analyzer 12.1** completes in ~5 min. The hang is in the upstream asp/analyzer-13.x plugin host, not in this package's rules (all rule visitors are loop-safe; a larger consumer on 12.1 passes). Consumers that also use `riverpod_lint` were already unaffected (it caps them at asp 0.3.14/analyzer 12.1). Consumers on `^2.0.0` pick this up automatically. The analyzer-13 range will be restored once the upstream host issue is resolved.

## [2.0.0] - 2026-06-05

> **Stable v2.0 release.** First stable release on the official [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin), validated against consumer projects (`ittae`, `flutter_boilerplate`) which fully migrated off `custom_lint`. See [2.0.0-dev.1] below for the full breaking-change list.

### Added

- **analyzer 9–13 compatibility.** Widened the analyzer constraint to `>=9.0.0 <14.0.0` and introduced a runtime AST compatibility layer (`analyzer_ast_compat`) bridging renamed analyzer APIs (formal parameter / named argument / class & extension members). This lets the plugin load across analyzer 9–13 and **coexist with other analysis_server_plugin plugins such as `riverpod_lint`** in a single consumer (ITT-338).

### Fixed (since `2.0.0-dev.1`)

- `repository_pass_through`: false report on non-`Future` `Result` returns and over-flagging of nested try-catch blocks (ITT-301).
- `circular_dependency`: false positive reporting cycles that do not contain the analyzed file (ITT-290).
- `repository_interface`: now detects data-layer models exposed inside nested generics (e.g. `Future<Result<UserModel>>`, `Future<List<UserModel>>`) via recursive type-argument inspection (ITT-291).
- `model_field_duplication`: replaced `startsWith`-based primitive detection with exact base-type matching (fixes false negatives for `Settings`/`Interval`/`MapLocation`/`Boolean`), added missing SDK types (`num`/`Object`/`dynamic`/`Iterable`), and stopped flagging record / function / structural-typed fields (ITT-295, ITT-380).
- `datasource_abstraction`: correct `lib/`→`test/` resolution for relative paths so a present test file is no longer missed (ITT-296).
- presentation rules: detect `try { } on X catch` data-exception handling (`CatchClause`), narrow over-broad `state = AsyncValue` matching, de-duplicate `!ref.mounted` reports, and fix the `extension_location` correction message (ITT-304).

## [2.0.0-dev.1] - 2026-05-31

> **v2.0 first dev release (analysis_server_plugin migration).** Pre-release; the stable `2.0.0` follows once the v2 contract is validated against consumer projects.

### 💥 Breaking Changes

- **Migrated from `custom_lint` to the official [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin)**, following the archival of upstream [invertase/dart_custom_lint](https://github.com/invertase/dart_custom_lint) and the original author's migration recommendation.
- **`analysis_options.yaml` format change**: lint activation moves from `analyzer: plugins: - custom_lint` to the top-level `plugins: clean_architecture_linter: <version>` map. The `analyzer: exclude:` block is unchanged.
- **`custom_lint` dependency removed**: consumers no longer add `custom_lint` as a dev_dependency, and the analyzer 9 / Riverpod 3+ `pubspec_overrides.yaml` workaround is no longer required.
- **CLI change**: lint runs via `dart analyze` / `flutter analyze` instead of `dart run custom_lint`.
- **Minimum Dart SDK raised to `^3.10.0`** (`analysis_server_plugin` requires Dart 3.10+).
- **Dependencies pinned to `analysis_server_plugin: ^0.3.15` + `analyzer: ^13.0.0`** so the plugin loads in-process under the analyzer shipped with current Dart/Flutter SDKs (Dart 3.12 / analyzer 13).

### 🔧 Changed

- All **33 rules** are registered in the v2 `analysis_server_plugin` plugin entrypoint (`lib/main.dart`) as default-enabled rules; per-rule severity is preserved from v1 (most WARNING, 7 INFO). Rule names and diagnostic messages remain equivalent to v1.
- Migrated all rule + helper AST traversal to the **analyzer 13 AST API** (`ClassDeclaration.namePart.typeName` / `ClassBody.members`, `RegularFormalParameter`, `NamedArgument`). Detection logic, messages, and severities are unchanged — only the AST accessors were updated.

### 🗑️ Removed

- Removed the v1 `custom_lint` entrypoint (`lib/clean_architecture_linter.dart`), all 34 `*_custom_lint_rule.dart` implementations, the `CleanArchitectureLintRule extends DartLintRule` base class, and the corresponding v1 tests. `CleanArchitectureUtils`, the shared mixins, the v2 rules, and the v2 test harness are retained.

### 📖 Docs

- Added [MIGRATION.md](MIGRATION.md) — v1 → v2.0 consumer migration guide (change table, step-by-step procedure, known differences).
- Flipped `README.md` / `README_KO.md` install guides to the v2 `plugins:` + `dart analyze` workflow and removed the v1 analyzer-9 compatibility workaround section.

## [1.3.2] - 2026-05-29

### 🔧 Changed

- Widened the direct `analyzer` constraint to `>=8.4.0 <10.0.0` so consumers on the analyzer 9 line (freezed 3.x, riverpod_generator 4.x, riverpod_lint 3.1.x) no longer need to override `clean_architecture_linter` itself in `pubspec_overrides.yaml`.
- Hardened the `DiagnosticReporter` compatibility layer with a typed `LintCode` bridge, severity-name mapping, and cached analyzer lint codes.

### 📖 Docs

- Added **Compatibility — analyzer 9 / Riverpod 3+** sections to `README.md` and `README_KO.md` covering: the archived `invertase/dart_custom_lint` upstream, a verified `pubspec_overrides.yaml` workaround for `custom_lint*`, a CI gitignore caveat for Flutter projects, and cleanup checkpoints leading up to v2.0 (analysis_server_plugin migration).

### 🧪 Tests

- Added unit coverage for analyzer lint code bridging, including metadata preservation, default severity handling, and cache reuse.

## [1.3.1] - 2026-05-05

### 🛠 Maintenance

- D 방향 reusable 워크플로우 적용 (Claude Code Review + mention responder)
- `karpathy-guidelines` 스킬 준수 줄을 CLAUDE.md에 추가
- `dart format` 미적용 파일 정리 (CI 통과 위함)

코드 로직 변경 없음 — 의존성/콘텐츠 안정. 1.3.0과 동등하게 사용 가능.

## [1.3.0] - 2026-02-15

### ✨ Added

- **P0 error-handling policy tightening** for pass-through + AsyncValue architecture
  - `repository_pass_through`: detects unnecessary `try-catch` rewrapping in Repository public methods
  - `usecase_no_result_return`: stronger Result/Either detection including typedef alias cases
  - `presentation_use_async_value` / `presentation_no_throw`: stronger detection for swallowed exceptions and direct business exception branching in presentation
- **Lint profiles**
  - `docs/config/lint_profile_balanced.yaml`
  - `docs/config/lint_profile_strict.yaml`

### 🔧 Changed

- Analyzer compatibility updates (DiagnosticReporter/DiagnosticSeverity/name/diagnosticCode)
- Documentation/messages aligned to **pass-through + AsyncValue** policy (removed stale Result-centric guidance)

### 🧪 Tests

- Added real AST-based tests for typedef alias Result detection in `return_type_validation_mixin_test.dart`
- `flutter analyze` and `dart test` pass

## [1.2.0] - 2026-01-19

### ✨ Added (2 new rules)

- **ref_mounted_usage** - Detects `ref.mounted` usage in Riverpod providers
  - Using `ref.mounted` to guard async operations masks design problems
  - Encourages proper patterns: AsyncValue, ref.listen, or completing async work before navigation
  - Only checks in `/presentation/` and `/providers/` directories
  - Severity: WARNING

- **riverpod_keep_alive** - Warns against unnecessary `@Riverpod(keepAlive: true)`
  - `keepAlive: true` should only be used for truly global state (auth, settings, cache)
  - Warns when used on feature-specific providers (e.g., TodoListNotifier)
  - Skips infrastructure providers (DataSource, Repository, UseCase, Service, Client, API)
  - Valid patterns: auth, user, session, settings, preferences, config, theme, locale, cache, analytics, notification, connectivity, permission
  - Severity: WARNING

### 📊 Statistics

- **Total rules: 33** (was 31 in v1.1.0)
  - Presentation layer rules: 13 (was 11)

## [1.1.0] - 2026-01-09

### 🚀 Breaking Changes

- **Pass-through Repository Pattern** - Result 패턴 제거, pass-through 패턴으로 전환
  - Repository는 이제 `Future<Entity>`를 직접 반환 (권장)
  - `Future<Result<Entity, Failure>>` 사용 시 경고 표시
  - 에러는 DataSource에서 발생하여 Presentation까지 pass-through
  - `AsyncValue.guard()`로 에러 자동 캐치

### ✨ Added

- **AppException 타입 인식** - `exception_validation_mixin`에 AppException 타입 세트 추가
  - 표준 AppException 타입: `AppException`, `NetworkException`, `TimeoutException`, `ServerException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `InvalidInputException`, `ConflictException`, `CacheException`, `UnknownException`
  - `isAppExceptionType()` 메서드 추가
  - `isAllowedWithoutPrefix()`가 AppException 타입 인식

- **Loading 필드 감지** - `presentation_use_async_value` 규칙 강화
  - `isLoading`, `loading`, `isSubmitting`, `submitting`, `isFetching`, `fetching`, `isProcessing`, `processing` 필드 감지
  - Freezed State에서 수동 로딩 상태 관리 금지 (AsyncValue가 자동 관리)

### 🔄 Changed

- **repository_must_return_result** - Result 패턴 사용 시 경고
  - 이전: `Future<Entity>` 또는 `Future<Result<Entity, Failure>>` 모두 허용
  - 이후: `Future<Entity>` 권장, Result 사용 시 WARNING

- **repository_must_return_result** → **repository_pass_through** (이름 변경)
  - 규칙 이름이 pass-through 패턴을 더 명확하게 반영

- **repository_no_throw** - 문서 업데이트
  - Pass-through 패턴 중심으로 문서 재작성
  - AppException 타입 throw 허용
  - 비표준 예외 throw 시 INFO 레벨 경고

- **datasource_exception_types** - AppException 타입 체크 추가
  - `isAppExceptionType()` 체크 추가
  - DataSource에서 AppException 타입만 throw 허용

### ⚠️ Deprecated

- **usecase_must_convert_failure** - Pass-through 패턴으로 인해 더 이상 필요 없음
  - UseCase에서 Failure→Exception 변환 불필요
  - 에러가 DataSource에서 Presentation까지 직접 전달됨
  - 규칙은 유지되지만 no-op (아무 동작 안함)

- **failure_naming_convention** - Failure 클래스 사용 자체를 경고
  - Result 패턴 제거로 Failure 클래스 불필요
  - 규칙이 Failure 클래스 정의 시 경고 표시
  - AppException 사용 권장

### 📝 Documentation

- **CLAUDE.md** - Pass-through 패턴 중심으로 업데이트
  - Result 패턴 예제 제거
  - STATE_MANAGEMENT_GUIDE.md 참조 추가

- **doc/UNIFIED_ERROR_GUIDE.md** - 통합 에러 핸들링 가이드 추가
- **doc/STATE_MANAGEMENT_GUIDE.md** - 상태 관리 가이드 추가

### 🧪 Tests

- 모든 테스트 업데이트 (568개 테스트 통과)
  - `exception_validation_mixin_test.dart` - AppException 타입 테스트 추가
  - `repository_no_throw_rule_test.dart` - Pass-through 패턴 테스트로 변경
  - `exception_handling_integration_test.dart` - 전체 리팩토링

## [1.0.11] - 2025-12-31

### 🔧 Fixed

- **layer_dependency_rule** - DI Provider 파일에서 Data Models import 금지 추가
  - DI/Provider 파일(`*_providers.dart`, `providers.dart`)에서 DataSource/Repository 구현체 import는 허용
  - 하지만 **Data Models(`/data/models/`)** import는 DI 파일에서도 **금지**
  - Data Models는 Data 레이어 내부용이며, Presentation 레이어(DI 포함)에서 사용하면 안됨
  - 새로운 `_isDataModelImport()` 헬퍼 메서드 추가

## [1.0.10] - 2025-12-10

### ✨ Added

- **allowed_instance_variables_rule** - Extended infrastructure SDK type support
  - Google Mobile Ads SDK: `BannerAd`, `InterstitialAd`, `RewardedAd`, `NativeAd`, `AppOpenAd`, `AdWidget`
  - In-App Purchase SDK: `InAppPurchase`, `ProductDetails`, `PurchaseDetails`
  - `Subscription` type (StreamSubscription, etc.)
  - These SDK types require mutable state for lifecycle management

### 🎨 Improved

- **Correction messages** - Made all rule correction messages more concise for better VS Code PROBLEMS panel display
  - Removed verbose examples from correction messages
  - Focused on brief, actionable fix instructions
  - Affected rules: `failure_naming_convention`, `model_naming_convention`, `exception_message_localization`, `presentation_no_data_exceptions`, `presentation_use_async_value`, `riverpod_provider_naming`, `riverpod_ref_usage`, `widget_no_usecase_call`, `widget_ref_read_then_when`

## [1.0.9] - 2025-11-12

### ✨ Added (1 new rule)

- **allowed_instance_variables_rule** - Enforce stateless architecture in UseCase, Repository, and DataSource classes
  - **UseCase**: Only `final`/`const` Repository and Service dependencies allowed
  - **Repository**: Only `final`/`const` DataSource and infrastructure dependencies (primitives, Stream, HTTP, Firebase, Database) allowed
  - **DataSource**: Only `final`/`const` primitives and infrastructure dependencies allowed
  - Mock/Fake classes can have mutable state for testing purposes
  - Prevents hidden state bugs and enables testability
  - Comprehensive validation with clear error messages
  - Total rules: **34** (was 33)
  - Cross-layer rules: 3 (was 2)

### 🔧 Fixed

- **Domain Layer dart:io Support** - Fixed false positive for `dart:io` imports in domain layer
  - `domain_purity_rule`: Now allows `dart:io` imports for type references (File, Directory) in domain layer method signatures
  - Actual I/O operations should still be implemented in data layer
  - Addresses legitimate use cases where domain repositories need File type parameters

- **Database Library Support** - Added proper exceptions for database libraries (ObjectBox, Realm, Isar, Drift)
  - `layer_dependency_rule`: Data layer can now import `package:objectbox/`, `package:realm/`, `package:isar/`, `package:drift/`
  - `datasource_abstraction_rule`:
    - Private methods/getters (starting with `_`) are now skipped from validation
    - Database entity types (Box<*Entity>, *ObjectBoxEntity, *RealmEntity, etc.) are allowed in return types
  - `model_structure_rule`: Models with database annotations (@Entity, @RealmModel, @collection, etc.) are exempt from @freezed requirement
  - These libraries require mutable classes with their own code generation, incompatible with Freezed

### 📝 Documentation

- **CLAUDE.md**
  - Added "Instance Variables & Stateless Architecture" section with comprehensive examples
  - Added "Domain Layer with dart:io Types" example showing allowed usage of File type in repository signatures
  - Updated Layer Dependencies section to clarify dart:io is allowed for type references
  - Documented allowed infrastructure types for each layer
  - Explained Mock/Fake exception for testing
  - Added "Database Library Exceptions" section with comprehensive examples
  - Explained why database Models don't use @freezed (mutability requirement)
  - Listed all allowed database imports and annotations

- **README.md**
  - Updated rule count from 33 to 34
  - Added allowed_instance_variables_rule to Core Clean Architecture Principles section
  - Added ObjectBox example in "Good Examples" section
  - Documented database library exceptions with clear note

- **README_KO.md**
  - Updated rule count from 29 to 34
  - Synchronized with English README structure

### 🎨 Improved

- **exception_naming_convention_rule** - More concise error messages for better VS Code PROBLEMS panel display

## [1.0.8] - 2025-10-30

### 🔧 Changed

- **Minimum Dart SDK updated to 3.7.0**
  - Updated from ^3.6.0 to ^3.7.0 for better compatibility
  - Downgraded lints from ^6.0.0 to ^5.1.1 for Dart 3.7.0 compatibility
  - All existing features and tests remain compatible
  - No breaking changes to API or functionality

## [1.0.6] - 2025-10-28

### 🔧 Fixed

- **Fixed package dependencies structure**
  - Moved `analyzer`, `custom_lint_builder`, and `path` back to `dependencies`
  - These packages are used in `lib/` code and must be runtime dependencies
  - `custom_lint`, `lints`, and `test` remain in `dev_dependencies`
  - Note: End users still add this package to `dev_dependencies` in their projects

### 📦 Dependencies

- Runtime dependencies (used in lib/): `analyzer`, `custom_lint_builder`, `path`
- Dev dependencies (development only): `custom_lint`, `lints`, `test`

## [1.0.5] - 2025-10-28

### 🔧 Changed

- **Upgraded custom_lint_builder** from `0.7.6` to `0.8.0`
  - Ensures compatibility with riverpod_generator 3.0.0
  - Upgraded custom_lint dev dependency to `0.8.0`
  - All 527 tests pass successfully
  - No breaking API changes required
  - Maintains backward compatibility

### 📦 Dependencies

- `custom_lint_builder`: ^0.7.6 → ^0.8.0
- `custom_lint`: ^0.7.6 → ^0.8.0 (dev dependency)

## [1.0.4] - 2025-10-22

### ✨ Added (2 new rules)

- **widget_no_usecase_call rule** - Enforce proper Riverpod architecture: Widget → Provider → UseCase
  - Prevents widgets from directly importing or calling UseCases
  - Enforces proper separation: Widgets should only interact with Providers
  - Detects UseCase imports in widget/page files
  - Detects direct UseCase provider calls via `ref.read()` or `ref.watch()`
  - Provides comprehensive correction messages with proper Riverpod patterns
  - Severity: WARNING

- **widget_ref_read_then_when rule** - Prevent anti-pattern of using `.when()` after `ref.read()`
  - Detects `ref.read()` followed by `.when()` in the same function
  - Enforces proper patterns: `ref.watch()` + `.when()` for UI, `ref.listen()` for side effects
  - Prevents misuse of AsyncValue state management
  - Explains why this pattern is incorrect (state is already settled after operation)
  - Provides three correct alternatives based on use case
  - Severity: WARNING

### 🔄 Changed

- **presentation_no_throw rule** - Enhanced detection capabilities
  - Now checks `/providers/` directory in addition to `/states/` and `/state/`
  - Improved State/Notifier class detection with three methods:
    1. Detects `@riverpod` annotation (Riverpod Generator pattern)
    2. Detects `extends AsyncNotifier/Notifier/StateNotifier/ChangeNotifier`
    3. Detects generated classes with `_$` prefix
  - More robust validation of Riverpod-based state management classes
  - Better coverage of modern Riverpod code generation patterns

- **Total rules: 31** (was 29 in v1.0.3)
  - Added: 2 new presentation layer rules
  - Modified: 1 rule (presentation_no_throw)

### 📝 Documentation

- Enhanced CLAUDE.md with comprehensive Riverpod state management patterns
  - Added 3-tier provider architecture documentation
  - Documented Entity Providers (AsyncNotifier), UI State Providers (Notifier), and Computed Logic Providers
  - Added detailed examples of AsyncValue.when() pattern usage
  - Included common violations and their solutions
  - Comprehensive Widget usage examples with proper error handling

### 📊 Statistics

- **Files changed**: 5 files
  - 2 new rule implementations
  - 1 rule enhancement
  - 1 test file
  - 1 main registration file
- **Lines added**: ~600+ lines
  - widget_no_usecase_call_rule.dart: 265 lines
  - widget_ref_read_then_when_rule.dart: 301 lines
  - Enhanced presentation_no_throw_rule.dart
- **Test coverage**: Comprehensive unit tests for widget_no_usecase_call rule

## [1.0.3] - 2025-10-17

### ✨ Added (3 new rules)

- **model_entity_direct_access rule** - Enforce `.toEntity()` method usage instead of direct `.entity` property access in Data layer
  - Prevents direct `.entity` access in Repository and DataSource implementations
  - Allows direct access inside extension methods (where conversion logic is implemented)
  - Allows direct access in test files
  - Provides clear architectural boundaries for Model → Entity conversion

- **model_naming_convention rule** - Enforce naming conventions for Models in Data layer
  - Models must end with `Model` suffix
  - Validates proper naming in `data/models/` directories
  - Helps maintain consistent codebase structure

- **presentation_no_throw rule** - Enforce no exception throwing in Presentation layer
  - Presentation layer should use AsyncValue for error handling
  - No direct exception throws in widgets, states, or notifiers
  - Aligns with Riverpod best practices

### 🔄 Changed

- **model_conversion_methods rule** - Updated to align with Dart/Freezed best practices
  - Now only requires `toEntity()` method in extensions (mandatory)
  - `fromEntity()` implementation is optional and should use factory constructors in the Model class
  - Removed extension static method pattern (not idiomatic in Dart)
  - Updated error messages to guide users toward factory constructor pattern

- **Total rules: 29** (was 26 in v1.0.2)
  - Added: 3 new rules
  - Modified: 1 rule (model_conversion_methods)

### 🐛 Bug Fixes

- Fixed `exception_naming_convention` rule to skip `core/` directory (framework-level exceptions)
- Fixed `failure_naming_convention` rule to skip `core/` directory
- Fixed data file detection to correctly exclude `domain/repositories/` from data layer
- Fixed `model_conversion_methods` rule incorrectly requiring extension static methods
- Improved error severity levels across multiple rules

### 📝 Documentation

- Updated CLAUDE.md with comprehensive `.entity` access control guidelines
- Updated Data Layer rules README with all 3 new rules documentation
- Enhanced Model conversion pattern examples with factory constructor approach
- Added 48 new lines of documentation in CLAUDE.md
- Added 55 new lines in Data Layer README
- Updated README.md with accurate rule count

### 📊 Statistics

- **Files changed**: 23 files
- **Lines added**: ~1,237 lines
- **New test coverage**: 398+ lines of new tests for new rules
- **Documentation improvements**: 100+ lines across multiple files

## [1.0.2] - 2025-10-09

### 🗑️ Removed

- **entity_business_logic rule** - Removed overly strict rule requiring all entities to have business logic methods
  - Not all entities need business logic (e.g., events, DTOs, value objects)
  - Users reported this as too restrictive for practical use cases
  - Total rules: 27 → 26

### 📝 Documentation

- Fixed incomplete code snippet in README.md examples section
- Synchronized README_KO.md structure with README.md (removed inconsistent sections)
- Updated rule count from 27 to 26 in both English and Korean READMEs

## [1.0.1] - 2025-10-09

### 📝 Documentation

- Updated README.md with accurate rule count (27 rules instead of 16+)
- Updated README_KO.md with accurate rule count and simplified structure
- Simplified configuration section, removed non-existent Core/Strict modes
- Reorganized rules documentation with clear categorization
- Removed unnecessary documentation files (VALIDATION_REPORT.md, ERROR_HANDLING_RULES_TODO.md)

### 🔧 CI/CD

- Improved publish workflow to use official OIDC-based authentication
- Added quality checks (tests, analyzer, format) before publishing
- Aligned publish workflow with CI workflow for consistency

## [1.0.0] - 2025-10-09

### 🎉 Initial Release

A comprehensive custom lint package that automatically enforces Clean Architecture principles in Flutter/Dart projects.

### ✨ Added

#### New Utility Infrastructure
- **CleanArchitectureUtils** - Centralized utility class for common Clean Architecture validations
  - File path detection (isDomainFile, isDataFile, isPresentationFile)
  - Component detection (isUseCaseFile, isDataSourceFile, isRepositoryFile)
  - Class name validation (isUseCaseClass, isDataSourceClass, isRepositoryClass)
  - Type checking (isVoidType, isResultType)
  - Exception pattern recognition (isDataException, isDomainException)
  - AST utilities (findParentClass, isPrivateMethod, isRethrow)
  - Feature extraction (extractFeatureName)

#### New Mixin System
- **ExceptionValidationMixin** - Exception naming and validation logic
- **ReturnTypeValidationMixin** - Return type validation for methods
- **RepositoryRuleVisitor** - Repository-specific validation

### 🔄 Changed

#### Code Organization
- **170 lines removed** (13.6% code reduction) through deduplication
- Consolidated 13 rules to use shared mixins and utilities
- Improved consistency across all validation logic
- Enhanced test coverage with **76 comprehensive tests**

#### Refactored All 24 Rules
All lint rules were refactored to leverage the new utility and mixin infrastructure:

**Cross-Layer Rules (4)**
- LayerDependencyRule
- CircularDependencyRule
- BoundaryCrossingRule
- TestCoverageRule

**Domain Layer Rules (4)**
- DomainPurityRule
- DependencyInversionRule
- RepositoryInterfaceRule
- UseCaseNoResultReturnRule
- UseCaseMustConvertFailureRule
- ExceptionNamingConventionRule
- ExceptionMessageLocalizationRule

**Data Layer Rules (7)**
- ModelStructureRule
- DataSourceAbstractionRule
- DataSourceNoResultReturnRule
- RepositoryMustReturnResultRule
- RepositoryNoThrowRule
- DataSourceExceptionTypesRule
- FailureNamingConventionRule

**Presentation Layer Rules (6)**
- NoPresentationModelsRule
- ExtensionLocationRule
- FreezedUsageRule
- RiverpodGeneratorRule
- PresentationNoDataExceptionsRule
- PresentationUseAsyncValueRule

### 📈 Improved

#### Documentation
- Added comprehensive ARCHITECTURE.md with system overview
- Created CONTRIBUTING.md with development guidelines
- Added RULE_DEVELOPMENT_GUIDE.md for contributors
- Enhanced inline documentation across all files

#### Testing
- **76 comprehensive tests** covering all utilities and mixins
- 100% coverage of utility methods
- Extensive mixin behavior validation

#### Code Quality
- Eliminated 170 lines of duplicate code
- Consistent validation patterns across all rules
- Improved error messages with better context
- Enhanced maintainability through shared components

### 🔧 Technical Details

#### Dependencies
- Dart SDK: ^3.6.0
- analyzer: ^7.6.0
- custom_lint_builder: ^0.7.6
- path: ^1.9.1
