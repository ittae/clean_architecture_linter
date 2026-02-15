# I18N / 다국어 지원 관점 분석

작성일: 2026-02-15  
대상: `/Volumes/T7 Shield/dev/clean_architecture_linter`

---

## 요약

현재 `clean_architecture_linter`는 **클린 아키텍처/에러 처리 구조** 중심 규칙은 강하지만,  
**UI 문자열 하드코딩 탐지 및 Flutter l10n(ARB/delegate) 강제 규칙은 사실상 부재**합니다.

다만 예외 설계 문맥에서 `code + debugMessage` 패턴을 i18n 친화적으로 언급하고 있어,  
완전 비호환은 아니고 **“확장 가능한 상태”**에 가깝습니다.

---

## 1) 하드코딩 문자열 탐지 규칙 유무

## 결론
- **전용 규칙 없음** (예: `Text('...')`, `SnackBar(content: Text('...'))`, `Exception('...')` 문자열 literal 금지 등)
- 룰 등록 목록(33개)에 i18n/hardcoded-string 관련 룰이 없음

## 파일 근거
1. 룰 등록 엔트리에서 i18n 관련 룰 import/등록 부재
   - `lib/clean_architecture_linter.dart:13-53` (import 목록)
   - `lib/clean_architecture_linter.dart:79-186` (실제 등록 룰 목록 33개)

2. README 룰 개요에도 i18n/하드코딩 문자열 룰 미기재
   - `README.md:27-91` (Rules Overview)

3. 코드베이스 내 문자열 literal AST 탐지 흔적 부재
   - `SimpleStringLiteral`, `StringInterpolation`, `AppLocalizations`, `Intl.message` 기준 검색 시 관련 룰 구현 없음

---

## 2) l10n delegate/ARB 기반 프로젝트와의 호환성

## 결론
- **간접 호환(충돌 가능성 낮음)**: 현재 룰들이 l10n delegate/ARB 사용을 방해하지는 않음
- **직접 지원/강제는 없음**: `AppLocalizations.of(context)` 또는 `S.of(context)` 사용을 요구/검증하지 않음

## 근거
1. 패키지 의존성이 analyzer/custom_lint 중심이며 flutter_localizations/intl 의존이 없음
   - `pubspec.yaml:20-23`

2. 현재 룰들은 주로 레이어/예외/리버팟 구조 검사
   - `lib/clean_architecture_linter.dart:79-186`

3. Presentation 예외 룰도 throw/계층 검증 중심이며 locale API 호출 검증은 없음
   - `lib/src/rules/presentation_rules/presentation_no_throw_rule.dart:93-137`

## 해석
- ARB/delegate를 이미 쓰는 프로젝트에서 **오탐으로 막을 가능성은 낮음**
- 반대로 ARB를 안 써도 현재 린터만으로는 **미탐(강제 불가)**

---

## 3) 위젯/에러메시지/예외메시지에서 다국어 강제 가능 여부

## 결론
- **현재는 강제 불가**

## 세부
1. 위젯 문자열
   - `Text('로그인')`, `AppBar(title: Text('Home'))` 같은 하드코딩을 잡는 규칙 없음

2. 에러 메시지(프레젠테이션)
   - `AsyncValue.error(Exception('실패'))` 또는 사용자 노출 메시지 literal 강제 규칙 없음

3. 예외 메시지(도메인/데이터)
   - 예외 타입/네이밍은 일부 강제하지만 메시지 localize 여부는 검사하지 않음
   - 예외 관련 규칙은 타입/패턴 중심:
     - `lib/src/rules/domain_rules/exception_naming_convention_rule.dart:49-99`
     - `lib/src/rules/data_rules/datasource_exception_types_rule.dart:118-131`

4. 참고: i18n 지향적 힌트는 존재
   - `ExceptionValidationMixin` 문서에서 `code + debugMessage` 구조를 i18n 지원 패턴으로 언급
   - `lib/src/mixins/exception_validation_mixin.dart:84-90, 182-183`
   - 그러나 실제 enforce 룰은 연결되어 있지 않음

---

## 4) 현재 부족한 점과 우회법

## 부족한 점
1. UI literal 금지 규칙 없음
2. Exception/Failure message literal 금지 규칙 없음
3. ARB key 기반(`errorValidationIdRequired`) 사용 강제 없음
4. l10n delegate 설정(MaterialApp `localizationsDelegates`, `supportedLocales`) 존재 검증 없음
5. 문서상 언급된 localization 룰의 구현 부재 정황
   - mixin 문서에 `exception_message_localization_rule` 언급
   - `lib/src/mixins/exception_validation_mixin.dart:31`
   - 실제 파일/등록 룰에서 해당 룰 확인 불가 (`lib/clean_architecture_linter.dart`)

## 현실적 우회법(당장 적용 가능)
1. **Dart 기본 lint + 팀 규약 병행**
   - 코드리뷰 규칙: `Text('literal')` 금지, `AppLocalizations` 필수

2. **예외는 코드 기반으로만 발생**
   - `InvalidInputException.withCode('errorValidationIdRequired')` 패턴 통일
   - 근거 예시: `lib/src/rules/domain_rules/usecase_no_result_return_rule.dart:31-33`

