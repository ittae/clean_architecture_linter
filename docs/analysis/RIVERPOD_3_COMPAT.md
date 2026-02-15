# Riverpod 3.0 호환성 분석 (clean_architecture_linter)

분석 대상: `/Volumes/T7 Shield/dev/clean_architecture_linter`

기준 파일(룰 등록):
- `lib/clean_architecture_linter.dart` (Riverpod 관련 룰 활성화: lines 154~185)

---

## 1) Riverpod 관련 규칙 목록 및 의도

### A. `riverpod_generator`
- 파일: `lib/src/rules/presentation_rules/riverpod_generator_rule.dart`
- 의도: 수동 Provider 선언 대신 `@riverpod` 코드 생성을 강제
- 핵심 탐지:
  - `StateNotifierProvider`, `ChangeNotifierProvider`, `StateProvider`, `FutureProvider`, `StreamProvider`를 수동 선언으로 간주 (lines 81~87)
  - presentation + provider 파일 경로에서만 검사 (lines 65~69)

### B. `riverpod_ref_usage`
- 파일: `lib/src/rules/presentation_rules/riverpod_ref_usage_rule.dart`
- 의도: `build()`에서는 `ref.watch`, 기타 메서드에서는 `ref.read` 사용 강제
- 핵심 탐지:
  - provider 파일 스코프 제한 (lines 116~126)
  - `@riverpod` 또는 `extends _$...` 클래스만 검사 (lines 145~163)
  - `build()` 내 `ref.read` 경고, 단 `UseCase 호출`/`.notifier`는 예외 (lines 182~215)
  - UseCase 추론: `...UseCaseProvider` 또는 동사 prefix + `Provider` (lines 300~325)

### C. `riverpod_provider_naming`
- 파일: `lib/src/rules/presentation_rules/riverpod_provider_naming_rule.dart`
- 의도: `@riverpod` 함수명이 반환 타입(`Repository/UseCase/DataSource`) suffix를 포함하도록 강제
- 핵심 탐지:
  - 함수형 `@riverpod`만 검사 (lines 107~143)
  - 반환 타입 문자열에서 suffix 추출 후 함수명 끝 suffix 비교 (lines 171~210)

### D. `widget_ref_read_then_when`
- 파일: `lib/src/rules/presentation_rules/widget_ref_read_then_when_rule.dart`
- 의도: 같은 함수에서 `ref.read(...).when()` 패턴 금지
- 핵심 탐지:
  - presentation widget/page/screen/view 파일만 검사 (lines 251~260)
  - `ref.read` 결과 변수에 대해 `.when()` 호출되면 경고 (lines 194~237)

### E. `ref_mounted_usage`
- 파일: `lib/src/rules/presentation_rules/ref_mounted_usage_rule.dart`
- 의도: `ref.mounted` 사용을 설계 문제 은폐로 간주해 금지
- 핵심 탐지:
  - `ref.mounted`, `!ref.mounted` 패턴 직접 탐지 (lines 81~113)

### F. `riverpod_keep_alive`
- 파일: `lib/src/rules/presentation_rules/riverpod_keep_alive_rule.dart`
- 의도: `@Riverpod(keepAlive: true)` 남용 방지
- 핵심 탐지:
  - `@Riverpod` + `keepAlive: true` + class 기반에서만 검사 (lines 112~140)
  - class명/path heuristic으로 global 상태인지 추정 (lines 52~85, 149~160)

---

## 2) Riverpod 3.0 API와 충돌 가능성 (deprecated/새 패턴)

전반 결론:
- **직접적인 Riverpod 3.0 API 파손은 크지 않음**
- 다만 다수 규칙이 **아키텍처 정책(팀 컨벤션)** 을 Riverpod API 규칙처럼 강제하고 있어, Riverpod 3의 합법 패턴을 과잉 제한/오탐할 수 있음

### 충돌/리스크 포인트

1. `riverpod_generator`의 “수동 provider 전면 금지”
- Riverpod 3에서도 `Provider/FutureProvider/StreamProvider/...` 수동 선언은 유효한 API 패턴
- 본 룰은 deprecated 여부와 무관하게 금지 (정책적 금지)
- 근거: `riverpod_generator_rule.dart` lines 81~87

