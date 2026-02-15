# Clean Architecture Linter 지원성 분석 (Clean Architecture + i18n + Riverpod 3.0)

> 대상: `/Volumes/T7 Shield/dev/clean_architecture_linter`  
> 분석 기준: 코드/규칙 구현 근거 + 실제 Flutter 적용 관점(예: flutter_boilerplate 류)

---

## 요약(한눈에)

- **종합 평가**: **Clean Architecture 특화도 높음**, **Riverpod 중심 규칙 강함**, **i18n 지원은 사실상 부재**
- **강점**
  - 레이어 의존/경계/순환 참조 등 아키텍처 핵심 규칙이 촘촘함
  - Data/Presentation에서 실무 패턴(UseCase 직접 호출 금지, ref.read/watch, keepAlive 점검 등)까지 커버
  - 테스트 커버리지 규칙(옵션) 제공
- **한계**
  - 규칙 상당수가 **경로/파일명/네이밍 휴리스틱** 의존 → 구조가 다르면 FP/FN 증가
  - i18n(하드코딩 문자열, 번역키 검증, l10n 사용 강제) 관련 룰 없음
  - Riverpod 3.0 “완전 호환”이라기보다 Riverpod Generator 중심 특정 아키텍처 강제
- **적합도(주관 점수)**
  - Clean Architecture: **8/10**
  - i18n: **1/10**
  - Riverpod 3.0: **7/10** (Generator 중심 팀에는 높음, 다양한 Riverpod 스타일 팀에는 제약)

---

## 1) 현재 규칙 목록과 커버 범위

근거: `lib/clean_architecture_linter.dart` (룰 등록 목록)

### A. Domain (5)
- `domain_purity` (`lib/src/rules/domain_rules/domain_purity_rule.dart`)
- `dependency_inversion` (`.../dependency_inversion_rule.dart`)
- `repository_interface` (`.../repository_interface_rule.dart`)
- `usecase_no_result_return` (`.../usecase_no_result_return_rule.dart`)
- `exception_naming_convention` (`.../exception_naming_convention_rule.dart`)

### B. Data (11)
- `model_structure`
- `model_field_duplication`
- `model_conversion_methods`
- `model_naming_convention`
- `datasource_abstraction`
- `datasource_no_result_return`
- `repository_implementation`
- `repository_pass_through`
- `repository_no_throw`
- `datasource_exception_types`
- `model_entity_direct_access`

(모두 `lib/src/rules/data_rules/*.dart`)

### C. Presentation (13)
- `no_presentation_models`
- `extension_location`
- `freezed_usage`
- `riverpod_generator`
- `presentation_no_data_exceptions`
- `presentation_use_async_value`
- `presentation_no_throw`
- `widget_no_usecase_call`
- `widget_ref_read_then_when`
- `riverpod_ref_usage`
- `riverpod_provider_naming`
- `ref_mounted_usage`
- `riverpod_keep_alive`

(모두 `lib/src/rules/presentation_rules/*.dart`)

### D. Cross-layer (4 + 1 optional)
- `layer_dependency`
- `circular_dependency`
- `boundary_crossing`
- `allowed_instance_variables`
- (옵션) `clean_architecture_linter_require_test`

(모두 `lib/src/rules/cross_layer/*.dart`)

### E. 범위 총평
- **레이어/의존성/예외흐름/상태관리 가드** 중심으로 매우 강함
- 반면, **UI 텍스트 품질(i18n), 접근성(a11y), 디자인 시스템 규칙**은 미포함

---

## 2) Clean Architecture 지원 수준 (강점/누락)

### 강점
1. **의존성 방향 강제**
   - `layer_dependency_rule.dart`, `boundary_crossing_rule.dart`
2. **Domain 순수성/추상화 강제**
   - `domain_purity_rule.dart`, `dependency_inversion_rule.dart`
3. **Repository/DataSource 경계 명확화**
   - `repository_interface_rule.dart`, `repository_implementation_rule.dart`, `datasource_abstraction_rule.dart`
4. **에러 처리 전략 일관성**
   - DataSource throw / Repository pass-through / Presentation AsyncValue 패턴 유도
   - `datasource_no_result_return_rule.dart`, `repository_no_throw_rule.dart`, `presentation_use_async_value_rule.dart`

### 누락/제약
1. **구조 인식이 경로 문자열 기반**
   - 레이어 판별이 `/domain/`, `/data/`, `/presentation/` 패턴 중심
   - 근거: `lib/src/clean_architecture_linter_base.dart` (`isDomainFile`, `isDataFile`, `isPresentationFile`)
