# 통합 유틸리티 마이그레이션 계획

## 문서 개요

**목적**: CleanArchitectureUtils와 RuleUtils를 단계적으로 통합하기 위한 구체적인 마이그레이션 로드맵 및 작업 우선순위 정의

**전략**: 4단계 점진적 통합 - 완전 중복 → 부분 중복 → 고유 메서드 → 규칙 파일 업데이트

**목표**:
- 코드 중복 제거 (33개 메서드 → ~25개 메서드)
- API 일관성 향상 (단일 진입점)
- 하위 호환성 유지 (@Deprecated 전략)
- 성능 저하 없음 (±5% 이내)

**전제 조건**:
- ✅ Task 11.1 완료: 메서드 인벤토리 (33개 메서드 식별)
- ✅ Task 11.2 완료: 중복 기능 분석 (3개 완전 중복, 2개 부분 중복)
- ✅ Task 11.3 완료: 사용량 분석 (38회 사용, 13개 파일 영향)
- ✅ Task 11.4 완료: 영향도 분석 (4시간 작업, 3주 프로젝트)

---

## Phase 1: 완전히 동일한 동작의 중복 메서드 통합

### 1.1 범위 및 목표

**목표**: 기능이 완전히 동일하여 즉시 병합 가능한 중복 메서드 통합

**대상 메서드**: 없음 (완전히 동일한 메서드 없음)

**발견 사항**: Task 11.2 분석 결과, 모든 중복 메서드가 미묘한 차이를 가지고 있음
- `isDomainLayerFile()` vs `isDomainFile()`: 파일 제외 로직 유무, 경로 패턴 수 차이
- `isDataLayerFile()` vs `isDataFile()`: 동일한 차이
- `isPresentationLayerFile()` vs `isPresentationFile()`: 동일한 차이

**결론**: Phase 1은 건너뛰고 Phase 2에서 처리

**작업량**: 0시간

---

## Phase 2: 미묘한 차이가 있는 메서드의 최적 구현 선택 및 통합

### 2.1 범위 및 목표

**목표**: 유사하지만 차이가 있는 메서드들을 최적 구현으로 통합

**대상 메서드 쌍**: 3개 쌍 (레이어 파일 감지 메서드)

**우선순위**: 최고 (전체 사용량의 44.7% 차지)

---

### 2.2 레이어 파일 감지 메서드 통합

#### 2.2.1 Domain Layer 파일 감지

**현재 상태**:
```dart
// CleanArchitectureUtils (11회 사용)
static bool isDomainLayerFile(String filePath) {
  if (shouldExcludeFile(filePath)) return false;
  return filePath.contains('/domain/') || filePath.contains('\\domain\\');
}

// RuleUtils (1회 사용)
static bool isDomainFile(String filePath) {
  final normalized = _normalizePath(filePath);
  return normalized.contains('/domain/') ||
      normalized.contains('/usecases/') ||
      normalized.contains('/use_cases/') ||
      normalized.contains('/entities/') ||
      normalized.contains('/exceptions/');
}
```

**장단점 비교**:

| 측면 | CleanArchitectureUtils | RuleUtils |
|------|------------------------|-----------|
| 파일 제외 | ✅ 자동 제외 (테스트, 생성 파일) | ❌ 미지원 |
| 경로 패턴 | ❌ 제한적 (1개) | ✅ 확장적 (5개) |
| 경로 정규화 | ❌ 수동 (조건문) | ✅ 자동 |
| 사용 빈도 | ✅ 높음 (11회) | ❌ 낮음 (1회) |

**통합 전략**: **두 가지 장점 결합 (Best of Both Worlds)**

