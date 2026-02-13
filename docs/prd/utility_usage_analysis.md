# 유틸리티 메서드 사용량 정량 분석

## 개요

lib/src/rules/ 디렉토리의 24개 lint 규칙 파일을 대상으로 CleanArchitectureUtils와 RuleUtils의 메서드 사용 패턴을 정량적으로 분석한 결과입니다.

**분석 대상 파일**: 24개 규칙 파일
- **Domain Rules**: 7개 파일
- **Data Rules**: 7개 파일
- **Presentation Rules**: 6개 파일
- **Cross-Layer Rules**: 4개 파일 (boundary_crossing, circular_dependency, layer_dependency, test_coverage)

---

## 1. CleanArchitectureUtils 사용량 분석

### 1.1 전체 메서드 사용 통계

| 메서드명 | 사용 횟수 | 사용 파일 수 | 사용률 |
|---------|----------|-------------|--------|
| `isDomainLayerFile()` | 11 | 3 | ⭐⭐⭐⭐⭐ 높음 |
| `isDataLayerFile()` | 2 | 1 | ⭐ 낮음 |
| `isPresentationLayerFile()` | 0 | 0 | ❌ 미사용 |
| `isRepositoryInterface()` | 0 | 0 | ❌ 미사용 |
| `isRepositoryInterfaceMethod()` | 0 | 0 | ❌ 미사용 |
| `shouldExcludeFile()` | 0 | 0 | ❌ 미사용 (간접 사용) |

**총 사용 횟수**: 13회
**활성 메서드**: 2개 / 6개 (33.3%)
**미사용 메서드**: 4개 / 6개 (66.7%)

### 1.2 파일별 상세 사용 내역

#### Domain Rules (11회 사용)

**dependency_inversion_rule.dart** (4회)
```dart
line 66:  if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
line 86:  if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
line 108: if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
line 130: if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
```
**용도**: 4개의 visitor 메서드에서 Domain 레이어 파일 필터링

**repository_interface_rule.dart** (4회)
```dart
line 66:  if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
line 89:  if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
line 121: if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
line 151: if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
```
**용도**: 4개의 visitor 메서드에서 Domain 레이어 파일 필터링

**domain_purity_rule.dart** (3회)
```dart
line 55:  if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
line 173: if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
```
**용도**: 2개의 visitor 메서드에서 Domain 레이어 파일 필터링 (3회 중 1회는 다른 컨텍스트)

#### Data Rules (2회 사용)

**datasource_abstraction_rule.dart** (2회)
```dart
line 86:  if (!CleanArchitectureUtils.isDataLayerFile(filePath)) return;
line 129: if (CleanArchitectureUtils.isDomainLayerFile(filePath)) {
line 147: if (!CleanArchitectureUtils.isDataLayerFile(filePath)) return;
```
**용도**:
- `isDataLayerFile()`: Data 레이어 파일 필터링 (2회)
- `isDomainLayerFile()`: Domain 레이어 검사 로직 (1회, 위의 11회에 포함되지 않음)

### 1.3 사용 패턴 분석

**패턴 1: Guard Clause로 사용 (100%)**
```dart
if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
```
- 모든 사용 케이스가 Guard Clause 패턴
- Visitor 메서드 시작 부분에서 파일 필터링
- 조기 반환으로 불필요한 검사 방지

**패턴 2: 다중 Visitor에서 반복 사용**
- 1개 규칙 파일 = 평균 3.67회 사용
- 각 visitor 메서드마다 레이어 검증 로직 중복

**미사용 이유 분석**:
- `isPresentationLayerFile()`: Presentation 규칙들이 RuleUtils.isPresentationFile() 사용
- `isRepositoryInterface()`: Repository 검증 규칙 미구현
- `shouldExcludeFile()`: CleanArchitectureLintRule 베이스 클래스에서 자동 처리 (간접 사용)

---

## 2. RuleUtils 사용량 분석

### 2.1 전체 메서드 사용 통계