2. **고정 아키텍처 가정 강함**
   - Result/Either 기반 도메인 설계를 의도적으로 배제하는 룰 존재
   - 근거: `usecase_no_result_return_rule.dart`, `repository_pass_through_rule.dart`
3. **DI 파일 예외 처리 휴리스틱**
   - `main.dart`, `di.dart`, `providers.dart` 등 파일명 기반 예외
   - 근거: `layer_dependency_rule.dart`, `boundary_crossing_rule.dart`

---

## 3) i18n(다국어) 규칙 지원 여부

### 결론
- **현재 i18n 전용 규칙은 없음**.
- 코드베이스에서 `intl`, `l10n`, `AppLocalizations` 관련 룰 구현/검사 로직이 확인되지 않음.

### 의미
- 다음 항목은 **검출 불가**:
  - 하드코딩 문자열(특히 `Text('...')`)
  - 번역 키 누락
  - `AppLocalizations.of(context)` 미사용
  - locale fallback 정책 위반

### 실무 영향
- Clean Architecture 준수와 별개로, 다국어 품질 관리는 별도 룰셋(또는 추가 개발)이 필요.

---

## 4) Riverpod 3.0 관련 규칙 호환성 및 한계

### 호환성 강점
- Riverpod Generator 패턴(`@riverpod`/`@Riverpod`)을 중심으로 룰 구성
  - `riverpod_generator_rule.dart`
  - `riverpod_ref_usage_rule.dart`
  - `riverpod_provider_naming_rule.dart`
  - `riverpod_keep_alive_rule.dart`
  - `ref_mounted_usage_rule.dart`

### 한계
1. **Generator 강제 성향**
   - 수동 Provider(`StateNotifierProvider`, `FutureProvider` 등)를 금지하는 방향
   - 팀의 Riverpod 스타일 다양성을 제한 가능
2. **UseCase provider 판별이 네이밍 기반**
   - `...UseCaseProvider`, 동사+provider 등 추정
   - 근거: `riverpod_ref_usage_rule.dart` (`_isUseCaseProviderName`)
3. **파일 위치 기반 검사 범위 제한**
   - `/presentation/providers/`, `_provider.dart` 등에 집중
   - 다른 구조에서는 룰 미적용(FN) 가능

### 평가
- Riverpod 3.0 “API 파손” 이슈는 현재 테스트 기준으로 크지 않으나,
- **아키텍처 자유도는 낮추고 일관성은 높이는 타입**의 룰셋.

---

## 5) Flutter 최신 analyzer/custom_lint 생태계 호환성

### 확인된 점
- 의존성
  - `analyzer: ^8.4.0`
  - `custom_lint_builder: ^0.8.1`
  - 근거: `pubspec.yaml`
- 로컬 실행
  - Dart 3.11.0 환경에서 `dart test` 전체 통과 확인

### 리스크/주의
1. **문서/제약 불일치 가능성**
   - README 요구사항(3.6+) vs pubspec SDK(`^3.7.0`) 차이
2. **analyzer/custom_lint 메이저 업데이트 민감성**
   - AST API 변화 시 규칙 유지보수 필요
3. **자동 수정(quick fix) 제공 부재**
   - 대부분 진단 중심

---

## 6) flutter_boilerplate 적용 시 예상 FP/FN

### 예상 False Positive (FP)
1. **커스텀 폴더 구조 사용 시 오탐**
   - 예: `application/`, `infra/`, `feature_x/ui_layer/`
2. **수동 Riverpod 패턴 유지 팀**
   - `riverpod_generator_rule`가 대량 경고 발생
3. **의도적 keepAlive 사용 케이스**
   - 클래스명/경로가 화이트리스트 패턴과 안 맞으면 경고
   - 근거: `riverpod_keep_alive_rule.dart` 패턴 리스트
4. **DI 파일 변형 네이밍**
   - 표준 패턴 미일치 시 DI 예외 미적용

### 예상 False Negative (FN)
1. **파일명/경로 미일치로 룰 미발동**
   - Provider 파일이 `_provider.dart` 계열이 아니면 일부 룰 누락
2. **i18n 위반 전반**
   - 하드코딩 문자열/번역 누락 검출 불가
3. **동적/간접 참조 기반 의존 위반**
   - import 기반 정적 체크 한계로 일부 누락

---

## 7) 개선 우선순위 Top 10 (즉시/중기/장기)

