# 중복 기능 식별 및 동작 차이점 분석

## 개요

CleanArchitectureUtils와 RuleUtils 간의 중복 메서드를 매핑하고 각 쌍의 구현 차이점을 상세히 분석합니다.

## 1. 파일 경로 감지 메서드 비교

### 1.1 Domain Layer 파일 감지

#### CleanArchitectureUtils.isDomainLayerFile()
```dart
// lib/src/clean_architecture_linter_base.dart:99-102
static bool isDomainLayerFile(String filePath) {
  if (shouldExcludeFile(filePath)) return false;
  return filePath.contains('/domain/') || filePath.contains('\\domain\\');
}
```

**특징**:
- ✅ 자동 파일 제외 필터링 (`shouldExcludeFile()` 호출)
- ✅ 백슬래시와 슬래시 모두 지원
- ❌ 제한적 경로 패턴 (오직 `/domain/` 디렉토리만)
- ❌ 추가 domain 관련 디렉토리 미지원

#### RuleUtils.isDomainFile()
```dart
// lib/src/utils/rule_utils.dart:28-35
static bool isDomainFile(String filePath) {
  final normalized = _normalizePath(filePath);
  return normalized.contains('/domain/') ||
      normalized.contains('/usecases/') ||
      normalized.contains('/use_cases/') ||
      normalized.contains('/entities/') ||
      normalized.contains('/exceptions/');
}
```

**특징**:
- ✅ 경로 정규화 (백슬래시 → 슬래시 변환)
- ✅ 확장된 경로 패턴 지원 (5가지 패턴)
- ❌ 파일 제외 필터링 없음 (테스트 파일, 생성 파일 포함)
- ✅ 더 유연한 프로젝트 구조 지원

**주요 차이점**:
| 항목 | CleanArchitectureUtils | RuleUtils |
|------|------------------------|-----------|
| 파일 제외 | ✅ 자동 제외 | ❌ 미지원 |
| 경로 패턴 | 1개 (`/domain/`) | 5개 (`/domain/`, `/usecases/`, `/use_cases/`, `/entities/`, `/exceptions/`) |
| 경로 정규화 | 수동 (조건문) | 자동 (`_normalizePath()`) |
| 테스트 파일 처리 | 자동 제외됨 | 포함됨 |

---

### 1.2 Data Layer 파일 감지

#### CleanArchitectureUtils.isDataLayerFile()
```dart
// lib/src/clean_architecture_linter_base.dart:105-108
static bool isDataLayerFile(String filePath) {
  if (shouldExcludeFile(filePath)) return false;
  return filePath.contains('/data/') || filePath.contains('\\data\\');
}
```

**특징**:
- ✅ 자동 파일 제외 필터링
- ✅ 백슬래시와 슬래시 모두 지원
- ❌ 제한적 경로 패턴 (오직 `/data/` 디렉토리만)

#### RuleUtils.isDataFile()
```dart
// lib/src/utils/rule_utils.dart:38-45
static bool isDataFile(String filePath) {
  final normalized = _normalizePath(filePath);
  return normalized.contains('/data/') ||
      normalized.contains('/datasources/') ||
      normalized.contains('/data_sources/') ||
      normalized.contains('/repositories/') ||
      normalized.contains('/models/');
}
```

**특징**:
- ✅ 경로 정규화
- ✅ 확장된 경로 패턴 지원 (5가지 패턴)
- ❌ 파일 제외 필터링 없음

**주요 차이점**:
| 항목 | CleanArchitectureUtils | RuleUtils |
|------|------------------------|-----------|
| 파일 제외 | ✅ 자동 제외 | ❌ 미지원 |
| 경로 패턴 | 1개 (`/data/`) | 5개 (`/data/`, `/datasources/`, `/data_sources/`, `/repositories/`, `/models/`) |
| 경로 정규화 | 수동 (조건문) | 자동 (`_normalizePath()`) |

---

### 1.3 Presentation Layer 파일 감지

#### CleanArchitectureUtils.isPresentationLayerFile()
```dart
// lib/src/clean_architecture_linter_base.dart:111-115
static bool isPresentationLayerFile(String filePath) {
  if (shouldExcludeFile(filePath)) return false;
  return filePath.contains('/presentation/') ||
      filePath.contains('\\presentation\\');
}
```

**특징**:
- ✅ 자동 파일 제외 필터링
- ✅ 백슬래시와 슬래시 모두 지원
- ❌ 제한적 경로 패턴 (오직 `/presentation/` 디렉토리만)