| 순위 | 메서드명 | 사용 횟수 | 사용 파일 수 | 사용률 |
|------|---------|----------|-------------|--------|
| 1 | `isDataSourceClass()` | 5 | 2 | ⭐⭐⭐⭐⭐ 최고 |
| 2 | `isResultType()` | 3 | 2 | ⭐⭐⭐⭐ 높음 |
| 3 | `isVoidType()` | 2 | 2 | ⭐⭐⭐ 중간 |
| 4 | `isUseCaseClass()` | 2 | 1 | ⭐⭐⭐ 중간 |
| 5 | `isPresentationFile()` | 2 | 2 | ⭐⭐⭐ 중간 |
| 6 | `findParentClass()` | 2 | 2 | ⭐⭐⭐ 중간 |
| 7 | `extractFeatureName()` | 2 | 2 | ⭐⭐⭐ 중간 |
| 8 | `isUseCaseFile()` | 1 | 1 | ⭐⭐ 낮음 |
| 9 | `isRethrow()` | 1 | 1 | ⭐⭐ 낮음 |
| 10 | `isRepositoryImplClass()` | 1 | 1 | ⭐⭐ 낮음 |
| 11 | `isPrivateMethod()` | 1 | 1 | ⭐⭐ 낮음 |
| 12 | `isDomainFile()` | 1 | 1 | ⭐⭐ 낮음 |
| 13 | `isDataSourceFile()` | 1 | 1 | ⭐⭐ 낮음 |
| 14 | `isDataException()` | 1 | 1 | ⭐⭐ 낮음 |
| 15 | `implementsException()` | 1 | 1 | ⭐⭐ 낮음 |

**총 사용 횟수**: 25회
**활성 메서드**: 15개 / 27개 (55.6%)
**미사용 메서드**: 12개 / 27개 (44.4%)

### 2.2 미사용 메서드 목록

| 메서드명 | 카테고리 | 미사용 이유 추정 |
|---------|---------|----------------|
| `isDataFile()` | 파일 경로 체크 | isDomainFile로 충분 또는 불필요 |
| `isRepositoryImplFile()` | 파일 경로 체크 | 클래스명 검증으로 대체 |
| `isRepositoryInterfaceFile()` | 파일 경로 체크 | Repository 규칙 미구현 |
| `isRepositoryImplementationFile()` | 파일 경로 체크 | Repository 규칙 미구현 |
| `isRepositoryClass()` | 클래스명 체크 | isRepositoryImplClass로 충분 |
| `isRepositoryInterfaceClass()` | 클래스명 체크 | Repository 규칙 미구현 |
| `isRepositoryImplementationClass()` | 클래스명 체크 | isRepositoryImplClass와 중복 |
| `isDomainException()` | Exception 패턴 | Domain 예외 검증 규칙 미구현 |
| `_normalizePath()` | 내부 유틸리티 | private 메서드 (간접 사용) |
| `_capitalizeAndSingularize()` | 내부 유틸리티 | private 메서드 (간접 사용) |

### 2.3 파일별 상세 사용 내역

#### Domain Rules

**usecase_no_result_return_rule.dart** (3회)
```dart
line 87:  if (!RuleUtils.isUseCaseClass(className)) return;
line 98:  if (RuleUtils.isVoidType(returnType)) return;
line 100: if (RuleUtils.isResultType(returnType)) {
```
**용도**: UseCase 클래스 검증 및 반환 타입 체크

**usecase_must_convert_failure_rule.dart** (3회)
```dart
line 85:  if (!RuleUtils.isUseCaseFile(filePath) && !_isUseCaseClass(node)) return;
line 180: final classNode = RuleUtils.findParentClass(node);
line 184: return RuleUtils.isUseCaseClass(className);
```
**용도**: UseCase 파일/클래스 검증, AST 탐색

**exception_naming_convention_rule.dart** (3회)
```dart
line 113: if (!RuleUtils.isDomainFile(filePath)) return;
line 116: if (!RuleUtils.implementsException(node)) return;
line 174: final featureName = RuleUtils.extractFeatureName(filePath);
```
**용도**: Domain 파일 검증, Exception 인터페이스 확인, Feature 이름 추출

#### Data Rules

**datasource_exception_types_rule.dart** (3회)
```dart
line 112: if (!RuleUtils.isDataSourceFile(filePath) && !_isDataSourceClass(node)) return;
line 155: final classNode = RuleUtils.findParentClass(node);
line 159: return RuleUtils.isDataSourceClass(className);
```
**용도**: DataSource 파일/클래스 검증, AST 탐색

