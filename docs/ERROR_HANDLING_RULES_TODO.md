# Error Handling Linter Rules - Implementation TODO

Clean Architecture의 계층별 에러 처리 규칙을 자동으로 검증하는 린트 규칙 구현 계획

## 개요

### 목적
Clean Architecture에서 각 계층은 고유한 에러 처리 방식을 가져야 합니다. 이를 수동으로 검증하는 대신, 린터가 자동으로 검증하도록 하여 아키텍처 일관성을 유지합니다.

### 목표
- ✅ **일관성**: 모든 계층이 올바른 에러 처리 패턴 사용
- ✅ **안정성**: 에러가 적절한 타입으로 변환되어 전달
- ✅ **생산성**: 실수를 컴파일 타임에 조기 발견
- ✅ **교육**: 린트 메시지로 올바른 패턴 학습

### 기대 효과
- 계층 경계 위반 방지
- 에러 타입 불일치 방지
- 코드 리뷰 시간 절감
- 신규 개발자 온보딩 개선

---

## 계층별 규칙 명세

### 1. DataSource Layer 규칙

#### Rule 1: `datasource_no_result_return`

**목적**: DataSource는 Result 패턴을 사용하지 않고 Exception을 던져야 함

**검증 로직**:
```
IF file_path.contains('datasources/') AND
   class_name.endsWith('DataSource') AND
   method_return_type is Result<T, F>
THEN report_error
```

**Bad Example**:
```dart
// ❌ BAD: DataSource에서 Result 반환
class TodoRemoteDataSource {
  Future<Result<Todo, Failure>> getTodo(String id) {
    return Success(todo);
  }
}
```

**Good Example**:
```dart
// ✅ GOOD: DataSource는 Exception throw
class TodoRemoteDataSource {
  Future<Todo> getTodo(String id) {
    if (!exists) {
      throw NotFoundException('Todo not found: $id');
    }
    return todo;
  }
}
```

**구현 힌트**:
- `MethodDeclaration` 노드 방문
- `returnType`이 `Result` 타입인지 확인
- 파일 경로에 `datasources/` 포함 여부 확인

**우선순위**: 🔴 High

---

#### Rule 2: `datasource_exception_types`

**목적**: DataSource는 정의된 Data Exception만 사용해야 함

**허용되는 Exception**:
- `NotFoundException`
- `UnauthorizedException`
- `NetworkException`
- `DataSourceException`

**검증 로직**:
```
IF file_path.contains('datasources/') AND
   throw_statement exists AND
   exception_type NOT IN [NotFoundException, UnauthorizedException, NetworkException, DataSourceException]
THEN report_warning
```

**Bad Example**:
```dart
// ❌ BAD: 정의되지 않은 Exception
throw Exception('Custom error');
throw StateError('Invalid state');
```

**Good Example**:
```dart
// ✅ GOOD: 정의된 Data Exception
throw NotFoundException('Todo not found');
throw NetworkException('Connection failed');
```

**우선순위**: 🟡 Medium

---

### 2. Repository Layer 규칙

#### Rule 3: `repository_must_return_result`

**목적**: Repository 구현은 반드시 Result 패턴을 반환해야 함

**검증 로직**:
```
IF file_path.contains('repositories/') AND
   file_name.endsWith('_impl.dart') AND
   implements_clause contains 'Repository' AND
   method_return_type is NOT Result<T, F>
THEN report_error
```

**Bad Example**:
```dart
// ❌ BAD: Result 대신 Entity 직접 반환
class TodoRepositoryImpl implements TodoRepository {
  Future<Todo> getTodo(String id) async {
    return await datasource.getTodo(id);
  }
}
```

**Good Example**:
```dart
// ✅ GOOD: Result 패턴 반환
class TodoRepositoryImpl implements TodoRepository {
  Future<Result<Todo, TodoFailure>> getTodo(String id) async {
    try {
      final todo = await datasource.getTodo(id);
      return Success(todo);
    } on Exception catch (e) {
      return Failure(TodoFailure.fromException(e));
    }
  }
}
```