**새로운 통합 API**:
```dart
/// Checks if a file belongs to the domain layer.
///
/// Supports extended path patterns:
/// - `/domain/`
/// - `/usecases/`, `/use_cases/`
/// - `/entities/`
/// - `/exceptions/`
///
/// By default, excludes test files, generated files, and build artifacts.
/// Set [excludeFiles] to false to include all files.
///
/// Examples:
/// ```dart
/// isDomainFile('lib/features/todos/domain/entities/todo.dart');  // true
/// isDomainFile('lib/features/todos/usecases/get_todos.dart');    // true
/// isDomainFile('lib/features/todos/domain/entities/todo_test.dart'); // false (excluded)
/// isDomainFile('lib/features/todos/domain/entities/todo_test.dart', excludeFiles: false); // true
/// ```
static bool isDomainFile(String filePath, {bool excludeFiles = true}) {
  // Step 1: File exclusion (optional, default: true)
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  // Step 2: Path normalization (always)
  final normalized = _normalizePath(filePath);

  // Step 3: Extended path pattern matching
  return normalized.contains('/domain/') ||
      normalized.contains('/usecases/') ||
      normalized.contains('/use_cases/') ||
      normalized.contains('/entities/') ||
      normalized.contains('/exceptions/');
}
```

**하위 호환성 유지**:
```dart
/// **Deprecated**: Use [isDomainFile] instead.
/// This method will be removed in v3.0.0.
@Deprecated('Use isDomainFile instead. Will be removed in v3.0.0.')
static bool isDomainLayerFile(String filePath) {
  return isDomainFile(filePath); // 기본값 excludeFiles: true
}
```

**검증 기준**:
- ✅ 기존 11회 사용 케이스 모두 통과
- ✅ `/usecases/` 디렉토리 파일 감지 (새 기능)
- ✅ 테스트 파일 자동 제외 (기존 동작 유지)
- ✅ `excludeFiles: false`로 테스트 파일 포함 가능

**작업량**: 2시간
- 구현: 30분
- 테스트 작성: 60분
- 문서화: 30분

---

#### 2.2.2 Data Layer 파일 감지

**현재 상태**:
```dart
// CleanArchitectureUtils (2회 사용)
static bool isDataLayerFile(String filePath) {
  if (shouldExcludeFile(filePath)) return false;
  return filePath.contains('/data/') || filePath.contains('\\data\\');
}

// RuleUtils (0회 사용)
static bool isDataFile(String filePath) {
  final normalized = _normalizePath(filePath);
  return normalized.contains('/data/') ||
      normalized.contains('/datasources/') ||
      normalized.contains('/data_sources/') ||
      normalized.contains('/repositories/') ||
      normalized.contains('/models/');
}
```

**통합 전략**: Domain 파일 감지와 동일한 패턴

**새로운 통합 API**:
```dart
/// Checks if a file belongs to the data layer.
///
/// Supports extended path patterns:
/// - `/data/`
/// - `/datasources/`, `/data_sources/`
/// - `/repositories/`
/// - `/models/`
///
/// By default, excludes test files, generated files, and build artifacts.
static bool isDataFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/data/') ||
      normalized.contains('/datasources/') ||
      normalized.contains('/data_sources/') ||
      normalized.contains('/repositories/') ||
      normalized.contains('/models/');
}
```

**하위 호환성**:
```dart
@Deprecated('Use isDataFile instead. Will be removed in v3.0.0.')
static bool isDataLayerFile(String filePath) {
  return isDataFile(filePath);
}
```

**작업량**: 1.5시간

---

#### 2.2.3 Presentation Layer 파일 감지

**현재 상태**:
```dart
// CleanArchitectureUtils (0회 사용)
static bool isPresentationLayerFile(String filePath) {
  if (shouldExcludeFile(filePath)) return false;
  return filePath.contains('/presentation/') ||
      filePath.contains('\\presentation\\');
}

// RuleUtils (2회 사용)
static bool isPresentationFile(String filePath) {
  final normalized = _normalizePath(filePath);
  return normalized.contains('/presentation/') ||
      normalized.contains('/ui/') ||
      normalized.contains('/views/') ||
      normalized.contains('/widgets/') ||
      normalized.contains('/pages/') ||
      normalized.contains('/screens/') ||
      normalized.contains('/states/');
}
```

**통합 전략**: 동일한 패턴, 확장 경로 패턴 + 파일 제외

**새로운 통합 API**:
```dart
/// Checks if a file belongs to the presentation layer.
///
/// Supports extended path patterns:
/// - `/presentation/`
/// - `/ui/`, `/views/`, `/widgets/`
/// - `/pages/`, `/screens/`
/// - `/states/`
///
/// By default, excludes test files, generated files, and build artifacts.
static bool isPresentationFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/presentation/') ||
      normalized.contains('/ui/') ||
      normalized.contains('/views/') ||
      normalized.contains('/widgets/') ||
      normalized.contains('/pages/') ||
      normalized.contains('/screens/') ||
      normalized.contains('/states/');
}
```

**하위 호환성**:
```dart
@Deprecated('Use isPresentationFile instead. Will be removed in v3.0.0.')
static bool isPresentationLayerFile(String filePath) {
  return isPresentationFile(filePath);
}
```

**작업량**: 1.5시간

---

### 2.3 Repository 인터페이스 검증 메서드 통합

#### 2.3.1 현재 상태 분석

**CleanArchitectureUtils.isRepositoryInterface()** (AST 기반):
```dart
static bool isRepositoryInterface(ClassDeclaration classDeclaration) {
  final className = classDeclaration.name.lexeme;

  final repositoryPatterns = ['Repository', 'DataSource', 'Gateway', 'Port'];
  final isRepositoryClass = repositoryPatterns.any((pattern) => className.contains(pattern));

  if (!isRepositoryClass) return false;

  final isAbstractClass = classDeclaration.abstractKeyword != null;
  final hasOnlyAbstractMethods = classDeclaration.members
      .whereType<MethodDeclaration>()
      .every((method) => method.isAbstract || method.isGetter || method.isSetter);

  return isRepositoryClass && (isAbstractClass || hasOnlyAbstractMethods);
}
```

**RuleUtils.isRepositoryInterfaceClass()** (문자열 기반):
```dart
static bool isRepositoryInterfaceClass(String className) {
  return className.endsWith('Repository') &&
      !className.endsWith('RepositoryImpl');
}
```

**장단점 비교**:

| 측면 | AST 기반 (CleanArchUtils) | 문자열 기반 (RuleUtils) |
|------|---------------------------|------------------------|
| 정확도 | ✅ 높음 (구조 분석) | ❌ 낮음 (이름만 검사) |
| 성능 | ❌ 느림 (AST 순회) | ✅ 빠름 (문자열 비교) |
| 패턴 수 | ✅ 4개 (Repository, DataSource, Gateway, Port) | ❌ 1개 (Repository) |
| abstract 확인 | ✅ 지원 | ❌ 미지원 |
| 메서드 검증 | ✅ 모든 메서드 abstract 확인 | ❌ 미지원 |

**통합 전략**: **두 메서드 모두 유지** (서로 다른 용도)

**구현 방안**:
```dart
// AST 기반 (정밀 검증) - CleanArchitectureUtils에 유지
/// Checks if a class is a repository interface using AST analysis.
///
/// This is a precise but slower method that examines the class structure.
/// Use this for accurate validation when you have AST nodes.
///
/// Validates:
/// - Class name contains Repository/DataSource/Gateway/Port
/// - Class is abstract OR all methods are abstract
/// - Getters and setters are allowed
static bool isRepositoryInterface(ClassDeclaration classDeclaration) {
  // 기존 구현 유지, 확장 패턴 추가
}