#### RuleUtils.isPresentationFile()
```dart
// lib/src/utils/rule_utils.dart:16-25
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

**특징**:
- ✅ 경로 정규화
- ✅ 확장된 경로 패턴 지원 (7가지 패턴)
- ❌ 파일 제외 필터링 없음

**주요 차이점**:
| 항목 | CleanArchitectureUtils | RuleUtils |
|------|------------------------|-----------|
| 파일 제외 | ✅ 자동 제외 | ❌ 미지원 |
| 경로 패턴 | 1개 (`/presentation/`) | 7개 (`/presentation/`, `/ui/`, `/views/`, `/widgets/`, `/pages/`, `/screens/`, `/states/`) |
| 경로 정규화 | 수동 (조건문) | 자동 (`_normalizePath()`) |

---

## 2. Repository 관련 메서드 비교

### 2.1 Repository Interface 검증

#### CleanArchitectureUtils.isRepositoryInterface()
```dart
// lib/src/clean_architecture_linter_base.dart:133-159
static bool isRepositoryInterface(ClassDeclaration classDeclaration) {
  final className = classDeclaration.name.lexeme;

  // Check if class name suggests it's a repository interface
  final repositoryPatterns = [
    'Repository',
    'DataSource',
    'Gateway',
    'Port',
  ];

  final isRepositoryClass =
      repositoryPatterns.any((pattern) => className.contains(pattern));

  if (!isRepositoryClass) return false;

  // Check if the class is abstract (interface) or has only abstract methods
  final isAbstractClass = classDeclaration.abstractKeyword != null;

  // Check if all methods in the class are abstract (interface pattern)
  final hasOnlyAbstractMethods = classDeclaration.members
      .whereType<MethodDeclaration>()
      .every((method) =>
          method.isAbstract || method.isGetter || method.isSetter);

  return isRepositoryClass && (isAbstractClass || hasOnlyAbstractMethods);
}
```

**특징**:
- ✅ AST 기반 검증 (`ClassDeclaration` 파라미터)
- ✅ abstract 키워드 확인
- ✅ 모든 메서드의 abstract 여부 확인
- ✅ Getter/Setter 허용
- ✅ 4가지 패턴 지원 (Repository, DataSource, Gateway, Port)
- ✅ 구현체 vs 인터페이스 구분 가능

#### RuleUtils.isRepositoryInterfaceClass()
```dart
// lib/src/utils/rule_utils.dart:115-118
static bool isRepositoryInterfaceClass(String className) {
  return className.endsWith('Repository') &&
      !className.endsWith('RepositoryImpl');
}
```

**특징**:
- ❌ 문자열 기반 검증 (AST 분석 없음)
- ❌ abstract 키워드 확인 불가
- ❌ 메서드 검증 불가
- ✅ 간단하고 빠른 이름 기반 검증
- ❌ 1가지 패턴만 지원 (Repository)
- ✅ Impl 접미사로 구현체 제외

**주요 차이점**:
| 항목 | CleanArchitectureUtils | RuleUtils |
|------|------------------------|-----------|
| 검증 방식 | AST 기반 (ClassDeclaration) | 문자열 기반 (className) |
| abstract 확인 | ✅ 지원 | ❌ 미지원 |
| 메서드 검증 | ✅ 모든 메서드 abstract 확인 | ❌ 미지원 |
| 패턴 수 | 4개 (Repository, DataSource, Gateway, Port) | 1개 (Repository) |
| 정확도 | 높음 (구조 분석) | 낮음 (이름 기반) |
| 성능 | 느림 (AST 순회) | 빠름 (문자열 비교) |

---

### 2.2 Repository Implementation 검증

#### RuleUtils.isRepositoryImplementationClass()
```dart
// lib/src/utils/rule_utils.dart:122-125
static bool isRepositoryImplementationClass(String className) {
  return className.endsWith('RepositoryImpl') ||
      (className.endsWith('Impl') && className.contains('Repository'));
}
```

**특징**:
- ✅ 2가지 패턴 지원 (`*RepositoryImpl`, `*Impl` + `Repository` 포함)
- ❌ 문자열 기반 검증만 가능
- ✅ 간단하고 빠름

**CleanArchitectureUtils 비교**:
- CleanArchitectureUtils에는 구현체 전용 검증 메서드가 없음
- `isRepositoryInterface()`에서 abstract 여부로 간접 구분

---

## 3. 파일 제외 로직 (CleanArchitectureUtils 고유)

### 3.1 shouldExcludeFile()
```dart
// lib/src/clean_architecture_linter_base.dart:21-43
static bool shouldExcludeFile(String filePath) {
  // Exclude test folders
  if (_isTestFile(filePath)) {
    return true;
  }

  // Exclude generated files
  if (_isGeneratedFile(filePath)) {
    return true;
  }

  // Exclude build artifacts
  if (_isBuildArtifact(filePath)) {
    return true;
  }

  // Exclude documentation files (but keep pubspec.yaml and analysis_options.yaml)
  if (_isDocumentationFile(filePath)) {
    return true;
  }

  return false;
}
```

**제외 대상**:
1. **테스트 파일** (`_isTestFile`):
   - `/test/`, `\test\` 디렉토리
   - `_test.dart` 접미사
   - `/integration_test/`, `\integration_test\` 디렉토리

2. **생성 파일** (`_isGeneratedFile`):
   - `.g.dart` (json_serializable)
   - `.freezed.dart` (freezed)
   - `.mocks.dart` (mockito)
   - `.config.dart` (build_runner)
   - `.gr.dart` (auto_route)
   - `.localizely.dart` (localizely)
   - `.pb.dart` (protobuf)

3. **빌드 아티팩트** (`_isBuildArtifact`):
   - `/build/`, `\build\` 디렉토리
   - `/.dart_tool/`, `\.dart_tool\` 디렉토리
   - `/.packages`, `\.packages` 파일

4. **문서 파일** (`_isDocumentationFile`):
   - `.md`, `.txt`, `.rst` 파일
   - 중요하지 않은 `.yaml`, `.yml` 파일 (pubspec.yaml, analysis_options.yaml 제외)

**RuleUtils 비교**:
- ❌ RuleUtils에는 파일 제외 로직이 전혀 없음
- ⚠️ 모든 파일을 검사 대상으로 포함 (테스트 파일, 생성 파일 포함)

---

## 4. 중복 기능 요약

### 4.1 완전 중복 (기능 동일, 구현 다름)

| CleanArchitectureUtils | RuleUtils | 차이점 |
|------------------------|-----------|--------|
| `isDomainLayerFile()` | `isDomainFile()` | 파일 제외 필터링 유무, 경로 패턴 수 (1 vs 5) |
| `isDataLayerFile()` | `isDataFile()` | 파일 제외 필터링 유무, 경로 패턴 수 (1 vs 5) |
| `isPresentationLayerFile()` | `isPresentationFile()` | 파일 제외 필터링 유무, 경로 패턴 수 (1 vs 7) |

### 4.2 부분 중복 (유사 기능, 다른 접근)

| CleanArchitectureUtils | RuleUtils | 차이점 |
|------------------------|-----------|--------|
| `isRepositoryInterface()` (AST) | `isRepositoryInterfaceClass()` (String) | AST 분석 vs 문자열 비교, 정확도 vs 성능 |
| - | `isRepositoryImplementationClass()` | CleanArchitectureUtils에는 구현체 전용 메서드 없음 |

### 4.3 고유 기능

**CleanArchitectureUtils 고유**:
- `shouldExcludeFile()` - 파일 제외 로직 (4가지 필터)
- `_isTestFile()`, `_isGeneratedFile()`, `_isBuildArtifact()`, `_isDocumentationFile()`
- `isRepositoryInterfaceMethod()` - 메서드 레벨 검증

**RuleUtils 고유**:
- `isDataSourceFile()`, `isRepositoryImplFile()`, `isUseCaseFile()`
- `isRepositoryInterfaceFile()`, `isRepositoryImplementationFile()` - 파일 경로 기반
- `isUseCaseClass()`, `isDataSourceClass()`, `isRepositoryClass()`, `isRepositoryImplClass()` - 클래스명 기반
- `isResultType()`, `isVoidType()`, `implementsException()` - 타입 검증
- `isDataException()`, `isDomainException()` - 예외 패턴
- `extractFeatureName()` - Feature 이름 추출
- `findParentClass()`, `isPrivateMethod()`, `isRethrow()` - AST 탐색
- `_normalizePath()`, `_capitalizeAndSingularize()` - 경로/문자열 유틸리티

---

## 5. 동작 차이점 분석

### 5.1 레이어 파일 감지 동작 차이

**시나리오 1: 테스트 파일**
```dart
// 파일 경로: lib/features/todos/domain/usecases/get_todos_usecase_test.dart