2. 수동 Provider 타입 커버리지 불완전
- 금지 목록에 `NotifierProvider`, `AsyncNotifierProvider`, `Provider` 등이 없음
- 즉 “수동 선언 금지” 의도 대비 누락
- 근거: 같은 파일 manualProviders 배열

3. `ref_mounted` 절대 금지
- Riverpod 3에서 `ref.mounted` 자체가 deprecated는 아님(실무에서 안전 가드로 사용 가능)
- 룰은 설계 철학 차원에서 무조건 경고
- 근거: `ref_mounted_usage_rule.dart` lines 43~47, 85~112

4. `riverpod_ref_usage`의 경직된 watch/read 규칙
- `build()` 내 `ref.read`를 거의 금지하지만, Riverpod 3에서는 의도적 one-shot read도 합법
- 또한 메서드 내 `ref.watch`도 일부 고급 패턴에서 정당화될 수 있음

5. `@Riverpod`/`@riverpod` 혼재 처리 비대칭
- 일부 룰은 둘 다 허용(예: naming/ref_usage), keepAlive 룰은 `@Riverpod`만 확인
- 생성 스타일 차이에 따라 누락 가능
- 근거: `riverpod_keep_alive_rule.dart` line 114

---

## 3) 코드 생성(@riverpod) 기반 아키텍처와의 적합성

장점:
- `riverpod_generator`, `riverpod_provider_naming`, `riverpod_ref_usage` 조합은 **생성 기반 + 컨벤션 기반** 아키텍처 표준화에 매우 유리
- 팀 내 “provider 이름만 봐도 역할 파악” 가능
- `clean_architecture_linter.dart`에서 관련 룰이 기본 활성화

한계:
- 규칙 간 결합이 문자열/파일명 휴리스틱 중심이라, 프로젝트 구조가 조금만 달라도 정확도 저하
- class-based `@riverpod`와 function-based `@riverpod`를 동일 깊이로 다루지 못함(특히 naming/keepAlive)

요약: **생성 중심 아키텍처에는 적합하지만, Riverpod 3의 유연한 합법 패턴까지 허용하려면 완화/정교화 필요**.

---

## 4) notifier/provider naming, ref 사용 패턴 탐지 정확도

### Naming 탐지 정확도
- 강점: 반환 타입 기반 suffix 강제 자체는 일관적 (`Repository/UseCase/DataSource`)
- 약점:
  - return type이 `Future<GetXUseCase>`/typedef/generic 래핑이면 탐지 실패 가능 (`NamedType` 단순 추출)
  - class-based provider는 검사 대상 아님 (함수 선언만)

### ref 사용 탐지 정확도
- 강점: AST 재귀로 `ref.watch/read` 수집, `.notifier` 예외 처리 존재
- 약점:
  - UseCase 추론이 네이밍 의존 (동사 prefix 기반) → 오탐 위험
  - `build()` 내 비반응 read 합법 사례를 위반으로 처리
  - provider 파일 경로 의존도가 높아 구조 변경 시 누락

---

## 5) False Positive 사례 5개

1. `riverpod_ref_usage`: build에서 의도적 one-shot read
```dart
@riverpod
class ClockLabel extends _$ClockLabel {
  @override
  String build() {
    final locale = ref.read(localeProvider); // 고정값 의도
    return format(locale);
  }
}
```
- Riverpod 관점 합법이나 룰 경고
- 근거 룰: `riverpod_ref_usage_rule.dart` lines 182~201

2. `riverpod_ref_usage`: build 내 command trigger용 read
```dart
@riverpod
class Boot extends _$Boot {
  @override
  Future<void> build() async {
    ref.read(analyticsProvider).trackOpen();
  }
}
```
- side-effect 서비스 호출 read도 경고 가능

3. `widget_ref_read_then_when`: 의도적 스냅샷 분기
```dart
void onTap() {
  final s = ref.read(todoProvider);
  s.when(data: ..., error: ..., loading: ...);
}
```
- UX상 즉시 스냅샷 처리 의도인데 무조건 anti-pattern 처리

