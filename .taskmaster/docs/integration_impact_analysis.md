# 유틸리티 통합 영향도 분석 보고서

## 문서 개요

**목적**: CleanArchitectureUtils와 RuleUtils 통합 시 영향받는 규칙 파일들을 식별하고 리팩토링 복잡도를 정량적으로 평가

**분석 범위**: 24개 lint 규칙 파일
**분석 일자**: 2025-10-05
**의존 분석**: Task 11.1 (메서드 인벤토리), Task 11.2 (중복 분석), Task 11.3 (사용량 분석)

---

## 1. 전체 영향도 요약

### 1.1 영향받는 파일 통계

| 영향도 | 파일 수 | 비율 | 예상 시간 |
|--------|---------|------|----------|
| **높음** (5회 이상) | 1개 | 4.2% | 30분 |
| **중간** (3-4회) | 9개 | 37.5% | 180분 |
| **낮음** (1-2회) | 3개 | 12.5% | 30분 |
| **영향 없음** (0회) | 11개 | 45.8% | 0분 |
| **총계** | **24개** | **100%** | **240분 (4시간)** |

### 1.2 유틸리티 클래스별 영향도

| 유틸리티 클래스 | 사용 파일 수 | 총 사용 횟수 | 평균 사용 횟수/파일 |
|----------------|-------------|-------------|-------------------|
| CleanArchitectureUtils | 3개 | 13회 | 4.3회 |
| RuleUtils | 10개 | 25회 | 2.5회 |
| **두 클래스 모두 사용** | 1개 | 5회 | 5.0회 |
| **합계** | **13개** | **38회** | **2.9회** |

---

## 2. 규칙 파일별 상세 영향도 분석

### 2.1 높은 영향도 (5회 이상 사용)

#### datasource_abstraction_rule.dart (5회)

**위치**: `lib/src/rules/data_rules/datasource_abstraction_rule.dart`

**사용 메서드**:
- `CleanArchitectureUtils.isDataLayerFile()` - 2회
- `CleanArchitectureUtils.isDomainLayerFile()` - 1회
- `RuleUtils.isDataSourceClass()` - 3회

**영향도 평가**: ⚠️ **매우 높음**
- 두 유틸리티 클래스를 모두 사용하는 유일한 파일
- 레이어 파일 검증 + 클래스 타입 검증 혼용
- 통합 시 가장 주의 깊게 다루어야 할 파일

**필요한 변경 사항**:
```dart
// 현재
import '../clean_architecture_linter_base.dart';
import '../../utils/rule_utils.dart';

if (!CleanArchitectureUtils.isDataLayerFile(filePath)) return;
if (!RuleUtils.isDataSourceClass(className)) return;

// 통합 후
import '../clean_architecture_linter_base.dart';

if (!CleanArchitectureUtils.isDataFile(filePath)) return;
if (!CleanArchitectureUtils.isDataSourceClass(className)) return;
```

**예상 작업량**:
- 변경 라인 수: ~8줄 (import 1줄 + 메서드 호출 5줄 + 테스트 2줄)
- 예상 시간: 30분
- 리스크: 중간 (두 클래스 혼용으로 인한 복잡도)

---

### 2.2 중간 영향도 (3-4회 사용)

#### 2.2.1 dependency_inversion_rule.dart (4회)

**위치**: `lib/src/rules/domain_rules/dependency_inversion_rule.dart`

**사용 메서드**:
- `CleanArchitectureUtils.isDomainLayerFile()` - 4회 (4개 visitor에서 각 1회)

**영향도 평가**: ⚠️ **중간**
- 단일 메서드 반복 사용
- Guard Clause 패턴으로 일관성 있게 사용됨

**필요한 변경 사항**:
```dart
// 현재
if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
// (4개 visitor에서 반복)

// 통합 후 (옵션 1: 그대로 유지)
if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

// 통합 후 (옵션 2: 베이스 클래스로 추상화)
@override
void run(...) {
  if (!CleanArchitectureUtils.isDomainFile(filePath)) return;
  super.run(...); // 모든 visitor 실행
}
```

**예상 작업량**:
- 변경 라인 수: 4줄 (메서드명만 변경)
- 예상 시간: 15분
- 리스크: 낮음 (단순 메서드명 변경)

