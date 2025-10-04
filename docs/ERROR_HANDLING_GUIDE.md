# Error Handling Guide

Clean Architecture 기반 Flutter 프로젝트의 계층별 에러 처리 가이드입니다.

## 목차

- [개요](#개요)
- [에러 흐름](#에러-흐름)
- [계층별 에러 처리](#계층별-에러-처리)
  - [1. DataSource Layer](#1-datasource-layer)
  - [2. Repository Layer](#2-repository-layer)
  - [3. UseCase Layer](#3-usecase-layer)
  - [4. Presentation Layer](#4-presentation-layer)
- [에러 타입 정의](#에러-타입-정의)
- [실전 예제](#실전-예제)
- [Best Practices](#best-practices)
- [트러블슈팅](#트러블슈팅)

---

## 개요

### 핵심 원칙

1. **타입 안전성**: 각 계층에서 적절한 에러 타입 사용
2. **명확한 책임 분리**: 각 계층은 자신의 에러만 처리
3. **정보 보존**: 에러 변환 시 원본 정보 유지
4. **간결함**: UI에서 실제로 다르게 처리할 에러만 구분

### 에러 처리 전략

```
UI에서 필요한 에러만 구분 → 나머지는 통합 처리
```

**필수 구분 에러** (각 계층에서 4가지만 구분):
- **NotFound**: "할 일을 찾을 수 없습니다" 메시지
- **Unauthorized**: "권한이 없습니다" + 로그인 유도
- **Network**: "네트워크 연결 확인" + 재시도 버튼
- **Unknown/Server**: "오류가 발생했습니다" + 일반 에러 처리

---

## 에러 흐름

```
┌─────────────────────────────────────────────────────────────────┐
│ External System (Firebase, API)                                 │
│ ↓ FirebaseException, HttpException, etc.                        │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ DataSource Layer                                                 │
│ ↓ Transform to: Data Exceptions                                 │
│   • NotFoundException                                            │
│   • UnauthorizedException                                        │
│   • NetworkException                                             │
│   • DataSourceException (with code, originalError)              │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Repository Layer                                                 │
│ ↓ Transform to: Result<T, DomainFailure>                        │
│   • Success(data)                                                │
│   • Failure(TodoFailure.notFound)                         │
│   • Failure(TodoFailure.unauthorized)                     │
│   • Failure(TodoFailure.networkError)                     │
│   • Failure(TodoFailure.serverError)                      │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ UseCase Layer                                                    │
│ ↓ Transform to: Domain Exceptions (throw)                       │
│   • TodoNotFoundException                                  │
│   • TodoUnauthorizedException                              │
│   • TodoNetworkException                                   │
│   • TodoServerException                                    │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Presentation Layer                                               │
│ ↓ Riverpod AsyncValue automatically catches exceptions          │
│   • AsyncValue.data(data)                                        │
│   • AsyncValue.error(exception, stackTrace)                      │
│   • AsyncValue.loading()                                         │
│ UI: Pattern matching on exception type for user-friendly UI     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 계층별 에러 처리

### 1. DataSource Layer

**역할**: 외부 시스템(Firebase, API)의 에러를 Data Exception으로 변환

**핵심 원칙**:
- ✅ **구체적인 Exception 던지기** (NotFoundException, UnauthorizedException, etc.)
- ✅ **핵심 에러만 구분**, 나머지는 DataSourceException으로 통합
- ✅ **원본 에러 정보 보존** (code, originalError 필드 활용)
- ❌ Result 패턴 사용 금지 (Repository에서만 사용)

#### 구현 예제

```dart
// core/exceptions/data_exceptions.dart
class NotFoundException implements Exception {
  final String message;
  const NotFoundException(this.message);
}

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException(this.message);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
}

class DataSourceException implements Exception {
  final String message;
  final String? code;           // 원본 에러 코드 보존
  final dynamic originalError;  // 원본 에러 객체 보존

  const DataSourceException(
    this.message, {
    this.code,
    this.originalError,
  });
}
```

#### DataSource 구현 패턴

```dart
class TodoFirestoreDataSource {
  Future<Todo> getTodo({required String id}) async {
    try {
      final doc = await _firestore.collection('todos').doc(id).get();

      if (!doc.exists) {
        throw NotFoundException('할 일을 찾을 수 없습니다: $id');
      }

      return model.toDomainEntity();
    } on FirebaseException catch (e) {
      _handleFirebaseException(e, 'Todo 조회');
    } on NotFoundException {
      rethrow;  // 이미 구체적인 Exception이므로 그대로 전달
    } catch (e) {
      throw DataSourceException(
        'Todo 조회 중 오류가 발생했습니다',
        originalError: e,
      );
    }
  }

  /// FirebaseException을 적절한 Data Exception으로 변환
  Never _handleFirebaseException(FirebaseException e, String operation) {
    Log.error('$operation 실패: ${e.code} - ${e.message}');

    switch (e.code) {
      // 핵심 에러만 구분
      case 'permission-denied':
      case 'unauthenticated':
        throw UnauthorizedException(e.message ?? '접근 권한이 없습니다');

      case 'unavailable':
      case 'deadline-exceeded':
      case 'cancelled':
        throw NetworkException(e.message ?? '네트워크 연결을 확인해주세요');

      case 'not-found':
        throw NotFoundException(e.message ?? '데이터를 찾을 수 없습니다');

      // 나머지는 전부 DataSourceException으로 통합
      default:
        throw DataSourceException(
          e.message ?? 'Firestore 오류가 발생했습니다',
          code: e.code,
          originalError: e,
        );
    }
  }
}
```

**핵심 포인트**:
1. **로그인 필요**: `UnauthorizedException` 던지기
2. **데이터 없음**: `NotFoundException` 던지기
3. **네트워크 문제**: `NetworkException` 던지기
4. **그 외 모든 에러**: `DataSourceException` (code, originalError 보존)

---

### 2. Repository Layer

**역할**: DataSource Exception을 Domain Failure로 변환하고 Result 패턴 반환

**핵심 원칙**:
- ✅ **Result 패턴 사용** (`Result<T, DomainFailure>`)
- ✅ **Exception → Failure 변환** (타입 안전하게)
- ✅ **Helper 함수 활용** (코드 중복 제거)
- ❌ Exception을 그대로 던지지 않기

#### 구현 예제

```dart
// domain/failures/todo_failure.dart
@freezed
sealed class TodoFailure with _$TodoFailure {
  const factory TodoFailure.notFound({
    required String message,
  }) = TodoNotFoundFailure;

  const factory TodoFailure.unauthorized({
    required String message,
  }) = TodoUnauthorizedFailure;

  const factory TodoFailure.networkError({
    required String message,
  }) = TodoNetworkErrorFailure;

  const factory TodoFailure.serverError({
    required String message,
  }) = TodoServerErrorFailure;

  const factory TodoFailure.unknown({
    required String message,
  }) = TodoUnknownFailure;
}
```

#### Repository 구현 패턴

```dart
class TodoRepositoryImpl implements TodoRepository {
  final TodoDataSource _datasource;

  @override
  Future<Result<Todo, TodoFailure>> read(String id) async {
    try {
      final result = await _datasource.getTodo(todoId: id);
      return Success(result);
    } on Exception catch (e) {
      return Failure(_mapExceptionToFailure(e, '할 일 조회'));
    }
  }

  /// DataSource Exception을 TodoFailure로 변환하는 헬퍼 함수
  TodoFailure _mapExceptionToFailure(Exception exception, String operation) {
    if (exception is NotFoundException) {
      Log.error('$operation - Not found: $exception');
      return TodoFailure.notFound(message: exception.message);
    } else if (exception is UnauthorizedException) {
      Log.error('$operation - Unauthorized: $exception');
      return TodoFailure.unauthorized(message: exception.message);
    } else if (exception is NetworkException) {
      Log.error('$operation - Network error: $exception');
      return TodoFailure.networkError(message: exception.message);
    } else if (exception is DataSourceException) {
      Log.error('$operation - DataSource error: $exception');
      return TodoFailure.serverError(message: exception.message);
    } else {
      Log.error('$operation - Unexpected error: $exception');
      return TodoFailure.unknown(message: '$operation 실패: ${exception.toString()}');
    }
  }
}
```

**핵심 포인트**:
1. **모든 메서드가 `Result<T, Failure>` 반환**
2. **try-catch로 Exception 포착**
3. **Helper 함수로 Exception → Failure 변환**
4. **코드 중복 최소화** (모든 메서드가 동일한 패턴)

---

### 3. UseCase Layer

**역할**: Repository의 Result를 Entity 또는 Exception으로 변환

**핵심 원칙**:
- ✅ **성공 시 Entity 반환**
- ✅ **실패 시 Domain Exception 던지기**
- ✅ **Failure → Exception 변환** (`.toException()` 사용)
- ✅ **입력 검증** (ArgumentError 사용)
- ❌ Result 패턴 사용 금지 (Repository에서만 사용)

#### 구현 예제

```dart
// domain/exceptions/todo_exception.dart
sealed class TodoException implements Exception {
  final String message;
  final TodoFailure failure;
  const TodoException(this.message, this.failure);
}

final class TodoNotFoundException extends TodoException {
  const TodoNotFoundException(super.message, super.failure);
}

final class TodoUnauthorizedException extends TodoException {
  const TodoUnauthorizedException(super.message, super.failure);
}

final class TodoNetworkException extends TodoException {
  const TodoNetworkException(super.message, super.failure);
}

// Extension for converting Failure to Exception
extension TodoFailureX on TodoFailure {
  TodoException toException() {
    return when(
      notFound: (message) => TodoNotFoundException(message, this),
      unauthorized: (message) => TodoUnauthorizedException(message, this),
      networkError: (message) => TodoNetworkException(message, this),
      serverError: (message) => TodoServerException(message, this),
      unknown: (message) => TodoUnknownException(message, this),
    );
  }
}
```

#### UseCase 구현 패턴

```dart
class GetTodoUseCase {
  final TodoRepository repository;

  Future<Todo> call(String todoId) async {
    // 1. 입력 검증 (ArgumentError 사용)
    if (todoId.trim().isEmpty) {
      throw ArgumentError('Todo ID는 필수입니다.');
    }

    // 2. Repository 호출 및 Result 처리
    final result = await repository.read(todoId.trim());

    // 3. Result를 Entity 또는 Exception으로 변환
    return result.when(
      success: (data) => data,
      failure: (error) => throw error.toException(),
    );
  }
}
```

**핵심 포인트**:
1. **입력 검증**: `ArgumentError` 던지기 (비즈니스 로직 위반)
2. **Result 패턴 매칭**: `.when()` 사용
3. **성공**: Entity 그대로 반환
4. **실패**: `failure.toException()` 호출하여 타입 안전한 Exception 던지기

---

### 4. Presentation Layer

**역할**: Riverpod AsyncValue로 UseCase Exception을 자동으로 처리하고 UI에 반영

**핵심 원칙**:
- ✅ **AsyncValue 사용** (Riverpod 자동 처리)
- ✅ **Exception 타입별 UI 처리** (pattern matching)
- ✅ **에러 상태를 State에 저장하지 않기** (AsyncValue가 관리)
- ❌ try-catch로 에러를 감춰서 State에 저장 금지
- ❌ 에러를 다시 throw 하지 않기

#### Provider 구현 패턴

```dart
@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  Future<Todo> build(String todoId) async {
    // UseCase 호출만 하면 Riverpod이 자동으로 에러 처리
    return ref.read(getTodoUseCaseProvider).call(todoId);
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();

    // AsyncValue.guard로 안전하게 에러 캐치
    state = await AsyncValue.guard(() async {
      return ref.read(getTodoUseCaseProvider).call(todoId);
    });
  }
}
```

#### UI 에러 처리 패턴

```dart
class TodoPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTodo = ref.watch(todoNotifierProvider(id));

    return asyncTodo.when(
      data: (todo) => _buildContent(todo),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => _buildError(error),
    );
  }

  Widget _buildError(Object error) {
    // Exception 타입별로 다른 UI 표시
    if (error is TodoNotFoundException) {
      return ErrorWidget(
        message: '할 일을 찾을 수 없습니다',
        action: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('뒤로가기'),
        ),
      );
    } else if (error is TodoUnauthorizedException) {
      return ErrorWidget(
        message: '권한이 없습니다',
        action: TextButton(
          onPressed: () => _navigateToLogin(),
          child: const Text('로그인'),
        ),
      );
    } else if (error is TodoNetworkException) {
      return ErrorWidget(
        message: '네트워크 연결을 확인해주세요',
        action: TextButton(
          onPressed: () => ref.refresh(todoNotifierProvider(id)),
          child: const Text('재시도'),
        ),
      );
    } else {
      return ErrorWidget(
        message: '오류가 발생했습니다',
        action: TextButton(
          onPressed: () => ref.refresh(todoNotifierProvider(id)),
          child: const Text('재시도'),
        ),
      );
    }
  }
}
```

**핵심 포인트**:
1. **AsyncValue.when()**: 로딩, 성공, 에러 상태 자동 처리
2. **Exception 타입 확인**: `is` 연산자로 타입별 UI 분기
3. **사용자 친화적 메시지**: 각 에러에 맞는 안내 메시지
4. **적절한 액션 버튼**: 뒤로가기, 로그인, 재시도 등

---

## 에러 타입 정의

### 1. Core Data Exceptions

**위치**: `lib/core/exceptions/data_exceptions.dart`

**용도**: DataSource에서 외부 시스템 에러를 변환

| Exception | 사용 시점 | 예시 |
|-----------|----------|------|
| `NotFoundException` | 데이터 없음 | Firestore 문서 없음, 404 |
| `UnauthorizedException` | 권한 없음 | 로그인 필요, 403 |
| `NetworkException` | 네트워크 문제 | 타임아웃, 연결 실패 |
| `DataSourceException` | 그 외 모든 에러 | 알 수 없는 Firestore 에러 |

### 2. Domain Failures (Freezed)

**위치**: `lib/features/{feature}/domain/failures/{feature}_failure.dart`

**용도**: Repository에서 Result 패턴의 에러 타입

```dart
@freezed
sealed class TodoFailure with _$TodoFailure {
  const factory TodoFailure.notFound({required String message}) = ...;
  const factory TodoFailure.unauthorized({required String message}) = ...;
  const factory TodoFailure.networkError({required String message}) = ...;
  const factory TodoFailure.serverError({required String message}) = ...;
  const factory TodoFailure.unknown({required String message}) = ...;
}
```

### 3. Domain Exceptions

**위치**: `lib/features/{feature}/domain/exceptions/{feature}_exception.dart`

**용도**: UseCase에서 Presentation으로 전달하는 타입 안전한 예외

```dart
sealed class TodoException implements Exception {
  final String message;
  final TodoFailure failure;  // 원본 Failure 보존
}

final class TodoNotFoundException extends TodoException { ... }
final class TodoUnauthorizedException extends TodoException { ... }
```

---

## 실전 예제

### 시나리오: 할 일 조회 실패 (NotFound)

```
1. Firebase에서 문서 없음
   ↓
2. DataSource: NotFoundException 던지기
   throw NotFoundException('할 일을 찾을 수 없습니다: $id');
   ↓
3. Repository: Result.Failure 반환
   return Failure(TodoFailure.notFound(message: exception.message));
   ↓
4. UseCase: TodoNotFoundException 던지기
   throw error.toException();  // TodoNotFoundException
   ↓
5. Presentation: AsyncValue.error에 자동 저장
   state = AsyncValue.error(exception, stackTrace);
   ↓
6. UI: 에러 타입별 처리
   if (error is TodoNotFoundException) {
     return ErrorWidget(message: '할 일을 찾을 수 없습니다', ...);
   }
```

### 시나리오: 네트워크 문제

```
1. Firebase 연결 실패
   ↓
2. DataSource: NetworkException 던지기
   throw NetworkException('네트워크 연결을 확인해주세요');
   ↓
3. Repository: Result.Failure 반환
   return Failure(TodoFailure.networkError(message: exception.message));
   ↓
4. UseCase: TodoNetworkException 던지기
   throw error.toException();
   ↓
5. UI: 재시도 버튼 표시
   if (error is TodoNetworkException) {
     return ErrorWidget(
       message: '네트워크 연결을 확인해주세요',
       action: TextButton(child: Text('재시도'), ...),
     );
   }
```

---

## Best Practices

### ✅ DO

1. **각 계층은 자신의 에러 타입만 사용**
   ```dart
   // DataSource: Data Exception
   throw NotFoundException('...');

   // Repository: Domain Failure
   return Failure(TodoFailure.notFound(message: '...'));

   // UseCase: Domain Exception
   throw error.toException();
   ```

2. **Helper 함수 활용**
   ```dart
   // Repository에서 Exception → Failure 변환
   TodoFailure _mapExceptionToFailure(Exception e, String operation) { ... }

   // UseCase에서 Failure → Exception 변환
   extension TodoFailureX on TodoFailure {
     TodoException toException() { ... }
   }
   ```

3. **원본 에러 정보 보존**
   ```dart
   DataSourceException(
     'Firestore 오류가 발생했습니다',
     code: e.code,           // 원본 코드
     originalError: e,       // 원본 에러 객체
   );
   ```

4. **AsyncValue 활용**
   ```dart
   // Riverpod이 자동으로 에러 처리
   state = await AsyncValue.guard(() async {
     return usecase.call();
   });
   ```

### ❌ DON'T

1. **계층 경계 위반 금지**
   ```dart
   // ❌ BAD: Presentation에서 DataSourceException 처리
   if (error is NotFoundException) { ... }

   // ✅ GOOD: Presentation에서 Domain Exception 처리
   if (error is TodoNotFoundException) { ... }
   ```

2. **에러를 State에 저장하지 말기**
   ```dart
   // ❌ BAD
   @freezed
   class MyState {
     String? errorMessage;  // ❌ AsyncValue가 이미 관리함
   }

   // ✅ GOOD
   AsyncValue<Data> state;  // AsyncValue.error로 자동 관리
   ```

3. **에러를 숨기지 말기**
   ```dart
   // ❌ BAD: catchError로 에러 무시
   usecase.call().catchError((_) => <Todo>[]);

   // ✅ GOOD: AsyncValue가 에러 처리
   state = await AsyncValue.guard(() => usecase.call());
   ```

4. **불필요한 에러 타입 추가 금지**
   ```dart
   // ❌ BAD: UI에서 구분할 필요 없는 에러
   const factory Failure.invalidEmailFormat() = ...;
   const factory Failure.passwordTooShort() = ...;

   // ✅ GOOD: 통합 처리
   const factory Failure.invalidParameters({required String message}) = ...;
   ```

---

## 트러블슈팅

### 문제 1: 에러가 UI에 표시되지 않음

**증상**: Exception을 던졌는데 UI에서 에러가 표시되지 않음

**원인**:
```dart
// ❌ BAD: catchError로 에러 감춤
usecase.call().catchError((_) => defaultValue);
```

**해결**:
```dart
// ✅ GOOD: AsyncValue.guard 사용
state = await AsyncValue.guard(() => usecase.call());
```

### 문제 2: 에러 타입 구분이 안됨

**증상**: `error is TodoNotFoundException` 조건이 false

**원인**: Exception이 제대로 변환되지 않음

**확인 사항**:
1. UseCase에서 `error.toException()` 호출했는지
2. Failure → Exception extension이 올바른지
3. build_runner 실행했는지 (`freezed` 코드 생성)

**해결**:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 문제 3: 에러 메시지가 영어로 표시됨

**증상**: Firebase 원본 에러 메시지가 그대로 표시됨

**원인**: DataSource에서 메시지를 변환하지 않음

**해결**:
```dart
// ❌ BAD
throw NotFoundException(e.message);  // Firebase 원본 메시지

// ✅ GOOD
throw NotFoundException('할 일을 찾을 수 없습니다: $id');  // 한국어 메시지
```

### 문제 4: AsyncValue.loading이 표시되지 않음

**증상**: 로딩 중에도 이전 데이터가 그대로 표시됨

**원인**: `state = AsyncValue.loading()` 누락

**해결**:
```dart
Future<void> reload() async {
  state = const AsyncValue.loading();  // ✅ 로딩 상태 설정
  state = await AsyncValue.guard(() => usecase.call());
}
```

---

## 요약

### 각 계층의 책임

| 계층 | 입력 | 출력 | 책임 |
|------|------|------|------|
| **DataSource** | Firebase/API Exception | Data Exception | 외부 에러 → 구체적 Exception 변환 |
| **Repository** | Data Exception | `Result<T, Failure>` | Exception → Failure 변환 |
| **UseCase** | `Result<T, Failure>` | Entity 또는 Domain Exception | Failure → Exception 변환 |
| **Presentation** | Domain Exception | AsyncValue | UI 에러 표시 |

### 에러 흐름 요약

```
FirebaseException
  ↓ DataSource
NotFoundException
  ↓ Repository
TodoFailure.notFound
  ↓ UseCase
TodoNotFoundException
  ↓ Presentation
AsyncValue.error → UI 에러 표시
```

### 핵심 패턴

1. **DataSource**: 구체적 Exception 던지기
2. **Repository**: Result 패턴 + Helper 함수
3. **UseCase**: Failure.toException() 활용
4. **Presentation**: AsyncValue + Pattern matching