### 즉시 (1~3)
1. **i18n 하드코딩 문자열 탐지 룰 추가**
   - `Text('literal')`, `SnackBar(content: Text('...'))` 등
2. **레이어 경로 패턴 설정화**
   - `/domain/`, `/data/`, `/presentation/`를 사용자 설정으로 외부화
3. **Rule severity/profile 기본셋 제공**
   - strict/balanced/minimal 프리셋 공식화

### 중기 (4~7)
4. **Riverpod 3.0 패턴 옵션화**
   - Generator 강제 on/off, manual provider 허용 모드
5. **UseCase provider 판별 고도화**
   - 네이밍+타입해석 혼합(휴리스틱 감소)
6. **i18n 키 사용 강제 룰**
   - `AppLocalizations`/번역 헬퍼 사용 여부 검사
7. **Quick Fix(자동 수정) 지원 확대**
   - 단순 rename/import 수정 자동화

### 장기 (8~10)
8. **프로젝트 구조 학습/매핑 기능**
   - 초기 스캔으로 사용자 프로젝트의 레이어 구조 인식
9. **타 룰셋과의 상호운용 가이드/충돌 탐지**
   - `very_good_analysis`, `flutter_lints`와 충돌 최소화
10. **CI 리포팅 강화(JSON/SARIF) 및 대규모 코드베이스 성능 최적화**

---

## 8) 적용 가이드: 권장 lint profile (strict / balanced / minimal)

아래는 `analysis_options.yaml` 기준 권장안.

### A. strict (아키텍처 강제 팀)
- 활성: 기본 33 + `clean_architecture_linter_require_test`
- 권장 대상: 신규 프로젝트, 단일 아키텍처 원칙 강한 팀
- 기대: 일관성 극대화 / 초기 경고량 큼

### B. balanced (실무 기본 권장)
- 활성: Core + Domain + Data 핵심 + Presentation 핵심
- 완화 후보:
  - `riverpod_keep_alive`(warning 유지)
  - `riverpod_provider_naming`(warning 유지)
  - `extension_location`(팀 컨벤션 따라 off 가능)
- test coverage rule: 핵심 모듈만 on

### C. minimal (점진 도입)
- 최소 활성 권장:
  - `layer_dependency`
  - `domain_purity`
  - `repository_interface`
  - `repository_implementation`
  - `widget_no_usecase_call`
- 목적: 큰 위반만 먼저 차단하고 점진 확대

---

## 실행 가능한 TODO 체크리스트

- [ ] `docs/analysis/SUPPORT_ANALYSIS.md` 리뷰 후 팀 합의 버전 확정
- [ ] 현재 프로젝트 폴더 구조가 룰 경로 가정(`/domain/`, `/data/`, `/presentation/`)과 맞는지 점검
- [ ] 도입 프로파일 선택 (strict / balanced / minimal)
- [ ] `clean_architecture_linter_require_test` 활성 여부 결정
- [ ] FP 다발 룰(예: provider naming, keepAlive) severity 조정
- [ ] i18n 보완 전략 수립 (별도 lint 또는 커스텀 룰 추가)
- [ ] 하드코딩 문자열 탐지(i18n) 신규 룰 설계 시작
- [ ] Riverpod manual provider 허용 옵션 필요 여부 결정
- [ ] CI에서 `dart run custom_lint`를 PR 게이트로 연결
- [ ] 2주 운영 후 FP/FN 사례 수집 및 룰셋 재튜닝

---

## 근거 파일(주요)

- 룰 등록/전체 구성: `lib/clean_architecture_linter.dart`
- 레이어 판별/파일 제외 유틸: `lib/src/clean_architecture_linter_base.dart`
- 의존성/경계:  
  - `lib/src/rules/cross_layer/layer_dependency_rule.dart`  
  - `lib/src/rules/cross_layer/boundary_crossing_rule.dart`  
  - `lib/src/rules/cross_layer/circular_dependency_rule.dart`
- Riverpod 관련:  
  - `lib/src/rules/presentation_rules/riverpod_generator_rule.dart`  
  - `lib/src/rules/presentation_rules/riverpod_ref_usage_rule.dart`  
  - `lib/src/rules/presentation_rules/riverpod_provider_naming_rule.dart`  
  - `lib/src/rules/presentation_rules/riverpod_keep_alive_rule.dart`
- 테스트 커버리지 규칙: `lib/src/rules/cross_layer/test_coverage_rule.dart`
- 의존성/SDK: `pubspec.yaml`
