# Unified Error Architecture Guide

Clean Architecture + Riverpod + AsyncValue 통합 에러 처리 가이드

---

## 목차

- [개요](#개요)
- [아키텍처 다이어그램](#아키텍처-다이어그램)
- [에러 처리 흐름](#에러-처리-흐름)
- [계층별 패턴](#계층별-패턴)
  - [1. DataSource Layer](#1-datasource-layer)
  - [2. Repository Layer](#2-repository-layer)
  - [3. UseCase Layer](#3-usecase-layer)
  - [4. Presentation Layer](#4-presentation-layer)
  - [5. UI Layer](#5-ui-layer)
- [AppException 타입](#appexception-타입)
- [i18n 패턴](#i18n-패턴)
- [Best Practices](#best-practices)
- [마이그레이션 가이드](#마이그레이션-가이드)

---

## 개요

### 핵심 원칙

1. **단일 에러 시스템** - `AppException` sealed class 하나로 통합
2. **AsyncValue가 에러 관리** - Result 패턴 불필요, Riverpod이 자동 처리
3. **code 기반 i18n** - Exception은 `code` + `debugMessage`만 가짐, UI에서 `toMessage(context)` 호출
4. **경계는 두 곳** - DataSource (외부→도메인), UI (도메인→사용자)

### 파일 구조

```
lib/core/error/
└── app_exception.dart       # 통합 Exception sealed class + i18n Extension

lib/l10n/
├── app_ko.arb               # 한국어 에러 메시지
├── app_en.arb               # 영어 에러 메시지
└── app_ja.arb               # 일본어 에러 메시지
```

### Spring Boot와 비교

| 구분 | Spring Boot | Flutter |
|------|-------------|---------|
| 외부 세계 | HTTP 클라이언트 | 사용자 (눈) |
| 위 경계 | @ControllerAdvice | UI (Widget) |
| 아래 경계 | Repository/DataSource | DataSource |
| i18n 도구 | MessageSource + Locale | AppLocalizations + BuildContext |
| 에러 래퍼 | ResponseEntity | AsyncValue |

**공통점:** 도메인 에러는 중앙에서 정의, 경계에서 변환

---

## 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                    사용자 (눈으로 보는 사람)                  │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│ UI (Widget)                                    ← 경계       │
│ • error.toMessage(context) 호출                             │
│ • i18n 메시지 표시                                          │
│ • 에러 타입별 아이콘/액션                                    │
├─────────────────────────────────────────────────────────────┤
│ Presentation (Notifier)                                     │
│ • AsyncValue.guard()로 에러 자동 캐치                       │
│ • 상태 관리만 담당                                          │
├─────────────────────────────────────────────────────────────┤
│ Domain (UseCase)                                            │
│ • 비즈니스 로직 + 입력 검증                                  │
│ • throw AppException (검증 실패시)                          │
├─────────────────────────────────────────────────────────────┤
│ Domain (Repository Interface)                               │
│ • 추상화만 정의                                             │
├─────────────────────────────────────────────────────────────┤
│ Data (Repository Impl)                                      │
│ • Model → Entity 변환                                       │
│ • 에러는 그냥 통과                                          │
├─────────────────────────────────────────────────────────────┤
│ Data (DataSource)                              ← 경계       │
│ • 외부 시스템 에러 → AppException 변환                      │
│ • Firebase/Dio Exception → AppException                     │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│              외부 시스템 (Firebase, REST API)                │
└─────────────────────────────────────────────────────────────┘
```

---

## 에러 처리 흐름

```
FirebaseException / DioException
        ↓ catch
DataSource: throw NotFoundException('Entity $id')  // debugMessage
        ↓ (통과)
Repository: (Model → Entity 변환만)
        ↓ (통과)
UseCase: (비즈니스 검증시 throw InvalidInputException.withCode('errorValidationXxx'))
        ↓ AsyncValue.guard() 자동 캐치
Presentation: AsyncValue.error(exception, stackTrace)
        ↓
UI: error.toMessage(context) → "요청한 데이터를 찾을 수 없어요"
```

**요약 표:**

| 레이어 | 역할 | 에러 처리 |
|--------|------|----------|
| DataSource | 외부 시스템 통신 | `throw AppException` |
| Repository | Model → Entity 변환 | 패스스루 (에러 그대로 전파) |
| UseCase | 비즈니스 로직/검증 | 검증 실패시 `throw AppException` |
| Presentation | 상태 관리 | `AsyncValue.guard()` |
| UI | 사용자 표시 | `error.toMessage(context)` |

---

## 계층별 패턴

### 1. DataSource Layer

**역할:** 외부 시스템(Firebase, API)의 에러를 AppException으로 변환

**핵심 규칙:**
- ✅ `throw AppException` 직접 던지기
- ✅ Firebase/Dio Exception을 AppException으로 변환
- ❌ Result 패턴 사용 금지

```dart
class TodoFirestoreDataSource implements TodoDataSource {
  @override
  Future<TodoModel> get(String id) async {
    try {
      await _delay();
      final todo = _store[id];
      if (todo == null) {
        throw NotFoundException('Todo $id');  // 직접 throw
      }
      return todo;
    } on AppException {
      rethrow;  // AppException은 그대로 전파
    } on FirebaseException catch (e) {
      // Firebase Exception → AppException 변환
      throw switch (e.code) {
        'permission-denied' => ForbiddenException(e.message),
        'unauthenticated' => UnauthorizedException(e.message),
        'not-found' => NotFoundException(e.message),
        'unavailable' || 'deadline-exceeded' => NetworkException(e.message),
        'already-exists' => ConflictException(e.message),
        _ => ServerException(e.message),
      };
    } catch (e) {
      throw UnknownException('Failed to get todo', e);
    }
  }
}
```

### 2. Repository Layer

**역할:** Model → Entity 변환, 에러는 그냥 통과

**핵심 규칙:**
- ✅ `Future<Entity>` 직접 반환
- ✅ 에러는 패스스루 (try-catch 없음)
- ❌ Result 패턴 사용 금지

```dart
class TodoRepositoryImpl implements TodoRepository {
  const TodoRepositoryImpl(this._dataSource);
  final TodoDataSource _dataSource;

  @override
  Future<List<Todo>> getAll() async {
    final models = await _dataSource.getAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Todo> get(String id) async {
    final model = await _dataSource.get(id);
    return model.toEntity();  // 에러는 그냥 통과
  }

  @override
  Future<Todo> create({required String title, String? description}) async {
    final model = await _dataSource.create(title: title, description: description);
    return model.toEntity();
  }

  @override
  Future<Todo> update(Todo todo) async {
    final model = await _dataSource.update(TodoModel.fromEntity(todo));
    return model.toEntity();
  }

  @override
  Future<void> delete(String id) => _dataSource.delete(id);
}
```

### 3. UseCase Layer

**역할:** 비즈니스 로직 + 입력 검증, 검증 실패시 throw

**핵심 규칙:**
- ✅ `Future<Entity>` 직접 반환
- ✅ 입력 검증 실패시 `throw AppException`
- ✅ 구체적 검증 에러는 `InvalidInputException.withCode()` 사용
- ❌ Result 패턴 반환 금지

```dart
class GetTodoUseCase {
  const GetTodoUseCase(this._repository);
  final TodoRepository _repository;

  Future<Todo> call(String id) {
    // 입력 검증 - withCode로 구체적 에러 코드 지정
    if (id.trim().isEmpty) {
      throw const InvalidInputException.withCode('errorValidationIdRequired');
    }
    return _repository.get(id);  // 그냥 호출
  }
}

class CreateTodoUseCase {
  const CreateTodoUseCase(this._repository);
  final TodoRepository _repository;

  Future<Todo> call({required String title, String? description}) {
    final trimmed = title.trim();

    // 비즈니스 검증 - withCode로 구체적 에러 코드 지정
    if (trimmed.isEmpty) {
      throw const InvalidInputException.withCode('errorValidationTitleRequired');
    }
    if (trimmed.length > 200) {
      throw const InvalidInputException.withCode('errorValidationTitleTooLong');
    }

    return _repository.create(title: trimmed, description: description?.trim());
  }
}
```

### 4. Presentation Layer

**역할:** AsyncValue.guard()로 에러 자동 캐치

**핵심 규칙:**
- ✅ `AsyncValue.guard()` 사용
- ✅ `build()` 메서드에서 직접 UseCase 호출
- ❌ try-catch로 에러를 State에 저장 금지
- ❌ errorMessage 필드 사용 금지

```dart
@riverpod
class TodoListNotifier extends _$TodoListNotifier {
  @override
  FutureOr<List<Todo>> build() {
    // Riverpod이 자동으로 에러 처리
    return ref.read(getAllTodosUseCaseProvider).call();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(getAllTodosUseCaseProvider).call(),
    );
  }

  Future<void> create({required String title, String? description}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(createTodoUseCaseProvider).call(
            title: title,
            description: description,
          );
      return ref.read(getAllTodosUseCaseProvider).call();
    });
  }

  Future<void> delete(String id) async {
    final previous = state;

    // Optimistic update
    state = AsyncData(
      state.valueOrNull?.where((t) => t.id != id).toList() ?? [],
    );

    final result = await AsyncValue.guard(() async {
      await ref.read(deleteTodoUseCaseProvider).call(id);
      return ref.read(getAllTodosUseCaseProvider).call();
    });

    // 실패시 롤백
    state = result.hasError ? previous : result;
  }
}
```

### 5. UI Layer

**역할:** 에러를 로컬라이즈된 메시지로 표시

```dart
class TodoListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTodos = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      body: asyncTodos.when(
        data: (todos) => TodoListView(todos: todos),
        loading: () => const Center(child: CircularProgressIndicator()),
        // 에러 → 사용자 메시지
        error: (error, _) => AppErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(todoListProvider),
        ),
      ),
    );
  }
}

class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // 핵심: 경계에서 에러 → 사용자 메시지 변환 (toMessage 사용)
    final message = error is AppException
        ? error.toMessage(context)
        : AppLocalizations.of(context)?.errorUnknown ?? '알 수 없는 오류';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getIcon(error), size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)?.retry ?? '재시도'),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(Object error) => switch (error) {
        NetworkException() => Icons.wifi_off,
        TimeoutException() => Icons.timer_off,
        NotFoundException() => Icons.search_off,
        UnauthorizedException() => Icons.lock,
        ForbiddenException() => Icons.block,
        ServerException() => Icons.cloud_off,
        InvalidInputException() => Icons.edit_off,
        _ => Icons.error_outline,
      };
}
```

---

## AppException 타입

### AppException 구조

```dart
sealed class AppException implements Exception {
  const AppException(this.code, [this.debugMessage]);

  /// i18n 키 (예: 'errorNetwork', 'errorNotFound')
  final String code;

  /// 개발자용 디버그 메시지 (로깅, 디버깅용)
  final String? debugMessage;
}
```

**핵심:**
- `code`: ARB 파일의 i18n 키와 매칭 (예: `errorNetwork` → `l10n.errorNetwork`)
- `debugMessage`: 개발자 로깅용, 사용자에게 노출 X

### 공통 타입 (10개로 90% 커버)

| 타입 | code | 설명 | HTTP |
|------|------|------|------|
| `NetworkException` | errorNetwork | 네트워크 연결 끊김 | - |
| `TimeoutException` | errorTimeout | 요청 타임아웃 | - |
| `ServerException` | errorServer | 서버 오류 | 5xx |
| `UnauthorizedException` | errorUnauthorized | 인증 필요 | 401 |
| `ForbiddenException` | errorForbidden | 권한 없음 | 403 |
| `NotFoundException` | errorNotFound | 리소스 없음 | 404 |
| `InvalidInputException` | errorInvalidInput | 입력값 오류 | 400 |
| `ConflictException` | errorConflict | 충돌/중복 | 409 |
| `CacheException` | errorCache | 캐시 오류 | - |
| `UnknownException` | errorUnknown | 알 수 없는 오류 | - |

### InvalidInputException.withCode() 패턴

```dart
/// 기본 검증 에러 (code: 'errorInvalidInput')
throw const InvalidInputException('debug: title empty');

/// 특정 검증 코드 사용 (code: 'errorValidationTitleRequired')
throw const InvalidInputException.withCode(
  'errorValidationTitleRequired',
  'debug: title was empty string',
);
```

**사용 시기:**
- 기본 `InvalidInputException()`: 일반적인 입력 에러, 모두 같은 메시지
- `InvalidInputException.withCode()`: 구체적 검증 에러, 각각 다른 메시지 필요

### 도메인 특화 타입 (필요할 때만 추가)

**추가 기준:** UI에서 특별한 처리가 필요하거나 추가 데이터가 있을 때

```dart
// ❌ 무조건 만들지 않기
final class AttendanceValidationException extends AppException { }

// ✅ withCode로 해결
throw const InvalidInputException.withCode('errorAttendanceValidation');

// ✅ 진짜 필요할 때만 (추가 데이터가 있을 때)
final class PaymentFailedException extends AppException {
  const PaymentFailedException(this.alternatives, [String? debug])
      : super('errorPaymentFailed', debug);
  final List<String> alternatives;  // 이런 데이터가 필요할 때만
}
```

---

## i18n 패턴

### Extension 정의 (app_exception.dart)

```dart
extension AppExceptionL10n on AppException {
  /// UI에서 호출: error.toMessage(context)
  String toMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return _fallbackMessages[code] ?? '알 수 없는 오류가 발생했습니다';
    }

    // code 기반 매칭 (타입이 아닌 code로 분기)
    return switch (code) {
      'errorNetwork' => l10n.errorNetwork,
      'errorTimeout' => l10n.errorTimeout,
      'errorServer' => l10n.errorServer,
      'errorUnauthorized' => l10n.errorUnauthorized,
      'errorForbidden' => l10n.errorForbidden,
      'errorNotFound' => l10n.errorNotFound,
      'errorInvalidInput' => l10n.errorInvalidInput,
      'errorConflict' => l10n.errorConflict,
      'errorCache' => l10n.errorCache,
      'errorUnknown' => l10n.errorUnknown,
      // 검증 에러 (withCode로 전달된 코드들)
      'errorValidationRequired' => l10n.errorValidationRequired,
      'errorValidationIdRequired' => l10n.errorValidationIdRequired,
      'errorValidationTitleRequired' => l10n.errorValidationTitleRequired,
      'errorValidationTitleTooLong' => l10n.errorValidationTitleTooLong,
      _ => l10n.errorUnknown,
    };
  }
}

// 폴백 메시지 (AppLocalizations 사용 불가 시)
const _fallbackMessages = {
  'errorNetwork': '네트워크 연결을 확인해주세요',
  'errorTimeout': '요청 시간이 초과되었습니다',
  'errorServer': '서버 오류가 발생했습니다',
  'errorUnauthorized': '로그인이 필요합니다',
  'errorForbidden': '접근 권한이 없습니다',
  'errorNotFound': '요청한 데이터를 찾을 수 없습니다',
  'errorInvalidInput': '입력값을 확인해주세요',
  'errorConflict': '이미 존재하는 데이터입니다',
  'errorCache': '저장 오류가 발생했습니다',
  'errorUnknown': '알 수 없는 오류가 발생했습니다',
  'errorValidationRequired': '필수 입력값입니다',
  'errorValidationIdRequired': 'ID가 필요합니다',
  'errorValidationTitleRequired': '제목을 입력해주세요',
  'errorValidationTitleTooLong': '제목이 너무 깁니다',
};
```

### ARB 파일

```json
// lib/l10n/app_ko.arb
{
  "errorNetwork": "네트워크 연결을 확인해주세요",
  "errorTimeout": "요청 시간이 초과되었어요",
  "errorServer": "서버 오류가 발생했어요",
  "errorUnauthorized": "로그인이 필요해요",
  "errorForbidden": "접근 권한이 없어요",
  "errorNotFound": "요청한 데이터를 찾을 수 없어요",
  "errorInvalidInput": "입력값을 확인해주세요",
  "errorConflict": "이미 존재하는 데이터예요",
  "errorCache": "저장 오류가 발생했어요",
  "errorUnknown": "알 수 없는 오류가 발생했어요",
  "errorValidationRequired": "필수 입력값이에요",
  "errorValidationIdRequired": "ID가 필요해요",
  "errorValidationTitleRequired": "제목을 입력해주세요",
  "errorValidationTitleTooLong": "제목이 너무 길어요",
  "retry": "재시도"
}
```

**검증 에러 코드 추가 시:**
1. ARB 파일에 키 추가 (예: `"errorValidationEmailInvalid": "올바른 이메일 형식이 아니에요"`)
2. `toMessage()` switch 문에 케이스 추가
3. `_fallbackMessages`에 폴백 추가
4. UseCase에서 `InvalidInputException.withCode('errorValidationEmailInvalid')` 사용

---

## Best Practices

### DO

1. **DataSource에서 AppException 직접 throw (debugMessage 활용)**
   ```dart
   throw NotFoundException('Todo $id');  // debugMessage로 로깅용 정보 전달
   throw ServerException('Firebase error: ${e.code}', statusCode: 500);
   ```

2. **Repository는 패스스루**
   ```dart
   Future<Todo> get(String id) async {
     final model = await _dataSource.get(id);
     return model.toEntity();  // 에러는 그냥 통과
   }
   ```

3. **UseCase에서 입력 검증 후 throw (withCode 활용)**
   ```dart
   if (id.isEmpty) {
     throw const InvalidInputException.withCode('errorValidationIdRequired');
   }
   ```

4. **Presentation에서 AsyncValue.guard()**
   ```dart
   state = await AsyncValue.guard(() => usecase.call(id));
   ```

5. **UI에서만 로컬라이즈 (toMessage 사용)**
   ```dart
   error.toMessage(context)
   ```

### DON'T

1. **Result 패턴 사용 금지**
   ```dart
   // ❌
   Future<Result<Todo, AppFailure>> get(String id) async { ... }

   // ✅
   Future<Todo> get(String id) async { ... }
   ```

2. **errorMessage State 필드 사용 금지**
   ```dart
   // ❌
   @freezed
   class TodoState with _$TodoState {
     const factory TodoState({
       String? errorMessage,  // ❌ AsyncValue가 관리함
     }) = _TodoState;
   }
   ```

3. **try-catch로 State에 저장 금지**
   ```dart
   // ❌
   try {
     await usecase.call(id);
   } catch (e) {
     state = state.copyWith(errorMessage: e.toString());
   }

   // ✅
   state = await AsyncValue.guard(() => usecase.call(id));
   ```

4. **Presentation에서 DataException 처리 금지**
   ```dart
   // ❌ (data_exception.dart의 NotFoundException)
   if (error is data_exception.NotFoundException) { ... }

   // ✅ (app_exception.dart의 NotFoundException)
   if (error is NotFoundException) { ... }
   ```

---

## 마이그레이션 가이드

### 기존 Result 패턴에서 마이그레이션

#### Repository 수정

**Before:**
```dart
Future<Result<Todo, AppFailure>> get(String id) async {
  try {
    final model = await _dataSource.get(id);
    return Success(model.toEntity());
  } on NotFoundException {
    return Failure(NotFoundFailure());
  }
}
```

**After:**
```dart
Future<Todo> get(String id) async {
  final model = await _dataSource.get(id);
  return model.toEntity();  // 에러는 그냥 통과
}
```

#### UseCase 수정

**Before:**
```dart
Future<Result<WhenToMeet, AppFailure>> call(String id) async {
  return await _repository.read(id);
}
```

**After:**
```dart
Future<WhenToMeet> call(String id) async {
  return await _repository.read(id);  // 그냥 호출
}
```

#### Presentation 수정

**Before:**
```dart
final result = await usecase.call(id);
result.when(
  success: (data) => state = AsyncData(data),
  failure: (error) => state = AsyncError(error, StackTrace.current),
);
```

**After:**
```dart
state = await AsyncValue.guard(() => usecase.call(id));
```

#### 테스트 수정

**Before:**
```dart
expect(result.isSuccess, true);
expect((result as Success).data.id, 'test-id');
```

**After:**
```dart
// 성공 케이스
final entity = await usecase.call(id);
expect(entity.id, 'test-id');

// 실패 케이스
expect(
  () => usecase.call(invalidId),
  throwsA(isA<NotFoundException>()),
);
```

### DataSource에서 data_exception → app_exception 마이그레이션

**Before:**
```dart
import 'package:ittae/core/error/data_exception.dart';

throw data_exception.NotFoundException('Todo $id');
```

**After:**
```dart
import 'package:ittae/core/error/app_exception.dart';

throw NotFoundException('Todo $id');
```

---

## 삭제/Deprecated 파일

마이그레이션 완료 후 삭제할 파일:

```
lib/core/error/data_exception.dart      # @deprecated
lib/core/error/app_failure.dart         # @deprecated
lib/core/error/app_failure_l10n.dart    # @deprecated
lib/core/utils/result.dart              # 더 이상 필요 없음
```

---

## 검증 방법

```bash
# 1. 정적 분석
flutter analyze
dart run custom_lint

# 2. 빌드 테스트
flutter build apk --debug

# 3. 유닛 테스트
flutter test test/features/{feature}/
```

**에러 시나리오 테스트:**
- 네트워크 끊김 상태에서 API 호출 → NetworkException → l10n.errorNetwork
- 존재하지 않는 리소스 조회 → NotFoundException → l10n.errorNotFound
- 권한 없는 작업 시도 → ForbiddenException → l10n.errorForbidden
- 각 케이스에서 올바른 로컬라이즈 메시지 표시 확인

---

## 체크리스트

새 Feature 개발 시:

- [ ] DataSource에서 외부 에러 → AppException 변환
- [ ] Repository는 패스스루 (에러 처리 없음)
- [ ] UseCase에서 비즈니스 검증 실패시 throw
- [ ] Notifier에서 AsyncValue.guard() 사용
- [ ] UI에서 error.toLocalizedMessage(context) 호출
- [ ] ARB 파일에 에러 메시지 추가 (도메인 특화 에러 추가시)