3. **Presentation에서 최종 메시지 매핑**
   - Exception/Failure의 `code`를 UI에서 ARB key로 매핑
   - debugMessage는 로깅 전용으로 제한

4. **보완용 custom_lint 추가 패키지 병행**
   - 본 패키지를 유지하면서 i18n 전용 규칙만 별도 custom_lint로 추가

---

## 5) i18n 지원을 위한 신규 규칙 제안 (5개)

아래 5개는 현재 아키텍처와 충돌이 적고, 기존 룰 스타일(파일 경로 + AST 매칭)로 구현 가능한 제안입니다.

### 제안 1. `presentation_no_hardcoded_text`
- **목적**: 위젯 트리 내 사용자 노출 문자열 literal 금지
- **탐지 로직 개요**:
  1. `MethodInvocation`/`InstanceCreationExpression`에서 `Text`, `RichText`, `TextSpan`, `SnackBar`, `AlertDialog`, `InputDecoration(labelText/hintText)` 추적
  2. 인자가 `SimpleStringLiteral` 또는 interpolation literal이면 위반
  3. 예외: 테스트 파일, `semanticsLabel` 등 접근성/디버그 whitelist
- **근거 연결**:
  - 현재 presentation 룰이 이미 파일 경로 기반 필터 사용: `presentation_no_throw_rule.dart:93-100`
  - 유사한 방식으로 presentation 디렉토리 대상 확장 가능

### 제안 2. `exception_require_error_code`
- **목적**: 예외 생성 시 로컬라이즈 가능한 코드 기반 생성 강제
- **탐지 로직 개요**:
  1. `throw`의 `InstanceCreationExpression` 분석
  2. `AppException` 계열이면서 positional string message 생성자 사용 시 경고
  3. `.withCode('...')` 또는 `code:` named arg를 요구
- **근거 연결**:
  - 코드베이스가 이미 `withCode` 패턴을 권장: `usecase_no_result_return_rule.dart:32`
  - `ExceptionValidationMixin`의 `code + debugMessage` 철학: `exception_validation_mixin.dart:84-90`

### 제안 3. `exception_no_user_facing_literal_message`
- **목적**: Exception/Failure 생성자에서 사용자 노출 메시지 literal 직접 주입 금지
- **탐지 로직 개요**:
  1. `throw SomeException('...')`, `Failure(message: '...')` 패턴 탐지
  2. 문자열이 ARB key 패턴(`^[a-z][a-zA-Z0-9_.]+$`)이 아니면 경고
  3. `debugMessage:`는 허용(단 릴리즈 노출 금지 권고 메시지)
- **근거 연결**:
  - 현재는 타입만 검사하고 메시지 내용 검사 없음: `datasource_exception_types_rule.dart:118-131`

### 제안 4. `require_l10n_delegate_configuration`
- **목적**: 앱 엔트리에서 Flutter l10n delegate/supportedLocales 설정 강제
- **탐지 로직 개요**:
  1. `MaterialApp`/`CupertinoApp`/`WidgetsApp` 인스턴스 생성 탐지
  2. `localizationsDelegates`, `supportedLocales` named arg 존재 여부 확인
  3. 누락 시 경고 + `AppLocalizations.delegate` 예시 제공
- **근거 연결**:
  - 현재 플러터 l10n 설정 검증 룰 전무 (룰 목록: `clean_architecture_linter.dart:79-186`)

### 제안 5. `arb_key_usage_in_presentation`
- **목적**: presentation 레이어에서 ARB 키 또는 generated localization accessor 사용 강제
- **탐지 로직 개요**:
  1. presentation 파일에서 `Text(...)` 인자 추적
  2. 허용 패턴: `context.l10n.xxx`, `AppLocalizations.of(context)!.xxx`, `S.of(context).xxx`
  3. literal/임의 문자열 반환식이면 경고
- **근거 연결**:
  - package가 Riverpod 전용 패턴까지 강제하는 성향이 있어(`README.md:8-9`, `clean_architecture_linter.dart:154-176`), i18n 접근자 강제도 정책 일관성 높음

---

## 부록: 근거 파일 인덱스

- 룰 등록/전체 범위: `lib/clean_architecture_linter.dart`
- 예외 관련 공통 믹스인: `lib/src/mixins/exception_validation_mixin.dart`
- 도메인 예외 네이밍 룰: `lib/src/rules/domain_rules/exception_naming_convention_rule.dart`
- 데이터소스 예외 타입 룰: `lib/src/rules/data_rules/datasource_exception_types_rule.dart`
- 프레젠테이션 throw 금지 룰: `lib/src/rules/presentation_rules/presentation_no_throw_rule.dart`
- 패키지 의존성: `pubspec.yaml`
- 문서상 룰 개요: `README.md`

---

## 최종 판단

`clean_architecture_linter`는 **i18n-ready error architecture(코드 기반 예외)** 쪽으로는 문맥이 있으나,  
실제 lint enforcement는 아직 **구조/레이어 중심**입니다.  
즉, 현재 상태는 **“다국어를 방해하지는 않지만, 다국어를 보장하지도 않는다”**가 정확한 평가입니다.
