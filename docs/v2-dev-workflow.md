# v2 analyzer plugin 개발 흐름

`clean_architecture_linter` v2는 `custom_lint_builder`에서 Dart 공식 `analysis_server_plugin` API로 이동한다. 이 문서는 v2 패키지가 publish되기 전에도 새 contributor가 로컬에서 plugin을 실행하고 검증할 수 있는 개발 흐름을 정의한다.

## 이 흐름을 쓰는 이유

Dart의 새 analyzer plugin 시스템은 `analysis_options.yaml`의 top-level `plugins` 섹션에서 켠다. publish된 plugin은 version constraint로 지정하고, 로컬 개발 중인 plugin은 path로 지정할 수 있다. analysis server는 plugin 전용 synthetic package를 만들어 의존성을 resolve한 뒤 `dart analyze` / `flutter analyze`에서 plugin을 실행한다.

따라서 contributor는 `.dartServer/.plugin_manager/<hash>/pubspec_overrides.yaml`을 수정하지 않는다. 해당 hash는 analysis server가 관리하는 임시 상태이고, 머신이나 실행 시점에 따라 달라진다.

참고 자료:

- [Dart analyzer plugins](https://dart.dev/tools/analyzer-plugins)
- [analysis_server_plugin package](https://pub.dev/packages/analysis_server_plugin)
- [Dart pub workspaces](https://dart.dev/tools/pub/workspaces)

## 현재 v2 구조

```text
lib/main.dart
lib/src/rules/cross_layer/
lib/src/rules/data_rules/
lib/src/rules/domain_rules/
lib/src/rules/presentation_rules/
poc_v2/example/
  pubspec.yaml
  analysis_options.yaml
  lib/features/todo/presentation/
    bad_notifier.dart
    good_notifier.dart
test/v2_harness/
tools/dev_setup.sh
```

`poc_v2`는 Phase 0의 standalone reference로 남겨둔다. 정식 v2 plugin
entrypoint는 root package의 `lib/main.dart`이고, 33개 rule 전부가
`lib/src/rules/{cross_layer,domain_rules,data_rules,presentation_rules}/`
아래로 변환되어 `lib/main.dart`의 `register()`에 `registerWarningRule(...)`로
등록되어 있다.

`poc_v2/example/analysis_options.yaml`은 로컬 plugin을 다음처럼 켠다.

```yaml
plugins:
  clean_architecture_linter:
    path: ../..
```

## Setup

repository root에서 실행한다.

```bash
./tools/dev_setup.sh
```

script는 아래 순서로 실행한다.

```bash
dart pub get
cd poc_v2/example && dart pub get
dart analyze
```

기대 결과: `dart analyze`가 `bad_notifier.dart`에서는 `presentation_no_throw`를 보고하고, `good_notifier.dart`에서는 보고하지 않는다.

## 수동 검증

```bash
dart pub get

cd poc_v2/example
dart pub get
dart analyze
```

`analysis_options.yaml`의 `plugins` 섹션을 바꿨다면 editor의 Dart Analysis Server를 재시작한다. command-line `dart analyze`는 다음 실행에서 변경을 읽는다.

## Rule 개발 루프

1. `lib/src/rules/` 아래에서 analyzer `AnalysisRule`을 구현하거나 수정한다.
2. `lib/main.dart`에 rule을 등록한다.
3. `test/v2_harness/` 기반 단위 테스트를 추가한다.
4. `./tools/dev_setup.sh`를 실행한다.
5. 필요하면 `poc_v2/example/lib/` 아래에 smoke fixture를 추가한다.

## v2 rule 마이그레이션 패리티 체크리스트

v1 `custom_lint_builder` rule을 v2 `AnalysisRule`로 옮길 때는 rule logic을
단순히 컴파일되게 바꾸는 것으로 끝내지 않는다. v1이 보고하던 조건, 건너뛰던
조건, 메시지의 context를 모두 보존해야 한다.

1. Visitor 진입부에 `CleanArchitectureUtils.shouldExcludeFile(filePath)`
   guard를 둔다. `allowed_instance_variables_rule.dart`와
   `test_coverage_rule.dart`의 패턴을 기준으로 삼는다.
2. v1 diagnostic message가 import URI, layer, class, field, cycle path 같은
   context를 포함했다면 v2도 `LintCode('... {0}')`와
   `reportAtNode(node, arguments: [...])`로 같은 context를 전달한다. v1이
   위반 종류별로 다른 `correctionMessage`를 제공했다면 v2도 `{1}` placeholder
   또는 category-specific `LintCode`로 같은 correction context를 유지한다.
   `boundary_crossing_rule.dart`와 `allowed_instance_variables_rule.dart`의
   패턴을 기준으로 삼고, context가 필요한 rule에서 bare `reportAtNode(node)`
   정적 메시지나 단일 정적 correction으로 축소하지 않는다.
3. v1의 모든 skip/exclusion 조건을 이식한다. 예: programming error 허용,
   private method 허용, constructor 허용, path narrowing, DI/provider 예외,
   generated/test/build file 제외.
4. v2 harness test는 `codeName`과 line만 보지 말고 diagnostic message와
   `correctionMessage` 내용도 assert한다. 특히 import URI, cycle path,
   class/field/type 이름, category-specific correction처럼 regression 때
   사라지기 쉬운 context를 검증한다.
5. excluded-file scenario를 테스트에 포함한다. `.g.dart` 또는 `.freezed.dart`가
   rule 위반 import/AST를 포함해도 diagnostic이 보고되지 않아야 한다.
6. v1 reference file은 보존한다. `*_custom_lint_rule.dart`와
   `CustomLintXxxRule` class 이름을 유지해서 v1/v2 parity review가 가능하게
   한다.
7. 새 v2 rule은 `lib/main.dart`에 등록하고, 등록 여부를 plugin creation 또는
   smoke test로 확인한다.

## Notes

- `analysis_server_plugin`은 Dart 3.10부터 지원된다.
- 새 plugin 시스템은 `analyzer: plugins:`가 아니라 top-level `plugins:` key를 쓴다.
- warning rule은 기본 활성화된다. lint rule은 plugin의 `diagnostics:` 섹션에서 명시적으로 켠다.
- plugin code는 `lib/main.dart`에서 top-level `final plugin = ...`를 노출해야 한다.
- machine-local `.dartServer` 수정은 피한다. plugin resolution이 깨지면 `analysis_options.yaml`, package constraint, local package path를 고친다.