**개선 기회**: 베이스 클래스로 추상화하면 4회 → 1회로 감소

---

#### 2.2.2 repository_interface_rule.dart (4회)

**위치**: `lib/src/rules/domain_rules/repository_interface_rule.dart`

**사용 메서드**:
- `CleanArchitectureUtils.isDomainLayerFile()` - 4회

**영향도 평가**: ⚠️ **중간**

**필요한 변경 사항**: dependency_inversion_rule.dart와 동일

**예상 작업량**:
- 변경 라인 수: 4줄
- 예상 시간: 15분
- 리스크: 낮음

---

#### 2.2.3 domain_purity_rule.dart (3회)

**위치**: `lib/src/rules/domain_rules/domain_purity_rule.dart`

**사용 메서드**:
- `CleanArchitectureUtils.isDomainLayerFile()` - 3회 (2개 visitor + 1개 헬퍼 메서드)

**영향도 평가**: ⚠️ **중간**

**예상 작업량**:
- 변경 라인 수: 3줄
- 예상 시간: 15분
- 리스크: 낮음

---

#### 2.2.4 usecase_no_result_return_rule.dart (3회)

**위치**: `lib/src/rules/domain_rules/usecase_no_result_return_rule.dart`

**사용 메서드**:
- `RuleUtils.isUseCaseClass()` - 1회
- `RuleUtils.isVoidType()` - 1회
- `RuleUtils.isResultType()` - 1회

**영향도 평가**: ⚠️ **중간**
- 3개의 서로 다른 메서드 사용
- 타입 검증 로직 포함

**필요한 변경 사항**:
```dart
// 현재
import '../../utils/rule_utils.dart';

if (!RuleUtils.isUseCaseClass(className)) return;
if (RuleUtils.isVoidType(returnType)) return;
if (RuleUtils.isResultType(returnType)) { ... }

// 통합 후
import '../clean_architecture_linter_base.dart';

if (!CleanArchitectureUtils.isUseCaseClass(className)) return;
if (CleanArchitectureUtils.isVoidType(returnType)) return;
if (CleanArchitectureUtils.isResultType(returnType)) { ... }
```

**예상 작업량**:
- 변경 라인 수: ~5줄 (import 1줄 + 메서드 호출 3줄 + 테스트 1줄)
- 예상 시간: 20분
- 리스크: 중간 (타입 검증 로직의 정확성 확인 필요)

---

#### 2.2.5 usecase_must_convert_failure_rule.dart (3회)

**위치**: `lib/src/rules/domain_rules/usecase_must_convert_failure_rule.dart`

**사용 메서드**:
- `RuleUtils.isUseCaseFile()` - 1회
- `RuleUtils.findParentClass()` - 1회
- `RuleUtils.isUseCaseClass()` - 1회

**영향도 평가**: ⚠️ **중간**
- AST 탐색 헬퍼 메서드 포함

**예상 작업량**:
- 변경 라인 수: ~5줄
- 예상 시간: 20분
- 리스크: 중간

---

#### 2.2.6 exception_naming_convention_rule.dart (3회)

**위치**: `lib/src/rules/domain_rules/exception_naming_convention_rule.dart`

**사용 메서드**:
- `RuleUtils.isDomainFile()` - 1회
- `RuleUtils.implementsException()` - 1회
- `RuleUtils.extractFeatureName()` - 1회

**영향도 평가**: ⚠️ **중간**

**예상 작업량**:
- 변경 라인 수: ~5줄
- 예상 시간: 20분
- 리스크: 중간

---

#### 2.2.7 datasource_exception_types_rule.dart (3회)

**위치**: `lib/src/rules/data_rules/datasource_exception_types_rule.dart`

**사용 메서드**:
- `RuleUtils.isDataSourceFile()` - 1회
- `RuleUtils.findParentClass()` - 1회
- `RuleUtils.isDataSourceClass()` - 1회

**영향도 평가**: ⚠️ **중간**

**예상 작업량**:
- 변경 라인 수: ~5줄
- 예상 시간: 20분
- 리스크: 중간

---

#### 2.2.8 repository_no_throw_rule.dart (3회)

