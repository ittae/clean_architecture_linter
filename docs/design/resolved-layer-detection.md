# Resolved layer detection

Status: design for the remaining migration. Owner has approved the direction. The published baseline is 2.8.0 ([#189](https://github.com/ittae/clean_architecture_linter/pull/189)). `LayerResolver` is on main ([#193](https://github.com/ittae/clean_architecture_linter/pull/193)); no rule calls it. This document does not change rule behavior. Step 2 ships as 3.0.0 from that 2.8.0 baseline, with the existing diagnostics left default-on. There is no shadow-diagnostic period. Unknown code stays exempt for `layer_dependency`, `boundary_crossing`, and `circular_dependency`. In that same 3.0.0 step, `domain_purity` reports a domain import of an in-package unknown library when `package:flutter`, `dart:ui`, `dart:io`, or an infrastructure package is reachable through unknown libraries only.

Audience: maintainers of `clean_architecture_linter`. The package is the public `analysis_server_plugin` that reports Clean Architecture violations from `dart analyze`.

## Verified toolchain

`dart pub get` on this repo resolves:

| Package | Version |
| --- | --- |
| `analysis_server_plugin` | 0.3.24 (`^0.3.23`) |
| `analyzer` | 14.5.0 (`>=14.3.0 <15.0.0`) |
| `_fe_analyzer_shared` | 109.0.0 |

API names below were read from those packages. `Source` is re-exported from `package:analyzer/source/source.dart` and is declared in `_fe_analyzer_shared` 109.0.0 with `Uri get uri` and `String get fullName`. Dart 3.13.5 `Uri.parse` was used to confirm path shape:

- `package:app/features/todo/domain/todo.dart` → path `app/features/todo/domain/todo.dart` (no leading slash)
- `dart:io` → path `io`
- `file:///tmp/app/lib/features/todo/data/todo.dart` → path `/tmp/app/lib/features/todo/data/todo.dart`. That path shape is real. It is not a layer input. A `file:` URI is `unknown` regardless of those segments, including when an ancestor directory is named `domain` or `data` (`file:///tmp/domain/app/lib/features/todo/data/todo.dart`).

## Current behavior

`lib/main.dart` registers 37 rules: 36 via `registerWarningRule` (default on) and one via `registerLintRule` (`riverpod_state_after_async_gap`, off until a consumer sets `diagnostics: riverpod_state_after_async_gap: true`). `lib/src/rules/cross_layer/test_coverage_rule.dart` exists and is not registered.

Every registered rule overrides `canUseParsedResult` to `true`. The analyzer default on `AnalysisRule` is `false` (`package:analyzer/src/analysis_rule/analysis_rule.dart` in 14.5.0). In `analysis_server_plugin` 0.3.24, `PluginServer._canUseParsedResult` returns false for a library when any enabled rule has `canUseParsedResult == false`. The parsed path builds `RuleContextWithParsedResults` from `getParsedUnit`. The resolved path calls `driver.getResolvedUnit` and builds `RuleContextWithResolvedResults` from a `ResolvedLibraryResult`. Today the whole plugin stays on parsed units.

Layer identity is a path substring. `CleanArchitectureUtils` (`lib/src/clean_architecture_linter_base.dart`) matches `/domain/`, `/data/`, `/presentation/`, `/widgets/`, `/usecases/`, `/repositories/`, and several aliases. `_normalizePath` only rewrites backslashes. It does not lowercase. Several rules lowercase before `contains`, including `layer_dependency` and `boundary_crossing`, so those rules and the shared helpers disagree on `Domain` versus `domain`.

Import checks classify `ImportDirective.uri.stringValue`, the literal in the file. A relative import that never spells the folder, and a barrel whose own URI is outside `/data/` and `/domain/`, never become a data or domain edge. The declaring library is not consulted.

Four rules are the hard boundary checks, and they still use those strings:

- `layer_dependency` — direction matrix, plus an `application` bucket for `/domain/usecases/` and `/domain/use_cases/`, and an `infrastructure` bucket for path segments and a fixed `package:` prefix list
- `circular_dependency` — same folder substrings, including `/widgets/`
- `domain_purity` — domain file path, then import-prefix and superclass-name lists
- `dependency_inversion` — domain-to-data and domain-to-presentation import strings, plus suffix lists

`dependency_inversion` treats a type whose name ends with `Impl`, `Implementation`, `Concrete`, `Client`, `Adapter`, or `Gateway` as a concrete implementation (`_isConcreteImplementation`). `repository_interface` treats a name ending in `Model`, `Dto`, or `Response` as a data model (`_isDataLayerModel`). `repository_implementation` decides interface versus implementation from the file path and from the `Repository` / `RepositoryImpl` suffixes.

Other recorded gaps, with the current code:

- `CleanArchitectureUtils.isRethrow` accepts only a `ThrowExpression`. `rethrow;` is a `RethrowExpression`, a sibling node (`rethrowExpression ::= 'rethrow'`), not the child of `throw`. `presentation_no_throw` registers `addThrowExpression` only, and its `_isRethrow` checks `ThrowExpression.expression is RethrowExpression`, which that grammar does not produce. `presentation_use_async_value` already walks `RethrowExpression` in `_RethrowFinder`.
- `presentation_no_throw._isStateOrNotifierClass` reads `extendsClause.superclass.name.lexeme` (the immediate superclass token) and `className.contains('State')`. The substring matches `Statement`. `ref_mounted_usage_rule` already walks `InterfaceElement.allSupertypes` for notifier classification.
- `riverpod_uncancelled_disposable` records the gap in source: helper bodies passed to `ref.onDispose` are not traversed, so a tear-off such as `ref.onDispose(subscription.cancel)` or `ref.onDispose(_dispose)` is invisible. That gap is recorded here and is not one of the PRs below.
- There is no rule that stops `features/x` from importing `features/y/data` or `features/y/presentation`.
- The only registered use-case rule is `usecase_no_result_return`. Nothing requires a single public `call`, and nothing forbids a use case from depending on another use case.

`ClassElement.isAbstract` is true only when the class has the `abstract` modifier. The analyzer documents that this is different from "has unimplemented members." A repository interface written without `abstract` still needs the existing structural method check.

## 1. Shared layer resolver

`lib/src/layer/layer_resolver.dart` is on main ([#193](https://github.com/ittae/clean_architecture_linter/pull/193)), with `test/src/layer/layer_resolver_test.dart`. It maps a resolved `Element` or `LibraryElement` to a feature and a layer. No rule calls it yet. Rules stop keeping private copies of `/domain/` and `/data/` when step 2 lands.

#193 is the resolver that exists, not a complete implementation of every rule in this section. Step 2 calls it only after it matches the rules below. The shipped gaps are: a `providers` segment is always presentation, including `core/providers` (this document keeps that pair `unknown`); a bare `usecases` or `use_cases` folder is promoted to `domain` (this document leaves it `unknown` with `useCaseLibrary` false); `repositories` is not a `data` segment (this document maps it to `data`). The `file:` rule below already matches #193.

Path conventions stay the configuration surface. There is no `analysis_options` path override today, and these PRs do not add one. The convention table is the folder vocabulary already used by `CleanArchitectureUtils` and by `layer_dependency`. A `file:` URI is `unknown` before any folder is read. Other kinds come only from the ordered segment rules in `### Classifying a URI`: `domain`; `data` plus `datasources`, `data_sources`, and `repositories`; `presentation` and the aliases `ui`, `widgets`, `screens`, `pages`, `views`, `states`, and `providers`, except a `providers` segment whose previous segment is `core`; `usecases` and `use_cases` only as the `useCaseLibrary` flag on a library that is already `domain`; infrastructure folders `infrastructure`, `services`, `external`; the existing infrastructure `package:` prefix list. The table is applied to the declaring library's canonical URI, not to import text and not to the part file currently being visited.

### Location type

```dart
enum LayerKind {
  domain,
  data,
  presentation,
  infrastructure,
  unknown,
  external,
}

class LayerLocation {
  final LayerKind kind;
  final String? feature;
  final bool useCaseLibrary;
  final bool infrastructurePackage;
  final Uri libraryUri;
}
```

`useCaseLibrary` is true only when the library's kind is `domain` and its path also has a `usecases` or `use_cases` segment. That is `layer_dependency`'s application bucket (`/domain/usecases/` and `/domain/use_cases/`). A `usecases` or `use_cases` segment does not by itself make the kind `domain`, and it does not set `useCaseLibrary`. `infrastructurePackage` preserves the existing `package:http/`, `package:dio/`, and sibling prefix list. Both flags are inputs to rules that already have those exceptions. They are not new diagnostics.

### Resolution entry points

Public types, all present in analyzer 14.5.0:

| Need | API |
| --- | --- |
| Current library inside a rule | `RuleContext.libraryElement` (`LibraryElement?` on the public `RuleContext`). The resolved implementation returns `definingUnit.unit.declaredFragment!.element`. |
| Canonical URI | `LibraryElement.uri`. The analyzer documents this as the same URI `firstFragment.source.uri` returns. |
| Part files of that library | `LibraryElement.fragments` (`List<LibraryFragment>`), including the defining unit and `part` units. Each fragment's file is `LibraryFragment.source` (`Source.uri`, `Source.fullName`). |
| Declaring library of a referenced element | `Element.library`. Null when the element is a `MultiplyDefinedElement` that is not in a single library. |
| Imported library | `ImportDirective.libraryImport` (`LibraryImport?`, null when the AST is unresolved) then `LibraryImport.importedLibrary`. |
| Export directive target | `LibraryExport.exportedLibrary`. |
| Libraries a library exports | `LibraryElement.exportedLibraries`. The getter's own doc says it ignores `hide` and `show`. |
| Type reference | `NamedType.element` (`Element?`) and `NamedType.type` (`DartType?`). |
| Supertype chain | `InterfaceType.allSupertypes` and `InterfaceType.element` (`InterfaceElement`). `InterfaceType.superclass` is only the immediate superclass. `InterfaceElement.allSupertypes` is the same chain on the element. |
| Class ownership | `ClassDeclaration.declaredFragment` (`ClassFragment?`) then `ClassFragment.element` (`ClassElement`, an `InterfaceElement`). |
| Abstract modifier | `ClassElement.isAbstract`. |
| SDK library | `LibraryElement.isInSdk`, `LibraryElement.isDartCore`, `LibraryElement.isDartAsync`. |
| Subtyping, when a rule already has a resolved type | `TypeSystem.isSubtypeOf` on `RuleContext.typeSystem`. `TypeProvider` in 14.5.0 has no `exceptionType` or `errorType`. |

`RuleContextWithParsedResults.libraryElement` throws `UnsupportedError` (`RuleContext with parsed results does not include a LibraryElement`). A rule that calls the resolver deletes `bool get canUseParsedResult => true` and inherits the default `false`. Production code under `lib/` stays on public libraries: `package:analyzer/dart/element/element.dart`, `package:analyzer/dart/element/type.dart`, `package:analyzer/dart/ast/ast.dart`, `package:analyzer/analysis_rule/rule_context.dart`. It does not import `package:analyzer/src/**`.

`LibraryImport.namespace` and `LibraryElement.exportNamespace` return `Namespace`. That class is declared in `package:analyzer/src/dart/resolver/scope.dart`. The resolver does not read it.

`Identifier` is marked `@ToBeDeprecated('Use NameExpression instead.')`. `NameExpression` and `NamedReadResolution` are `@experimental` in 14.5.0. `NamedReadResolutionWithElement.element` exists on that experimental type. The resolver's supported surface for references is `NamedType.element` and `ImportDirective.libraryImport`. Value-level tear-offs stay out of this sequence (see the `onDispose` note above). When a later change follows a tear-off, it uses `Identifier.element` until `NameExpression` is stable, and it says so in that PR.

`ThrowExpression.expression` is `@ToBeDeprecated('Use expression2 instead.')`. `expression2` is `@experimental`. Error-boundary work keeps the V1 `expression` getter and, for `rethrow;`, visits `RethrowExpression` directly so it does not need either getter.

### Classifying a URI

`resolveLibrary` reads `library.uri` and returns a `LayerLocation`. `resolveElement` returns null when `element.library` is null, and otherwise returns `resolveLibrary(element.library!)`.

Segment rules, in order:

1. Match the infrastructure `package:` prefix list (`package:http/`, `package:dio/`, and the sibling prefixes) before the general foreign-package `external` rule: `kind: external` and `infrastructurePackage: true`. This includes a null `RuleContext.package`. A match stops here.
2. `dart:` scheme, or `LibraryElement.isInSdk`, or a `package:` URI whose first path segment is not the package under analysis: `LayerKind.external` with `infrastructurePackage` false. When `RuleContext.package` is non-null, that value is the package under analysis. When it is null, the package under analysis is the `pubspec.yaml` name (`cal_v2_harness_app` for the harness temp package). A scratch file with no package name has no package under analysis, so every `package:` URI that step 1 did not match is foreign. A null package does not classify `package:` URIs with file-URI segment rules. A `package:` URI for the package under analysis skips segment 0 and then uses the step 4 priority on the remaining segments. A `file:` URI is not decided in this step. Infrastructure prefixes are already step 1, and a `dart:` URI is `external`. Every other foreign package is `external` with `infrastructurePackage` false, for both a null package and a non-null package. `package:data/foo.dart` is not `data`. `package:flutter/src/widgets/...` is `external`; later segments such as `widgets` are not layer hits.
3. A `file:` URI, and any other scheme that is not `dart` and not `package`, is `LayerKind.unknown` before any segment is read. Kind and `feature` are not taken from the absolute path. Ancestor directories and in-path folders do not classify it. `file:///tmp/domain/app/lib/features/todo/data/todo.dart` is `unknown` with `feature` null, not `domain` and not `data`. `file:///tmp/data/app/lib/main.dart` is `unknown`, not `data`. `file:///tmp/app/lib/features/billing/ui/page.dart` is `unknown`, not `presentation`, and `feature` is null. This is what #193 ships. Stripping the path to a guessed package root and then applying the priority below would still let a `file:` URI become a layer, which depends on finding that root from the checkout path. The resolver does not do that. A library whose canonical URI is `package:` is classified by steps 1, 2, and 4 on that `package:` URI. The `file:` path of the same source is not a second classification.
4. Otherwise inspect `uri.pathSegments` of the current package's `package:` URI. Skip segment 0 (the package name). Compare segments as written. Do not lowercase. Exactly one kind is chosen, by this priority, and the first hit wins:
   - `domain` — a segment equal to `domain`.
   - `data` — a segment equal to `data`, `datasources`, `data_sources`, or `repositories`.
   - `presentation` — a segment equal to `presentation`, or a segment equal to `ui`, `widgets`, `screens`, `pages`, `views`, `states`, or `providers`, except a `providers` segment whose immediately previous segment is `core`. That `providers` segment is not a presentation alias. Aliases are not limited to `features/<feature>/`; the `core`/`providers` pair is the exception that keeps the decided unknown exemption.
   - `infrastructure` — a segment equal to `infrastructure`, `services`, or `external`.
5. `useCaseLibrary` is true only when step 4 yielded `domain` and a `usecases` or `use_cases` segment is also present. This is the same definition as `LayerLocation.useCaseLibrary` above and as `layer_dependency`'s application bucket. `lib/features/todo/usecases/foo.dart` has no `domain` segment, so it is `unknown` and `useCaseLibrary` is false. It is not promoted to `domain`.
6. No hit in step 4: `LayerKind.unknown`. `feature` may still be set. `package:app/core/providers/foo.dart` and `lib/core/providers/foo.dart` are `unknown`, not `presentation`, so `layer_dependency`, `boundary_crossing`, and `circular_dependency` exempt them.
7. `feature` is the segment after a `features` segment, when that segment matches `[A-Za-z0-9_]+` (the same character class as `CleanArchitectureUtils`'s `/features/(\w+)/`). Otherwise null. `feature` is computed only for a `package:` URI that reached step 4. A `file:` URI does not get a feature from an ancestor or in-path `features` segment.

Skipping the package-name segment keeps `package:data/foo.dart` (a package named `data`) on `external`, not `data`, whether `RuleContext.package` is null or not. That is also what `contains('/data/')` does to that string today: the package name is not a `/data/` path segment. `package:app/domain/todo.dart` has a `domain` segment after `app` and is `domain`. `package:flutter/src/widgets/...` is `external` for a null package and for a known package. Foreign-package segments after the package name are not layer hits.

Step 4 is the only segment order. `domain` wins over `data`, `repositories`, `datasources`, `data_sources`, and presentation aliases, matching `isDataFile`, which refuses any path that contains `/domain/` before it accepts `/data/` or `/repositories/`. `features/todo/data/providers/foo.dart` is `data`. `features/todo/domain/repositories/foo.dart` is `domain`. `features/todo/repositories/foo.dart`, `features/todo/datasources/foo.dart`, and `features/todo/data_sources/foo.dart` are `data`. A library cannot be two kinds.

### Re-exports and barrels

The dependency target of a name is the declaring library of the resolved element, not the library that exported it.

`presentation/todo_page.dart` imports `package:app/features/todo/todo.dart`. That barrel's own URI has no layer segment, so the barrel library is `unknown`. The page mentions `TodoModel`, whose `NamedType.element.library.uri` is `package:app/features/todo/data/models/todo_model.dart`. The edge is presentation → data.

An import that is not referenced contributes only its `importedLibrary`. A barrel that exports data and is imported but unused does not, by itself, create a data edge. `exportedLibraries` is the wrong tool for a tighter check: it ignores `hide` and `show`, so a barrel that hides its data types would still look like a data export.

`show` and `hide` are already applied by resolution. A name that survives a `show` clause has an element. A hidden name has no reference to classify.

The barrel edge is the same set for `layer_dependency`, `boundary_crossing`, `circular_dependency`, and `domain_purity`:

- a direct import whose `importedLibrary` kind is `data` or `presentation`
- a referenced `NamedType` whose declaring library is `NamedType.element.library` (the library that declares the type, not the barrel that exported it)

`circular_dependency` does not read arbitrary referenced elements. Its referenced set is `NamedType` only, the same as the other three rules. Those rules still classify other kinds (`domain`, `infrastructure`, `external`, `unknown`) from the same two sources, `importedLibrary` and `NamedType.element.library`. The data/presentation pair above is the shared barrel edge, not a narrower matrix.

The unknown reachability walk is not a barrel edge. It only tests whether `package:flutter`, `dart:ui`, `dart:io`, or an infrastructure prefix is reachable through in-package `unknown` libraries. It does not follow `LibraryFragment.libraryExports`. A barrel that only `export`s a data library, and does not import it, is not a data edge unless a referenced `NamedType` resolves to that declaring library. `exportedLibraries` stays unused: it ignores `hide` and `show`.

### Part files

Elements declared in a part belong to the parent `LibraryElement`. The resolver uses `element.library.uri`, which is the library URI, including when `RuleContext.currentUnit.file.path` is the part file or a `.freezed.dart` / `.g.dart` sibling.

A part file that physically sits in `data/` while its library file sits in `domain/` is `domain`. `shouldExcludeFile` still skips generated files as analysis roots. It does not change the library's layer.

### Package URIs and relative URIs

`import '../domain/todo.dart'` and `import 'package:app/features/todo/domain/todo.dart'` resolve to one `LibraryElement` when they name the same library. The resolver classifies `importedLibrary.uri` and ignores `ImportDirective.uri.stringValue` for the layer decision. `DirectiveUriWithRelativeUri.relativeUri` is the literal relative URI. `DirectiveUriWithLibrary.library` is the resolved library. Rules use `libraryImport.importedLibrary` and do not re-resolve the string.

### Unknown layer policy

`unknown` is a real result. It is not itself a diagnostic.

**Decided.** Composition roots and other in-package libraries that step 4 leaves as `unknown`, and every `file:` library from step 3, stay exempt from the direction rules. That set includes `lib/main.dart`, `app.dart`, bootstrap code, and `core/providers` (a `providers` segment after `core` is not a presentation alias). For `layer_dependency`, `boundary_crossing`, and `circular_dependency`:

- `unknown` → `unknown`: allow
- `unknown` → any in-package layer: allow
- any in-package layer → `unknown`: allow
- `external` is not fed through the in-package direction matrix. Direct infrastructure imports keep the current prefix-list behavior through `infrastructurePackage` and `isInSdk`
- in-package layer → in-package layer: the existing direction matrix

DI-file exceptions inside `layer_dependency` stay in that rule. The resolver does not treat a file named `injection.dart` as `unknown`.

`domain_purity` does not treat domain → in-package `unknown` as a blanket allow. The 3.0.0 walk is specified under PR 2b. A domain file that imports `package:flutter`, `dart:ui`, or an infrastructure-package URI directly still reports on that import, which is the rule's current prefix check on the resolved URI. A direct `dart:io` import from a domain library stays allowed: domain signatures may name `File` and `Directory`. `dart:io` is a hit only when an unknown library reached from domain imports it.

## 2. Migration plan

Each PR stays under 800 lines, including tests and fixtures. None of them migrate the other path-based rules (model rules, Riverpod rules, `allowed_instance_variables`, `widget_no_usecase_call`, and the rest). Those rules keep working on a resolved AST once any rule in the plugin requires resolution; they do not start calling the resolver until their own PR.

"Breaking" means a default-on diagnostic that fires on code that is clean today, or a default-on diagnostic that stops firing on code that warns today. The published baseline is 2.8.0 ([#189](https://github.com/ittae/clean_architecture_linter/pull/189)). Step 2 is 3.0.0 from that baseline. Source-compatible diagnostic changes still break consumers who fail `dart analyze`.

| PR | Change | Breaking | Semver | Default |
| --- | --- | --- | --- | --- |
| 1 | `LayerResolver` + unit tests. Merged on main: [#193](https://github.com/ittae/clean_architecture_linter/pull/193). No rule calls it. No rule drops `canUseParsedResult => true`. | No new or removed diagnostics | On main after the 2.8.0 release commit. Not a diagnostic release. | n/a |
| 2 | `layer_dependency` and `boundary_crossing` classify `importedLibrary` and referenced `NamedType.element.library`. | Yes. Barrels, extension-less relative imports, and mis-foldered part libraries gain diagnostics. Some substring false positives disappear (`Domain` vs `domain` included). A library whose only layer segment is `repositories`, `datasources`, or `data_sources` is `data` and enters the direction matrix (`layer_dependency._identifyLayer` returns null for that path today; `isDataFile` already treats it as data). A `domain` segment still wins, so `domain/repositories` stays `domain`. A `usecases` or `use_cases` folder with no `domain` segment stays `unknown` and leaves the direction matrix, including `circular_dependency`'s current `application` classification of `/usecases/`. `core/providers` stays `unknown`, not `presentation`. `boundary_crossing` stops using `_impl.dart`, `_implementation.dart`, and `/impl/` as the definition of concrete. An abstract type in a file that matched that pattern stops warning. A concrete class in a forbidden layer whose name does not match the pattern starts warning. Concrete is the referenced `ClassElement`: `isAbstract` is false, or its methods are not all abstract. | **Major 3.0.0.** No shadow-diagnostic period and no parallel codes. | Default-on in 3.0.0. Same codes: `layer_dependency`, `boundary_crossing`. |
| 2b | Same release as PR 2. `circular_dependency` and the import half of `domain_purity` use the resolver, including the unknown-library reachability walk. Split out only if PR 2 would cross 800 lines. | Yes. Barrel edges, plus a domain import of in-package `unknown` that can reach Flutter, `dart:ui`, `dart:io`, or an infrastructure package. | Ships inside 3.0.0. Do not publish PR 2 without 2b. The four hard checks would disagree on a barrel. | Default-on, same codes. |
| 3 | `dependency_inversion`, `repository_interface`, `repository_implementation` use declaration ownership. Drop `Gateway` / `Client` / `Adapter` and `Dto` / `Response` / `Model` as proof of a concrete data type. | Yes. A domain type named `PaymentGateway` stops warning. A data class named `TodoStore` referenced from domain starts warning. A domain signature that mentions a type declared in `data/` starts warning even when the name does not end in `Dto`. A domain class that implements a domain repository interface and has a concrete method body starts warning under `repository_implementation` even when its name does not end with `Impl`. Method bodies on ordinary domain entities and value objects stay silent. | **Major**, same 3.0.0 as PR 2 if it lands in that release; otherwise the next major. Do not ship this as a patch on 2.x. | Default-on, same codes. |
| 4 | New rule `cross_feature_boundary`. | New diagnostic. Not breaking while it is opt-in. Breaking if turned on by default. | **Minor** while opt-in. Flipping the default is a later **major**. | **Opt-in** via `registerLintRule`, same mechanism as `riverpod_state_after_async_gap`. |
| 5 | Error-boundary corrections on the existing presentation and repository throw rules. Supertype classification deletes `canUseParsedResult => true` on the rules it touches. | Mixed. `contains('State')` false positives go away (a fix). `rethrow;` and intermediate bases such as `class DomainFailure extends AppFailure` where `AppFailure implements Exception` start participating in the check the rule already documents. | The `rethrow;` visit may ship as a **minor**. Supertype classification ships in the 3.0.0 release with PR 2. It is not a 2.x resolution flip. The section 3 gate stays on PR 2. | Default-on, same codes. |
| 6 | New use-case rules. | New diagnostics. | **Minor** while opt-in. | **Opt-in.** |

Suggested order is the table order. PR 1 is merged ([#193](https://github.com/ittae/clean_architecture_linter/pull/193)) and has no user-visible diagnostic change. PR 2 and PR 2b are one 3.0.0 release from the 2.8.0 baseline. Open question 6 asks only whether PR 4 and PR 6 may be ordered before PR 2. It does not decide when those rules delete `canUseParsedResult => true`. Deleting that flag on `cross_feature_boundary` and on the PR 6 use-case rules ships in the same 3.0.0 measurement release as PR 2. If either rule is published in 2.x before that release, enabling it (`diagnostics: cross_feature_boundary: true`, or either use-case code) is not allowed until the section 3 2× gate passes. While the rule stays off, `PluginServer._canUseParsedResult` does not switch the plugin to resolved units. PR 5 is not this transition: its flag deletion stays in that 3.0.0 release and is not a second gate.

### PR 1 — resolver and tests

Merged as [#193](https://github.com/ittae/clean_architecture_linter/pull/193). Files on main: `lib/src/layer/layer_resolver.dart`, `test/src/layer/layer_resolver_test.dart`. No edits under `lib/src/rules/` and no edit to `lib/main.dart`. No rule calls the resolver.

The test constructs libraries with `V2RuleHarness` (`test/v2_harness/analysis_rule_harness.dart`), which already calls `getResolvedLibraryContaining` and visits resolved units. Assertions read `LibraryElement.uri` through the public element on the resolved compilation unit (`declaredFragment.element`). They do not add new `package:analyzer/src` imports beyond what the harness already has. The `file:` case in that file locks absolute paths that contain `data`, `features`, and `ui` as `unknown`. The ancestor case in the test table (`file:///tmp/domain/...`) is the same rule.

### PR 2 — `layer_dependency` and `boundary_crossing`

Both rules delete `canUseParsedResult => true`. For each `ImportDirective` they classify `context.libraryElement` as the source and `libraryImport.importedLibrary` as the direct target. They also visit `NamedType` and classify `element.library` when that library differs from the imported library (the barrel case). Data and presentation edges from those two sources are the barrel edge in `### Re-exports and barrels`, shared with `circular_dependency` and `domain_purity`.

`boundary_crossing` stops treating `_impl.dart`, `_implementation.dart`, and `/impl/` as the definition of concrete. A concrete cross-layer edge is a referenced `ClassElement` whose declaring library is a forbidden layer and whose `isAbstract` is false, or whose methods are not all abstract. The domain → data and domain → presentation import edges that the rule already reports stay, now keyed by `LayerLocation.kind`.

`layer_dependency`'s direction matrix, DI-file exception, and infrastructure allow-list stay. The allow-list reads `infrastructurePackage` and `LayerKind.infrastructure` instead of `importUri.startsWith`. Unknown libraries stay exempt in this PR, including `lib/main.dart`, `app.dart`, bootstrap, and `core/providers`. A `providers` segment preceded by `core` is not a presentation alias, so `package:app/core/providers/foo.dart` stays `unknown`. The `/core/constants/` domain cross-cutting change is in PR 2b, same release, not a new direction-rule report.

### PR 2b — `circular_dependency` and `domain_purity` imports

`circular_dependency` builds its graph from `importedLibrary.uri` and from declaring libraries of referenced `NamedType`s (`NamedType.element.library` only), using the same `LayerKind` and the same barrel edge as PR 2.

`domain_purity` decides the source file with `resolveLibrary(context.libraryElement!)`. Data and presentation import violations use the same barrel edge: a direct `importedLibrary` whose kind is `data` or `presentation`, and a referenced `NamedType`'s declaring library. The infrastructure prefix list uses `LayerLocation` on the direct import and on the unknown-walk terminal below. The superclass and interface name lists in `domain_purity` stay in this PR only when the diff still fits; otherwise they move with PR 5's supertype walk and this PR only switches the import check. Framework classes are then recognized because `element.library.isInSdk` (or an `infrastructurePackage` URI) is true, which removes the need to special-case the identifier `HttpClient`.

**Decided (unknown reachability).** When the source library is `domain` and an import's `importedLibrary` is an in-package `unknown` library, `domain_purity` follows that library's imports. The first hop is the domain `ImportDirective.libraryImport.importedLibrary`, the same edge as PR 2. Further hops read `LibraryFragment.libraryImports` (`List<LibraryImport> get libraryImports` on `LibraryFragment` in analyzer 14.5.0) from `LibraryElement.fragments` and follow `LibraryImport.importedLibrary`. The walk does not follow `LibraryFragment.libraryExports`. It continues only along in-package `unknown` → `unknown` edges. It does not enter `domain`, `data`, `presentation`, or `infrastructure` libraries. An `external` target is not walked; it is only tested as a terminal. Cycles in the unknown graph stop at a library already on the stack. The reachability cache is not the `LayerResolver` classification cache. Classification is a pure function of `LibraryElement.uri.toString()` and lives for the `registerNodeProcessors` call. Reachability depends on that library's imports, so it is a separate map: one entry per `library.uri.toString()`, reused only inside the current analysis pass, including when a second domain file imports the same unknown library. The cache does not retain `LibraryElement`. It is discarded when the pass ends.

If any of the following is reachable, report on the domain file's import line (the `ImportDirective` in the domain library), still under the existing code `domain_purity`. The message names the chain of library URIs from that import to the forbidden library, in order:

- `package:flutter/` (any library, including `package:flutter/widgets.dart` and `package:flutter/material.dart`)
- `dart:ui`
- `dart:io`
- the existing infrastructure prefix list in `layer_dependency._isInfrastructurePackage`: `package:http/`, `package:dio/`, `package:sqflite/`, `package:hive/`, `package:shared_preferences/`, `package:cloud_firestore/`, `package:firebase_`, `package:drift/`, `package:isar/`, `package:objectbox/`, `package:realm/`
- the IO prefixes `domain_purity._checkForViolation` already reports on a direct domain import: networking (`package:http/`, `package:dio/`, `package:connectivity_plus/`), storage (`package:sqflite/`, `package:hive/`, `package:shared_preferences/`, `package:path_provider/`, `package:cloud_firestore/`, `package:firebase_database/`), and platform (`package:device_info_plus/`, `package:permission_handler/`, `package:camera/`, `package:location/`, `package:geolocator/`)

The walk does not add `package:ffi/`, `dart:html`, `dart:js`, or the state-management prefixes. Those stay on the direct-import check only. The walk does not apply to `layer_dependency`, `boundary_crossing`, or `circular_dependency`. Those three still allow the unknown edges in the policy section, so `lib/main.dart` importing Flutter stays silent for them.

`/core/constants/` leaves the domain cross-cutting allowlist. Today `layer_dependency._isCrossCuttingConcern` matches `/core/constants/` and `/shared/constants/` for every source layer. In 3.0.0 a domain source no longer treats `/core/constants/` as cross-cutting. `/shared/constants/` is unchanged. Data and presentation sources still match `/core/constants/`. `layer_dependency` itself still allows domain → `unknown`, so this drop does not make `layer_dependency` report `core/constants`. The report is the `domain_purity` walk.

Evidence from consumer apps:

- `ittae` `lib/core/error/app_exception.dart`, and `flutter_boilerplate` and `dear_days` `lib/core/errors/exceptions.dart`, import `package:flutter/widgets.dart` only for the `AppExceptionL10n.toLocalizedMessage(BuildContext)` extension. `ittae` `features/schedule/domain/usecases/create_schedule_usecase.dart` imports that core error library. The diagnostic is the domain import. The chain names the core error library and `package:flutter/widgets.dart`.
- `ittae` `core/constants/domain_colors.dart` imports `package:flutter/material.dart`. That is why `/core/constants/` is not a domain allowlist entry. A domain import of that library reports until the file no longer reaches `package:flutter`.
- `maeil_scrum` and `short_form` `failures` / `result` libraries are pure Dart. An unknown library that never reaches `package:flutter`, `dart:ui`, `dart:io`, or an IO/infrastructure prefix stays silent.

3.0.0 migration: each affected app moves the `BuildContext` localization extension out of `core/error` or `core/errors` into presentation. That is one file per app. The exception types stay where they are. After the move, the domain use case can keep importing the core error library.

### PR 3 — declaration ownership

Scope is the three rules named here.

- `dependency_inversion` deletes `_isConcreteImplementation`'s suffix lists (`Impl`, `Implementation`, `Concrete`, `Client`, `Adapter`, `Gateway`). A domain library references a concrete data type when the resolved `ClassElement.library` has `kind == data` and the class is concrete (`isAbstract` false, or the structural "has a method body" check the rule already uses). An abstract domain type whose name ends with `Gateway` or `Client` is clean.
- `repository_interface` deletes `_isDataLayerModel`'s `Model` / `Dto` / `Response` suffix test. A signature type is a data model when its declaring library is `data`. `Entity` names declared in `domain` stay legal.
- `repository_implementation` treats a class as a repository implementation when it is declared in a `data` library and it implements an interface declared in a `domain` library, regardless of `RepositoryImpl`. A class declared in a `domain` library is a misplaced implementation only when it implements a domain repository interface and it has a concrete method body. Method bodies on ordinary domain entities and value objects are silent. Abstract interfaces stay in `domain` because their declaring library is `domain`, not because the file path string contains `/domain/`.

`ClassElement.isAbstract` alone misses interfaces that omit the modifier. Keep the method-body structural check next to the library check.

### PR 4 — `cross_feature_boundary`

New diagnostic code `cross_feature_boundary`. Register with `registerLintRule` so it stays off until `diagnostics: cross_feature_boundary: true`.

The rule reads `LayerLocation`, `importedLibrary`, and referenced `NamedType`, so it deletes `canUseParsedResult => true`. That deletion is the transition in the migration-plan paragraph above: the same 3.0.0 measurement release as PR 2, or a 2.x publish whose enablement waits for the section 3 2× gate. Default-off does not flip resolution.

The rule reports when the source and target `LayerLocation.feature` values are both non-null, they differ, and the target `kind` is `data` or `presentation`. `features/x` importing `features/y/domain` is allowed. A library with no `features` segment is outside the rule. Targets are `importedLibrary` and, for barrels, the declaring library of each referenced `NamedType`.

### PR 5 — error-boundary corrections

- Visit `RethrowExpression` anywhere the rule currently visits `ThrowExpression` and calls `isRethrow`. `CleanArchitectureUtils.isRethrow(ThrowExpression)` cannot see a `rethrow;` statement. Replace that helper with a check that accepts `RethrowExpression`, or delete it and use the node type. `presentation_use_async_value` already handles `RethrowExpression`; its existing harness tests, including `when(error:)` catch handling, stay green.
- Replace immediate `superclass.name.lexeme` checks that decide "is a notifier / state / exception" with `InterfaceType.allSupertypes` (and the type's own `element`, because `allSupertypes` does not include the type itself). `class BaseNotifier extends Notifier<int>` then `class TodoNotifier extends BaseNotifier` is a notifier. `class Statement extends ConsumerWidget` is not a state class.
- Classify an exception by the chain, not by a suffix. A type is an exception or error when its element, or any `allSupertypes` element, has `library?.isDartCore == true` and `name` equal to `Exception` or `Error`. There is no `TypeProvider.exceptionType` to call. `class AppFailure implements Exception` then `class DomainFailure extends AppFailure` classifies as an exception. Programming-error types (`ArgumentError`, `StateError`, and the existing set) stay allow-listed by element name plus `isDartCore`, not by `contains`.

`presentation_no_throw`, `presentation_no_data_exceptions`, `repository_no_throw`, and `repository_pass_through` are the rules this PR touches. It does not follow `onDispose` tear-offs.

Supertype classification reads resolved elements (`InterfaceType.allSupertypes` and the type's own `element`). In the PR that does that classification, those four rules delete `canUseParsedResult => true`. Parsed context throws `UnsupportedError` from `RuleContext.libraryElement`, and an unresolved type has no `allSupertypes` chain. That deletion does not ship in 2.x. It ships in the 3.0.0 release with PR 2. Section 3's measurement gate stays on PR 2. PR 5 is not an earlier resolution transition and is not a second gate. The `RethrowExpression` visit does not read elements, so shipping or holding those reports does not move the gate.

### PR 6 — use case rules

Two new opt-in codes, `registerLintRule`. Both rules call the resolver, so both delete `canUseParsedResult => true` on the same schedule as PR 4: the 3.0.0 measurement release with PR 2, or a 2.x publish that stays off until the section 3 2× gate passes. Enabling either code before that gate is not allowed. Default-off does not flip resolution.

- `usecase_single_public_call`. The library is `useCaseLibrary`. The class under check has exactly one public instance method, and its name is `call`. Public means `Element.isPublic`. Constructors are not counted. Private helpers are allowed.
- `usecase_no_usecase_dependency`. From a `useCaseLibrary`, a referenced `NamedType` whose declaring library is also `useCaseLibrary` and is not the current library is a violation. A use case may still reference domain entities and domain repository interfaces (`kind == domain` and `useCaseLibrary == false`).

`usecase_no_result_return` stays as it is in this PR. Folding it onto the resolver is a later cleanup, not a behavior change.

### After this sequence

Still on path or name heuristics until their own small PRs: the model rules (`Dto` / `Response` there), data-source rules, `allowed_instance_variables` (`Client` in the infrastructure name set), Riverpod rules, `widget_no_usecase_call` (import string contains `usecase`), `extension_location`, `freezed_usage`, `no_presentation_models`, and the unregistered `test_coverage` rule. `riverpod_uncancelled_disposable`'s `onDispose` tear-off is a separate bugfix, not a layer-resolver PR.

## 3. Performance

Resolution cost is paid once per library by the plugin, not once per rule. The moment any enabled rule inherits `canUseParsedResult == false`, `analysis_server_plugin` 0.3.24 stops using `forParsedLibrary` for that library and requests a resolved unit. Every other enabled rule then runs on that resolved AST even if it never reads an element. #193 did not flip the flag, so the resolver on main does not change `dart analyze` cost. PR 2 does, and that step is the one to measure. PR 5's supertype classification also deletes the flag on its own rules, but only in that same 3.0.0 release, after this gate. It does not land in 2.x and it is not a second measurement point. Enabling PR 4 or PR 6 in 2.x is not a second measurement point either. That enablement waits for this same 2× gate, as the migration plan states. A rule that stays off does not request resolved units.

After a library is resolved, `LayerResolver.resolveLibrary` is a walk of `uri.pathSegments` and a map lookup. The classification is a pure function of `LibraryElement.uri.toString()` and the convention table. Cache it in a map on the resolver for the `registerNodeProcessors` call. Keying by the URI string does not retain `LibraryElement` instances across analysis requests. Do not key a long-lived cache by element identity; a later analysis of the same file is a new element.

That map is only the classification cache. The `domain_purity` reachability cache is a different map, specified under PR 2b: one entry per library URI, reused only inside the current analysis pass, not retained as a `LibraryElement`, and discarded when the pass ends. Reachability is not a pure function of the URI, because it depends on that library's imports.

Per-rule cost on top of resolution:

- one `resolveLibrary` for `context.libraryElement` per library
- one `resolveLibrary` per import's `importedLibrary`
- one `Element.library` read per `NamedType` the rule already has a reason to visit
- for `domain_purity` only, one walk of in-package `unknown` → `unknown` imports when a domain library imports an unknown library, cached for this analysis pass and discarded when the pass ends

That is a pointer read plus a hash lookup. It is not another resolution. The unknown walk does not call `getResolvedUnit` again; it reads import edges on libraries the driver has already resolved, and each unknown library's reachability result is stored once for this analysis pass. Rules that do not need referenced names (`layer_dependency` on a direct, non-barrel import) skip the `NamedType` walk.

`InterfaceType.allSupertypes` is computed by the analyzer for the type. PR 5 calls it on the thrown type and on the class being classified, not on every type in the unit.

### Benchmark plan

Run this in PR 2, before merging the `canUseParsedResult` flip, and record the numbers in that PR. The resolver is already on main with the flag still true, so that tree is not a separate cost step.

Targets, the trees already used as consumer smokes:

- `example/`
- `poc_v2/consumer_riverpod_lint/`
- `poc_v2/example/` when that package analyzes on its own

Protocol:

1. Warm up once, then record the median wall time of three `dart analyze` runs. Same machine, same SDK, analyzer 14.5.0.
2. Baseline: current rules, all `canUseParsedResult == true`.
3. Current main: resolver present ([#193](https://github.com/ittae/clean_architecture_linter/pull/193)), flag still true. Expect this to match the baseline within noise.
4. PR 2 tree: `layer_dependency` and `boundary_crossing` require resolution. This is the step change.
5. A unit-level cache check in `layer_resolver_test.dart`: classify the URI set from those packages twice. The second pass only hits the map. This separates resolver CPU from analyzer resolution.

Proposed gate for the owner, not a measured result: median `example/` time at step 4 stays within 2× step 2. If it does not, stop the migration and report the three medians before converting more rules. Also record diagnostic counts at steps 2 and 4 so a slower run that newly reports a barrel is visible as a product change rather than a hang.

Commands are the ones this repo already documents: root `dart analyze`, root `dart test` for the resolver tests, `cd example && dart analyze`, `cd poc_v2/consumer_riverpod_lint && dart analyze`.

## 4. Test strategy

`doc/CONTRIBUTING.md` requires a test file next to the source layout and a pair of cases: one where the rule fires, one where it does not. `doc/RULE_DEVELOPMENT_GUIDE.md` shows the same pair as an integration test, plus `example/lib/bad_examples` and `example/lib/good_examples` for behavior consumers can read. `V2RuleHarness` is the integration runner. It resolves a real library, so multi-file barrels and parts work. Single-string AST snippets do not.

Each implementation PR is red first:

1. Add the failing harness test and, for a user-visible rule, the `example/lib/bad_examples` and `example/lib/good_examples` pair.
2. Run that test file and confirm the new assertion fails for the current behavior.
3. Implement the smallest change that turns that file green.
4. Run the existing test file for every rule the PR touches, so a lost diagnostic fails the same PR.

The resolver tests are on main ([#193](https://github.com/ittae/clean_architecture_linter/pull/193)): a barrel library URI classifies as `unknown` while the exported model's `element.library` classifies as `data`. No example app fixture is required until a rule reports it. Later PRs stay red first.

Required bypass fixtures, each as a negative/positive pair inside the harness `files:` map:

| Fixture | Negative (reports) | Positive (silent) |
| --- | --- | --- |
| Barrel re-export | `presentation` imports `features/todo/todo.dart`, which exports `data/models/todo_model.dart`, and the page names `TodoModel`. PR 2 reports `layer_dependency`. | The same barrel exports only `domain/entities/todo.dart`, and the page names `Todo`. |
| Misnamed implementation | Domain code names `TodoStore`, a concrete class in `data/` that implements domain `TodoRepository` and does not end with `Impl`, `Gateway`, or `Client`. PR 3 reports. | Domain declares `abstract class PaymentGateway` with no method bodies. No `dependency_inversion` report. |
| Custom intermediate base | `class AppFailure implements Exception` and `class DomainFailure extends AppFailure`, thrown from a presentation notifier whose immediate superclass is a project `BaseNotifier extends Notifier`. PR 5 classifies the throw as an exception and the class as a notifier. | `class Statement extends ConsumerWidget` does not match the state check. A `rethrow;` inside an allowed catch stays allowed where the rule already allows rethrow. |
| Part file | Library file is `domain/todo.dart` with `part 'todo_part.dart'` stored beside it. The part's elements classify as `domain` even if a second fixture places the part source under `data/` via the harness path. | A `data/` library with a part under `data/` classifies as `data`. |
| Package vs relative | `import '../domain/todo.dart'` and `import 'package:<harness>/features/todo/domain/todo.dart'` in two files produce the same `LayerLocation.kind`. | A `package:meta/meta.dart` import is `external`, not `unknown` and not `domain`. |
| Unknown | `lib/features/todo/domain/todo.dart` imports `lib/features/todo/data/todo_model.dart`. Report `layer_dependency`. | `lib/main.dart` imports a domain entity. No `layer_dependency` report. `app.dart`, `core/providers`, and bootstrap stay silent for `layer_dependency`, `boundary_crossing`, and `circular_dependency` even when they import Flutter. |
| Segment priority | `package:<harness>/features/todo/data/providers/foo.dart` classifies as `data`. `package:<harness>/features/todo/repositories/foo.dart`, `.../datasources/foo.dart`, and `.../data_sources/foo.dart` classify as `data`. `package:<harness>/features/todo/domain/usecases/foo.dart` is `domain` with `useCaseLibrary` true. | `package:<harness>/core/providers/foo.dart` classifies as `unknown`, not `presentation`. `package:<harness>/features/todo/domain/repositories/foo.dart` is `domain`. `package:<harness>/features/todo/usecases/foo.dart` (no `domain` segment) is `unknown` with `useCaseLibrary` false. |
| Null-package URI | `package:data/foo.dart` classifies as `external`, not `data`, when `RuleContext.package` is null. `package:flutter/src/widgets/framework.dart` classifies as `external` when `RuleContext.package` is null and when it is non-null. The `widgets` segment is not a presentation hit on that URI. | `package:<harness>/features/todo/domain/todo.dart` is `domain` when `RuleContext.package` is null, because segment 0 is skipped and the step 4 priority applies. The same `package:flutter/src/widgets/...` URI is `external` for a non-null package. |
| File URI checkout path | `file:///tmp/domain/app/lib/features/todo/data/todo.dart` is `unknown`, not `domain`. `file:///tmp/data/app/lib/main.dart` is `unknown`, not `data`. `kind` and `feature` ignore every segment of a `file:` URI, including ancestor `domain` or `data` and in-path `features`, `ui`, and `providers`. | `package:<harness>/features/todo/data/todo.dart` is `data`. A `package:` URI is not classified from a `file:` path. |
| Domain unknown reachability | Domain imports `lib/core/error/app_exception.dart`, which imports `package:flutter/widgets.dart`. `domain_purity` reports on the domain import and the message names both URIs. The same report fires for `lib/core/constants/domain_colors.dart` importing `package:flutter/material.dart`, and for an unknown library that imports `dart:io`. | Domain imports `lib/core/failures.dart`, which imports only `lib/core/result.dart` (pure Dart, as in `maeil_scrum` / `short_form`). Silent. A direct `dart:io` import in the domain file, used as a `File` or `Directory` signature, stays silent. |
| Cross-feature | Opt-in rule, PR 4: `features/todo/presentation` imports `features/user/data`. Report. | `features/todo/presentation` imports `features/user/domain`. Silent. |
| Use case | Opt-in, PR 6: a use case class with public `call` and public `execute`, and a use case that constructs another use case. Report the matching code. | A use case with public `call` and private `_validate`, depending on a domain repository. Silent. |

`example/` fixtures cover the three bypasses that should stay readable in the sample app: the barrel, the misnamed data class, and `Statement` / `BaseNotifier`. The harness covers parts, relative URIs, and opt-in rules that must not appear as default diagnostics in `example/`.

## 5. Risks and open questions

Risks to accept before PR 2 merges:

- The first `canUseParsedResult` deletion changes the cost model for every enabled rule, including rules that still ignore elements. The 2× gate in section 3 is the stop condition.
- `RuleContext.libraryElement` throws on a parsed context. A rule that calls the resolver and also overrides `canUseParsedResult => true` will throw inside `dart analyze`, not merely miss a diagnostic.
- `MultiplyDefinedElement.library` is null. The resolver returns null and the rule skips that node. It must not cast.
- `ClassElement.isAbstract` is the modifier, not "no concrete methods." Dropping it in PR 3 reintroduces false negatives for `class TodoRepository { Future<Todo> get(String id); }` without `abstract`.
- `exportedLibraries` ignores combinators. Using it as a "this barrel exports data" check will report barrels that `hide` the data names.
- Publishing PR 2 without PR 2b leaves `layer_dependency` and `circular_dependency` / `domain_purity` on different definitions of the same import.
- The unknown walk reports a domain import when Flutter or IO is reachable only through other unknown libraries. It does not follow a known layer, so an unknown file that imports presentation, which then imports Flutter, stays silent for this check. The direction rules still allow that unknown → presentation edge.
- Case folding is inconsistent today (`CleanArchitectureUtils` is case-sensitive; `layer_dependency` lowercases). The resolver is case-sensitive. A tree that relies on `Domain` matching `/domain/` will lose that accidental match in 3.0.0.
- `Identifier` is deprecated and `NameExpression` is experimental. Building PR 2 on `NameExpression.resolution` would couple the release to an unstable AST. PR 2 uses `NamedType` and `LibraryImport` only.
- `onDispose` tear-offs stay false negatives until a separate bugfix. This design does not schedule that fix.

Open questions for the owner:

1. **Decided:** Step 2 ships as 3.0.0 from the 2.8.0 baseline ([#189](https://github.com/ittae/clean_architecture_linter/pull/189)), with the existing codes left default-on. There is no shadow-diagnostic period and no 2.x minor that registers parallel codes via `registerLintRule`. The resolver on main ([#193](https://github.com/ittae/clean_architecture_linter/pull/193)) is not that release.
2. Confirm that an unused import of a barrel which exports a data library is silent. The alternative (walk `exportedLibraries`) false-positives on `hide` / `show`.
3. Confirm that a part file's layer is the parent library URI even when the part's own path is under a different layer folder.
4. Should path conventions become an `analysis_options` map, or stay an internal table? These PRs assume the internal table.
5. Is the 2× `example/` analyze-time gate the right stop line, or should the gate be a fixed budget once step 4 is measured?
6. May PR 4 and PR 6 land in 2.x, before the 3.0.0 boundary change, so opt-in rules are not blocked on the major? This question is order only. Deleting `canUseParsedResult => true` on those rules, and enabling them, is fixed in the migration plan: the same 3.0.0 measurement release as PR 2, or a 2.x publish that stays off until the section 3 2× gate passes.
7. For `usecase_single_public_call`, is the folder (`usecases` / `use_cases`) enough to select the class, or must the class name also end with `UseCase`? The proposal is folder-only, so a misnamed class in that folder is still checked.
8. Should PR 5's new `rethrow;` findings ship as the minor bugfix, or be held for 3.0.0 if they are noisy? The supertype classification is not part of that choice. It stays in the 3.0.0 release with PR 2, and the section 3 gate stays on PR 2.
9. When should `domain_purity`'s remaining superclass name list, the model rules' `Dto` / `Response` checks, and `allowed_instance_variables`'s `Client` name set move onto declaring libraries? They are intentionally outside PRs 1–6 except where PR 2b can absorb the `domain_purity` import half.
10. **Decided:** Unknown libraries (`lib/main.dart`, `app.dart`, `core/providers`, bootstrap, every `file:` URI, and any other in-package library that step 4 does not classify) stay exempt for `layer_dependency`, `boundary_crossing`, and `circular_dependency`. A `providers` segment preceded by `core` is not a presentation alias, so `package:app/core/providers/foo.dart` is `unknown`. `domain_purity` in 3.0.0 walks in-package `unknown` → `unknown` imports. That reachability cache lives for one analysis pass, does not retain `LibraryElement`, and is discarded when the pass ends. The walk reports on the domain import when `package:flutter`, `dart:ui`, `dart:io`, or an IO/infrastructure prefix is reachable. The message names the chain. `/core/constants/` is removed from the domain cross-cutting allowlist. Each affected app moves the `BuildContext` l10n extension out of `core/error(s)` into presentation, one file per app.