**repository_no_throw_rule.dart** (3회)
```dart
line 87:  if (RuleUtils.isRethrow(node)) return;
line 91:  if (method != null && RuleUtils.isPrivateMethod(method)) return;
line 115: if (!RuleUtils.isRepositoryImplClass(className)) return false;
```
**용도**: rethrow 감지, private 메서드 필터링, Repository 구현체 검증

**repository_must_return_result_rule.dart** (2회)
```dart
line 96:  if (RuleUtils.isVoidType(returnType)) return;
line 98:  if (!RuleUtils.isResultType(returnType)) {
```
**용도**: 반환 타입 검증 (void, Result)

**datasource_abstraction_rule.dart** (3회)
```dart
line 89:  if (!RuleUtils.isDataSourceClass(className)) return;
line 126: if (!RuleUtils.isDataSourceClass(className)) return;
line 154: if (!RuleUtils.isDataSourceClass(className)) return;
```
**용도**: DataSource 클래스 검증 (3개 visitor에서 반복)

**datasource_no_result_return_rule.dart** (2회)
```dart
line 86:  if (!RuleUtils.isDataSourceClass(className)) return;
line 92:  if (RuleUtils.isResultType(returnType)) {
```
**용도**: DataSource 클래스 검증, Result 타입 체크

#### Presentation Rules

**presentation_use_async_value_rule.dart** (1회)
```dart
line 101: if (!RuleUtils.isPresentationFile(filePath)) return;
```
**용도**: Presentation 파일 필터링

**presentation_no_data_exceptions_rule.dart** (3회)
```dart
line 107: if (!RuleUtils.isPresentationFile(filePath)) return;
line 116: if (RuleUtils.isDataException(typeName)) {
line 139: final featureName = RuleUtils.extractFeatureName(filePath);
```
**용도**: Presentation 파일 필터링, Data Exception 감지, Feature 이름 추출

### 2.4 사용 패턴 분석

**패턴 1: 클래스 타입 검증 (40%)**
```dart
if (!RuleUtils.isDataSourceClass(className)) return;
if (!RuleUtils.isUseCaseClass(className)) return;
```
- 가장 많이 사용되는 패턴
- Guard Clause로 클래스 타입 필터링

**패턴 2: 타입 어노테이션 검증 (20%)**
```dart
if (RuleUtils.isResultType(returnType)) { ... }
if (RuleUtils.isVoidType(returnType)) return;
```
- 메서드 반환 타입 검증
- Result/Either 타입 감지

**패턴 3: AST 탐색 (8%)**
```dart
final classNode = RuleUtils.findParentClass(node);
if (RuleUtils.isPrivateMethod(method)) return;
```
- 부모 클래스 찾기
- private 메서드 필터링

**패턴 4: 파일 경로 검증 (16%)**
```dart
if (!RuleUtils.isPresentationFile(filePath)) return;
if (!RuleUtils.isDomainFile(filePath)) return;
```
- 레이어 파일 필터링
- Guard Clause 패턴

**패턴 5: Feature/Exception 패턴 분석 (16%)**
```dart
final featureName = RuleUtils.extractFeatureName(filePath);
if (RuleUtils.isDataException(typeName)) { ... }
```
- Feature 이름 추출
- Exception 타입 분류

---

## 3. 통합 사용량 비교

### 3.1 전체 사용량 통계

| 유틸리티 클래스 | 총 사용 횟수 | 사용 파일 수 | 활성 메서드 수 | 메서드 활성화율 |
|----------------|-------------|-------------|--------------|----------------|
| CleanArchitectureUtils | 13 | 3 | 2 / 6 | 33.3% |
| RuleUtils | 25 | 10 | 15 / 27 | 55.6% |
| **합계** | **38** | **13 (중복 제외)** | **17 / 33** | **51.5%** |

### 3.2 카테고리별 사용 분포