**위치**: `lib/src/rules/data_rules/repository_no_throw_rule.dart`

**사용 메서드**:
- `RuleUtils.isRethrow()` - 1회
- `RuleUtils.isPrivateMethod()` - 1회
- `RuleUtils.isRepositoryImplClass()` - 1회

**영향도 평가**: ⚠️ **중간**
- AST 탐색 및 특수 패턴 검증

**예상 작업량**:
- 변경 라인 수: ~5줄
- 예상 시간: 20분
- 리스크: 중간

---

#### 2.2.9 presentation_no_data_exceptions_rule.dart (3회)

**위치**: `lib/src/rules/presentation_rules/presentation_no_data_exceptions_rule.dart`

**사용 메서드**:
- `RuleUtils.isPresentationFile()` - 1회
- `RuleUtils.isDataException()` - 1회
- `RuleUtils.extractFeatureName()` - 1회

**영향도 평가**: ⚠️ **중간**

**예상 작업량**:
- 변경 라인 수: ~5줄
- 예상 시간: 20분
- 리스크: 중간

---

### 2.3 낮은 영향도 (1-2회 사용)

#### 2.3.1 repository_must_return_result_rule.dart (2회)

**위치**: `lib/src/rules/data_rules/repository_must_return_result_rule.dart`

**사용 메서드**:
- `RuleUtils.isVoidType()` - 1회
- `RuleUtils.isResultType()` - 1회

**영향도 평가**: ✅ **낮음**

**예상 작업량**:
- 변경 라인 수: 3줄
- 예상 시간: 10분
- 리스크: 낮음

---

#### 2.3.2 datasource_no_result_return_rule.dart (2회)

**위치**: `lib/src/rules/data_rules/datasource_no_result_return_rule.dart`

**사용 메서드**:
- `RuleUtils.isDataSourceClass()` - 1회
- `RuleUtils.isResultType()` - 1회

**영향도 평가**: ✅ **낮음**

**예상 작업량**:
- 변경 라인 수: 3줄
- 예상 시간: 10분
- 리스크: 낮음

---

#### 2.3.3 presentation_use_async_value_rule.dart (1회)

**위치**: `lib/src/rules/presentation_rules/presentation_use_async_value_rule.dart`

**사용 메서드**:
- `RuleUtils.isPresentationFile()` - 1회

**영향도 평가**: ✅ **낮음**

**예상 작업량**:
- 변경 라인 수: 2줄
- 예상 시간: 10분
- 리스크: 낮음

---

### 2.4 영향 없음 (0회 사용)

다음 11개 파일은 유틸리티 메서드를 사용하지 않으므로 통합의 영향을 받지 않습니다:

1. `boundary_crossing_rule.dart`
2. `circular_dependency_rule.dart`
3. `layer_dependency_rule.dart`
4. `test_coverage_rule.dart`
5. `model_structure_rule.dart`
6. `failure_naming_convention_rule.dart`
7. `extension_location_rule.dart`
8. `freezed_usage_rule.dart`
9. `no_presentation_models_rule.dart`
10. `riverpod_generator_rule.dart`
11. `exception_message_localization_rule.dart`

---

## 3. 리팩토링 복잡도 분석

### 3.1 복잡도 등급별 분류

#### 높은 복잡도 (1개 파일)

**datasource_abstraction_rule.dart**
- **이유**: 두 유틸리티 클래스 혼용
- **복잡도 점수**: 8/10
- **주요 리스크**:
  - 레이어 검증 로직 변경 (CleanArchitectureUtils)
  - 클래스 타입 검증 로직 변경 (RuleUtils)
  - 통합 후 동작 일치성 검증 필요
- **완화 전략**:
  - 단계적 마이그레이션 (레이어 검증 → 클래스 검증)
  - 각 단계마다 테스트 실행
  - 롤백 계획 수립

#### 중간 복잡도 (9개 파일)

**공통 패턴**:
- 단일 유틸리티 클래스 사용
- 3-4개 메서드 호출
- Guard Clause 패턴 또는 타입 검증 로직

**복잡도 점수**: 4-6/10

**주요 리스크**:
- 메서드명 변경으로 인한 오타 가능성
- 타입 검증 로직의 정확성 유지
- AST 탐색 로직의 동작 일치성