CleanArchitectureUtils.isDomainLayerFile(filePath)
// → false (shouldExcludeFile()에서 _test.dart 감지하여 제외)

RuleUtils.isDomainFile(filePath)
// → true (파일 제외 로직 없음, /domain/ 또는 /usecases/ 감지)
```

**시나리오 2: 생성 파일**
```dart
// 파일 경로: lib/features/todos/data/models/todo_model.freezed.dart

CleanArchitectureUtils.isDataLayerFile(filePath)
// → false (shouldExcludeFile()에서 .freezed.dart 감지하여 제외)

RuleUtils.isDataFile(filePath)
// → true (파일 제외 로직 없음, /data/ 또는 /models/ 감지)
```

**시나리오 3: 확장 디렉토리 구조**
```dart
// 파일 경로: lib/features/todos/usecases/get_todos.dart

CleanArchitectureUtils.isDomainLayerFile(filePath)
// → false (/domain/ 디렉토리가 없음)

RuleUtils.isDomainFile(filePath)
// → true (/usecases/ 감지)
```

---

### 5.2 Repository 검증 동작 차이

**시나리오 1: Abstract Repository 인터페이스**
```dart
abstract class TodoRepository {
  Future<List<Todo>> getTodos();
}

CleanArchitectureUtils.isRepositoryInterface(classDeclaration)
// → true (abstract 키워드 + Repository 패턴)

