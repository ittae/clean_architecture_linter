# `flutter analyze`는 플러그인 진단을 유실한다 — `dart analyze`를 쓰세요

**요약(TL;DR):** Flutter 앱 CI에서 `flutter analyze`만 실행하면
`clean_architecture_linter`(그리고 다른 모든 `analysis_server_plugin` 기반
플러그인)의 진단이 **조용히 유실**됩니다. `flutter analyze`는 "No issues found!"를
출력하지만 위반이 실제로는 존재합니다. **CI/로컬 게이트에서는 `dart analyze`를
사용하세요.**

관련 이슈: ITT-1677(최초 발견) · ITT-1836(원인 규명 + 회귀 가드).

## 증상

동일한 fixture(`poc_v2/example`), 동일한 `analysis_options.yaml`, 동일한 SDK
(Flutter 3.44.6 / Dart 3.12.2)에서:

| 명령 | 결과 |
| --- | --- |
| `dart analyze` | 12 issues found (플러그인 진단 정상) |
| `flutter analyze` | `No issues found! (ran in 0.7s)` (진단 유실) |
| LSP 직접 handshake(충분히 대기) | 진단 수신 |

`flutter analyze`는 재현할 때마다 일관되게 진단을 유실합니다(2회+ 확인).

## 원인

**레이어: `flutter_tools`의 `flutter analyze` 완료 판정 로직 × `analysis_server_plugin`의
비동기 진단 전달.** config 오류도, 플러그인 미로딩도, analyzer/asp 버전 문제도
아닙니다.

`flutter analyze`는 내부적으로 `dart language-server`(LSP)를 띄우고
(`packages/flutter_tools/lib/src/dart/analysis.dart`의 `AnalysisServer`),
서버가 보내는 `$/progress` "Analyzing…" work-done 토큰의 **`end` 이벤트**가 오면
분석이 끝났다고 보고 진단 수집을 멈춥니다(`_isAnalyzing = false`). 그런데:

1. core analyzer의 "Analyzing…" progress 토큰은 **플러그인 격리(isolate)가
   진단을 내보내기 전에** 먼저 끝납니다.
2. `analysis_server_plugin`의 진단은 그 뒤에 **별도의 늦은
   `textDocument/publishDiagnostics`** 라운드로 도착합니다.
3. `flutter analyze`는 이미 수집을 멈춘 뒤라 이 진단을 보지 못하고
   "No issues found!"를 출력합니다.

### 재현 타임라인 (직접 LSP 계측, ITT-1836)

flutter_tools와 동일한 LSP 요청을 재현해 `publishDiagnostics`와 progress
`begin`/`end`의 타임스탬프를 찍은 결과:

```
[1.62s] progress BEGIN  title=Analyzing…
[1.64s] progress END    <-- flutter analyze는 여기서 수집을 멈춘다
[2.05s] publishDiagnostics n=11 (AFTER progress END)  codes=[domain_purity, ...]  bad_domain.dart
[2.08s] publishDiagnostics n=1  (AFTER progress END)  codes=[presentation_no_throw] bad_notifier.dart
```

progress `end`는 1.64s에 오는데 플러그인 진단은 2.05s / 2.08s에 **그 이후**
도착합니다. `flutter analyze`가 "ran in 0.7s"로 빠르게 끝나는 것도 같은 이유입니다.

- `dart analyze`(analyzer CLI)는 플러그인 결과를 **기다렸다가** 출력하므로 진단이
  포함됩니다.
- LSP를 직접 몰아 충분히 대기하면(ITT-1677, ITT-1836 probe) 진단이 수신됩니다.

## 소비자 권장 경로 (CI에서 무엇을 실행할 것인가)

**`clean_architecture_linter`를 강제하려면 `dart analyze`를 사용하세요.**
`flutter analyze`에만 의존하면 아키텍처 위반이 CI를 조용히 통과합니다.

Flutter 앱 CI 예시:

```yaml
- name: Analyze (clean_architecture_linter 강제)
  run: dart analyze          # flutter analyze 아님
```

- `dart analyze`는 Flutter 번들 Dart SDK로도 동작하며 top-level `plugins:`로 켠
  플러그인을 로딩하고 그 진단을 기다립니다.
- `--fatal-warnings`(기본값)로 warning을 CI 실패로 승격할 수 있습니다.
- 실제 위반이 없는지 로컬에서도 `flutter analyze` 대신 `dart analyze`로 확인하세요.

## 회귀 가드

- `tools/verify_analyze_parity.sh` — `poc_v2/example` fixture에서 `dart analyze`가
  `tools/slice_contracts.json`에 선언한 슬라이스 contract 진단(현재
  `presentation_no_throw`, `domain_purity`, `repository_pass_through`,
  `layer_dependency`)을 계속 보고하는지 검증합니다. 유실되면 실패합니다.
  `--contracts-only`는 선언 파일만 검사합니다. Flutter가 있으면
  `flutter analyze` 개수도 함께 출력해 이 gap을 가시화하지만, 문서화된
  upstream 이슈이므로 기본적으로 실패시키지는 않습니다(`--require-parity`로
  opt-in).
- `.github/workflows/ci.yml`의 `plugin-diagnostics` 잡이 위 스크립트를 매 PR에서
  실행합니다(Dart-only 러너, `flutter` 스킵).

## 향후 (upstream)

`flutter analyze`가 플러그인 격리의 늦은 진단까지 기다리도록 고쳐지면(예: 마지막
`publishDiagnostics` 라운드까지 settle), 이 gap은 사라집니다. 그때는
`tools/verify_analyze_parity.sh --require-parity`가 통과하는지로 확인할 수 있습니다.
그전까지 소비자 권장 경로는 `dart analyze`로 유지합니다.

analyzer / `analysis_server_plugin` upper-bound는 이 이슈로 인해 변경하지 않습니다.
