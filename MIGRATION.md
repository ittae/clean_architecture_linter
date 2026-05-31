# MIGRATION — v1 → v2.0

`clean_architecture_linter` v2.0은 `custom_lint` 기반에서 Dart 공식 [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin) 기반으로 전환된다. 이 문서는 v1.x 사용자가 v2.0으로 옮길 때 무엇이 바뀌고 어떤 순서로 적용하는지를 안내한다.

> ⚠️ **적용 시점**: v2.0은 아직 pub.dev에 release되지 않았다. 현재 pub.dev 최신본은 v1.3.2(`custom_lint` 기반)이며, 이 가이드는 **v2.0 release 이후** 적용한다. 지금은 [README의 Compatibility 섹션](README.md#-compatibility--analyzer-9--riverpod-3-temporary-workaround)의 v1 워크어라운드를 그대로 사용하면 된다.

## 무엇이 바뀌나

규칙의 **동작·이름·진단 메시지는 v1과 동일**하다. 33개 rule이 v2 plugin에 그대로 등록되며, 바뀌는 것은 lint를 켜는 **설치/실행 방식**뿐이다.

| 항목 | v1.x (custom_lint) | v2.0 (analysis_server_plugin) |
|------|--------------------|-------------------------------|
| `analysis_options.yaml` | `analyzer: plugins: - custom_lint` | top-level `plugins: clean_architecture_linter: <version>` |
| `pubspec.yaml` dev_dependency | `clean_architecture_linter` + `custom_lint` | `clean_architecture_linter` (단독, `custom_lint` 제거) |
| 실행 CLI | `dart run custom_lint` | `dart analyze` (Flutter: `flutter analyze`) |
| Dart SDK 최소 | `^3.6.0` | `^3.10.0` |
| `pubspec_overrides.yaml` 워크어라운드 | 필요 (analyzer 9 / Riverpod 3+ 충돌) | **불필요** — `custom_lint*` 체인 자체가 사라짐 |
| Rule 개수 / 이름 / 진단 메시지 | 33개 | 33개 (동일, 진단 메시지 동등) |

> `analysis_server_plugin`은 Dart 3.10부터 지원된다. SDK가 `^3.10.0` 미만이면 v2.0을 쓸 수 없으므로 v1.x에 머물러야 한다.

## 마이그레이션 절차

### 1. Dart SDK 확인

`pubspec.yaml`의 `environment` SDK 하한을 `^3.10.0` 이상으로 올린다.

```yaml
# pubspec.yaml
environment:
  sdk: ^3.10.0
```

### 2. 의존성 교체

`custom_lint` dev_dependency를 제거하고 `clean_architecture_linter`만 v2.0으로 둔다.

```yaml
# pubspec.yaml
dev_dependencies:
  clean_architecture_linter: ^2.0.0
  # custom_lint: ^0.8.1   # ← 제거
```

### 3. `pubspec_overrides.yaml` 정리

v1.x에서 analyzer 9 / Riverpod 3+ 충돌 때문에 추가했던 `custom_lint*` override가 있다면 더 이상 필요 없다. 해당 `dependency_overrides` 블록을 제거한다. (파일에 다른 override가 없다면 파일 자체를 비우거나 삭제 가능 — 삭제는 사용자가 직접 판단해 수행한다.)

### 4. `analysis_options.yaml` 전환

`analyzer: plugins:` 리스트 항목을 top-level `plugins:` 맵으로 옮긴다. `exclude` 블록은 `analyzer:` 아래에 **그대로 둔다**.

```yaml
# analysis_options.yaml — v2.0
plugins:
  clean_architecture_linter: ^2.0.0

analyzer:
  exclude:
    - test/**
    - "**/*.g.dart"        # 생성 파일 제외
    - "**/*.freezed.dart"  # Freezed 파일 제외
    - "**/*.mocks.dart"    # Mock 파일 제외
```

### 5. 설치 및 실행

```bash
dart pub get
dart analyze        # Flutter 프로젝트는 flutter analyze
```

`dart run custom_lint`은 더 이상 사용하지 않는다. v2.0의 33개 rule은 `dart analyze` / `flutter analyze` 결과에 직접 포함된다.

### 6. IDE 재시작

`analysis_options.yaml`의 `plugins` 섹션을 바꿨다면 editor의 Dart Analysis Server를 재시작한다(VS Code: "Dart: Restart Analysis Server", IntelliJ/Android Studio: analyzer 재시작). command-line `dart analyze`는 다음 실행에서 변경을 자동으로 반영한다.

## 알려진 차이 / 주의

- **실행 명령 변경**: CI/CD 스크립트나 `Makefile`/`derry`/`melos` 태스크에서 `dart run custom_lint`을 호출하던 부분을 `dart analyze`(또는 `flutter analyze`)로 교체한다.
- **severity**: v2.0 rule은 대부분 analyzer **WARNING**으로 보고되지만, 일부(7개: `repository_no_throw`, `extension_location`, `freezed_usage`, `no_presentation_models`, `ref_mounted_usage`, `riverpod_generator`, `riverpod_keep_alive`)는 v1 패리티에 맞춰 **INFO**로 보고된다. CI에서 WARNING을 실패로 처리하려면 `dart analyze --fatal-warnings`를 쓰고, **INFO rule까지** 실패로 처리하려면 `--fatal-infos`도 함께 지정해야 한다(`--fatal-warnings`만으로는 INFO가 잡히지 않는다).
- **IDE 통합**: 별도 `custom_lint` 플러그인 활성화 없이 Dart/Flutter 확장이 제공하는 기본 analyzer 경로로 진단이 표시된다.
- **테스트 커버리지 rule**: `clean_architecture_linter_require_test` 같은 옵션 rule의 활성화 형식은 v2.0 release 노트(CHANGELOG)에서 최종 확정된다.
- **워크어라운드 종료**: v2.0에서는 archive된 `invertase/dart_custom_lint`에 묶이지 않으므로, 최신 `riverpod_generator 4.x` / `riverpod_lint 3.1.x` / `freezed 3.x`와 override 없이 함께 resolve된다.

## 참고

- [Dart analyzer plugins](https://dart.dev/tools/analyzer-plugins)
- [analysis_server_plugin package](https://pub.dev/packages/analysis_server_plugin)
- [v2 analyzer plugin 개발 흐름](docs/v2-dev-workflow.md) — contributor용 로컬 개발 가이드
- 마이그레이션 배경: upstream [invertase/dart_custom_lint](https://github.com/invertase/dart_custom_lint) archive 및 원작자의 `analysis_server_plugin` 이주 권고