4. `ref_mounted_usage`: 취소 불가능 외부 API 보호용 가드
```dart
await sdk.call();
if (!ref.mounted) return;
state = ...;
```
- 실무 안전 가드도 전면 금지

5. `riverpod_keep_alive`: 전역성 있지만 이름 heuristic 미스
```dart
@Riverpod(keepAlive: true)
class TokenStore extends _$TokenStore {}
```
- class/path에 `auth|session|...` 키워드가 없으면 경고 가능
- 근거: `riverpod_keep_alive_rule.dart` lines 52~75, 149~161

---

## 6) False Negative 사례 5개

1. `riverpod_generator`: `NotifierProvider` 수동 선언 미검출
```dart
final p = NotifierProvider<TodoNotifier, TodoState>(TodoNotifier.new);
```
- manualProviders 목록 누락

2. `riverpod_generator`: `AsyncNotifierProvider` 미검출
```dart
final p = AsyncNotifierProvider<TodoNotifier, TodoState>(TodoNotifier.new);
```

3. `riverpod_generator`: `Provider` 수동 선언 미검출
```dart
final envProvider = Provider((ref) => Env.prod);
```

4. `riverpod_keep_alive`: 함수형 provider keepAlive 누락
```dart
@Riverpod(keepAlive: true)
Future<Config> config(Ref ref) async => ...;
```
- parent를 `ClassDeclaration`로만 처리 (lines 137~140)

5. `riverpod_provider_naming`: class-based notifier naming 미검사
```dart
@riverpod
class Todo extends _$Todo {}
```
- 함수 선언만 검사하여 class provider naming 정책 누락

---

## 7) 개선 제안 (규칙별)

### `riverpod_generator` 개선
- `manualProviders` 확장: `Provider`, `NotifierProvider`, `AsyncNotifierProvider`, autoDispose 변형 포함
- `MethodInvocation` 외 `InstanceCreationExpression` 패턴도 커버
- 옵션화: `strict_generator_only: true/false`로 팀 정책 강도 조절

### `riverpod_ref_usage` 개선
- `build()` 내 `ref.read`를 전면 금지 대신 분류:
  - 상태 provider read만 경고, service/usecase read 허용(타입 기반)
- 네이밍 기반 UseCase 추론 대신 analyzer type resolution 사용
- `ref.watch` 허용 예외(메모이즈/derived provider) 옵션 제공

### `riverpod_provider_naming` 개선
- 함수뿐 아니라 class-based `@riverpod class` naming 정책 추가
- 반환 타입 unwrap (`Future<T>`, `Result<T>`, typedef) 처리
- 별칭(`Repo`, `UC`, `DS`) 허용 여부를 config로 제공

### `widget_ref_read_then_when` 개선
- “같은 함수 내 존재”가 아닌 데이터 흐름 기반으로 정밀화
- 허용 컨텍스트 도입: debug/logging/instant snapshot handler
- `ref.listen` 사용 중일 때 중복 경고 억제

### `ref_mounted_usage` 개선
- 전면 금지 대신 severity 하향 + 예외 태그 허용(예: `// ignore: ...` 가이드 강화)
- `CancelableOperation`, `ref.onDispose` 사용 시 경고 억제

### `riverpod_keep_alive` 개선
- `@riverpod(keepAlive: true)` 표기도 함께 처리
- class 외 함수형 provider도 검사
- 키워드 휴리스틱 + 실제 의존성(예: auth/session provider graph) 기반 판단으로 정밀화

---

## 종합 결론

- 현재 룰셋은 **Riverpod 3 API 호환성 자체보다는 팀 아키텍처 표준 강제에 최적화**되어 있음.
- `@riverpod` 생성 기반 아키텍처를 밀어붙이는 목적에는 효과적.
- 다만 Riverpod 3에서 허용되는 유연한 패턴을 일부 과도하게 제한하고, 반대로 일부 수동 provider 패턴은 놓치고 있음.
- 우선순위 높은 수정은:
  1) `riverpod_generator` 누락 타입 보완
  2) `riverpod_ref_usage` type-aware 판별 전환
  3) `riverpod_keep_alive`의 함수형/소문자 어노테이션 커버
