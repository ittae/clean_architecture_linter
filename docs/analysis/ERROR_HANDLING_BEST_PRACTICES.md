# ERROR_HANDLING_BEST_PRACTICES

`/Volumes/T7 Shield/dev/clean_architecture_linter` 기준으로, Clean Architecture + Riverpod(AsyncValue) 관점의 에러 핸들링 규칙 적합도를 분석했다.

---

## 0) 요약 (핵심 결론)

- 현재 린터는 **pass-through + AsyncValue 중심 아키텍처**를 이미 강하게 지향한다.
  - 근거: `usecase_no_result_return_rule.dart`, `repository_pass_through_rule.dart`, `datasource_no_result_return_rule.dart`, `presentation_use_async_value_rule.dart`.
- 다만 일부 규칙/문서에는 **구(舊) Result 패턴 서술이 혼재**되어 있어 메시지 일관성이 떨어진다.
  - 예: `data_rules/README.md`는 Repository에서 Result 변환을 권장 (`lib/src/rules/data_rules/README.md:15, 101, 127`), 반면 실제 룰/UNIFIED 가이드는 pass-through 지향.
  - 예: `datasource_no_result_return_rule.dart`의 correctionMessage 일부도 Repository가 Result로 변환한다고 안내 (`.../datasource_no_result_return_rule.dart:61-63`).
- 실무 적용 관점에서 가장 중요한 개선 포인트는 다음 3개:
  1. **문서/룰 메시지의 단일 철학 정렬(pass-through)**
  2. **검출 로직 정밀화(타입 추론 기반)로 FP/FN 축소**
  3. **UseCase/Presentation 경계에서 “예외 직접 처리 금지”를 더 명시적으로 강제**

---

## 1) 현재 린터 내 에러 핸들링 관련 규칙 식별

아래는 에러 핸들링과 직접 연관된 룰들이다.

| 레이어 | 파일 경로 | 규칙명 | 의도 |
|---|---|---|---|
| Data | `lib/src/rules/data_rules/datasource_no_result_return_rule.dart` | `datasource_no_result_return` | DataSource는 Result/Either 대신 예외를 던지고, 상위 레이어로 전파하도록 강제 |
| Data | `lib/src/rules/data_rules/datasource_exception_types_rule.dart` | `datasource_exception_types` | DataSource에서 허용된 AppException 계열만 사용하도록 유도 |
| Data | `lib/src/rules/data_rules/repository_pass_through_rule.dart` | `repository_pass_through` | Repository는 Result 패턴 대신 `Future<Entity>` 반환 + 예외 pass-through 유도 |
| Data | `lib/src/rules/data_rules/repository_no_throw_rule.dart` | `repository_no_throw` | Repository의 직접 throw를 억제(비표준 예외 throw 시 INFO 경고) |
| Domain | `lib/src/rules/domain_rules/usecase_no_result_return_rule.dart` | `usecase_no_result_return` | UseCase에서 Result/Either 반환 금지, 엔티티 직접 반환 + 검증 예외 throw 유도 |
| Domain | `lib/src/rules/domain_rules/exception_naming_convention_rule.dart` | `exception_naming_convention` | 도메인 예외 이름을 feature prefix 형태로 표준화 |
| Presentation | `lib/src/rules/presentation_rules/presentation_use_async_value_rule.dart` | `presentation_use_async_value` | 상태 객체에 `error/loading` 필드 저장 금지, AsyncValue 패턴 강제 |
| Presentation | `lib/src/rules/presentation_rules/presentation_no_throw_rule.dart` | `presentation_no_throw` | Notifier/State 계층에서 throw/rethrow 금지(상태로 표현) |
| Presentation | `lib/src/rules/presentation_rules/presentation_no_data_exceptions_rule.dart` | `presentation_no_data_exceptions` | Presentation에서 Data-layer 예외 타입 직접 분기 금지 |
| Presentation(간접) | `lib/src/rules/presentation_rules/widget_ref_read_then_when_rule.dart` | `widget_ref_read_then_when` | AsyncValue lifecycle을 우회하는 post-read `.when()` 안티패턴 방지 |

참고: 룰 등록 진입점은 `lib/clean_architecture_linter.dart`.

---

## 2) 레이어별 모범 사례 정리

### 2.1 Data Layer

#### 모범 사례
- **외부 예외 → AppException 변환은 DataSource 경계에서 수행**
  - 네트워크/SDK 예외를 도메인 친화적(앱 표준) 예외로 정규화.