**완화 전략**:
- IDE의 Find & Replace 기능 활용
- 각 파일마다 테스트 실행
- 타입 검증 로직의 단위 테스트 강화

#### 낮은 복잡도 (3개 파일)

**공통 패턴**:
- 1-2개 메서드만 사용
- 단순 Guard Clause 또는 타입 체크

**복잡도 점수**: 1-3/10

**리스크**: 거의 없음

---

### 3.2 리팩토링 작업량 정량화

#### 파일 수준 통계

| 복잡도 | 파일 수 | 평균 변경 라인 수 | 총 변경 라인 수 | 예상 시간 |
|--------|---------|------------------|----------------|-----------|
| 높음 | 1 | 8줄 | 8줄 | 30분 |
| 중간 | 9 | 5줄 | 45줄 | 180분 |
| 낮음 | 3 | 2.5줄 | 7.5줄 | 30분 |
| **합계** | **13** | **4.6줄** | **60.5줄** | **240분** |

#### 변경 유형별 통계

| 변경 유형 | 파일 수 | 변경 횟수 | 비율 |
|----------|---------|----------|------|
| import 문 변경 | 10 | 10회 | 16.5% |
| 메서드명 변경 (`isDomainLayerFile` → `isDomainFile`) | 3 | 11회 | 18.2% |
| 메서드명 변경 (RuleUtils → CleanArchitectureUtils) | 10 | 27회 | 44.6% |
| 테스트 코드 업데이트 | 13 | 13회 | 21.5% |
| **합계** | **13** | **61회** | **100%** |

---

## 4. 하위 호환성 전략

### 4.1 @Deprecated 어노테이션 사용

**전략**: 기존 메서드를 당장 삭제하지 않고 @Deprecated로 표시하여 점진적 마이그레이션 지원

**구현 예시**:
```dart
// lib/src/clean_architecture_linter_base.dart

/// Checks if a file belongs to the domain layer.
///
/// **Deprecated**: Use [isDomainFile] instead.
/// This method will be removed in v3.0.0.
@Deprecated('Use isDomainFile instead. Will be removed in v3.0.0.')
static bool isDomainLayerFile(String filePath) {
  return isDomainFile(filePath);
}

/// Checks if a file belongs to the domain layer (new unified API).
///
/// Supports extended path patterns:
/// - `/domain/`
/// - `/usecases/`, `/use_cases/`
/// - `/entities/`
/// - `/exceptions/`
///
/// Automatically excludes test files, generated files, and build artifacts.
static bool isDomainFile(String filePath) {
  if (shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/domain/') ||
      normalized.contains('/usecases/') ||
      normalized.contains('/use_cases/') ||
      normalized.contains('/entities/') ||
      normalized.contains('/exceptions/');
}
```

**장점**:
- ✅ 기존 코드 호환성 유지
- ✅ 사용자에게 마이그레이션 시간 제공
- ✅ IDE에서 자동 경고 표시

**단점**:
- ❌ 코드 중복 증가
- ❌ 유지보수 부담

**권장 타임라인**:
- v2.0.0: @Deprecated 추가, 새 API 소개
- v2.1.0-v2.9.0: 마이그레이션 기간
- v3.0.0: @Deprecated 메서드 제거

---

### 4.2 RuleUtils 클래스 래퍼 유지

**전략**: RuleUtils를 완전히 삭제하지 않고 CleanArchitectureUtils의 래퍼로 유지

**구현 예시**:
```dart
// lib/src/utils/rule_utils.dart

/// **Deprecated**: This class has been merged into CleanArchitectureUtils.
/// All methods are now available in CleanArchitectureUtils.
/// This wrapper will be removed in v3.0.0.
@Deprecated('Use CleanArchitectureUtils instead. Will be removed in v3.0.0.')
class RuleUtils {
  RuleUtils._();

  @Deprecated('Use CleanArchitectureUtils.isDomainFile instead')
  static bool isDomainFile(String filePath) =>
      CleanArchitectureUtils.isDomainFile(filePath);

  @Deprecated('Use CleanArchitectureUtils.isDataFile instead')
  static bool isDataFile(String filePath) =>
      CleanArchitectureUtils.isDataFile(filePath);

  @Deprecated('Use CleanArchitectureUtils.isPresentationFile instead')
  static bool isPresentationFile(String filePath) =>
      CleanArchitectureUtils.isPresentationFile(filePath);

  // ... 나머지 27개 메서드도 동일한 패턴
}
```

