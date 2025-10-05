# 유틸리티 메서드 인벤토리

## CleanArchitectureUtils (lib/src/clean_architecture_linter_base.dart)

### 파일 제외 및 경로 분석

| 메서드 시그니처 | 파라미터 | 반환 타입 | 주요 기능 |
|----------------|---------|----------|----------|
| `shouldExcludeFile(String filePath)` | filePath: String | bool | 테스트 파일, 생성 파일, 빌드 아티팩트, 문서 파일 제외 여부 확인 |
| `isDomainLayerFile(String filePath)` | filePath: String | bool | /domain/ 경로에 위치한 파일인지 확인 (제외 파일 필터링 포함) |
| `isDataLayerFile(String filePath)` | filePath: String | bool | /data/ 경로에 위치한 파일인지 확인 (제외 파일 필터링 포함) |
| `isPresentationLayerFile(String filePath)` | filePath: String | bool | /presentation/ 경로에 위치한 파일인지 확인 (제외 파일 필터링 포함) |

### Repository 검증

| 메서드 시그니처 | 파라미터 | 반환 타입 | 주요 기능 |
|----------------|---------|----------|----------|
| `isRepositoryInterfaceMethod(MethodDeclaration method)` | method: MethodDeclaration | bool | 메서드가 Repository 인터페이스에 속하는지 확인 |
| `isRepositoryInterface(ClassDeclaration classDeclaration)` | classDeclaration: ClassDeclaration | bool | 클래스가 Repository 인터페이스인지 확인 (abstract + Repository/DataSource/Gateway/Port 패턴) |

### 내부 헬퍼 메서드 (private)

| 메서드 시그니처 | 반환 타입 | 주요 기능 |
|----------------|----------|----------|
| `_isTestFile(String filePath)` | bool | 테스트 파일 판별 (/test/, _test.dart, /integration_test/) |
| `_isGeneratedFile(String filePath)` | bool | 생성 파일 판별 (.g.dart, .freezed.dart, .mocks.dart 등) |
| `_isBuildArtifact(String filePath)` | bool | 빌드 아티팩트 판별 (/build/, /.dart_tool/, .packages) |
| `_isDocumentationFile(String filePath)` | bool | 문서 파일 판별 (.md, .txt, .rst, 중요하지 않은 .yaml) |

---

## RuleUtils (lib/src/utils/rule_utils.dart)

### 파일 경로 체크