// 문자열 기반 (빠른 필터링) - CleanArchitectureUtils로 이동
/// Checks if a class name suggests it's a repository interface.
///
/// This is a fast but less precise method for quick filtering.
/// Use this for performance-critical checks or when AST is unavailable.
///
/// Examples:
/// - `TodoRepository` → true
/// - `TodoRepositoryImpl` → false
/// - `UserRepository` → true
static bool isRepositoryInterfaceClass(String className) {
  return className.endsWith('Repository') &&
      !className.endsWith('RepositoryImpl');
}
```

**사용 가이드**:
```dart
// 빠른 필터링 (Guard Clause)
if (!isRepositoryInterfaceClass(className)) return;

// 정밀 검증 (실제 규칙 검사)
if (isRepositoryInterface(classDeclaration)) {
  // Repository 인터페이스로 확정
}
```

**작업량**: 2시간
- 메서드 통합: 30분
- 테스트 작성: 60분
- 문서화: 30분

---

### 2.4 Phase 2 요약

| 메서드 쌍 | 통합 전략 | 예상 시간 | 우선순위 |
|----------|----------|----------|---------|
| isDomainLayerFile + isDomainFile | 장점 결합 (excludeFiles 옵션) | 2h | 최고 |
| isDataLayerFile + isDataFile | 동일 패턴 | 1.5h | 최고 |
| isPresentationLayerFile + isPresentationFile | 동일 패턴 | 1.5h | 최고 |
| isRepositoryInterface + isRepositoryInterfaceClass | 두 메서드 유지 (다른 용도) | 2h | 중간 |

**Phase 2 총 작업량**: 7시간

**완료 기준**:
- ✅ 4개 메서드 쌍 통합 완료
- ✅ @Deprecated 어노테이션 추가
- ✅ 단위 테스트 작성 (각 메서드당 5개 이상 테스트 케이스)
- ✅ dartdoc 주석 작성
- ✅ 기존 기능 회귀 테스트 통과

---

## Phase 3: 고유 메서드들의 클래스 재배치 및 네이밍 일관성 개선

### 3.1 범위 및 목표

**목표**: RuleUtils의 고유 메서드들을 CleanArchitectureUtils로 이동하고 네이밍 일관성 개선

**대상 메서드**: 25개 (RuleUtils의 모든 public 메서드)

**작업 방식**: 카테고리별 그룹화 → 네이밍 일관성 검토 → CleanArchitectureUtils로 이동

---

### 3.2 파일 경로 체크 메서드 (6개)

**대상 메서드**:
- `isDataSourceFile()` - 1회 사용
- `isUseCaseFile()` - 1회 사용
- `isRepositoryImplFile()` - 0회 사용
- `isRepositoryInterfaceFile()` - 0회 사용
- `isRepositoryImplementationFile()` - 0회 사용

**네이밍 컨벤션**: `is{Component}File(String filePath)`

**이동 전략**:
```dart
// CleanArchitectureUtils에 추가
/// Checks if a file is a data source file.
///
/// Supports path patterns:
/// - `/datasources/`, `/data_sources/`
static bool isDataSourceFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/datasources/') ||
      normalized.contains('/data_sources/');
}