**장점**:
- ✅ 100% 하위 호환성
- ✅ 외부 사용자 코드 무중단
- ✅ 점진적 마이그레이션 가능

**단점**:
- ❌ 파일 유지 필요
- ❌ 메서드 중복 27개

**권장 사용 시기**:
- 외부 사용자가 RuleUtils를 직접 import하는 경우
- 라이브러리 버전 업그레이드 시 breaking change 최소화

---

### 4.3 통합 API 설계 원칙

**일관된 네이밍 컨벤션**:
```dart
// 파일 경로 검증: {layer}File()
isDomainFile(String filePath)
isDataFile(String filePath)
isPresentationFile(String filePath)
isDataSourceFile(String filePath)
isUseCaseFile(String filePath)
isRepositoryFile(String filePath)

// 클래스명 검증: is{Type}Class()
isUseCaseClass(String className)
isDataSourceClass(String className)
isRepositoryClass(String className)
isRepositoryInterfaceClass(String className)
isRepositoryImplementationClass(String className)

// 타입 어노테이션 검증: is{Type}Type()
isResultType(TypeAnnotation? returnType)
isVoidType(TypeAnnotation? returnType)

// AST 노드 검증: {verb}{Noun}()
findParentClass(AstNode? node)
implementsException(ClassDeclaration node)

// 패턴 분석: is{Pattern}()
isDataException(String typeName)
isDomainException(String typeName)
isPrivateMethod(MethodDeclaration method)
isRethrow(ThrowExpression node)

// 유틸리티: {verb}{Noun}()
extractFeatureName(String filePath)
shouldExcludeFile(String filePath)
```

**파라미터 일관성**:
- 파일 경로 검증: `String filePath`
- 클래스명 검증: `String className`
- AST 노드 검증: 구체적 타입 (`ClassDeclaration`, `MethodDeclaration` 등)

---

## 5. 리스크 분석 및 완화 전략

### 5.1 기술적 리스크

#### 리스크 1: 파일 제외 로직 차이로 인한 동작 변경

**설명**: CleanArchitectureUtils는 자동 파일 제외, RuleUtils는 제외 없음

**영향 범위**: RuleUtils를 사용하는 10개 파일

**발생 확률**: 높음 (80%)

**영향도**: 중간
- 테스트 파일, 생성 파일도 검사 대상에 포함됨
- 불필요한 경고 발생 가능

**완화 전략**:
1. **옵션 1**: 파일 제외 기능을 선택적으로 만들기
   ```dart
   static bool isDomainFile(String filePath, {bool excludeFiles = true}) {
     if (excludeFiles && shouldExcludeFile(filePath)) return false;
     // ...
   }
   ```

2. **옵션 2**: RuleUtils 동작 유지 (제외 없음)
   ```dart
   static bool isDomainFileStrict(String filePath) {
     // 파일 제외 없이 순수 경로만 검사
   }
   ```

3. **권장**: 옵션 1 (기본값 true, 필요시 false)

**검증 방법**:
- 테스트 파일에서 규칙 실행
- 생성 파일(.freezed.dart)에서 규칙 실행
- 예상: 경고 없음 (제외됨)

---

#### 리스크 2: 경로 패턴 확장으로 인한 예상치 못한 파일 감지

**설명**: RuleUtils의 확장 경로 패턴이 예상치 못한 파일 감지

**영향 범위**: CleanArchitectureUtils만 사용하던 3개 파일

**발생 확률**: 중간 (40%)

**영향도**: 낮음
- 더 많은 파일을 올바르게 감지 (장점)
- 기존에 감지 안 되던 파일 감지 (Breaking change 가능)

**완화 전략**:
1. 릴리스 노트에 명확히 기재
2. 마이그레이션 가이드 제공
3. 단계적 적용 (v2.0.0에서 경고만, v2.1.0에서 적용)

