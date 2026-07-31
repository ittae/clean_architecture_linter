## 이 레포 고유 지침
- 이 저장소는 Flutter 앱이 아니라 외부 사용자에게 배포되는 **public Dart package (`analysis_server_plugin` 기반 Clean Architecture linter)**.
- 패키지 구현 경로는 `lib/src/rules/`, `lib/src/mixins/`, plugin entrypoint는 `lib/clean_architecture_linter.dart`다. 예제/fixture의 `lib/features/...`는 소비자 앱 lint semantics를 검증하기 위한 입력이며, agent 구현 레이아웃으로 해석하지 않는다.
- lint semantics와 agent 운영 규칙을 분리한다. public GitHub metadata에 private Multica `ITT-*` key를 노출하지 않고, PR은 human merge only로 둔다.
- 검증은 root `dart analyze`, root `dart test`, `cd example && dart analyze`, `cd poc_v2/consumer_riverpod_lint && dart analyze`를 기준으로 한다.
- 상세 규칙 / Vision / rule 등록: `CLAUDE.md` 참조.

## sandbox 안전 규율
<!-- BEGIN agent-safety-discipline (managed) -->
- `.env` secret을 출력·검사·커밋하지 않는다. 필요한 경우 `.env.example`의 key 이름만 확인한다.
- 삭제가 필요하면 대상을 정확히 특정해 `rm`, `rmdir`, `git rm`을 사용할 수 있다. `rm -rf`와 대량 삭제는 명확한 scope·dry-run·rollback을 먼저 확인한다.
- 홈 루트, repo `.git/`, secret/credential, shared runner/worktree root처럼 고위험 대상을 삭제·정리할 때는 명시 승인을 받는다.
- 승인 없이 `curl | sh`, 출처 불명 installer, `chmod`, `sudo`, network shell을 실행하지 않는다.
- conductor/Multica가 관리하는 workspace는 담당 issue/worktree의 scope 안에서만 수정한다.
<!-- END agent-safety-discipline -->

## 개발 판단 규율 (위험·경계 비례)
<!-- BEGIN agent-lean-discipline (managed) -->
- 새 구현 전에 기존 코드, stdlib, 플랫폼 기능, 현재 dependency로 해결 가능한지 확인한다.
- architecture와 테스트 범위는 실제 dependency/trust boundary, 변경 위험, 실패 비용에 비례시킨다. 미래 확장만을 위한 layer/interface/factory/wrapper는 만들지 않는다.
- LOC·파일 수는 목표가 아니다. correctness, security, privacy, data integrity, accessibility, i18n, 명시적 error handling과 필요한 경계를 단순화와 교환하지 않는다.
- repo의 architecture convention과 required gate가 optional skill/plugin/persona 지침보다 우선한다.
<!-- END agent-lean-discipline -->

## 검색·컨텍스트 규율 (토큰 효율)
<!-- BEGIN agent-search-discipline (managed) -->
- 코드/텍스트 검색은 `rg`, 파일 탐색은 `fd`, 구조(AST) 매칭은 `ast-grep`/`sg` (`grep -r`/`find`/정규식 대신).
- 파일을 통째로 읽지 않는다. `rg`/`ast-grep`로 위치를 특정한 뒤 필요한 심볼/라인 범위만 읽는다.
- 툴 결과 JSON/YAML을 raw로 컨텍스트에 넣지 않는다. `jq`/`yq`로 필요한 필드만 필터한다.
- GitHub는 `gh`, HTTP 스모크는 `xh`(없으면 `curl`). Multica 플랫폼은 `multica` CLI만.
- 광범위 매칭을 통째로 프롬프트에 넣지 않는다. 범위를 좁히거나 count만 확인한다.
- 목적: 토큰 낭비·환각(길 잃음) 방지. Multica 할당 에이전트도 workspace context/agent instructions의 Mac mini CLI routing과 동일 적용.
- **위 필터 규율은 조회(read)에만 적용한다.** 상태를 바꾸는 명령(`git push`, `gh pr create/edit/merge`, `--apply`, 배포·설정 생성)은 출력을 `| tail`/`| head`로 자르지 않는다. 에러는 잘린 부분에 숨고, 남은 마지막 줄은 성공처럼 보인다. 실측 사례: `gh pr edit ... -q .`가 `unknown shorthand flag: 'q'`로 실패했는데 `| tail -1`이 usage 끝줄만 남겨 성공으로 오독했다.
- **쓰기 명령은 실행 후 목적지를 조회해 확인한다.** `push` 성공은 브랜치에 올라갔다는 뜻일 뿐 PR에 반영됐다는 뜻이 아니다 — `gh pr view <n> --json state,commits`로 확인한다. 이 확인을 생략해 수정 커밋이 머지 1분 뒤에 도착했고, 게이트가 깨진 채 하루 동안 배포돼 있었다.
<!-- END agent-search-discipline -->

## 검증 규율 (analyze 먼저, test 나중)
<!-- BEGIN agent-verify-discipline (managed) -->
- 코드 작성/수정 직후 정적 분석을 **테스트보다 먼저** 돌린다. 통과 후에만 필요한 테스트를 타겟 실행.
  - Dart/Flutter: `dart analyze`/`flutter analyze` (+ clean_architecture_linter) · TS/Node: `tsc --noEmit` + eslint · Python: `ruff`+`mypy`
- analyze 경고/에러는 test 전에 해소. 무지성 전체 test 반복 대신 정적 피드백 루프 우선 → 토큰 절감.
- 실행 검증도 전체가 아니라 바뀐 부분만 타겟한다.
<!-- END agent-verify-discipline -->

## PR 작성 규율 (public package)
<!-- BEGIN agent-pr-discipline (managed) -->
- `clean_architecture_linter`는 public package다. branch, commit, PR title/body/comment, release note 등 public GitHub metadata에 private Multica `ITT-*` key를 넣지 않는다.
- PR 본문은 org template를 사용하고 workspace `pr-fetch-template-ittae.sh` → validate → `pr-create-ittae.sh --body-file` 경로로 생성한다. private issue 연결란은 `해당 없음`으로 명시한다.
- 실제 검증 명령·결과와 미검증 범위, public API/lint semantics risk, rollback을 본문에 기록한다.
- PR은 ready까지 전환하되 agent가 merge, approve, force-push, protection 변경을 하지 않는다. 이 package는 human merge only다.
<!-- END agent-pr-discipline -->

## 프로젝트 지침 정본
<!-- BEGIN agent-project-reference (managed) -->
- 이 tool-specific 지침과 함께 root `AGENTS.md`의 project role·trust boundary·검증 계약을 반드시 따른다.
- 더 깊은 project context가 필요하면 root `CLAUDE.md`를 읽고, 충돌 시 repository required gate와 scoped project rule을 우선한다.
<!-- END agent-project-reference -->