/// Checks if a file is a use case file.
static bool isUseCaseFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/usecases/') ||
      normalized.contains('/use_cases/');
}

/// Checks if a file is a repository implementation file.
static bool isRepositoryImplFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/repositories/') &&
      (normalized.contains('_impl.dart') || normalized.contains('_repository_impl.dart'));
}
```

**미사용 메서드 처리**:
- `isRepositoryInterfaceFile()`: 삭제 (isRepositoryImplFile로 충분)
- `isRepositoryImplementationFile()`: 삭제 (isRepositoryImplFile과 중복)

**작업량**: 3시간

---

### 3.3 클래스명 체크 메서드 (7개)

**대상 메서드**:
- `isUseCaseClass()` - 2회 사용
- `isDataSourceClass()` - 5회 사용
- `isRepositoryClass()` - 0회 사용
- `isRepositoryImplClass()` - 1회 사용
- `isRepositoryInterfaceClass()` - 0회 사용 (Phase 2에서 처리됨)
- `isRepositoryImplementationClass()` - 0회 사용

**네이밍 컨벤션**: `is{Component}Class(String className)`

**이동 전략**:
```dart
// CleanArchitectureUtils에 추가
/// Checks if a class name suggests it's a use case.
///
/// Examples:
/// - `GetTodoUseCase` → true
/// - `GetTodosUseCase` → true
/// - `TodoRepository` → false
static bool isUseCaseClass(String className) {
  return className.endsWith('UseCase');
}

/// Checks if a class name suggests it's a data source.
///
/// Supports patterns:
/// - `*DataSource` (e.g., `TodoRemoteDataSource`)
/// - `*Datasource` (e.g., `TodoRemoteDatasource`)
static bool isDataSourceClass(String className) {
  return className.endsWith('DataSource') || className.endsWith('Datasource');
}

/// Checks if a class name suggests it's a repository implementation.
///
/// Examples:
/// - `TodoRepositoryImpl` → true
/// - `TodoRepository` → false (interface)
static bool isRepositoryImplClass(String className) {
  return className.endsWith('RepositoryImpl') ||
      (className.endsWith('Impl') && className.contains('Repository'));
}
```

**미사용 메서드 처리**:
- `isRepositoryClass()`: 삭제 (isRepositoryImplClass + isRepositoryInterfaceClass로 충분)
- `isRepositoryImplementationClass()`: 삭제 (isRepositoryImplClass와 중복)

**작업량**: 2시간

---

### 3.4 타입 어노테이션 체크 메서드 (2개)

**대상 메서드**:
- `isResultType()` - 3회 사용
- `isVoidType()` - 2회 사용

**네이밍 컨벤션**: `is{Type}Type(TypeAnnotation? returnType)`

**이동 전략**:
```dart
// CleanArchitectureUtils에 추가
/// Checks if a return type is Result or Either type.
///
/// Recognizes:
/// - `Result<T, E>`
/// - `Either<L, R>`
/// - `Task<T>`
/// - `TaskEither<L, R>`
static bool isResultType(TypeAnnotation? returnType) {
  if (returnType == null) return false;
  final typeString = returnType.toString();
  return typeString.startsWith('Result<') ||
      typeString.startsWith('Either<') ||
      typeString.startsWith('Task<') ||
      typeString.startsWith('TaskEither<');
}

/// Checks if a return type is void.
static bool isVoidType(TypeAnnotation? returnType) {
  if (returnType == null) return false;
  return returnType.toString() == 'void';
}
```

**작업량**: 1.5시간

---

### 3.5 Exception 패턴 메서드 (3개)

**대상 메서드**:
- `isDataException()` - 1회 사용
- `isDomainException()` - 0회 사용
- `implementsException()` - 1회 사용

**네이밍 컨벤션**: `is{Layer}Exception(String typeName)`, `implements{Interface}()`

**이동 전략**:
```dart
// CleanArchitectureUtils에 추가
/// Checks if an exception type belongs to the data layer.
///
/// Recognizes patterns:
/// - `*DataException`
/// - `*DataError`
/// - `ServerException`, `CacheException`, `NetworkException`
static bool isDataException(String typeName) {
  return typeName.endsWith('DataException') ||
      typeName.endsWith('DataError') ||
      typeName == 'ServerException' ||
      typeName == 'CacheException' ||
      typeName == 'NetworkException';
}

/// Checks if an exception type belongs to the domain layer.
static bool isDomainException(String typeName) {
  return typeName.endsWith('DomainException') ||
      typeName.endsWith('DomainError') ||
      typeName.endsWith('Failure');
}