RuleUtils.isRepositoryInterfaceClass('TodoRepository')
// → true (Repository 접미사, Impl 없음)
```

**시나리오 2: Concrete Repository (구현 메서드 있음)**
```dart
class TodoRepository {
  Future<List<Todo>> getTodos() async {
    // implementation
  }
}

CleanArchitectureUtils.isRepositoryInterface(classDeclaration)
// → false (abstract 아님, 구현 메서드 있음)

RuleUtils.isRepositoryInterfaceClass('TodoRepository')
// → true (이름만 검사, 구현 여부 미확인)
```

**시나리오 3: Abstract Methods만 있는 Repository (abstract 키워드 없음)**
```dart
class TodoRepository {
  Future<List<Todo>> getTodos();
  Future<void> addTodo(Todo todo);
}

CleanArchitectureUtils.isRepositoryInterface(classDeclaration)
// → true (모든 메서드가 abstract)

RuleUtils.isRepositoryInterfaceClass('TodoRepository')
// → true (이름만 검사)
```

---

## 6. 통합 권장 사항

### 6.1 통합 우선순위

**높은 우선순위 (즉시 통합)**:
1. 레이어 파일 감지 (isDomainLayerFile, isDataLayerFile, isPresentationLayerFile)
   - RuleUtils의 확장 경로 패턴 + CleanArchitectureUtils의 파일 제외 로직 결합

**중간 우선순위 (검토 후 통합)**:
2. Repository 인터페이스 검증
   - AST 기반 검증 (CleanArchitectureUtils) 유지
   - 문자열 기반 검증 (RuleUtils) 보조 메서드로 활용

**낮은 우선순위 (필요시 통합)**:
3. 유틸리티 메서드
   - RuleUtils의 경로 정규화 메서드 전역 적용
   - CleanArchitectureUtils의 private 메서드 재사용

### 6.2 제안된 통합 API

```dart
// 레이어 파일 감지 (통합 버전)
static bool isDomainFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/domain/') ||
      normalized.contains('/usecases/') ||
      normalized.contains('/use_cases/') ||
      normalized.contains('/entities/') ||
      normalized.contains('/exceptions/');
}

// Repository 인터페이스 검증 (통합 버전)
static bool isRepositoryInterface(ClassDeclaration classDeclaration) {
  // AST 기반 검증 (CleanArchitectureUtils 방식 유지)
  // + 확장 패턴 추가 (RuleUtils의 다양한 패턴)
}

static bool isRepositoryInterfaceByName(String className) {
  // 문자열 기반 빠른 검증 (RuleUtils 방식 유지)
  // 보조 메서드로 활용
}
```

---

## 7. 영향도 분석

### 7.1 파일 제외 로직 누락의 영향

**현재 RuleUtils를 사용하는 규칙**:
- 테스트 파일과 생성 파일도 검사 대상에 포함됨
- 불필요한 경고/오류 발생 가능성
- 성능 저하 (불필요한 파일 분석)

**예상 문제**:
```dart
// lib/features/todos/domain/entities/todo.freezed.dart
// RuleUtils.isDomainFile() → true (제외되지 않음)
// → Freezed 생성 코드에 대한 불필요한 lint 검사
```

### 7.2 경로 패턴 제한의 영향

**현재 CleanArchitectureUtils를 사용하는 규칙**:
- 확장 디렉토리 구조 미지원 (`/usecases/`, `/entities/` 등)
- 유연하지 않은 프로젝트 구조 제약
- 표준 Clean Architecture 디렉토리만 인식

**예상 문제**:
```dart
// lib/features/todos/usecases/get_todos.dart
// CleanArchitectureUtils.isDomainLayerFile() → false
// → Domain 레이어 파일인데도 감지되지 않음
```

---

## 결론

1. **중복 기능**: 3개의 레이어 감지 메서드가 완전 중복
2. **주요 차이**: 파일 제외 로직 vs 확장 경로 패턴
3. **통합 필요성**: 두 장점을 결합한 통합 API 필요
4. **영향도**: 현재 두 유틸리티 클래스의 한계로 인한 잠재적 문제 존재