**우선순위**: 🔴 High

---

#### Rule 4: `repository_no_throw`

**목적**: Repository는 Exception을 던지지 않고 Result로 감싸야 함

**검증 로직**:
```
IF file_path.contains('repositories/') AND
   file_name.endsWith('_impl.dart') AND
   method contains 'throw' statement AND
   NOT (throw is inside try-catch for re-throw)
THEN report_error
```

**Bad Example**:
```dart
// ❌ BAD: Repository에서 직접 throw
class TodoRepositoryImpl implements TodoRepository {
  Future<Result<Todo, TodoFailure>> getTodo(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('ID required'); // ❌
    }
    // ...
  }
}
```

**Good Example**:
```dart
// ✅ GOOD: try-catch로 감싸서 Result 반환
class TodoRepositoryImpl implements TodoRepository {
  Future<Result<Todo, TodoFailure>> getTodo(String id) async {
    try {
      final todo = await datasource.getTodo(id);
      return Success(todo);
    } on Exception catch (e) {
      return Failure(_mapException(e));
    }
  }
}
```

**예외 케이스**:
- try-catch 내부의 `rethrow`는 허용
- Helper 함수에서의 throw는 허용 (private 함수)

**우선순위**: 🔴 High

---

### 3. UseCase Layer 규칙

#### Rule 5: `usecase_no_result_return`

**목적**: UseCase는 Result를 반환하지 않고 Entity 또는 Exception을 사용

**검증 로직**:
```
IF file_path.contains('usecases/') AND
   class_name.endsWith('UseCase') AND
   method_return_type is Result<T, F>
THEN report_error
```

**Bad Example**:
```dart
// ❌ BAD: UseCase에서 Result 반환
class GetTodoUseCase {
  Future<Result<Todo, TodoFailure>> call(String id) {
    return repository.getTodo(id);
  }
}
```

**Good Example**:
```dart
// ✅ GOOD: Entity 또는 Exception
class GetTodoUseCase {
  Future<Todo> call(String id) async {
    final result = await repository.getTodo(id);
    return result.when(
      success: (data) => data,
      failure: (error) => throw error.toException(),
    );
  }
}
```

**우선순위**: 🔴 High

---

#### Rule 6: `usecase_must_convert_failure`

**목적**: UseCase는 Failure를 Domain Exception으로 변환해야 함

**검증 로직**:
```
IF file_path.contains('usecases/') AND
   Result.when() call exists AND
   failure_case does NOT contain '.toException()'
THEN report_warning
```

**Bad Example**:
```dart
// ❌ BAD: Failure를 그대로 throw
return result.when(
  success: (data) => data,
  failure: (error) => throw error, // ❌ Failure 직접 throw
);
```

**Good Example**:
```dart
// ✅ GOOD: .toException()으로 변환
return result.when(
  success: (data) => data,
  failure: (error) => throw error.toException(), // ✅
);
```

**우선순위**: 🟡 Medium

---

### 4. Presentation Layer 규칙

#### Rule 7: `presentation_no_data_exceptions`

**목적**: Presentation은 Data Exception을 직접 처리하지 않음

**검증 로직**:
```
IF file_path.contains('presentation/') AND
   is_expression contains (NotFoundException | UnauthorizedException | NetworkException | DataSourceException)
THEN report_error
```

**Bad Example**:
```dart
// ❌ BAD: Presentation에서 Data Exception 처리
Widget build(BuildContext context, WidgetRef ref) {
  return asyncValue.when(
    error: (error, stack) {
      if (error is NotFoundException) { // ❌ Data Exception
        return ErrorWidget('Not found');
      }
    },
  );
}
```