/// Checks if a class implements the Exception interface.
static bool implementsException(ClassDeclaration node) {
  final extendsClause = node.extendsClause;
  final implementsClause = node.implementsClause;
  final withClause = node.withClause;

  return (extendsClause?.superclass.toString().contains('Exception') ?? false) ||
      (implementsClause?.interfaces.any((i) => i.toString().contains('Exception')) ?? false) ||
      (withClause?.mixinTypes.any((m) => m.toString().contains('Exception')) ?? false);
}
```

**작업량**: 2시간

---

### 3.6 AST 탐색 및 유틸리티 메서드 (7개)

**대상 메서드**:
- `findParentClass()` - 2회 사용
- `isPrivateMethod()` - 1회 사용
- `isRethrow()` - 1회 사용
- `extractFeatureName()` - 2회 사용
- `_normalizePath()` - private (간접 사용)
- `_capitalizeAndSingularize()` - private (간접 사용)

**네이밍 컨벤션**: `{verb}{Noun}()` (AST), `extract{Data}()` (유틸리티)

**이동 전략**:
```dart
// CleanArchitectureUtils에 추가
/// Finds the parent class declaration of an AST node.
///
/// Returns null if the node is not inside a class.
static ClassDeclaration? findParentClass(AstNode? node) {
  var current = node;
  while (current != null) {
    if (current is ClassDeclaration) return current;
    current = current.parent;
  }
  return null;
}

/// Checks if a method is private (starts with underscore).
static bool isPrivateMethod(MethodDeclaration method) {
  return method.name.lexeme.startsWith('_');
}

/// Checks if a throw expression is a rethrow.
static bool isRethrow(ThrowExpression node) {
  return node.expression.toString() == 'rethrow';
}

/// Extracts the feature name from a file path.
///
/// Examples:
/// - `lib/features/todos/domain/entities/todo.dart` → `Todos`
/// - `lib/features/user/data/models/user_model.dart` → `User`
static String extractFeatureName(String filePath) {
  final match = RegExp(r'/features/(\w+)/').firstMatch(filePath);
  if (match == null) return '';

  final featureName = match.group(1)!;
  return _capitalizeAndSingularize(featureName);
}

/// Private: Normalizes a file path (backslash → forward slash).
static String _normalizePath(String path) {
  return path.replaceAll('\\', '/');
}

/// Private: Capitalizes and singularizes a string.
static String _capitalizeAndSingularize(String text) {
  // Capitalize first letter
  final capitalized = text[0].toUpperCase() + text.substring(1);

  // Singularize (simple heuristic)
  if (capitalized.endsWith('ies')) {
    return capitalized.substring(0, capitalized.length - 3) + 'y';
  } else if (capitalized.endsWith('s')) {
    return capitalized.substring(0, capitalized.length - 1);
  }

  return capitalized;
}
```

**작업량**: 3시간

---

### 3.7 Phase 3 요약

| 카테고리 | 메서드 수 | 사용 횟수 | 미사용 | 예상 시간 |
|---------|---------|----------|--------|----------|
| 파일 경로 체크 | 6개 | 2회 | 3개 | 3h |
| 클래스명 체크 | 7개 | 8회 | 3개 | 2h |
| 타입 체크 | 2개 | 5회 | 0개 | 1.5h |
| Exception 패턴 | 3개 | 2회 | 1개 | 2h |
| AST 탐색/유틸리티 | 7개 | 6회 | 2개 | 3h |
| **합계** | **25개** | **23회** | **9개** | **11.5h** |

**네이밍 일관성 개선**:
- 파일 경로: `is{Component}File(String filePath, {bool excludeFiles = true})`
- 클래스명: `is{Component}Class(String className)`
- 타입: `is{Type}Type(TypeAnnotation? returnType)`
- Exception: `is{Layer}Exception(String typeName)`, `implements{Interface}()`
- AST: `{verb}{Noun}()` (예: `findParentClass()`)
- 유틸리티: `extract{Data}()`, `_internalHelper()`

**완료 기준**:
- ✅ 25개 메서드 CleanArchitectureUtils로 이동
- ✅ 미사용 메서드 9개 삭제 또는 문서화
- ✅ 네이밍 컨벤션 100% 준수
- ✅ 모든 public 메서드에 dartdoc 주석
- ✅ 단위 테스트 작성

---

## Phase 4: 13개 규칙 파일의 import 문 및 메서드 호출 업데이트

### 4.1 범위 및 목표

**목표**: Phase 2-3에서 통합/이동된 메서드를 사용하는 13개 규칙 파일 업데이트

**영향받는 파일**: 13개 (전체 24개 중 54.2%)

**작업 방식**: 영향도 역순 (낮음 → 중간 → 높음)

---

### 4.2 낮은 영향도 파일 (3개, 1-2회 사용)

#### 4.2.1 presentation_use_async_value_rule.dart (1회 사용)

**현재 import**:
```dart
import '../../utils/rule_utils.dart';
```

**현재 메서드 호출**:
- `RuleUtils.isPresentationFile()` - 1회

**변경 후**:
```dart
import '../clean_architecture_linter_base.dart';
```

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isPresentationFile()` - 1회