**검증 방법**:
- `/usecases/` 디렉토리 파일로 테스트
- 기존: 감지 안 됨 → 새 버전: 감지됨

---

#### 리스크 3: AST 노드 검증 로직의 미묘한 차이

**설명**: `isRepositoryInterface()` (AST 기반) vs `isRepositoryInterfaceClass()` (문자열 기반)

**영향 범위**: Repository 검증 규칙 (Tasks 1-10, 아직 미구현)

**발생 확률**: 낮음 (20%)

**영향도**: 높음
- AST 기반이 더 정확하지만 느림
- 문자열 기반이 빠르지만 부정확할 수 있음

**완화 전략**:
1. 두 메서드 모두 유지
   ```dart
   // AST 기반 (정확하지만 느림)
   static bool isRepositoryInterface(ClassDeclaration node) { }

   // 문자열 기반 (빠르지만 덜 정확)
   static bool isRepositoryInterfaceClass(String className) { }
   ```

2. 사용 가이드 제공
   - 빠른 필터링: `isRepositoryInterfaceClass()`
   - 정밀 검증: `isRepositoryInterface()`

---

### 5.2 프로젝트 리스크

#### 리스크 4: 외부 사용자의 breaking change 불만

**발생 확률**: 높음 (70%)

**영향도**: 높음
- 라이브러리 평가 하락
- 마이그레이션 부담

**완화 전략**:
1. **Major 버전 업그레이드** (v1.x.x → v2.0.0)
   - Semantic Versioning 준수
   - Breaking change 명시

2. **충분한 Deprecation 기간** (3-6개월)
   - v2.0.0: @Deprecated 추가
   - v2.5.0: 마이그레이션 도구 제공
   - v3.0.0: 제거

3. **자동 마이그레이션 도구**
   ```bash
   dart run clean_architecture_linter:migrate
   ```
   - import 자동 변경
   - 메서드명 자동 교체

4. **상세한 마이그레이션 가이드**
   - Before/After 코드 예제
   - 단계별 가이드
   - FAQ

---

#### 리스크 5: 테스트 커버리지 부족

**발생 확률**: 중간 (50%)

**영향도**: 높음
- 통합 후 버그 발생
- 회귀 테스트 실패

**완화 전략**:
1. **통합 전 테스트 커버리지 90% 달성**
   - 현재: 측정 필요
   - 목표: 90% 이상

2. **통합 중 회귀 테스트 강화**
   - 각 메서드의 before/after 동작 비교
   - 모든 규칙 파일 테스트 실행

3. **CI/CD 파이프라인 강화**
   - 테스트 자동 실행
   - 커버리지 리포트 생성
   - Pull Request 품질 게이트

---

## 6. 단계별 마이그레이션 로드맵

### Phase 1: 준비 단계 (1주)

**목표**: 통합 기반 작업 완료

**작업 내역**:
1. ✅ 메서드 인벤토리 작성 (Task 11.1 완료)
2. ✅ 중복 기능 분석 (Task 11.2 완료)
3. ✅ 사용량 분석 (Task 11.3 완료)
4. ⏳ 영향도 분석 (Task 11.4 진행 중)
5. ⏳ 마이그레이션 계획 수립 (Task 11.5 대기 중)

**완료 기준**:
- 모든 분석 문서 완성
- 마이그레이션 로드맵 확정

---

### Phase 2: 통합 API 설계 및 구현 (1주)

**목표**: 새로운 통합 CleanArchitectureUtils 완성

**작업 내역**:
1. 통합 API 설계 (Task 12)
   - 네이밍 컨벤션 정의
   - 메서드 시그니처 확정
   - 하위 호환성 전략 결정

2. 통합 클래스 구현 (Task 13)
   - CleanArchitectureUtils 확장
   - RuleUtils 메서드 통합
   - @Deprecated 어노테이션 추가

3. 단위 테스트 작성
   - 모든 새 메서드 테스트
   - 기존 기능 회귀 테스트
   - 경계 조건 테스트

**완료 기준**:
- 33개 유틸리티 메서드 통합 완료
- 단위 테스트 90% 커버리지
- dart analyze 경고 0개

**예상 소요 시간**: 40시간 (5일)

---

