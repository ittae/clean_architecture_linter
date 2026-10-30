## 이 레포 고유 지침


## Cross-repo data exchange (org policy)

- **English SoT (ITT-5349):** [`policies/cross-repo-contract.md`](https://github.com/ittae/workspace/blob/main/policies/cross-repo-contract.md) in [`ittae/workspace`](https://github.com/ittae/workspace) — ITT-5349 의존 · 문서 준비 중 (intended path; update when ITT-5349 merges).
- 이 저장소는 Flutter 앱이 아니라 외부 사용자에게 배포되는 **public Dart package (`analysis_server_plugin` 기반 Clean Architecture linter)**.
- 패키지 구현 경로는 `lib/src/rules/`, `lib/src/mixins/`, plugin entrypoint는 `lib/clean_architecture_linter.dart`다. 예제/fixture의 `lib/features/...`는 소비자 앱 lint semantics를 검증하기 위한 입력이며, agent 구현 레이아웃으로 해석하지 않는다.
- lint semantics와 agent 운영 규칙을 분리한다. 이 패키지는 Riverpod 기반 Clean Architecture 위반을 `dart analyze`에서 검출하는 제품이며, agent 지침은 maintainer 작업 절차일 뿐 package behavior나 public docs API가 아니다.
- public GitHub metadata(브랜치명, PR 제목/본문, release note)에 private Multica `ITT-*` key를 노출하지 않는다. traceability는 Multica 내부에만 둔다.
- PR은 human merge only다. agent는 명시 승인 없이 merge/close/label/review approval/force push를 하지 않는다.
- 실제 검증 명령은 manifest/현행 문서 기준으로만 기록하고 실행한다: root `dart analyze`, root `dart test`, consumer smoke `cd example && dart analyze`, analysis_server_plugin/Riverpod coexistence smoke `cd poc_v2/consumer_riverpod_lint && dart analyze`.
- Vision / rule 등록 / Riverpod 3-tier 상세: `CLAUDE.md` 참조.

<!-- BEGIN agent-owner-brief (managed) -->
## 성준님 브리프 (작업 전에 먼저 읽는다)

정본은 workspace `policies/owner-brief.md`다. 다른 지침과 충돌하면 결정 규칙은 이 블록을 따르고, 금지 사항은 `policies/owner-rules.md`를 따른다.

**목표.** 성준님이 손대지 않아도 돌아가는 앱이 순이익을 내게 한다. 사업의 월 순이익이 500만원이 되면 성준님은 퇴사한다. 지금 앱 매출은 0이다. 모든 작업은 이 거리를 줄이거나, 성준님의 손을 덜거나, 사용자가 좋아할 이유를 늘려야 한다.

**돈의 원칙.** 돈은 사용자가 원해서 내는 것이다. 사용자를 속이는 결제 화면, 해지를 막는 흐름, 과한 알림은 만들지 않는다. 사용자의 말(리뷰·추천)이 매출보다 먼저 오른다.

**완료의 기준.**
- `## Result`의 `evidence:` 줄이 `done_evidence`를 충족한다. 이 줄이 비어 있으면 완료가 아니다.
- 작업하는 동안 성준님이 손댄 횟수가 0이다.
- 성준님께 보내는 결과는 화면 캡처, 짧은 영상, 숫자 한 줄 중 하나다. 1분 안에 판단할 수 있어야 한다. 성준님의 시간은 주 4시간뿐이다. 코드와 diff는 보내지 않는다.

**초점** (갱신일 2026-10-22. 이 날짜에서 8일이 지나면 이 목록은 무시한다)
- ittae 0.5, 11월 초: 1인 창업자와 크리에이터를 위한 매니저 앱. 아침에는 하루가 이미 정리돼 있고, 때맞춰 알림이 오고, 밤에는 확인만 누른다. 결제할 수 있어야 한다.
- nebtoon: 스토어에 한 번 제출한다. 기능은 추가하지 않는다.
- h.itae 카드뉴스: 지금처럼 봇이 운영한다.
- 위 세 가지 밖의 작업과, 지표를 움직이지 못하는 시스템 개선은 하지 않는다.

**스스로 결정한다.**
1. 지표 셋(순이익, 성준님의 손, 사용자의 말) 중 무엇을 움직이는지 한 줄로 쓰지 못하면 하지 않는다.
2. 되돌릴 수 있는 결정은 묻지 않고 한다. 되돌릴 수 없는 일(키, prd 데이터, 스토어 제출, 결제 실행)에서만 멈춘다.
3. 두 방법이 비슷하면 성준님의 손이 덜 가는 쪽을 고른다. 돈과 성준님의 손이 충돌해도 손을 지킨다.
4. 수익이 나기 전의 저장소에서는 다듬기보다 출시가 먼저다.
5. 막혀도 묻지 않는다. `blocked` 또는 `needs-info`를 남기고 멈춘다. 성준님께 가져가는 안건은 자본 배분, 인력, 최종 승인 세 가지뿐이다.

**시작하기 전에.** 같은 goal의 열린 이슈나 PR이 있으면 `no-op`으로 끝낸다. 브리프와 이슈의 Constraints를 첫 답글에 되읽는다. 자기 lane에 해당하는 `docs/known-mistakes.md` 항목을 읽는다. 같은 방법이 두 번 실패하면 방법을 바꾸고 `mistake:` 줄을 남긴다.
<!-- END agent-owner-brief -->

## 검색·컨텍스트 규율 (토큰 효율)
<!-- BEGIN agent-search-discipline (managed) -->
- 텍스트 검색은 `rg`, 파일명·최근 변경은 `fd`(`find` 금지), 구조(AST) 매칭은 `ast-grep`. Dart는 완전한 문맥 + `--selector`로 쓴다: `ast-grep run -l dart -p 'void f(){ print($A); }' --selector call_expression lib` (맨 `print($A)`는 0건, exit 1은 매치 없음). `customLanguages`로 `dart`를 재등록하지 않는다(상세: workspace `policies/worker-contract.md` §2).
- 파일을 통째로 읽지 않는다. 위치를 특정한 뒤 필요한 범위만 읽고, 툴 결과 JSON/YAML은 `jq`/`yq`로 필요한 필드만 남긴다. GitHub는 `gh`, HTTP 스모크는 `xh`(없으면 `curl`), Multica는 `multica` CLI만.
- 이 필터 규율은 조회(read)에만 적용한다. 상태를 바꾸는 명령(`git push`, `gh pr create/edit/merge`, `--apply`, 배포·설정 생성)은 출력을 `| tail`/`| head`로 자르지 않는다. 에러는 잘린 부분에 숨고 마지막 줄은 성공처럼 보인다.
- 쓰기 명령은 실행 뒤 목적지를 조회해 확인한다. `push` 성공은 PR 반영이 아니다 — `gh pr view <n> --json state,commits`.
<!-- END agent-search-discipline -->

## 검증 규율 (analyze 먼저, test 나중)
<!-- BEGIN agent-verify-discipline (managed) -->
- 코드 작성/수정 직후 정적 분석을 **테스트보다 먼저** 돌린다. 통과 후에만 필요한 테스트를 타겟 실행.
  - **Dart/Flutter (`analysis_options.yaml`에 `plugins:` 있는 repo):** 게이트는 VS Code/Cursor **Problems**와 동일 소스인 `dart analyze`다 (`riverpod_lint`, `clean_architecture_linter` 등). **`flutter analyze`만으로 통과 선언·PR 금지** — 플러그인 진단을 놓쳐 Problems가 남은 채로 CI green이 된다. Multica/Codex/Cursor 에이전트도 동일. SoT는 repo 종류로 갈린다. **sentinel 없는 repo:** `dart analyze --fatal-infos`(또는 그것을 호출하는 `./scripts/verify.sh` / `--quick`)의 exit 0이 통과 증거다. **lint sentinel(`lib/zz_lint_sentinel/`)이 있는 repo:** 통과 증거는 `bash scripts/analyze.sh`의 exit 0뿐이고, `verify.sh`는 그 래퍼를 호출할 때만 인정한다. `scripts/analyze.sh`는 clean_architecture_linter `tools/lint_sentinel/check.sh`의 사본이며, 래퍼가 아직 없으면 그 파일을 `scripts/analyze.sh`로 복사한 뒤 호출한다. sentinel이 있는 repo에서만 단독 `dart analyze`는 통과 증거가 아니다: 플러그인이 전달되면 sentinel 2행(`riverpod_keep_alive`·`presentation_no_throw`, 경로 `lib/zz_lint_sentinel/`)만 허용 진단이고 그 외는 0건이어야 하며, 0행·exit 0은 깨끗함이 아니라 플러그인 미수신(실패, 재시도는 래퍼가 수행)이다.
  - **Dart/Flutter (`plugins:` 없는 repo):** 플러그인 진단이 없으므로 게이트는 `dart analyze --fatal-infos`(또는 그것을 호출하는 `./scripts/verify.sh`) exit 0. `--fatal-infos` 없는 `dart analyze`와 `flutter analyze --no-fatal-infos` 결과는 통과 증거로 쓰지 않는다.
  - TS/Node: `tsc --noEmit` + eslint · Python: `ruff`+`mypy`
- analyze 이슈(Problems)는 test 전에 **0건**(sentinel repo는 위 2행 제외). "flutter analyze OK"만 증거로 쓰지 않는다.
- 실행 검증도 전체가 아니라 바뀐 부분만 타겟한다.
<!-- END agent-verify-discipline -->

## PR 작성 규율 (org 템플릿 준수)
<!-- BEGIN agent-pr-discipline (managed) -->
- `clean_architecture_linter`는 public package다. branch, commit, PR title/body/comment, release note 등 public GitHub metadata에 private Multica `ITT-*` key를 넣지 않는다.
- PR 본문은 org template를 사용하고 workspace `pr-fetch-template-ittae.sh` → validate → `pr-create-ittae.sh --body-file` 경로로 생성한다. private Multica 이슈 키는 public metadata에 넣지 않는다. 해당 없는 섹션은 지우고, "미확인" 또는 "해당 없음" placeholder는 쓰지 않는다.
- 한 스토리이고 effective 800 cap 안이면 workspace `scripts/git/pr-create-ittae.sh` 단일 PR. 레이어가 여러 개이거나 그 cap을 넘기면 workspace `scripts/git/stack-submit-ittae.sh`만 사용한다. bare `gh stack submit`와 브랜치 인자 `gh stack link`는 금지. 정본: workspace `policies/ittae-gh-stack.md`.
- 실제 검증 명령·결과와 미검증 범위, public API/lint semantics risk, rollback을 본문에 기록한다.
- PR은 ready까지 전환하되 agent가 merge, approve, force-push, protection 변경을 하지 않는다. 이 package는 human merge only다.
<!-- END agent-pr-discipline -->

## sandbox 안전 규율
<!-- BEGIN agent-safety-discipline (managed) -->
- `.env` secret을 출력·검사·커밋하지 않는다. 필요한 경우 `.env.example`의 key 이름만 확인한다.
- 삭제가 필요하면 대상을 정확히 특정해 `rm`, `rmdir`, `git rm`을 사용할 수 있다. `rm -rf`와 대량 삭제는 명확한 scope·dry-run·rollback을 먼저 확인한다.
- 홈 루트, repo `.git/`, secret/credential, shared runner/worktree root처럼 고위험 대상을 삭제·정리할 때는 명시 승인을 받는다.
- 승인 없이 `curl | sh`, 출처 불명 installer, `chmod`, `sudo`, network shell을 실행하지 않는다.
- conductor/Multica가 관리하는 workspace는 담당 issue/worktree의 scope 안에서만 수정한다.
<!-- END agent-safety-discipline -->

## 개발 판단 규율 (위험·경계 비례)
<!-- BEGIN agent-lean-discipline (managed) -->
- 새 구현 전에 기존 코드, stdlib, 플랫폼 기능, 현재 dependency로 해결 가능한지 확인한다.
- architecture와 테스트 범위는 실제 dependency/trust boundary, 변경 위험, 실패 비용에 비례시킨다. 미래 확장만을 위한 layer/interface/factory/wrapper는 만들지 않는다.
- LOC·파일 수는 목표가 아니다. correctness, security, privacy, data integrity, accessibility, i18n, 명시적 error handling과 필요한 경계를 단순화와 교환하지 않는다.
- repo의 architecture convention과 required gate가 optional skill/plugin/persona 지침보다 우선한다.
<!-- END agent-lean-discipline -->

<!-- BEGIN merged-from-claude (ITT-5352) -->
## Project Why (Read First)

> **Org Vision:** Help people turn their plans into reality. *(원문: 사람들의 계획이 현실이 되도록 돕는 것입니다.)*
> **Org Mission:** Help people cherish yesterday, dream of tomorrow, and live today. *(원문: 어제를 소중히 여기고, 내일을 꿈꾸며, 오늘을 살아갈 수 있도록 돕는 것입니다.)*

**This project's role:** Auto-enforces Riverpod-based Clean Architecture via lints — so good architecture does not depend on a PR reviewer's memory, sustaining the Vision.

> Note: This package is also published to external users. The Org Vision is the *internal working standard for the maintainer (ittae)* and is not imposed on external users. External users only see "Automatic Clean Architecture enforcement" in the README.

Every change here must *reinforce* the Vision and this project's role. If a change would dilute them, stop and ask the human first.

### Decision Filter (ask before starting)

1. Does this change *reinforce* or *dilute* the Vision and this project's role?
2. Does this change conflict with this project's How (consistency across 33 rules, Riverpod 3-tier assumptions, Domain Purity, etc.)?
3. If it conflicts — is the principle worth changing, or should this change be dropped?

### Mandatory First Step (before any code/file changes)

When a new issue arrives, post the following as your first response (if a comment channel exists, publish it there) before starting work:

1. **Why restatement (1 sentence):** describe how this issue reinforces the Vision (사람들의 계획이 현실이 되도록 돕는 것입니다) and this project's role.
2. If you conclude it does not reinforce them → stop and ask the human.
3. If it does → state your How (approach principles) in 1–3 bullets, then begin.

> This step is a gate to catch misunderstandings early. Keep it brief and to the point.

---

## Project Overview

This is a Dart package that provides custom lint rules for enforcing Clean Architecture principles in Flutter projects. It uses the `analysis_server_plugin` framework to create static analysis rules that validate proper architectural boundaries and patterns.

## Clean Architecture Principles

This linter enforces the following Clean Architecture principles:

### Layer Dependencies
- ✅ **Allowed**: Presentation → Domain
- ✅ **Allowed**: Data → Domain
- ✅ **Allowed**: Domain can use `dart:io` for type references (File, Directory) in method signatures
- ❌ **Violation**: Presentation → Data
- ❌ **Violation**: Domain → Presentation
- ❌ **Violation**: Domain → Data

### Layer-Specific Patterns
- **Data Layer**: Use **Freezed Models** (contains Entity + metadata only) with extensions in same file
- **Domain Layer**: Use **Freezed Entities** with business logic extensions in same file
- **Presentation Layer**: Use **Freezed State** (Riverpod) with UI extensions in same file - NO ViewModels

**Key Rules**:
- Presentation layer should NEVER import from Data layer - Always use Domain Entities
- Models contain Entities (no duplicate data)
- Extensions in same file as the class
- NO separate extensions/ directories

For detailed examples and implementation patterns, see [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md).

For error handling patterns, see [UNIFIED_ERROR_GUIDE.md](doc/UNIFIED_ERROR_GUIDE.md).

For state management patterns (Riverpod + Freezed), see [STATE_MANAGEMENT_GUIDE.md](doc/STATE_MANAGEMENT_GUIDE.md).

## Riverpod State Management Patterns

The linter enforces proper Riverpod state management using a **3-tier provider architecture** that separates entity data, UI state, and computed logic.

### 3-Tier Provider Architecture

```
┌─────────────────────────────────────┐
│  Tier 1: Entity Providers          │  ← AsyncNotifier + AsyncValue
│  (scheduleListProvider)             │     (Data from Domain/UseCases)
└─────────────┬───────────────────────┘
              │ ref.watch() / ref.listen()
              ↓
┌─────────────────────────────────────┐
│  Tier 2: UI State Providers        │  ← Notifier (UI-only state)
│  (scheduleDetailUIProvider)         │     (selection, dialogs, etc.)
└─────────────┬───────────────────────┘
              │
              ↓
┌─────────────────────────────────────┐
│  Tier 3: Computed Logic Providers  │  ← Functions combining
│  (canConfirmScheduleProvider)       │     Entity + UI state
└─────────────────────────────────────┘
```

### ✅ Tier 1: Entity Providers (AsyncNotifier)

Entity providers manage domain data using `AsyncNotifier` with `AsyncValue`.

```dart
@riverpod
class ScheduleDetail extends _$ScheduleDetail {
  @override
  Future<Schedule> build(String scheduleId) async {  // ✅ ID parameter, not entity
    // UseCase throws AppException on error, AsyncValue catches automatically
    return ref.read(getScheduleDetailUseCaseProvider)(scheduleId);
  }
}

extension ScheduleUIX on Schedule {
  String get formattedDate => DateFormat('MMM dd, yyyy').format(startDate);
  Color get statusColor => isExpired ? Colors.grey : isConfirmed ? Colors.green : Colors.orange;
}
```

### ✅ Tier 2: UI State Providers (Depends on Entity)

```dart
@freezed
sealed class ScheduleDetailUIState with _$ScheduleDetailUIState {
  const factory ScheduleDetailUIState({
    @Default([]) List<String> selectedAttendeeIds,
    @Default(false) bool isSubmitting,
  }) = _ScheduleDetailUIState;
}

@riverpod
class ScheduleDetailUI extends _$ScheduleDetailUI {
  @override
  ScheduleDetailUIState build(String scheduleId) {
    ref.listen(scheduleDetailProvider(scheduleId), (prev, next) {
      next.whenData((_) {
        if (prev?.value?.id != next.value?.id) state = const ScheduleDetailUIState();
      });
    });
    return const ScheduleDetailUIState();
  }
}
```

### ✅ Tier 3: Computed Logic Providers

```dart
@riverpod
bool canConfirmSchedule(CanConfirmScheduleRef ref, String scheduleId) {
  final scheduleAsync = ref.watch(scheduleDetailProvider(scheduleId));
  final uiState = ref.watch(scheduleDetailUIProvider(scheduleId));

  return scheduleAsync.when(
    data: (s) => uiState.selectedAttendeeIds.isNotEmpty && !s.isExpired,
    loading: () => false,
    error: (_, __) => false,
  );
}
```

### ✅ Widget Usage (AsyncValue.when Pattern)

```dart
class ScheduleDetailPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleDetailProvider(scheduleId));

    return scheduleAsync.when(
      loading: () => CircularProgressIndicator(),
      error: (e, s) => ErrorWidget(e),
      data: (schedule) => ScheduleContent(schedule),  // ✅ Non-nullable
    );
  }
}
```

### ❌ Common Violations

#### ❌ Violation: Manual isLoading/errorMessage in State

**Problem**:
```dart
// ❌ WRONG - Manual state management
@freezed
sealed class ScheduleState with _$ScheduleState {
  const factory ScheduleState({
    Schedule? schedule,
    @Default(false) bool isLoading,      // ❌ Manual loading
    @Default('') String errorMessage,    // ❌ Manual error
  }) = _ScheduleState;
}

@riverpod
class ScheduleNotifier extends _$ScheduleNotifier {
  @override
  ScheduleState build() => const ScheduleState();

  Future<void> loadSchedule(String id) async {
    state = state.copyWith(isLoading: true);  // ❌ Manual management
    // ...
  }
}
```

**Solution**:
```dart
// ✅ CORRECT - AsyncNotifier with AsyncValue
@riverpod
class Schedule extends _$Schedule {
  @override
  Future<entities.Schedule> build(String scheduleId) async {
    // UseCase throws AppException on error, AsyncValue catches automatically
    return ref.read(getScheduleUseCaseProvider)(scheduleId);
  }
}

// Widget
final scheduleAsync = ref.watch(scheduleProvider(scheduleId));
scheduleAsync.when(
  loading: () => Loader(),      // ✅ Automatic
  error: (e, s) => Error(e),    // ✅ Automatic
  data: (schedule) => UI(),     // ✅ Automatic
);
```

#### ❌ Violation: Mixed Entity and UI State

**Problem**:
```dart
// ❌ WRONG - Entity and UI mixed
@freezed
class ScheduleState with _$ScheduleState {
  const factory ScheduleState({
    Schedule? schedule,                    // ❌ Entity
    @Default([]) List<String> selectedIds, // ❌ UI state
  }) = _ScheduleState;
}
```

**Solution**:
```dart
// ✅ CORRECT - Separated concerns

// Entity Provider
@riverpod
class Schedule extends _$Schedule {
  Future<entities.Schedule> build(String id) async { }
}

// UI State Provider
@freezed
class ScheduleUIState with _$ScheduleUIState {
  const factory ScheduleUIState({
    @Default([]) List<String> selectedIds,  // ✅ UI only
  }) = _ScheduleUIState;
}

@riverpod
class ScheduleUI extends _$ScheduleUI {
  ScheduleUIState build(String scheduleId) {
    ref.watch(scheduleProvider(scheduleId));  // ✅ Depends on entity
    return const ScheduleUIState();
  }
}
```

#### ❌ Violation: Family Provider with Entity Parameter

**Problem**:
```dart
// ❌ WRONG - Entity as family parameter
@riverpod
class ScheduleUI extends _$ScheduleUI {
  ScheduleUIState build(Schedule schedule) {  // ❌ Entity parameter
    // ...
  }
}
```

**Solution**:
```dart
// ✅ CORRECT - ID as family parameter
@riverpod
class ScheduleUI extends _$ScheduleUI {
  ScheduleUIState build(String scheduleId) {  // ✅ ID parameter
    final schedule = ref.watch(scheduleDetailProvider(scheduleId));
    // ...
  }
}
```

**Why**: IDs are immutable and stable, entities change. Using IDs enables proper caching, invalidation, and dependency tracking.

#### ❌ Violation: Incorrect ref.watch() / ref.read() Usage

**Problem**:
```dart
// ❌ WRONG - ref.read() for State provider in build() misses reactive updates
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    final user = ref.read(currentUserProvider);  // ❌ Won't rebuild when user changes
    return getTodos(user.id);
  }
}

// ❌ WRONG - ref.watch() in method creates unwanted dependency
@riverpod
class TodoNotifier extends _$TodoNotifier {
  Future<void> createTodo(String title) async {
    final user = ref.watch(currentUserProvider);  // ❌ Creates unwanted dependency
    await repository.createTodo(user.id, title);
  }
}
```

**Solution**:
```dart
// ✅ CORRECT - ref.watch() for State provider in build()
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    final user = ref.watch(currentUserProvider);  // ✅ Rebuilds when user changes
    return getTodos(user.id);
  }
}

// ✅ CORRECT - ref.read() for UseCase provider in build()
@riverpod
class ScheduleList extends _$ScheduleList {
  @override
  Future<List<Schedule>> build() async {
    // ✅ One-time UseCase call - throws AppException on error
    return ref.read(getScheduleListUseCaseProvider)();
  }
}

// ✅ CORRECT - ref.read() in methods for one-time access
@riverpod
class TodoNotifier extends _$TodoNotifier {
  Future<void> createTodo(String title) async {
    final user = ref.read(currentUserProvider);  // ✅ One-time read
    await repository.createTodo(user.id, title);
  }
}

// ✅ CORRECT - ref.read() for .notifier access
@riverpod
class TodoUI extends _$TodoUI {
  void confirmSchedule() {
    ref.read(scheduleProvider.notifier).confirm();  // ✅ .notifier always uses ref.read()
  }
}
```

**Why**:
- `ref.watch()` creates reactive dependencies that rebuild when the provider changes
- `ref.read()` reads the current value without creating dependencies
- **State providers** (other Notifiers) need `ref.watch()` in `build()` to rebuild when data changes
- **UseCase providers** (one-time function calls) use `ref.read()` because they don't need reactive tracking
- Using `ref.read()` for State providers in `build()` means the provider won't rebuild (stale data)
- Using `ref.watch()` in methods creates unwanted dependencies and can cause unnecessary rebuilds

**Rules**:
- ✅ In `build()` methods: Use `ref.watch()` for **State providers** (reactive dependencies)
- ✅ In `build()` methods: Use `ref.read()` for **UseCase providers** (one-time function calls)
- ✅ In `build()` methods: Use `ref.read()` for **`.notifier` access**
- ✅ In other methods: Use `ref.read()` for all providers (one-time reads)
- ✅ Exception: `ref.listen()` can be used in `build()` for side effects without returning values

**UseCase Provider Identification**:
- Provider name ends with `UseCaseProvider` (e.g., `getTodosUseCaseProvider`)
- Provider name starts with action verbs: `get`, `create`, `update`, `delete`, `fetch`, `save`, `load`, `submit`, `send`, `retrieve`
- Followed by immediate function call: `ref.read(useCaseProvider)()`

#### ❌ Violation: Provider Function Missing Type Suffix

**Problem**:
```dart
// ❌ WRONG - Missing 'usecase' suffix
@riverpod
GetEventsUsecase getEvents(Ref ref) {
  return GetEventsUsecase(ref.watch(eventRepositoryProvider));
}
// Generates: getEventsProvider (ambiguous!)

// ❌ WRONG - Missing 'repository' suffix
@riverpod
EventRepository eventRepo(Ref ref) {
  return EventRepositoryImpl(ref.watch(eventDataSourceProvider));
}
// Generates: eventRepoProvider (ambiguous!)

// ❌ WRONG - Missing 'datasource' suffix
@riverpod
EventDataSource eventData(Ref ref) {
  return EventRemoteDataSource();
}
// Generates: eventDataProvider (ambiguous!)
```

**Solution**:
```dart
// ✅ CORRECT - Includes 'usecase' suffix
@riverpod
GetEventsUsecase getEventsUsecase(Ref ref) {
  return GetEventsUsecase(ref.watch(eventRepositoryProvider));
}
// Generates: getEventsUsecaseProvider (clear!)

// ✅ CORRECT - Includes 'repository' suffix
@riverpod
EventRepository eventRepository(Ref ref) {
  return EventRepositoryImpl(ref.watch(eventDataSourceProvider));
}
// Generates: eventRepositoryProvider (clear!)

// ✅ CORRECT - Includes 'datasource' suffix
@riverpod
EventDataSource eventDataSource(Ref ref) {
  return EventRemoteDataSource();
}
// Generates: eventDataSourceProvider (clear!)
```

**Why**:
- Riverpod code generation creates provider names from function names
- Without proper suffix, generated provider names are ambiguous (e.g., `getEventsProvider`)
- With proper suffix, provider names are clear (e.g., `getEventsUsecaseProvider`)
- Proper naming enables automatic UseCase provider detection in `ref.watch()`/`ref.read()` rules
- Consistent naming improves codebase maintainability

**Rules**:
- ✅ Repository return type: function name must end with `repository`
- ✅ UseCase return type: function name must end with `usecase`
- ✅ DataSource return type: function name must end with `datasource`

### Key Principles

1. **Entity Providers**: Use `AsyncNotifier` with `Future<T> build()` for domain data
2. **UI State Providers**: Use `Notifier` with synchronous `build()` for UI-only state
3. **Family Pattern**: Always use IDs, never entity objects as parameters
4. **Dependencies**: Use `ref.watch()` or `ref.listen()` to depend on entity providers
5. **AsyncValue**: Let Riverpod manage loading/error/data states automatically
6. **Computed Logic**: Create separate providers for derived values
7. **Entity UI Extensions**: Keep formatting/display logic in extensions, not business logic

See [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md) and [STATE_MANAGEMENT_GUIDE.md](doc/STATE_MANAGEMENT_GUIDE.md) for more comprehensive examples.

## Repository Pattern

### Error Handling Strategy

> **Note**: For detailed error handling patterns, see [UNIFIED_ERROR_GUIDE.md](doc/UNIFIED_ERROR_GUIDE.md).

The linter supports a **simplified pass-through pattern** for Repository error handling:
- DataSource throws `AppException` (defined in `app_exception.dart`)
- Repository returns `Future<Entity>` directly (no Result pattern, pass-through errors)
- UseCase calls Repository, may add business validation (throws `AppException`)
- Presentation uses `AsyncValue.guard()` to catch all exceptions

### Correct Pattern

```dart
// domain/repositories/user_repository.dart
abstract interface class UserRepository {
  Future<User> getUser(String id);  // ✅ Returns Entity directly
}

// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource dataSource;

  @override
  Future<User> getUser(String id) async {
    // ✅ Pass-through: Let DataSource exceptions bubble up
    final model = await dataSource.getUser(id);
    return model.toEntity();
  }
}

// data/datasources/user_remote_datasource.dart
class UserRemoteDataSource {
  Future<UserModel> getUser(String id) async {
    try {
      final response = await client.get('/users/$id');
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw e.toAppException();  // ✅ Convert to AppException
    }
  }
}

// domain/usecases/get_user_usecase.dart
class GetUserUseCase {
  final UserRepository repository;

  Future<User> call(String id) async {
    if (id.isEmpty) {
      throw const InvalidInputException.withCode('errorValidationIdRequired');
    }
    return repository.getUser(id);  // ✅ Pass-through
  }
}
```

### Repository Pattern Summary

**Domain Layer (Interfaces)**:
- ✅ Abstract classes or abstract interface classes
- ✅ Return `Future<Entity>` directly (no Result pattern)
- ✅ Named `*Repository` (e.g., `UserRepository`, `TodoRepository`)
- ❌ No implementations or method bodies
- ❌ No Model types in signatures

**Data Layer (Implementations)**:
- ✅ Concrete classes implementing domain interfaces
- ✅ Named `*RepositoryImpl` (e.g., `UserRepositoryImpl`)
- ✅ Must use `implements` keyword
- ✅ Pass-through pattern: Let DataSource exceptions bubble up
- ✅ Use `.toEntity()` method instead of direct `.entity` access
- ❌ No Model types in return signatures (convert to Entity)
- ❌ Never access `.entity` property directly (use `.toEntity()` method)

## Instance Variables & Stateless Architecture

UseCase, Repository, and DataSource classes must be **stateless** and only contain **final** dependency injection fields.

### Allowed Instance Variables

**UseCase** - Only `final`/`const` Repository and Service dependencies:
```dart
// ✅ CORRECT
class GetTodoUseCase {
  final TodoRepository repository;  // ✅ Repository dependency
  final RankingService rankingService;  // ✅ Domain Service dependency

  const GetTodoUseCase(this.repository, this.rankingService);

  Future<Todo> call(String id) {
    return repository.getTodo(id);
  }
}
```

**Repository** - Only `final`/`const` DataSource and infrastructure dependencies:
```dart
// ✅ CORRECT - Both "DataSource" and "Datasource" are accepted
class TodoRepositoryImpl implements TodoRepository {
  final TodoRemoteDataSource remoteDataSource;  // ✅ DataSource (uppercase S)
  final TodoLocalDataSource localDataSource;    // ✅ DataSource
  final AuthDatasource authDatasource;          // ✅ Datasource (lowercase s)
  final StreamController<User> authStateController;  // ✅ Infrastructure
  final String userId;  // ✅ Configuration primitive

  const TodoRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.authDatasource,
    required this.authStateController,
    required this.userId,
  });
}
```

**DataSource** - Only `final`/`const` infrastructure dependencies:
```dart
// ✅ CORRECT
class TodoRemoteDataSource {
  final Dio client;       // ✅ HTTP client
  final String baseUrl;   // ✅ Configuration value

  // ✅ const fields for magic strings (best practice)
  static const String _todoCollection = 'todos';
  static const String _userIdField = 'userId';

  const TodoRemoteDataSource({
    required this.client,
    required this.baseUrl,
  });
}

// ✅ Mock/Fake can have mutable state for testing
class MockAuthDatasource implements AuthDatasource {
  User? _currentUser;  // ✅ Allowed in Mock/Fake

  void setUser(User user) {
    _currentUser = user;
  }
}
```

### Violations

**❌ Mutable State Variables**:
```dart
// ❌ WRONG - UseCase with mutable state
class GetTodoUseCase {
  final TodoRepository repository;
  int callCount = 0;  // ❌ Mutable state variable

  Future<Todo> call(String id) {
    callCount++;  // ❌ State mutation
    return repository.getTodo(id);
  }
}

// ❌ WRONG - Repository with cache state
class TodoRepositoryImpl implements TodoRepository {
  final TodoRemoteDataSource remoteDataSource;
  Todo? _cachedTodo;  // ❌ Mutable state variable

  Future<Todo> getTodo(String id) async {
    if (_cachedTodo?.id == id) return _cachedTodo!;
    // ...
  }
}
```

**❌ Wrong Layer Dependencies**:
```dart
// ❌ WRONG - UseCase directly depending on DataSource
class GetTodoUseCase {
  final TodoRemoteDataSource dataSource;  // ❌ Should use Repository

  Future<Todo> call(String id) {
    return dataSource.getTodo(id);
  }
}

// ❌ WRONG - Repository depending on UseCase (wrong direction)
class TodoRepositoryImpl implements TodoRepository {
  final GetTodoUseCase useCase;  // ❌ Wrong dependency direction

  Future<Todo> getTodo(String id) {
    return useCase.call(id);
  }
}

// ❌ WRONG - DataSource depending on Domain layer
class TodoRemoteDataSource {
  final Dio client;
  final TodoRepository repository;  // ❌ Domain dependency in Data layer
}
```

### Summary

| Component | Allowed Variables | Disallowed |
|-----------|------------------|------------|
| **UseCase** | `final` Repository, Service (Domain) | Mutable state, DataSource dependencies |
| **Repository** | `final` DataSource, primitives (String, int), infrastructure (Stream, Firebase) | Mutable state, UseCase dependencies |
| **DataSource** | `final` primitives, infrastructure (HTTP, DB, Firebase, Stream), Mock/Fake can have mutable state | Domain dependencies (Repository, UseCase, Entity), Service, Manager, Controller |

**Why Stateless?**
- State management belongs in Presentation layer (Riverpod Notifiers)
- Enables testability and predictability
- Prevents hidden state bugs
- Supports concurrent operations

**Allowed Infrastructure Types:**
- Primitives: `String`, `int`, `double`, `bool`, `num`, `List`, `Map`, `Set`
- Async: `Stream`, `Future`, `Completer`, `StreamController`, `StreamSubscription`, `Subscription`
- HTTP: `Dio`, `Client`, `Http`
- Firebase: `Firebase*`, `Firestore*`
- Database: `Database*`, `Cache*`, `Storage*`
- Messaging: `Messaging*`
- Google Mobile Ads: `BannerAd`, `InterstitialAd`, `RewardedAd`, `NativeAd`, `AppOpenAd`, `AdWidget`
- In-App Purchase: `InAppPurchase`, `ProductDetails`, `PurchaseDetails`

**Mock/Fake Exception:**
- Classes starting with `Mock` or `Fake` can have mutable state for testing purposes

## Package Internals (rule registration)

AGENTS.md가 위임하는 rule 등록·패키지 내부 가이드 (본 문서 중복 제거 후 정본 링크):

- Rule 추가/등록: [CONTRIBUTING.md](CONTRIBUTING.md), [doc/RULE_DEVELOPMENT_GUIDE.md](doc/RULE_DEVELOPMENT_GUIDE.md)
- Mixin / 아키텍처: [ARCHITECTURE.md](ARCHITECTURE.md), [lib/src/mixins/README.md](lib/src/mixins/README.md)
- Exception 패턴: [doc/UNIFIED_ERROR_GUIDE.md](doc/UNIFIED_ERROR_GUIDE.md)
- Configuration / Testing / Commands: [doc/CONFIGURATION.md](doc/CONFIGURATION.md), [doc/TESTING_GUIDE.md](doc/TESTING_GUIDE.md)
<!-- END merged-from-claude (ITT-5352) -->