**변경 라인 수**: 2줄
**예상 시간**: 10분

---

#### 4.2.2 repository_must_return_result_rule.dart (2회 사용)

**현재 import**:
```dart
import '../../utils/rule_utils.dart';
```

**현재 메서드 호출**:
- `RuleUtils.isVoidType()` - 1회
- `RuleUtils.isResultType()` - 1회

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isVoidType()` - 1회
- `CleanArchitectureUtils.isResultType()` - 1회

**변경 라인 수**: 3줄
**예상 시간**: 10분

---

#### 4.2.3 datasource_no_result_return_rule.dart (2회 사용)

**현재 메서드 호출**:
- `RuleUtils.isDataSourceClass()` - 1회
- `RuleUtils.isResultType()` - 1회

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isDataSourceClass()` - 1회
- `CleanArchitectureUtils.isResultType()` - 1회

**변경 라인 수**: 3줄
**예상 시간**: 10분

**낮은 영향도 합계**: 3개 파일, 8줄 변경, 30분

---

### 4.3 중간 영향도 파일 (9개, 3-4회 사용)

#### 4.3.1 dependency_inversion_rule.dart (4회 사용)

**현재 메서드 호출**:
- `CleanArchitectureUtils.isDomainLayerFile()` - 4회 (4개 visitor)

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isDomainFile()` - 4회

**변경 라인 수**: 4줄
**예상 시간**: 15분

**개선 기회** (선택적):
```dart
// 현재: 각 visitor마다 반복
@override
void visitClassDeclaration(ClassDeclaration node) {
  if (!CleanArchitectureUtils.isDomainFile(filePath)) return;
  // ...
}

@override
void visitMethodDeclaration(MethodDeclaration node) {
  if (!CleanArchitectureUtils.isDomainFile(filePath)) return;
  // ...
}

// 개선: 파일 레벨에서 1회만 검사
@override
void run(...) {
  if (!CleanArchitectureUtils.isDomainFile(filePath)) return;
  super.run(...); // 모든 visitor 실행
}
```

---

#### 4.3.2 repository_interface_rule.dart (4회 사용)

동일한 패턴 (dependency_inversion_rule.dart와 동일)

**변경 라인 수**: 4줄
**예상 시간**: 15분

---

#### 4.3.3 domain_purity_rule.dart (3회 사용)

**현재 메서드 호출**:
- `CleanArchitectureUtils.isDomainLayerFile()` - 3회

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isDomainFile()` - 3회

**변경 라인 수**: 3줄
**예상 시간**: 15분

---

#### 4.3.4 usecase_no_result_return_rule.dart (3회 사용)

**현재 import**:
```dart
import '../../utils/rule_utils.dart';
```

**현재 메서드 호출**:
- `RuleUtils.isUseCaseClass()` - 1회
- `RuleUtils.isVoidType()` - 1회
- `RuleUtils.isResultType()` - 1회

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isUseCaseClass()` - 1회
- `CleanArchitectureUtils.isVoidType()` - 1회
- `CleanArchitectureUtils.isResultType()` - 1회

**변경 라인 수**: 4줄 (import 1줄 + 메서드 3줄)
**예상 시간**: 20분

---

#### 4.3.5 usecase_must_convert_failure_rule.dart (3회 사용)

**현재 메서드 호출**:
- `RuleUtils.isUseCaseFile()` - 1회
- `RuleUtils.findParentClass()` - 1회
- `RuleUtils.isUseCaseClass()` - 1회

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isUseCaseFile()` - 1회
- `CleanArchitectureUtils.findParentClass()` - 1회
- `CleanArchitectureUtils.isUseCaseClass()` - 1회

**변경 라인 수**: 4줄
**예상 시간**: 20분

---

#### 4.3.6 exception_naming_convention_rule.dart (3회 사용)

**현재 메서드 호출**:
- `RuleUtils.isDomainFile()` - 1회
- `RuleUtils.implementsException()` - 1회
- `RuleUtils.extractFeatureName()` - 1회

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isDomainFile()` - 1회 (이미 Phase 2에서 통합됨)
- `CleanArchitectureUtils.implementsException()` - 1회
- `CleanArchitectureUtils.extractFeatureName()` - 1회

**변경 라인 수**: 4줄
**예상 시간**: 20분

---

#### 4.3.7 datasource_exception_types_rule.dart (3회 사용)

**현재 메서드 호출**:
- `RuleUtils.isDataSourceFile()` - 1회
- `RuleUtils.findParentClass()` - 1회
- `RuleUtils.isDataSourceClass()` - 1회

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isDataSourceFile()` - 1회
- `CleanArchitectureUtils.findParentClass()` - 1회
- `CleanArchitectureUtils.isDataSourceClass()` - 1회

