# Presentation rules · Riverpod 3.3 gap inventory

Status: inventory for package `2.4.0` on Flutter 3.44.x / Dart 3.12.2 /
Riverpod 3.3.x + `riverpod_generator` 4.x line (local SDK: Flutter 3.44.9,
Dart 3.12.2).

Scope: **presentation rules only** (`lib/src/rules/presentation_rules/`).
Does not re-open data/domain/cross-layer. Additive 2.x fixes only — no v3 rewrite.

Related docs:

- `docs/analysis/RIVERPOD_3_COMPAT.md` — earlier Riverpod 3.0 note (partially
  superseded; several listed FNs were closed by ITT-1838 / CAL#110).
- `docs/analysis/ERROR_HANDLING_BEST_PRACTICES.md` —
  `presentation_use_async_value` residual (CAL#137 exact-set FP fix).

Verdict key:

| Label | Meaning |
| --- | --- |
| **pass** | Rule matches current Riverpod 3.3 / CA policy with acceptable noise |
| **FP** | Reports legitimate Riverpod 3.3 / CA code |
| **FN** | Misses real violations consumers still hit |
| **stale** | Policy/message targets a retired pattern or wrong API surface |

---

## Inventory matrix

| Rule | Severity | Verdict | One-line judgment | Evidence |
| --- | --- | --- | --- | --- |
| `no_presentation_models` | INFO | **pass** | ViewModel/ChangeNotifier ban still matches generator-first CA | `no_presentation_models_rule.dart`, `no_presentation_models_v2_rule_test.dart` |
| `extension_location` | INFO | **pass** | Same-file extension policy; path heuristics only | `extension_location_rule.dart`, `extension_location_v2_rule_test.dart` |
| `freezed_usage` | INFO | **pass** (low residual **FP**) | Equatable → Freezed still valid; pure `==` / Dart 3 records not forced | `freezed_usage_rule.dart`, `freezed_usage_v2_rule_test.dart` |
| `presentation_no_data_exceptions` | WARNING | **FN** | `is` / typed `catch` only; Dart 3 `switch` patterns / `on X catch` gaps remain | `presentation_no_data_exceptions_rule.dart`; ERROR_HANDLING §3/§4 |
| `presentation_no_throw` | WARNING | **pass** | State/provider throw ban + `AsyncValue.guard` exempt still correct for 3.3 | `presentation_no_throw_rule.dart`, `presentation_no_throw_rule_test.dart` |
| `presentation_use_async_value` | WARNING | **pass** | Exact-set field match after CAL#137; prefix compounds (`userErrorMessage`) intentional FN | `presentation_use_async_value_rule.dart`, `presentation_use_async_value_v2_rule_test.dart`, CHANGELOG#137 |
| `ref_mounted_usage` | INFO | **pass** | Layer-aware: Notifier OK, widget UI gate still INFO | `ref_mounted_usage_rule.dart`, `ref_mounted_usage_v2_rule_test.dart` |
| `riverpod_generator` | INFO | **pass** (residual **FN** on bare `Provider`) | Notifier/Async/Stream(+AutoDispose/family) covered; bare DI `Provider` left out by design | `riverpod_generator_rule.dart`, `riverpod_provider_detector.dart`, `riverpod_generator_v2_rule_test.dart` |
| `riverpod_keep_alive` | INFO | **FP** | Name/path keyword allowlist misses real global stores (`TokenStore`, `WalletBalance`, …) | `riverpod_keep_alive_rule.dart` `_validKeepAlivePatterns`, `riverpod_keep_alive_v2_rule_test.dart` |
| `riverpod_provider_naming` | WARNING | **FN** | Function `@riverpod` only; class-based notifiers + `Future<T>` unwrap not covered | `riverpod_provider_naming_rule.dart`, `riverpod_provider_naming_v2_rule_test.dart` |
| `riverpod_ref_after_async_gap` | INFO | **fixed (state write; same-statement RHS await)** | Path-sensitive `ref.*` + unguarded `state =` / `this.state =` after await (incl. `state = await …`); `ref.mounted` guards shared; RHS-await skips disposal-guard suppress | `riverpod_ref_after_async_gap_rule.dart`; `riverpod_ref_after_async_gap_v2_rule_test.dart` |
| `riverpod_ref_usage` | WARNING | **FP** → mitigated | `build()` one-shot DI reads were flagged; UseCase prefix alone too narrow | `riverpod_ref_usage_rule.dart`, tests below |
| `riverpod_uncancelled_disposable` | WARNING | **pass** | Timer / StreamSubscription / listener + `ref.onDispose` still the 3.3 disposal story | `riverpod_uncancelled_disposable_rule.dart`, `riverpod_uncancelled_disposable_v2_rule_test.dart` |
| `widget_no_usecase_call` | WARNING | **pass** | Widget→UseCase direct call ban remains CA-correct | `widget_no_usecase_call_rule.dart`, `widget_no_usecase_call_v2_rule_test.dart` |
| `widget_ref_read_then_when` | WARNING | **FP** | Any `.when` after `ref.read` — collides with Freezed/sealed Result snapshot handlers | `widget_ref_read_then_when_rule.dart`, `widget_ref_read_then_when_v2_rule_test.dart` |

---

## Riverpod 3.3 / generator 4 notes that matter

1. **Non-codegen Notifiers are first-class.** Shared
   `lib/src/utils/riverpod_provider_detector.dart` already treats
   `Notifier` / `AsyncNotifier` / `StreamNotifier` (+ AutoDispose / Family)
   like `@riverpod` classes for ref-usage / async-gap / generator / mounted.
2. **`ref.mounted` is the documented post-gap guard** on the state layer.
   `ref_mounted_usage` correctly exempts Notifiers; `riverpod_ref_after_async_gap`
   suppresses guarded `ref.*` and unguarded `state =` / `this.state =` (and
   invalidates the guard after a later `await`).
3. **`state =` after dispose still throws** in Riverpod 3 — tracked as INFO by
   `riverpod_ref_after_async_gap` when unguarded after an async gap, including
   same-statement `state = await …` (RHS await; preceding `ref.mounted` does
   not protect the store — split then re-guard).
4. **Bare `Provider` for DI stays legal.** `riverpod_generator` intentionally
   does not ban it (DI FP risk). Do not treat that silence as a bug unless a
   `strict_generator_only` option is introduced.
5. **Analyzer 13 / ASP coexistence** with `riverpod_lint 3.1.x` is a packaging
   concern (README Compatibility), not a presentation-rule semantics bug.

---

## Top 3 fix candidates (consumer pain, 2.x additive)

### 1. `riverpod_ref_usage` — DI / infrastructure `ref.read` in `build()` (**shipped in this change**)

- **Pain:** WARNING noise on every Notifier that injects
  `*RepositoryProvider` / `*ServiceProvider` / analytics / API clients once in
  `build()`. Message claims “State providers” even when the dependency is pure DI.
- **Fix (2.x additive):** treat known stable-dependency suffixes as allowed
  one-shot reads (same gate as UseCase / `.notifier`).
- **Evidence:** `riverpod_ref_usage_rule.dart` `_isAllowedOneShotProviderName`;
  test `allows stable DI dependency reads (repository/datasource/service/client/api/dao/logger/analytics/storage) in build`.
- **Residual:**
  - locale/config/theme 등 suffix 없는 의도적 one-shot state read → 계속 TP(정책).
  - `*ServiceProvider` / `*ApiProvider` / `*StorageProvider`가 반응형 상태를 감싼
    경우 → 새 FN 가능(이름 휴리스틱 한계). type-aware 전환 전까지 허용 목록 유지.

### 2. `widget_ref_read_then_when` — Freezed/sealed `.when` after snapshot read

- **Pain:** WARNING on intentional event-handler snapshots:
  `final r = ref.read(resultProvider); r.when(success: …, failure: …)`.
- **Fix direction:** require AsyncValue-ish receiver (type resolve or
  chained `AsyncValue` construction), or allow freezed-style multi-case
  `.when` with non-loading branches; do not blanket-ban every `.when`.
- **Risk:** type-aware path needs resolved AST; parsed-only path stays weak.

### 3. `riverpod_ref_after_async_gap` — track `state` writes after await (**shipped**)

- **Pain:** silent FN for the most common post-dispose crash path:
  `await x; state = AsyncData(...)` without `if (!ref.mounted) return;`.
- **Fix (2.x additive):** after an async gap, report simple `state =` /
  `this.state =` assignments unless disposal-guarded (reuse existing mounted
  guard walker). Keep INFO severity.
- **Out of scope:** full CFG; private helpers already skipped by design.

Honorable mentions (not top-3): `riverpod_keep_alive` keyword FP (INFO only);
`riverpod_provider_naming` class-based FN; `presentation_no_data_exceptions`
pattern-match FN.

---

## Change log for this inventory PR

| Area | Change |
| --- | --- |
| Docs | This matrix + top-3 ranking |
| Rule | `riverpod_ref_usage`: allow stable DI suffix reads in `build()` |
| Tests | New case covering all stable DI suffixes (repository/datasource/service/client/api/dao/logger/analytics/storage) |

No publish/release. Public GitHub metadata must not carry private Multica issue keys.