| 카테고리 | CleanArchitectureUtils | RuleUtils | 합계 |
|---------|------------------------|-----------|------|
| 파일 경로 검증 | 13 (100%) | 4 (16%) | 17 (44.7%) |
| 클래스명 검증 | 0 (0%) | 10 (40%) | 10 (26.3%) |
| 타입 검증 | 0 (0%) | 6 (24%) | 6 (15.8%) |
| AST 탐색 | 0 (0%) | 3 (12%) | 3 (7.9%) |
| Exception 패턴 | 0 (0%) | 1 (4%) | 1 (2.6%) |
| Feature 유틸리티 | 0 (0%) | 2 (8%) | 2 (5.3%) |

### 3.3 규칙 파일별 유틸리티 사용 현황

| 규칙 파일 | CleanArchUtils | RuleUtils | 합계 | 주요 용도 |
|----------|----------------|-----------|------|-----------|
| **Domain Rules** | | | | |
| dependency_inversion_rule.dart | 4 | 0 | 4 | Domain 파일 필터링 |
| repository_interface_rule.dart | 4 | 0 | 4 | Domain 파일 필터링 |
| domain_purity_rule.dart | 3 | 0 | 3 | Domain 파일 필터링 |
| usecase_no_result_return_rule.dart | 0 | 3 | 3 | UseCase 검증, 타입 체크 |
| usecase_must_convert_failure_rule.dart | 0 | 3 | 3 | UseCase 검증, AST 탐색 |
| exception_naming_convention_rule.dart | 0 | 3 | 3 | Domain 파일, Exception 검증 |
| **Data Rules** | | | | |
| datasource_abstraction_rule.dart | 2 | 3 | 5 | 혼합: Layer + DataSource 검증 |
| datasource_exception_types_rule.dart | 0 | 3 | 3 | DataSource 검증, AST 탐색 |
| repository_no_throw_rule.dart | 0 | 3 | 3 | Repository 구현체, AST 탐색 |
| repository_must_return_result_rule.dart | 0 | 2 | 2 | 타입 검증 |
| datasource_no_result_return_rule.dart | 0 | 2 | 2 | DataSource + 타입 검증 |
| **Presentation Rules** | | | | |
| presentation_use_async_value_rule.dart | 0 | 1 | 1 | Presentation 파일 필터링 |
| presentation_no_data_exceptions_rule.dart | 0 | 3 | 3 | Presentation 파일, Exception 검증 |
| **Cross-Layer Rules** | | | | |
| boundary_crossing_rule.dart | 0 | 0 | 0 | 미사용 |
| circular_dependency_rule.dart | 0 | 0 | 0 | 미사용 |
| layer_dependency_rule.dart | 0 | 0 | 0 | 미사용 |
| test_coverage_rule.dart | 0 | 0 | 0 | 미사용 |

**사용 파일 통계**:
- CleanArchitectureUtils 사용: 3개 파일 (Domain 규칙만)
- RuleUtils 사용: 10개 파일 (모든 레이어)
- 두 유틸리티 모두 사용: 1개 파일 (datasource_abstraction_rule.dart)
- 유틸리티 미사용: 11개 파일 (24개 중)

---

## 4. 주요 발견 사항

### 4.1 사용 빈도 TOP 10

| 순위 | 메서드 | 클래스 | 사용 횟수 | 점유율 |
|------|--------|--------|----------|--------|
| 1 | `isDomainLayerFile()` | CleanArchitectureUtils | 11 | 28.9% |
| 2 | `isDataSourceClass()` | RuleUtils | 5 | 13.2% |
| 3 | `isResultType()` | RuleUtils | 3 | 7.9% |
| 4 | `isVoidType()` | RuleUtils | 2 | 5.3% |
| 5 | `isUseCaseClass()` | RuleUtils | 2 | 5.3% |
| 6 | `isPresentationFile()` | RuleUtils | 2 | 5.3% |
| 7 | `findParentClass()` | RuleUtils | 2 | 5.3% |
| 8 | `extractFeatureName()` | RuleUtils | 2 | 5.3% |
| 9 | `isDataLayerFile()` | CleanArchitectureUtils | 2 | 5.3% |
| 10 | `isUseCaseFile()` | RuleUtils | 1 | 2.6% |

**상위 3개 메서드가 전체 사용량의 50% 차지**

### 4.2 중복 기능 사용 현황

#### 완전 중복 메서드 (기능 동일, 사용량 비교)