**Good Example**:
```dart
// ✅ GOOD: Domain Exception만 처리
Widget build(BuildContext context, WidgetRef ref) {
  return asyncValue.when(
    error: (error, stack) {
      if (error is TodoNotFoundException) { // ✅ Domain Exception
        return ErrorWidget('할 일을 찾을 수 없습니다');
      }
    },
  );
}
```

**우선순위**: 🔴 High

---

#### Rule 8: `presentation_use_async_value`

**목적**: Presentation은 AsyncValue로 에러 처리해야 함 (State에 저장 금지)

**검증 로직**:
```
IF file_path.contains('presentation/states/') AND
   @freezed class contains field named (error | errorMessage | failure)
THEN report_warning
```

**Bad Example**:
```dart
// ❌ BAD: State에 에러 저장
@freezed
class TodoState with _$TodoState {
  const factory TodoState({
    List<Todo> todos,
    String? errorMessage,  // ❌
  }) = _TodoState;
}
```

**Good Example**:
```dart
// ✅ GOOD: AsyncValue 사용
@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  Future<List<Todo>> build() async { // AsyncValue<List<Todo>>
    return repository.getTodos();
  }
}
```

**우선순위**: 🟡 Medium

---

## 구현 우선순위

### 🔴 Phase 1: High Priority (필수 규칙)

**목표**: 계층별 핵심 에러 처리 패턴 강제

1. **`datasource_no_result_return`** ✅
   - DataSource는 Result 반환 금지
   - 명확한 위반 사항
   - 구현 난이도: 낮음

2. **`repository_must_return_result`** ✅
   - Repository는 Result 반환 필수
   - 아키텍처 핵심 규칙
   - 구현 난이도: 낮음

3. **`repository_no_throw`** ✅
   - Repository는 throw 금지
   - 예외 케이스 처리 필요
   - 구현 난이도: 중간

4. **`usecase_no_result_return`** ✅
   - UseCase는 Result 반환 금지
   - 명확한 위반 사항
   - 구현 난이도: 낮음

5. **`presentation_no_data_exceptions`** ✅
   - Presentation은 Data Exception 처리 금지
   - 계층 분리 핵심
   - 구현 난이도: 중간

**예상 기간**: 2-3주

---

### 🟡 Phase 2: Medium Priority (품질 향상)

**목표**: 에러 변환 및 타입 안전성 강화

6. **`datasource_exception_types`** ⚠️
   - DataSource는 정의된 Exception만 사용
   - 일관성 향상
   - 구현 난이도: 중간

7. **`usecase_must_convert_failure`** ⚠️
   - UseCase는 .toException() 사용 권장
   - 타입 안전성 향상
   - 구현 난이도: 높음 (AST 패턴 매칭)

8. **`presentation_use_async_value`** ⚠️
   - State에 에러 저장 금지
   - AsyncValue 패턴 권장
   - 구현 난이도: 중간

**예상 기간**: 2-3주

---

### 🔵 Phase 3: Low Priority (고급 검증)

**목표**: 엣지 케이스 및 세밀한 검증

9. **`exception_naming_convention`** 🔍
   - Exception 클래스명 규칙 검증
   - 예: `{Feature}NotFoundException` 형식

10. **`failure_naming_convention`** 🔍
    - Failure 클래스명 규칙 검증
    - 예: `{Feature}Failure` 형식

11. **`exception_message_localization`** 🔍
    - Exception 메시지 한글 검증
    - 사용자 친화적 메시지 권장

**예상 기간**: 2-3주

---

## 기술적 구현 가이드

### AST 분석 기초

#### 1. 반환 타입 검사
```dart
class MyLintRule extends DartLintRule {
  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    context.registry.addMethodDeclaration((node) {
      final returnType = node.returnType;

      // Result 타입 체크
      if (returnType is NamedType && returnType.name2.lexeme == 'Result') {
        reporter.reportErrorForNode(code, node);
      }
    });
  }
}
```