- **Repository는 pass-through + 모델→엔티티 변환만 담당**
  - 불필요한 try-catch/Result wrapping 지양.
- **Repository의 직접 throw는 원칙적으로 금지**
  - 필요한 경우(입력 검증/명시적 정책)만 제한적으로 허용하되 AppException 계열 사용.

#### 현재 룰 반영
- `datasource_no_result_return` ✅
- `datasource_exception_types` ✅
- `repository_pass_through` ✅
- `repository_no_throw` ◑ (비표준 throw만 INFO, 강제력 약함)

---

### 2.2 Domain Layer

#### 모범 사례 (일반론)
- UseCase 반환 타입은 팀 정책이 갈린다.
  - **A안:** `Result/Either`로 명시적 실패 모델링
  - **B안:** pass-through 예외 + `Future<Entity>`
- 중요한 것은 **프로젝트 단일 철학 유지**.
- 도메인 예외는 feature prefix + 의미 있는 타입 분리.

#### 현재 프로젝트 철학(코드 근거)
- 이 린터/가이드는 **B안(pass-through)** 를 명시적으로 선택.
  - `usecase_no_result_return_rule.dart:8-19, 54-60`
  - `doc/UNIFIED_ERROR_GUIDE.md` 전반

#### 현재 룰 반영
- `usecase_no_result_return`은 B안에는 매우 적합, A안(Either 선호 팀)에는 불일치.
- `exception_naming_convention`은 예외 가독성/충돌 방지 측면에서 유효.

---

### 2.3 Presentation Layer (Riverpod)

#### 모범 사례
- **AsyncValue를 단일 에러 표현 채널**로 사용 (`AsyncValue.guard`, `when`).
- UI 상태(선택/편집 등)와 비동기 상태(loading/error/data) 분리.
- UI/Notifier에서 예외를 다시 throw하지 말고 상태로 표출.
- UI는 에러 타입 세부 분기 최소화 + 재시도/대체 UX 제공.

#### 현재 룰 반영
- `presentation_use_async_value`가 핵심 안티패턴(loading/error 필드)을 잘 차단.
- `presentation_no_throw`가 throw 기반 흐름을 억제.
- `presentation_no_data_exceptions`가 레이어 경계 침범(데이터 예외 직접 처리) 억제.

---

## 3) 현재 규칙 ↔ 모범 사례 매핑표

평가 기준: **충분 / 부분 / 부족**

| 모범 사례 | 관련 룰 | 평가 | 코멘트 |
|---|---|---|---|
| DataSource에서 Result 반환 금지 | `datasource_no_result_return` | 충분 | 핵심 방향 일치. 단, 메시지 일부가 구 패턴 문구 포함 (`...:61-63`) |
| DataSource에서 표준 예외만 사용 | `datasource_exception_types` | 부분 | 변수 throw(`throw e`)는 스킵되어 FN 가능 (`...:111-113`) |
| Repository pass-through 유지 | `repository_pass_through` | 충분 | Result 반환 금지 + Future<Entity> 유도는 좋음 |
| Repository 직접 throw 금지 | `repository_no_throw` | 부분 | 비표준 throw만 INFO; AppException throw는 허용되어 정책 강제 약함 |
| UseCase Result/Either 금지(프로젝트 정책) | `usecase_no_result_return` | 충분(현 정책) | pass-through 정책과 정합. 단, 일반론(Either 선호)과는 충돌 가능 |
| 도메인 예외 네이밍 표준화 | `exception_naming_convention` | 부분 | 이름 강제는 좋으나 도메인 예외 “사용 위치/변환 책임”까지는 미검증 |
| Presentation에서 AsyncValue 사용 | `presentation_use_async_value` | 부분 | 네이밍 기반 탐지로 FP 가능(예: `hasErrorPermission`) |
| Presentation에서 throw 금지 | `presentation_no_throw` | 충분 | 방향 명확. 다만 일부 프레임워크 코드 패턴에서 오탐 여지 |
| UI에서 Data 예외 직접 처리 금지 | `presentation_no_data_exceptions` | 부분 | `is` 표현식만 탐지(try-on-catch, pattern matching 일부 미포착) |

---

## 4) 실무 경계 사례 10개 (FP/FN 포함)

1. **`throw e` (변수 throw) in DataSource**
   - 현상: 타입 추론 못하면 스킵
   - 영향: FN (`datasource_exception_types`)

2. **Repository에서 `throw InvalidInputException`**
   - 현상: AppException이면 허용
   - 영향: 정책상 “Repository no-throw”를 강제하려면 FN (`repository_no_throw`)