**변경 라인 수**: 4줄
**예상 시간**: 20분

---

#### 4.3.8 repository_no_throw_rule.dart (3회 사용)

**현재 메서드 호출**:
- `RuleUtils.isRethrow()` - 1회
- `RuleUtils.isPrivateMethod()` - 1회
- `RuleUtils.isRepositoryImplClass()` - 1회

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isRethrow()` - 1회
- `CleanArchitectureUtils.isPrivateMethod()` - 1회
- `CleanArchitectureUtils.isRepositoryImplClass()` - 1회

**변경 라인 수**: 4줄
**예상 시간**: 20분

---

#### 4.3.9 presentation_no_data_exceptions_rule.dart (3회 사용)

**현재 메서드 호출**:
- `RuleUtils.isPresentationFile()` - 1회
- `RuleUtils.isDataException()` - 1회
- `RuleUtils.extractFeatureName()` - 1회

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isPresentationFile()` - 1회 (Phase 2에서 통합됨)
- `CleanArchitectureUtils.isDataException()` - 1회
- `CleanArchitectureUtils.extractFeatureName()` - 1회

**변경 라인 수**: 4줄
**예상 시간**: 20분

**중간 영향도 합계**: 9개 파일, 35줄 변경, 165분 (2.75시간)

---

### 4.4 높은 영향도 파일 (1개, 5회 사용, 두 유틸리티 혼용)

#### 4.4.1 datasource_abstraction_rule.dart (5회 사용)

**현재 import**:
```dart
import '../clean_architecture_linter_base.dart';
import '../../utils/rule_utils.dart';
```

**현재 메서드 호출**:
- `CleanArchitectureUtils.isDataLayerFile()` - 2회
- `CleanArchitectureUtils.isDomainLayerFile()` - 1회
- `RuleUtils.isDataSourceClass()` - 3회

**변경 후 import**:
```dart
import '../clean_architecture_linter_base.dart';
```

**변경 후 메서드 호출**:
- `CleanArchitectureUtils.isDataFile()` - 2회 (Phase 2에서 통합됨)
- `CleanArchitectureUtils.isDomainFile()` - 1회 (Phase 2에서 통합됨)
- `CleanArchitectureUtils.isDataSourceClass()` - 3회 (Phase 3에서 이동됨)

**변경 라인 수**: 7줄 (import 1줄 + 메서드 6줄)
**예상 시간**: 30분

**검증 중요도**: 최고
- 두 유틸리티 클래스 혼용하는 유일한 파일
- 레이어 파일 검증 + 클래스 타입 검증 동시 사용
- 통합 후 동작 일치성 필수 확인

**높은 영향도 합계**: 1개 파일, 7줄 변경, 30분

---

### 4.5 Phase 4 요약

| 영향도 | 파일 수 | 변경 라인 수 | 예상 시간 | 작업 순서 |
|--------|---------|-------------|----------|----------|
| 낮음 | 3개 | 8줄 | 30분 | Day 1 |
| 중간 | 9개 | 35줄 | 165분 | Day 2-3 |
| 높음 | 1개 | 7줄 | 30분 | Day 3 (마지막) |
| **합계** | **13개** | **50줄** | **225분 (3.75h)** | **3일** |

**작업 프로세스** (파일당):
1. [ ] import 문 변경
2. [ ] 메서드 호출 변경 (CleanArchitectureUtils.{method})
3. [ ] 메서드명 변경 (Layer → 없음, 예: isDomainLayerFile → isDomainFile)
4. [ ] 로컬 테스트 실행
5. [ ] 수동 검증 (예제 프로젝트 lint)
6. [ ] 커밋

**완료 기준**:
- ✅ 13개 파일 모두 마이그레이션 완료
- ✅ import '../clean_architecture_linter_base.dart' 단일 import
- ✅ RuleUtils 참조 0개
- ✅ 모든 테스트 통과
- ✅ 예제 프로젝트 lint 실행 성공

---

## 전체 마이그레이션 로드맵 요약

### 타임라인