| 메서드 시그니처 | 파라미터 | 반환 타입 | 주요 기능 |
|----------------|---------|----------|----------|
| `isPresentationFile(String filePath)` | filePath: String | bool | Presentation 레이어 파일 확인 (/presentation/, /ui/, /views/, /widgets/, /pages/, /screens/, /states/) |
| `isDomainFile(String filePath)` | filePath: String | bool | Domain 레이어 파일 확인 (/domain/, /usecases/, /use_cases/, /entities/, /exceptions/) |
| `isDataFile(String filePath)` | filePath: String | bool | Data 레이어 파일 확인 (/data/, /datasources/, /data_sources/, /repositories/, /models/) |
| `isDataSourceFile(String filePath)` | filePath: String | bool | DataSource 파일 확인 (/datasources/, /data_sources/) |
| `isRepositoryImplFile(String filePath)` | filePath: String | bool | Repository 구현체 파일 확인 (/repositories/ + _impl.dart) |
| `isUseCaseFile(String filePath)` | filePath: String | bool | UseCase 파일 확인 (/usecases/, /use_cases/) |
| `isRepositoryInterfaceFile(String filePath)` | filePath: String | bool | Repository 인터페이스 파일 확인 (lib/*/domain/repositories/*.dart) |
| `isRepositoryImplementationFile(String filePath)` | filePath: String | bool | Repository 구현체 파일 확인 (lib/*/data/repositories/*_impl.dart) |

### 클래스 이름 체크

| 메서드 시그니처 | 파라미터 | 반환 타입 | 주요 기능 |
|----------------|---------|----------|----------|
| `isUseCaseClass(String className)` | className: String | bool | UseCase 클래스명 확인 (*UseCase, *Usecase, contains UseCase) |
| `isDataSourceClass(String className)` | className: String | bool | DataSource 클래스명 확인 (*DataSource, contains DataSource) |
| `isRepositoryClass(String className)` | className: String | bool | Repository 클래스명 확인 (*Repository, contains Repository) |
| `isRepositoryImplClass(String className)` | className: String | bool | Repository 구현체 클래스명 확인 (*RepositoryImpl, *Impl + contains Repository) |
| `isRepositoryInterfaceClass(String className)` | className: String | bool | Repository 인터페이스 클래스명 확인 (*Repository but NOT *RepositoryImpl) |
| `isRepositoryImplementationClass(String className)` | className: String | bool | Repository 구현체 클래스명 확인 (*RepositoryImpl, *Impl + contains Repository) |

### 타입 체크

| 메서드 시그니처 | 파라미터 | 반환 타입 | 주요 기능 |
|----------------|---------|----------|----------|
| `isResultType(TypeAnnotation? returnType)` | returnType: TypeAnnotation? | bool | Result 또는 Either 타입 확인 (재귀적 검사 포함) |
| `isVoidType(TypeAnnotation? returnType)` | returnType: TypeAnnotation? | bool | void 타입 확인 |
| `implementsException(ClassDeclaration node)` | node: ClassDeclaration | bool | Exception 인터페이스 구현 여부 확인 |

### Exception & 에러 패턴

| 메서드 시그니처 | 파라미터 | 반환 타입 | 주요 기능 |
|----------------|---------|----------|----------|
| `isDataException(String typeName)` | typeName: String | bool | Data 레이어 예외 타입 확인 (NotFoundException, UnauthorizedException 등) |
| `isDomainException(String typeName)` | typeName: String | bool | Domain 예외 타입 확인 (feature prefix + Exception) |

**Data Exception 목록**:
- NotFoundException
- UnauthorizedException
- NetworkException
- DataSourceException
- ServerException
- CacheException
- DatabaseException

### Feature & 경로 유틸리티

| 메서드 시그니처 | 파라미터 | 반환 타입 | 주요 기능 |
|----------------|---------|----------|----------|
| `extractFeatureName(String filePath)` | filePath: String | String? | 파일 경로에서 feature 이름 추출 (/features/{feature}/ 패턴) |

### AST 탐색 헬퍼

| 메서드 시그니처 | 파라미터 | 반환 타입 | 주요 기능 |
|----------------|---------|----------|----------|
| `findParentClass(AstNode? node)` | node: AstNode? | ClassDeclaration? | 노드의 부모 클래스 선언 찾기 |
| `isPrivateMethod(MethodDeclaration method)` | method: MethodDeclaration | bool | private 메서드 확인 (이름이 _로 시작) |
| `isRethrow(ThrowExpression node)` | node: ThrowExpression | bool | rethrow 표현식 확인 |

### 내부 헬퍼 메서드 (private)

| 메서드 시그니처 | 반환 타입 | 주요 기능 |
|----------------|----------|----------|
| `_normalizePath(String filePath)` | String | 경로 정규화 (백슬래시를 슬래시로 변환) |
| `_capitalizeAndSingularize(String name)` | String | 첫 글자 대문자화 및 복수형 제거 |

---

## 메서드 카테고리별 분류

### 1. 파일 경로 감지 (File Path Detection)

**CleanArchitectureUtils**:
- `shouldExcludeFile()` - 제외 파일 필터링
- `isDomainLayerFile()` - Domain 레이어 (제외 필터 포함)
- `isDataLayerFile()` - Data 레이어 (제외 필터 포함)
- `isPresentationLayerFile()` - Presentation 레이어 (제외 필터 포함)

**RuleUtils**:
- `isPresentationFile()` - Presentation 레이어 (더 많은 경로 패턴)
- `isDomainFile()` - Domain 레이어 (더 많은 경로 패턴)
- `isDataFile()` - Data 레이어 (더 많은 경로 패턴)
- `isDataSourceFile()` - DataSource 전용
- `isRepositoryImplFile()` - Repository 구현체 전용
- `isUseCaseFile()` - UseCase 전용
- `isRepositoryInterfaceFile()` - Repository 인터페이스 전용
- `isRepositoryImplementationFile()` - Repository 구현체 전용

### 2. 클래스/타입 검증 (Class/Type Validation)

**CleanArchitectureUtils**:
- `isRepositoryInterface()` - ClassDeclaration 기반 Repository 인터페이스 확인
- `isRepositoryInterfaceMethod()` - MethodDeclaration 기반 Repository 메서드 확인

**RuleUtils**:
- `isUseCaseClass()` - UseCase 클래스명 패턴
- `isDataSourceClass()` - DataSource 클래스명 패턴
- `isRepositoryClass()` - Repository 클래스명 패턴
- `isRepositoryImplClass()` - Repository 구현체 클래스명 패턴
- `isRepositoryInterfaceClass()` - Repository 인터페이스 클래스명 패턴
- `isRepositoryImplementationClass()` - Repository 구현체 클래스명 패턴
- `isResultType()` - Result/Either 타입 검증
- `isVoidType()` - void 타입 검증
- `implementsException()` - Exception 구현 여부

### 3. Exception 패턴 (Exception Patterns)

**RuleUtils**:
- `isDataException()` - Data 레이어 예외 타입
- `isDomainException()` - Domain 레이어 예외 타입 (feature prefix)

### 4. AST 유틸리티 (AST Utilities)

**RuleUtils**:
- `findParentClass()` - 부모 클래스 탐색
- `isPrivateMethod()` - private 메서드 확인
- `isRethrow()` - rethrow 확인

### 5. Feature 유틸리티 (Feature Utilities)

**RuleUtils**:
- `extractFeatureName()` - feature 이름 추출

---

## 주요 차이점 요약

### 파일 경로 감지 차이

1. **제외 필터링**:
   - `CleanArchitectureUtils`: `shouldExcludeFile()` 사용하여 자동 필터링
   - `RuleUtils`: 제외 필터링 없음, 단순 경로 패턴 매칭

2. **경로 패턴**:
   - `CleanArchitectureUtils`: 기본 경로만 (/domain/, /data/, /presentation/)
   - `RuleUtils`: 확장된 경로 (/ui/, /views/, /widgets/, /usecases/, /entities/ 등)

3. **메서드명**:
   - `CleanArchitectureUtils`: `isDomainLayerFile()`, `isDataLayerFile()`, `isPresentationLayerFile()`
   - `RuleUtils`: `isDomainFile()`, `isDataFile()`, `isPresentationFile()`

### Repository 검증 차이

1. **CleanArchitectureUtils**:
   - AST 노드 기반 검증 (`ClassDeclaration`, `MethodDeclaration`)
   - Repository 인터페이스 패턴 매칭 (Repository, DataSource, Gateway, Port)
   - abstract 클래스 또는 abstract 메서드만 가진 클래스 확인

2. **RuleUtils**:
   - 클래스명 문자열 기반 검증
   - 파일 경로 기반 검증
   - 인터페이스와 구현체 분리 (InterfaceClass vs ImplementationClass)

### 고유 기능

**CleanArchitectureUtils 고유**:
- 파일 제외 로직 (테스트, 생성 파일, 빌드 아티팩트)
- AST 기반 Repository 인터페이스 검증

**RuleUtils 고유**:
- 타입 검증 (Result, Either, void)
- Exception 패턴 검증
- AST 탐색 헬퍼 (findParentClass, isPrivateMethod, isRethrow)
- Feature 이름 추출
- UseCase, DataSource 전용 검증