#### 2. Throw 문 감지
```dart
context.registry.addThrowExpression((node) {
  final throwExpression = node.expression;

  // Exception 타입 확인
  if (throwExpression is InstanceCreationExpression) {
    final typeName = throwExpression.constructorName.type.name2.lexeme;

    if (!allowedExceptions.contains(typeName)) {
      reporter.reportErrorForNode(code, node);
    }
  }
});
```

#### 3. 타입 체크 감지 (is 연산자)
```dart
context.registry.addIsExpression((node) {
  final checkedType = node.type;

  // Data Exception 타입 체크 감지
  if (checkedType is NamedType) {
    final typeName = checkedType.name2.lexeme;

    if (dataExceptions.contains(typeName)) {
      reporter.reportErrorForNode(code, node);
    }
  }
});
```

#### 4. 파일 경로 기반 검증
```dart
void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
  final filePath = resolver.path;

  if (filePath.contains('datasources/')) {
    // DataSource 규칙 적용
  } else if (filePath.contains('repositories/') && filePath.endsWith('_impl.dart')) {
    // Repository 규칙 적용
  }
}
```

### 유틸리티 함수

#### 계층 감지
```dart
enum ArchitectureLayer {
  dataSource,
  repository,
  useCase,
  presentation,
  unknown,
}

ArchitectureLayer detectLayer(String filePath) {
  if (filePath.contains('datasources/')) return ArchitectureLayer.dataSource;
  if (filePath.contains('repositories/')) return ArchitectureLayer.repository;
  if (filePath.contains('usecases/')) return ArchitectureLayer.useCase;
  if (filePath.contains('presentation/')) return ArchitectureLayer.presentation;
  return ArchitectureLayer.unknown;
}
```

#### Result 타입 체크
```dart
bool isResultType(TypeAnnotation? type) {
  if (type is! NamedType) return false;

  final name = type.name2.lexeme;
  return name == 'Result' || name == 'Either';
}
```

#### Exception 타입 분류
```dart
final dataExceptions = {
  'NotFoundException',
  'UnauthorizedException',
  'NetworkException',
  'DataSourceException',
};

final domainExceptions = {
  'TodoNotFoundException',
  'TodoUnauthorizedException',
  'TodoNetworkException',
  'TodoServerException',
};

bool isDataException(String typeName) {
  return dataExceptions.contains(typeName);
}

bool isDomainException(String typeName) {
  return typeName.endsWith('Exception') &&
         !dataExceptions.contains(typeName);
}
```

---

## 구현 체크리스트

### Phase 1: High Priority

- [ ] **Rule 1: datasource_no_result_return**
  - [ ] AST 분석 로직 구현
  - [ ] 테스트 케이스 작성 (good/bad examples)
  - [ ] 에러 메시지 한글화
  - [ ] 문서화

- [ ] **Rule 2: repository_must_return_result**
  - [ ] AST 분석 로직 구현
  - [ ] 파일명 체크 (_impl.dart)
  - [ ] 테스트 케이스 작성
  - [ ] 문서화

- [ ] **Rule 3: repository_no_throw**
  - [ ] Throw 문 감지 구현
  - [ ] try-catch 예외 처리
  - [ ] Helper 함수 예외 처리
  - [ ] 테스트 케이스 작성
  - [ ] 문서화

- [ ] **Rule 4: usecase_no_result_return**
  - [ ] AST 분석 로직 구현
  - [ ] 테스트 케이스 작성
  - [ ] 문서화

- [ ] **Rule 5: presentation_no_data_exceptions**
  - [ ] IsExpression 분석 구현
  - [ ] Data Exception 목록 정의
  - [ ] 테스트 케이스 작성
  - [ ] 문서화

### Phase 2: Medium Priority

- [ ] **Rule 6: datasource_exception_types**
  - [ ] 허용된 Exception 목록 정의
  - [ ] Throw 문 타입 체크
  - [ ] 테스트 케이스 작성
  - [ ] 문서화