3. **`FutureOr<Entity>` vs `Future<Entity>` 반환**
   - 현상: 일부 규칙 허용, 일부 메시지와 불일치
   - 영향: 개발자 혼란(정책 해석 차이)

4. **State 필드명에 `error` 문자열 포함된 비에러 의미**
   - 예: `errorBoundaryEnabled`
   - 영향: FP (`presentation_use_async_value`)

5. **`isLoading`이 실제로 UI-only 플래그(비동기와 무관)**
   - 영향: FP 가능 (`presentation_use_async_value`)

6. **Presentation에서 `on AppException catch`는 합리적이지만, `is` 분기만 금지 우회**
   - 영향: 룰 일관성 공백 (`presentation_no_data_exceptions`는 `is`만 검사)

7. **Dart 3 pattern matching (`switch (error) { NotFoundException() => ... }`)**
   - 영향: FN (`IsExpression` 중심 탐지일 때)

8. **UseCase 클래스명 컨벤션 미준수 (`GetTodoInteractor`)**
   - 영향: `usecase_no_result_return` 미적용 FN (클래스명 기반)

9. **Repository 식별이 이름/implements 기반**
   - 영향: 비정형 naming에서 FN (`RepositoryRuleVisitor` 의존)

10. **문서/코드 정책 불일치**
   - 예: `data_rules/README.md`는 Result 변환 권고, 실제 룰은 pass-through
   - 영향: 팀 온보딩/코드리뷰 기준 혼선

---

## 5) 개선 제안

### 5.1 기존 규칙 튜닝

1) `datasource_no_result_return`
- 수정: correctionMessage의 “Repository will catch exceptions and convert to Result” 제거
- 제안 문구: “Repository는 예외를 pass-through하고 Model→Entity 변환만 수행”
- 우선순위: **P0**

2) `repository_no_throw`
- 현재: 비표준 예외에 INFO (`.../repository_no_throw_rule.dart:94`)
- 제안: 기본 WARNING로 상향 + `strict_repository_no_throw: true` 옵션 시 모든 public throw 금지
- 우선순위: **P1**

3) `presentation_no_data_exceptions`
- 현재: `is` 표현식만 검사 (`.../presentation_no_data_exceptions_rule.dart:82`)
- 제안: `CatchClause`/pattern switch까지 확장
- 우선순위: **P1**

4) `presentation_use_async_value`
- 현재: 문자열 포함 탐지로 FP 여지 큼
- 제안: 타입 정보 결합 (`String?`, `Exception`, `Failure`, `bool isLoading`)일 때만 경고 강화
- 우선순위: **P2**

5) 문서 정합성
- `lib/src/rules/data_rules/README.md`, `domain_rules/README.md`, 각 규칙 주석에서 Result 잔재 제거
- 우선순위: **P0**

---

### 5.2 신규 규칙 제안 5개

#### 1) `usecase_must_not_catch_and_wrap`
- 목적: UseCase가 Data/App 예외를 catch 후 문자열/일반 Exception으로 래핑하는 안티패턴 금지
- 탐지 개요:
  - UseCase 클래스 내 `CatchClause` 탐지
  - catch 내부에서 `throw Exception(...)`, `throw StateError(...)` 등 발생 시 경고

#### 2) `repository_no_try_catch_passthrough`
- 목적: pass-through 정책에서 Repository의 불필요 try-catch 자체를 제한
- 탐지 개요:
  - Repository public method 내 `TryStatement` 탐지
  - catch에서 단순 재throw/재매핑이면 위반 (허용 예외: 로깅 only + rethrow 옵션)

#### 3) `presentation_asyncvalue_guard_required`
- 목적: AsyncNotifier/Notifier의 async action에서 `AsyncValue.guard` 사용 강제
- 탐지 개요:
  - provider/notifier 메서드 중 `Future` 반환 메서드 탐지
  - state를 loading으로 바꾸고 직접 try-catch만 하는 패턴 경고

#### 4) `widget_no_error_type_switch`
- 목적: Widget에서 상세 예외 타입 분기 남용 억제(특히 Data 예외)
- 탐지 개요:
  - presentation/widget 파일의 `switch(error)`/`if (error is ...)` 탐지
  - Data 예외 분기 시 위반, Domain/AppException만 제한 허용