### Phase 3: 규칙 파일 마이그레이션 (3일)

**목표**: 13개 규칙 파일을 새 API로 마이그레이션

**작업 순서** (영향도 역순):

**Day 1** - 낮은 영향도 (3개 파일, 30분)
1. presentation_use_async_value_rule.dart
2. repository_must_return_result_rule.dart
3. datasource_no_result_return_rule.dart

**Day 2** - 중간 영향도 Part 1 (5개 파일, 120분)
4. dependency_inversion_rule.dart
5. repository_interface_rule.dart
6. domain_purity_rule.dart
7. usecase_no_result_return_rule.dart
8. usecase_must_convert_failure_rule.dart

**Day 3** - 중간 영향도 Part 2 + 높은 영향도 (5개 파일, 130분)
9. exception_naming_convention_rule.dart
10. datasource_exception_types_rule.dart
11. repository_no_throw_rule.dart
12. presentation_no_data_exceptions_rule.dart
13. datasource_abstraction_rule.dart (가장 마지막)

**각 파일별 체크리스트**:
- [ ] import 문 변경
- [ ] 메서드 호출 변경
- [ ] 테스트 실행 및 통과
- [ ] 수동 검증 (예제 프로젝트)
- [ ] 코드 리뷰

**완료 기준**:
- 모든 규칙 파일 마이그레이션 완료
- 전체 테스트 스위트 통과
- 예제 프로젝트 lint 실행 성공

**예상 소요 시간**: 4시간 (실제 작업) + 2시간 (테스트 및 검증) = 6시간

---

### Phase 4: RuleUtils 클래스 정리 (1일)

**목표**: RuleUtils.dart 파일 처리

**옵션 1**: 완전 삭제
- lib/src/utils/rule_utils.dart 삭제
- import 정리
- Breaking change 릴리스 (v2.0.0)

**옵션 2**: @Deprecated 래퍼 유지 (권장)
- RuleUtils를 CleanArchitectureUtils 래퍼로 변경
- @Deprecated 어노테이션 추가
- v3.0.0에서 삭제 예정 명시

**완료 기준**:
- RuleUtils 처리 완료
- 외부 사용자 영향 최소화
- 마이그레이션 가이드 작성

**예상 소요 시간**: 4시간

---

### Phase 5: 테스트 및 문서화 (2일)

**목표**: 품질 보증 및 릴리스 준비

**작업 내역**:
1. 전체 테스트 실행
   - 단위 테스트
   - 통합 테스트
   - 회귀 테스트

2. 커버리지 측정 및 개선
   - 목표: 90% 이상
   - 부족한 부분 추가 테스트

3. 문서 업데이트
   - CLAUDE.md: 새 API 반영
   - README.md: 마이그레이션 가이드
   - CHANGELOG.md: Breaking changes 명시
   - API 문서: dartdoc 주석 추가

4. 성능 벤치마크
   - 통합 전후 성능 비교
   - 예제 프로젝트 lint 실행 시간 측정

**완료 기준**:
- 테스트 커버리지 ≥90%
- 모든 문서 업데이트 완료
- 성능 저하 없음 (±5% 이내)

**예상 소요 시간**: 16시간 (2일)

---

### 전체 타임라인 요약

| Phase | 작업 내용 | 예상 시간 | 담당자 | 우선순위 |
|-------|----------|----------|--------|----------|
| Phase 1 | 준비 단계 | 1주 | Architect | 높음 |
| Phase 2 | API 설계 및 구현 | 1주 (40h) | Developer | 높음 |
| Phase 3 | 규칙 파일 마이그레이션 | 3일 (24h) | Developer | 높음 |
| Phase 4 | RuleUtils 정리 | 1일 (8h) | Developer | 중간 |
| Phase 5 | 테스트 및 문서화 | 2일 (16h) | QA + Writer | 높음 |
| **총계** | **전체 통합 프로세스** | **3주** | **팀** | **높음** |

---

## 7. 성공 지표 (KPI)

### 7.1 정량적 지표