| Phase | 작업 내용 | 예상 시간 | 담당 | 우선순위 |
|-------|----------|----------|------|---------|
| **Phase 1** | 완전 중복 메서드 통합 | **0h** (건너뛰기) | - | - |
| **Phase 2** | 미묘한 차이 메서드 통합 | **7h** | Developer | 최고 |
| **Phase 3** | 고유 메서드 이동 및 네이밍 | **11.5h** | Developer | 높음 |
| **Phase 4** | 13개 규칙 파일 업데이트 | **3.75h** | Developer | 높음 |
| **합계** | **통합 작업** | **22.25h (~3일)** | Team | 최고 |

### 변경 통계

| 항목 | 수량 |
|------|------|
| 통합/이동 메서드 수 | 29개 (Phase 2: 4개, Phase 3: 25개) |
| 삭제 메서드 수 | 9개 (미사용 메서드) |
| 영향받는 규칙 파일 수 | 13개 / 24개 (54.2%) |
| 변경 라인 수 | ~50줄 (규칙 파일) + ~200줄 (유틸리티 클래스) |
| @Deprecated 메서드 수 | 3개 (isDomainLayerFile, isDataLayerFile, isPresentationLayerFile) |

### 의존성 그래프

```
Phase 1 (건너뛰기)
  ↓
Phase 2 (레이어 감지 + Repository 검증 통합) [7h]
  ├─ isDomainFile() ← isDomainLayerFile() + isDomainFile()
  ├─ isDataFile() ← isDataLayerFile() + isDataFile()
  ├─ isPresentationFile() ← isPresentationLayerFile() + isPresentationFile()
  └─ isRepositoryInterface() + isRepositoryInterfaceClass() (두 메서드 유지)
  ↓
Phase 3 (고유 메서드 이동) [11.5h]
  ├─ 파일 경로 체크 (6개 메서드 이동)
  ├─ 클래스명 체크 (7개 메서드 이동)
  ├─ 타입 체크 (2개 메서드 이동)
  ├─ Exception 패턴 (3개 메서드 이동)
  └─ AST/유틸리티 (7개 메서드 이동)
  ↓
Phase 4 (규칙 파일 업데이트) [3.75h]
  ├─ 낮은 영향도 (3개 파일) [0.5h]
  ├─ 중간 영향도 (9개 파일) [2.75h]
  └─ 높은 영향도 (1개 파일) [0.5h]
```

### 리스크 관리

| 리스크 | 완화 전략 | 담당 |
|--------|----------|------|
| 파일 제외 로직 차이 | excludeFiles 옵션 제공 (기본값 true) | Developer |
| 경로 패턴 확장 | 릴리스 노트 명시, 마이그레이션 가이드 | Writer |
| AST 검증 로직 차이 | 두 메서드 유지 (용도 구분) | Developer |
| 외부 사용자 불만 | @Deprecated + 3-6개월 기간 | Product |
| 테스트 커버리지 부족 | 단위 테스트 90% 목표 | QA |

### 성공 지표

| 지표 | 현재 | 목표 |
|------|------|------|
| 코드 중복도 | 33개 메서드 분산 | 통합 단일 클래스 (~24개) |
| 사용 일관성 | 50% (중복 사용) | 100% (단일 API) |
| 테스트 커버리지 | 측정 필요 | ≥90% |
| RuleUtils 참조 | 25회 | 0회 |
| lint 실행 시간 | 측정 필요 | ±5% 이내 |

---

## 다음 단계

### 즉시 실행 (Task 12)

1. **통합 API 설계 문서 작성**
   - 네이밍 컨벤션 확정
   - 메서드 시그니처 정의
   - 하위 호환성 전략 결정

2. **테스트 커버리지 측정**
   - 현재 상태 파악
   - 목표 설정 (90%)

### 1주 내 (Task 13)

1. **Phase 2 구현**
   - isDomainFile(), isDataFile(), isPresentationFile() 통합
   - Repository 검증 메서드 정리
   - 단위 테스트 작성

2. **Phase 3 구현**
   - 25개 메서드 CleanArchitectureUtils로 이동
   - 네이밍 일관성 적용
   - 미사용 메서드 정리

### 2주 내 (Task 14)

1. **Phase 4 실행**
   - 13개 규칙 파일 마이그레이션
   - 전체 테스트 실행
   - 예제 프로젝트 검증

2. **RuleUtils 정리** (Task 15)
   - @Deprecated 래퍼 생성 또는 삭제
   - 마이그레이션 가이드 작성

---

## 결론

**총 작업 시간**: 22.25시간 (~3일)
**총 프로젝트 기간**: 약 3주 (Phase 1-5 포함)
**ROI**: 높음 (코드 중복 제거, API 일관성 향상, 유지보수성 개선)

**권장 사항**: 즉시 실행
- ✅ 명확한 실행 계획
- ✅ 관리 가능한 범위
- ✅ 충분한 리스크 완화 전략
- ✅ 하위 호환성 유지 가능

**다음 Task**: Task 12 (통합 유틸리티 클래스 설계 및 API 정의)