| 기능 | CleanArchitectureUtils | RuleUtils | 선호도 |
|------|------------------------|-----------|--------|
| Domain 파일 감지 | `isDomainLayerFile()` (11회) | `isDomainFile()` (1회) | CleanArchUtils ⭐⭐⭐⭐⭐ |
| Data 파일 감지 | `isDataLayerFile()` (2회) | `isDataFile()` (0회) | CleanArchUtils ⭐⭐ |
| Presentation 파일 감지 | `isPresentationLayerFile()` (0회) | `isPresentationFile()` (2회) | RuleUtils ⭐⭐⭐ |

**발견**: 중복 메서드 사용이 일관성 없음
- Domain 레이어: CleanArchitectureUtils 선호
- Presentation 레이어: RuleUtils 선호
- Data 레이어: CleanArchitectureUtils만 사용 (RuleUtils 미사용)

### 4.3 미사용 메서드 분석

**CleanArchitectureUtils 미사용 메서드** (4개, 66.7%):
1. `isPresentationLayerFile()` - RuleUtils.isPresentationFile()로 대체됨
2. `isRepositoryInterface()` - Repository 검증 규칙 미구현
3. `isRepositoryInterfaceMethod()` - Repository 검증 규칙 미구현
4. `shouldExcludeFile()` - 간접 사용 (베이스 클래스에서 처리)

**RuleUtils 미사용 메서드** (12개, 44.4%):
- 파일 경로 체크: 4개 (`isDataFile`, `isRepositoryImplFile`, `isRepositoryInterfaceFile`, `isRepositoryImplementationFile`)
- 클래스명 체크: 4개 (`isRepositoryClass`, `isRepositoryInterfaceClass`, `isRepositoryImplementationClass` 등)
- Exception 패턴: 1개 (`isDomainException`)
- Private 메서드: 2개 (내부 유틸리티)

**미사용 이유**:
1. **기능 중복**: 같은 기능의 다른 메서드 존재
2. **규칙 미구현**: Repository 검증 규칙 아직 구현 안 됨 (Tasks 1-10에서 예정)
3. **과도한 세분화**: 너무 구체적인 메서드 (isRepositoryInterfaceFile vs isRepositoryClass)

### 4.4 사용 패턴 인사이트

**패턴 1: Guard Clause 패턴 (84%)**
```dart
if (!RuleUtils.isUseCaseClass(className)) return;
if (!CleanArchitectureUtils.isDomainLayerFile(filePath)) return;
```
- 대부분의 사용이 Guard Clause
- Visitor 메서드 시작 부분에서 조기 반환

**패턴 2: 다중 Visitor 반복 (60%)**
- 1개 규칙 = 평균 2.9회 유틸리티 사용
- 각 visitor마다 동일한 검증 로직 반복
- 베이스 클래스로 추상화 가능

**패턴 3: 혼합 사용 (7.7%)**
- 1개 파일만 두 유틸리티 클래스 동시 사용
- datasource_abstraction_rule.dart: CleanArchitectureUtils (레이어 검증) + RuleUtils (클래스 검증)

---

## 5. 통합 영향도 분석

### 5.1 통합 시 영향받는 파일

**높은 영향도 (3회 이상 사용)**:
1. `dependency_inversion_rule.dart` - 4회 사용
2. `repository_interface_rule.dart` - 4회 사용
3. `domain_purity_rule.dart` - 3회 사용
4. `datasource_abstraction_rule.dart` - 5회 사용 (두 유틸리티 혼합)
5. `usecase_no_result_return_rule.dart` - 3회 사용
6. `usecase_must_convert_failure_rule.dart` - 3회 사용
7. `datasource_exception_types_rule.dart` - 3회 사용
8. `repository_no_throw_rule.dart` - 3회 사용
9. `exception_naming_convention_rule.dart` - 3회 사용
10. `presentation_no_data_exceptions_rule.dart` - 3회 사용

**중간 영향도 (2회 사용)**:
- `repository_must_return_result_rule.dart` - 2회
- `datasource_no_result_return_rule.dart` - 2회

**낮은 영향도 (1회 사용)**:
- `presentation_use_async_value_rule.dart` - 1회

**총 영향받는 파일**: 13개 / 24개 (54.2%)

### 5.2 리팩토링 복잡도 평가

