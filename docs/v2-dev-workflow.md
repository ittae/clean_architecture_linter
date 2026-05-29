# v2 analyzer plugin 개발 흐름

`clean_architecture_linter` v2는 `custom_lint_builder`에서 Dart 공식 `analysis_server_plugin` API로 이동한다. 이 문서는 v2 패키지가 publish되기 전에도 새 contributor가 로컬에서 plugin을 실행하고 검증할 수 있는 개발 흐름을 정의한다.

## 이 흐름을 쓰는 이유

Dart의 새 analyzer plugin 시스템은 `analysis_options.yaml`의 top-level `plugins` 섹션에서 켠다. publish된 plugin은 version constraint로 지정하고, 로컬 개발 중인 plugin은 path로 지정할 수 있다. analysis server는 plugin 전용 synthetic package를 만들어 의존성을 resolve한 뒤 `dart analyze` / `flutter analyze`에서 plugin을 실행한다.

따라서 contributor는 `.dartServer/.plugin_manager/<hash>/pubspec_overrides.yaml`을 수정하지 않는다. 해당 hash는 analysis server가 관리하는 임시 상태이고, 머신이나 실행 시점에 따라 달라진다.

참고 자료:

- [Dart analyzer plugins](https://dart.dev/tools/analyzer-plugins)
- [analysis_server_plugin package](https://pub.dev/packages/analysis_server_plugin)
- [Dart pub workspaces](https://dart.dev/tools/pub/workspaces)

## 현재 PoC 구조

```text
poc_v2/
  pubspec.yaml
  lib/main.dart
  lib/src/presentation_no_throw_rule.dart
  example/
    pubspec.yaml
    analysis_options.yaml
    lib/features/todo/presentation/
      bad_notifier.dart
      good_notifier.dart
tools/dev_setup.sh
```

`poc_v2`는 작은 standalone v2 plugin package다. analyzer plugin key가 plugin package name과 맞아야 하므로 package name은 의도적으로 `clean_architecture_linter`를 사용한다.

`poc_v2/example/analysis_options.yaml`은 로컬 plugin을 다음처럼 켠다.

```yaml
plugins:
  clean_architecture_linter:
    path: ..
```

## Setup

repository root에서 실행한다.

```bash
./tools/dev_setup.sh
```

script는 아래 순서로 실행한다.

```bash
cd poc_v2 && dart pub get
cd example && dart pub get
dart analyze
```

기대 결과: `dart analyze`가 `bad_notifier.dart`에서는 `presentation_no_throw`를 보고하고, `good_notifier.dart`에서는 보고하지 않는다.

## 수동 검증

```bash
cd poc_v2
dart pub get

cd example
dart pub get
dart analyze
```

`analysis_options.yaml`의 `plugins` 섹션을 바꿨다면 editor의 Dart Analysis Server를 재시작한다. command-line `dart analyze`는 다음 실행에서 변경을 읽는다.

## Rule 개발 루프

1. `poc_v2/lib/src/`에서 rule을 구현하거나 수정한다.
2. `poc_v2/lib/main.dart`에 rule을 등록한다.
3. `poc_v2/example/lib/` 아래에 bad/good fixture를 추가한다.
4. `./tools/dev_setup.sh`를 실행한다.
5. rule 동작이 안정되면 대응하는 v1 `custom_lint_builder` test를 v2 analyzer test harness로 옮긴다.

## Notes

- `analysis_server_plugin`은 Dart 3.10부터 지원된다.
- 새 plugin 시스템은 `analyzer: plugins:`가 아니라 top-level `plugins:` key를 쓴다.
- warning rule은 기본 활성화된다. lint rule은 plugin의 `diagnostics:` 섹션에서 명시적으로 켠다.
- plugin code는 `lib/main.dart`에서 top-level `final plugin = ...`를 노출해야 한다.
- machine-local `.dartServer` 수정은 피한다. plugin resolution이 깨지면 `analysis_options.yaml`, package constraint, local package path를 고친다.
