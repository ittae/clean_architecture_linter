# Clean Architecture Linter - Refactoring Plan

## 🔍 중복 코드 분석 결과

### 발견된 중복 패턴

#### 1. **파일 경로 체크 메서드** (6개 중복)
- `_isPresentationFile()` - 2개 파일에서 중복
- `_isDomainFile()` - 1개 파일
- `_isDataSourceFile()` - 1개 파일
- `_isUseCaseFile()` - 1개 파일
- `_isDataModelFile()` - 1개 파일
- `_isDependencyInjectionFile()` - 2개 파일에서 중복

**영향받는 파일**:
- `presentation_use_async_value_rule.dart`
- `presentation_no_data_exceptions_rule.dart`
- `exception_naming_convention_rule.dart`
- `datasource_exception_types_rule.dart`
- `usecase_must_convert_failure_rule.dart`

#### 2. **클래스 이름 체크 메서드** (10개 중복)
- `_isDataSourceClass()` - 2개 파일에서 중복
- `_isRepositoryImplClass()` - 2개 파일에서 중복
- `_isUseCaseClass()` - 2개 파일에서 다른 시그니처로 중복

**영향받는 파일**:
- `datasource_abstraction_rule.dart`
- `datasource_exception_types_rule.dart`
- `repository_must_return_result_rule.dart`
- `repository_no_throw_rule.dart`
- `usecase_no_result_return_rule.dart`
- `usecase_must_convert_failure_rule.dart`

#### 3. **타입 체크 메서드** (3개 완전 중복)
- `_isResultType()` - **3개 파일에서 동일한 코드**

**영향받는 파일**:
- `datasource_no_result_return_rule.dart`
- `repository_must_return_result_rule.dart`
- `usecase_no_result_return_rule.dart`

#### 4. **Feature 이름 추출 로직** (2개 중복)
- `_suggestFeatureName()` / `_suggestDomainException()` - 유사한 로직

**영향받는 파일**:
- `exception_naming_convention_rule.dart`
- `presentation_no_data_exceptions_rule.dart`

---

## ✅ 해결 방안

### 1단계: 공통 유틸리티 파일 생성 ✅

`lib/src/utils/rule_utils.dart` 파일 생성 완료:

**제공하는 기능**:
- ✅ 파일 경로 체크: `isPresentationFile()`, `isDomainFile()`, `isDataFile()` 등
- ✅ 클래스 이름 체크: `isUseCaseClass()`, `isDataSourceClass()` 등
- ✅ 타입 체크: `isResultType()`, `isVoidType()`, `implementsException()`
- ✅ Exception 패턴: `dataExceptions` 상수, `isDataException()`, `isDomainException()`
- ✅ Feature 추출: `extractFeatureName()`
- ✅ AST 유틸: `findParentClass()`, `isPrivateMethod()`, `isRethrow()`

### 2단계: 기존 규칙 파일 리팩토링

각 규칙 파일에서 중복 메서드를 `RuleUtils` 사용으로 교체:

#### 우선순위 높음 (High Priority)
1. **Result 타입 체크 중복 제거** (3개 파일)
   - [ ] `datasource_no_result_return_rule.dart`
   - [ ] `repository_must_return_result_rule.dart`
   - [ ] `usecase_no_result_return_rule.dart`

2. **파일 경로 체크 중복 제거** (5개 파일)
   - [ ] `presentation_use_async_value_rule.dart`
   - [ ] `presentation_no_data_exceptions_rule.dart`
   - [ ] `exception_naming_convention_rule.dart`
   - [ ] `datasource_exception_types_rule.dart`
   - [ ] `usecase_must_convert_failure_rule.dart`

#### 우선순위 중간 (Medium Priority)
3. **클래스 이름 체크 중복 제거** (6개 파일)
   - [ ] `datasource_abstraction_rule.dart`
   - [ ] `datasource_exception_types_rule.dart`
   - [ ] `repository_must_return_result_rule.dart`
   - [ ] `repository_no_throw_rule.dart`
   - [ ] `usecase_no_result_return_rule.dart`
   - [ ] `usecase_must_convert_failure_rule.dart`

#### 우선순위 낮음 (Low Priority)
4. **Feature 이름 추출 로직 통합** (2개 파일)
   - [ ] `exception_naming_convention_rule.dart`
   - [ ] `presentation_no_data_exceptions_rule.dart`

---

## 📊 개선 효과