#### 5) `datasource_must_map_external_exception`
- 목적: 외부 SDK 예외(DioException/FirebaseException 등)를 AppException으로 매핑 강제
- 탐지 개요:
  - DataSource 내 외부 클라이언트 호출 존재 시
  - `on DioException`/`on FirebaseException` catch 없는 경우 혹은 catch 후 AppException 변환 없는 경우 경고

---

## 6) flutter_boilerplate 스타일 적용 가이드

> 본 린터 철학(UNIFIED_ERROR_GUIDE) 기준

### 6.1 Repository pass-through + throw 예외정책

- Repository public method 정책:
  - 기본: **throw 금지**, try-catch 금지
  - 허용: DataSource 호출 + model.toEntity 변환
- DataSource:
  - 외부 예외를 AppException으로 변환 후 throw
- UseCase:
  - 입력/비즈니스 검증 실패 시만 AppException throw

권장 템플릿:
```dart
// Repository
Future<User> getUser(String id) async {
  final model = await dataSource.getUser(id);
  return model.toEntity();
}

// UseCase
Future<User> call(String id) {
  if (id.trim().isEmpty) throw const InvalidInputException.withCode('errorValidationIdRequired');
  return repository.getUser(id);
}
```

### 6.2 Riverpod 3.0 AsyncValue 패턴

- Entity provider: `@riverpod class X extends _$X` + `FutureOr<T> build()`
- mutation/refresh: `state = await AsyncValue.guard(() async { ... })`
- UI state provider는 별도 분리(선택/필터 등), 에러/로딩 필드 금지

권장 템플릿:
```dart
@riverpod
class UserList extends _$UserList {
  @override
  FutureOr<List<User>> build() => ref.read(getUsersUseCaseProvider)();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(getUsersUseCaseProvider)());
  }
}
```

### 6.3 테스트 전략 (단위/위젯)

- 단위 테스트
  - DataSource: 외부 예외 → AppException 매핑 검증
  - Repository: 예외 pass-through + 변환 로직(model→entity) 검증
  - UseCase: 입력 검증 예외/정상 경로 검증
- 위젯 테스트
  - `AsyncLoading/AsyncData/AsyncError` 렌더링 분기
  - retry 액션이 provider invalidate/refresh를 호출하는지 검증

최소 케이스 세트:
1. DataSource가 404 응답 시 `NotFoundException` throw
2. Repository가 해당 예외를 가공하지 않고 상위로 전달
3. UseCase invalid input 시 `InvalidInputException.withCode` throw
4. Provider `AsyncValue.guard`로 `AsyncError` 상태 전이
5. Widget에서 error UI + retry 동작

---

## 7) 이번 주 바로 실행 체크리스트 (우선순위 포함)

### P0 (이번 주 즉시)
- [ ] `datasource_no_result_return_rule.dart` correctionMessage에서 Result 변환 문구 제거 (`:61-63`)
- [ ] `lib/src/rules/data_rules/README.md`의 Result 중심 설명을 pass-through로 전면 정렬
- [ ] `presentation_no_data_exceptions_rule.dart` 가이드 링크를 `UNIFIED_ERROR_GUIDE.md` 기준으로 정리

### P1 (이번 주 내)
- [ ] `repository_no_throw` severity를 WARNING로 상향하거나 strict 옵션 추가
- [ ] `presentation_no_data_exceptions`를 `CatchClause`/pattern switch까지 확장
- [ ] 신규 룰 1개 우선 구현: `repository_no_try_catch_passthrough`

### P2 (다음 스프린트 시작)
- [ ] `presentation_use_async_value` 오탐 축소(이름+타입 결합)
- [ ] `usecase_must_not_catch_and_wrap` 신규 룰 PoC
- [ ] 경계 사례 10개를 회귀 테스트 fixture로 추가

---

## 부록: 정책 일관성 이슈(근거)

- pass-through 정책 근거:
  - `doc/UNIFIED_ERROR_GUIDE.md`
  - `lib/src/rules/domain_rules/usecase_no_result_return_rule.dart:8-19`
  - `lib/src/rules/data_rules/repository_pass_through_rule.dart:12-15`
- 혼재/구패턴 근거:
  - `lib/src/rules/data_rules/README.md:15, 101, 127, 164`
  - `lib/src/rules/data_rules/datasource_no_result_return_rule.dart:61-63`
  - `lib/src/rules/presentation_rules/presentation_no_throw_rule.dart:15-16` (주석상 Result 흐름 서술)

즉, **룰 엔진 방향성은 이미 올바른 편**이며, 지금 필요한 것은 **문구/문서 정합성 + 탐지 정밀화**다.
