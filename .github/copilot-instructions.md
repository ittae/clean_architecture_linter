## 이 레포 고유 지침
- 이 저장소는 Flutter 앱이 아니라 외부 사용자에게 배포되는 **public Dart package (`analysis_server_plugin` 기반 Clean Architecture linter)**.
- 패키지 구현 경로는 `lib/src/rules/`, `lib/src/mixins/`, plugin entrypoint는 `lib/clean_architecture_linter.dart`다. 예제/fixture의 `lib/features/...`는 소비자 앱 lint semantics를 검증하기 위한 입력이며, agent 구현 레이아웃으로 해석하지 않는다.
- lint semantics와 agent 운영 규칙을 분리한다. public GitHub metadata에 private Multica `ITT-*` key를 노출하지 않고, PR은 human merge only로 둔다.
- 검증은 root `dart analyze`, root `dart test`, `cd example && dart analyze`, `cd poc_v2/consumer_riverpod_lint && dart analyze`를 기준으로 한다.
- 상세 규칙 / Vision / rule 등록: `CLAUDE.md` 참조.