### 코드 감소 예상치
- **제거될 중복 코드**: ~500-700 라인
- **유지보수 포인트 감소**: 21개 메서드 → 1개 파일
- **일관성 향상**: 모든 규칙이 동일한 로직 사용

### 유지보수 개선
- ✅ **단일 진실 공급원**: 로직 변경 시 1곳만 수정
- ✅ **테스트 용이성**: 유틸리티 함수 단위 테스트 가능
- ✅ **버그 수정 간편**: 한 번 수정으로 모든 규칙에 적용
- ✅ **새 규칙 추가 용이**: 재사용 가능한 빌딩 블록 제공

### 성능
- 변화 없음 (정적 메서드 호출로 오버헤드 최소)

---

## 🚀 실행 계획

### Phase 1: 유틸리티 준비 ✅
- [x] `rule_utils.dart` 생성
- [x] 공통 메서드 구현
- [x] 문서화

### Phase 2: 핵심 규칙 리팩토링 (1-2시간)
- [ ] Result 타입 체크 3개 파일 리팩토링
- [ ] 파일 경로 체크 5개 파일 리팩토링
- [ ] 테스트 실행 및 검증

### Phase 3: 나머지 규칙 리팩토링 (2-3시간)
- [ ] 클래스 이름 체크 6개 파일 리팩토링
- [ ] Feature 추출 로직 2개 파일 리팩토링
- [ ] 전체 테스트 실행

### Phase 4: 검증 및 정리
- [ ] 모든 규칙 테스트 통과 확인
- [ ] Example 프로젝트 lint 실행
- [ ] 성능 비교 (before/after)
- [ ] 문서 업데이트

---

## 📝 리팩토링 체크리스트

### 각 파일 리팩토링 시
- [ ] Import `RuleUtils` 추가
- [ ] Private 메서드를 `RuleUtils` 호출로 교체
- [ ] 사용하지 않는 import 제거
- [ ] 로직 변경 없이 동작 확인
- [ ] 해당 규칙의 bad/good example 테스트

### 완료 조건
- [ ] 모든 24개 규칙 파일이 `RuleUtils` 사용
- [ ] 중복 메서드 0개
- [ ] 모든 테스트 통과
- [ ] Example 프로젝트에서 동일한 lint 결과

---

## 🎯 추가 개선 기회

### 1. Exception 상수 통합
현재 여러 파일에 흩어진 Exception 목록을 `RuleUtils`로 통합:
```dart
static const dataExceptions = {...};
static const allowedExceptions = {...};
static const errorFieldNames = {...};
```

### 2. Error Message 템플릿화
반복되는 에러 메시지 패턴을 템플릿으로:
```dart
static String buildFeaturePrefixMessage(String className, String suggested) {
  return 'Add feature prefix:\n'
         '  ❌ Bad:  class $className\n'
         '  ✅ Good: class $suggested';
}
```

### 3. 규칙 베이스 클래스 강화
`CleanArchitectureLintRule`에 더 많은 유틸리티 메서드 추가:
- `checkFileLayer()` - 파일 레이어 검증
- `validateClassNaming()` - 클래스 명명 규칙 검증
- `extractContext()` - 컨텍스트 정보 추출

---

## 📈 측정 가능한 목표

- **코드 중복률**: 현재 ~15-20% → 목표 <5%
- **유지보수 포인트**: 현재 21개 → 목표 5개
- **신규 규칙 추가 시간**: 현재 30분 → 목표 10분
- **버그 수정 파급 범위**: 현재 평균 3개 파일 → 목표 1개 파일

---

## ⚠️ 주의사항

### Breaking Changes 없음
- Public API 변경 없음
- 모든 규칙은 기존과 동일하게 동작
- Backward compatibility 100% 유지

### 테스트 필수
- 각 리팩토링 후 해당 규칙 테스트
- Phase 완료 시 전체 테스트
- Example 프로젝트 검증 필수

### 점진적 적용
- 한 번에 1-2개 파일만 리팩토링
- 즉시 테스트 및 검증
- 문제 발생 시 즉시 롤백 가능

---

## 🔄 다음 단계

1. **즉시 시작 가능**: Phase 2 핵심 규칙 리팩토링
2. **빠른 효과**: Result 타입 체크 3개 파일부터 시작
3. **점진적 개선**: 매일 2-3개 파일씩 리팩토링
4. **주간 목표**: 1주일 내 모든 리팩토링 완료

---

*Last Updated: 2024-10-05*
*Status: ✅ Utils Created, Ready for Refactoring*