- [ ] **Rule 7: usecase_must_convert_failure**
  - [ ] Result.when() 패턴 감지
  - [ ] .toException() 호출 검증
  - [ ] 테스트 케이스 작성
  - [ ] 문서화

- [ ] **Rule 8: presentation_use_async_value**
  - [ ] Freezed State 분석
  - [ ] 에러 필드 감지
  - [ ] 테스트 케이스 작성
  - [ ] 문서화

### Phase 3: Low Priority

- [ ] **Rule 9: exception_naming_convention**
  - [ ] 네이밍 패턴 정의
  - [ ] 검증 로직 구현
  - [ ] 문서화

- [ ] **Rule 10: failure_naming_convention**
  - [ ] 네이밍 패턴 정의
  - [ ] 검증 로직 구현
  - [ ] 문서화

- [ ] **Rule 11: exception_message_localization**
  - [ ] 한글 메시지 검증
  - [ ] 패턴 매칭 구현
  - [ ] 문서화

### 공통 작업

- [ ] **유틸리티 함수 구현**
  - [ ] 계층 감지 (detectLayer)
  - [ ] Result 타입 체크 (isResultType)
  - [ ] Exception 타입 분류

- [ ] **테스트 인프라**
  - [ ] Good examples 디렉토리 구성
  - [ ] Bad examples 디렉토리 구성
  - [ ] 통합 테스트 작성

- [ ] **문서화**
  - [ ] README 업데이트
  - [ ] CONFIGURATION.md 업데이트
  - [ ] 마이그레이션 가이드 작성

- [ ] **배포 준비**
  - [ ] CHANGELOG 업데이트
  - [ ] 버전 번호 결정
  - [ ] pub.dev 배포

---

## 참고 자료

### 내부 문서
- [ERROR_HANDLING_GUIDE.md](ERROR_HANDLING_GUIDE.md) - 에러 처리 상세 가이드
- [CLEAN_ARCHITECTURE_GUIDE.md](CLEAN_ARCHITECTURE_GUIDE.md) - Clean Architecture 패턴
- [CONFIGURATION.md](CONFIGURATION.md) - 린터 설정 가이드

### 외부 리소스
- [custom_lint_builder 문서](https://pub.dev/packages/custom_lint_builder)
- [Analyzer API](https://pub.dev/documentation/analyzer/latest/)
- [AST 노드 타입](https://pub.dev/documentation/analyzer/latest/dart_ast_ast/dart_ast_ast-library.html)

---

## 예상 일정

### Timeline

```
Week 1-2: Phase 1 Rule 1-2 (datasource, repository Result 규칙)
Week 3-4: Phase 1 Rule 3-4 (repository throw, usecase Result 규칙)
Week 5-6: Phase 1 Rule 5 + 테스트 (presentation 규칙)
Week 7-8: Phase 2 Rule 6-7 (exception 타입, failure 변환)
Week 9-10: Phase 2 Rule 8 + 테스트 (AsyncValue 규칙)
Week 11-12: Phase 3 + 문서화 + 배포 준비
```

### Milestones

- **M1 (Week 6)**: Phase 1 완료 - 핵심 에러 처리 규칙 5개
- **M2 (Week 10)**: Phase 2 완료 - 품질 향상 규칙 3개
- **M3 (Week 12)**: Phase 3 완료 - 고급 검증 + 배포

---

## 기대 효과

### 개발자 경험
- ✅ 실시간 피드백으로 빠른 학습
- ✅ 코드 리뷰 부담 감소
- ✅ 일관된 에러 처리 패턴

### 코드 품질
- ✅ 계층 분리 명확화
- ✅ 타입 안전성 향상
- ✅ 유지보수성 개선

### 프로젝트 관리
- ✅ 아키텍처 일관성 유지
- ✅ 기술 부채 감소
- ✅ 신규 멤버 온보딩 효율화