| 지표 | 현재 | 목표 | 측정 방법 |
|------|------|------|----------|
| **코드 중복도** | 33개 메서드 분산 | 통합 단일 클래스 | 유틸리티 클래스 수 |
| **사용 일관성** | 50% (중복 사용) | 100% (단일 API) | API 호출 패턴 분석 |
| **테스트 커버리지** | 측정 필요 | ≥90% | dart pub test --coverage |
| **메서드 수** | 33개 (중복 포함) | ~25개 (중복 제거) | 유틸리티 메서드 카운트 |
| **영향받는 파일** | 13개 (54.2%) | 0개 (100% 마이그레이션) | 규칙 파일 카운트 |
| **lint 실행 시간** | 측정 필요 | ±5% 이내 | 예제 프로젝트 벤치마크 |

### 7.2 정성적 지표

| 지표 | 평가 기준 |
|------|----------|
| **코드 가독성** | 동료 리뷰 점수 ≥4/5 |
| **API 일관성** | 네이밍 컨벤션 100% 준수 |
| **문서 품질** | 모든 public API dartdoc 주석 포함 |
| **사용자 만족도** | GitHub Issues 감소 30% |

---

## 8. 롤백 계획

### 8.1 롤백 시나리오

**시나리오 1**: Phase 2 중 통합 API 설계 실패
- **트리거**: 테스트 커버리지 <80%
- **조치**: Phase 1로 복귀, 설계 재검토
- **영향**: 1주 지연

**시나리오 2**: Phase 3 중 규칙 파일 마이그레이션 실패
- **트리거**: 회귀 테스트 실패 >3개 파일
- **조치**: 실패한 파일 롤백, 나머지 계속
- **영향**: 부분 롤백, 2-3일 지연

**시나리오 3**: Phase 5 중 성능 저하 발견
- **트리거**: lint 실행 시간 >10% 증가
- **조치**: 성능 최적화 또는 전체 롤백
- **영향**: 1주 지연 또는 릴리스 연기

### 8.2 롤백 절차

1. **즉시 조치**:
   - main 브랜치로 복귀
   - 롤백 커밋 생성
   - 팀 통보

2. **영향 평가**:
   - 실패 원인 분석
   - 영향 범위 파악
   - 대안 검토

3. **재계획**:
   - 문제 해결 방안 수립
   - 타임라인 재조정
   - 우선순위 재평가

---

## 9. 결론 및 권장 사항

### 9.1 핵심 발견 사항

1. **중간 수준의 영향도**
   - 13개 파일 영향 (54.2%)
   - 예상 작업 시간: 4시간 (실제 코드 변경)
   - 총 프로젝트 기간: 3주

2. **관리 가능한 리스크**
   - 기술적 리스크: 대부분 중간 수준
   - 완화 전략 수립 완료
   - 롤백 계획 준비됨

3. **높은 ROI 기대**
   - 코드 중복 제거
   - API 일관성 향상
   - 유지보수성 개선

### 9.2 권장 사항

#### 단기 (즉시 실행)

1. **Phase 1 완료**: 마이그레이션 계획 수립 (Task 11.5)
2. **테스트 커버리지 측정**: 현재 상태 파악
3. **팀 리뷰**: 이 영향도 분석 보고서 검토

#### 중기 (1-2주 내)

1. **Phase 2 시작**: 통합 API 설계 및 구현
2. **CI/CD 파이프라인 강화**: 회귀 테스트 자동화
3. **마이그레이션 도구 개발**: import/메서드명 자동 변경

#### 장기 (1-2개월 내)

1. **v2.0.0 릴리스**: Breaking change 포함
2. **마이그레이션 가이드 배포**: 외부 사용자 지원
3. **커뮤니티 피드백 수렴**: 개선 사항 반영

### 9.3 최종 의견

**통합 실행 권장**: 이 리팩토링은 **즉시 실행할 가치**가 있습니다.

**근거**:
- ✅ 명확한 개선 목표 (코드 중복 제거, API 일관성)
- ✅ 관리 가능한 범위 (13개 파일, 4시간 작업)
- ✅ 충분한 리스크 완화 전략
- ✅ 하위 호환성 유지 가능 (@Deprecated)
- ✅ 높은 ROI (3주 투자 → 장기적 유지보수성 향상)

**다음 단계**: Task 11.5 (통합 유틸리티 마이그레이션 계획 수립) 시작