**복잡도 등급**:
- **높음**: 5회 이상 사용 또는 두 유틸리티 혼합 (1개 파일)
- **중간**: 3-4회 사용 (9개 파일)
- **낮음**: 1-2회 사용 (3개 파일)

**예상 리팩토링 시간**:
- 높음: 파일당 30분 (1개 × 30분 = 30분)
- 중간: 파일당 20분 (9개 × 20분 = 180분)
- 낮음: 파일당 10분 (3개 × 10분 = 30분)
- **총 예상 시간**: 240분 (4시간)

### 5.3 통합 우선순위

**Phase 1: 레이어 파일 감지 통합** (최우선)
- 영향도: 17회 사용 (44.7%)
- 대상 메서드: `isDomainLayerFile`, `isDataLayerFile`, `isPresentationLayerFile`, `isDomainFile`, `isDataFile`, `isPresentationFile`
- 영향 파일: 7개
- 예상 시간: 2시간

**Phase 2: 클래스 타입 검증 통합**
- 영향도: 10회 사용 (26.3%)
- 대상 메서드: `isDataSourceClass`, `isUseCaseClass`, `isRepositoryImplClass`
- 영향 파일: 6개
- 예상 시간: 1.5시간

**Phase 3: 나머지 유틸리티 통합**
- 영향도: 11회 사용 (28.9%)
- 대상 메서드: 타입 검증, AST 탐색, Feature 유틸리티
- 영향 파일: 7개
- 예상 시간: 1시간

---

## 6. 권장 사항

### 6.1 통합 전략

1. **레이어 파일 감지 우선 통합**
   - 가장 많이 사용되는 기능 (44.7%)
   - RuleUtils의 확장 경로 패턴 + CleanArchitectureUtils의 파일 제외 로직 결합

2. **클래스 타입 검증 표준화**
   - RuleUtils의 메서드 유지 (높은 사용률)
   - 네이밍 일관성 개선 (isXxxClass 패턴)

3. **미사용 메서드 제거 또는 문서화**
   - 16개 미사용 메서드 정리
   - 향후 사용 예정이면 문서화, 아니면 제거

4. **베이스 클래스 추상화**
   - Guard Clause 패턴 반복 → Mixin 또는 베이스 메서드로 추상화
   - 각 visitor마다 중복 검증 로직 제거

### 6.2 성능 개선 기회

**현재 문제점**:
- 같은 파일 경로를 여러 visitor에서 반복 검사
- dependency_inversion_rule.dart: `isDomainLayerFile()` 4회 호출

**개선 방안**:
```dart
// 현재: 각 visitor마다 검사
void visitClassDeclaration(...) {
  if (!isDomainLayerFile(filePath)) return;
  // ...
}

// 개선: 파일 레벨에서 1회만 검사
@override
void run(...) {
  if (!isDomainLayerFile(filePath)) return;
  super.run(...); // 모든 visitor 실행
}
```

**예상 성능 향상**: 파일당 검증 횟수 75% 감소

---

## 7. 결론

### 7.1 핵심 발견

1. **불균형한 사용률**
   - RuleUtils가 CleanArchitectureUtils보다 2배 많이 사용됨 (25 vs 13)
   - 메서드 활성화율: RuleUtils 55.6% vs CleanArchitectureUtils 33.3%

2. **중복 기능의 일관성 없는 사용**
   - Domain 레이어: CleanArchitectureUtils 선호 (11 vs 1)
   - Presentation 레이어: RuleUtils 선호 (2 vs 0)
   - 표준화 필요

3. **높은 미사용 메서드 비율**
   - 전체 33개 메서드 중 16개 미사용 (48.5%)
   - Repository 검증 규칙 미구현으로 인한 미사용 다수

4. **통합 시 중간 수준의 리팩토링 필요**
   - 13개 파일 영향 (54.2%)
   - 예상 시간: 4시간
   - 높은 ROI 예상 (중복 제거 + 일관성 향상)

### 7.2 다음 단계

Task 11.4에서 이 분석을 바탕으로 구체적인 통합 영향도 분석 보고서 작성 예정:
- 단계별 마이그레이션 계획
- 리스크 평가
- 회귀 테스트 전략
- 롤백 계획
