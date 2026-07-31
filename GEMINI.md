## 이 레포 고유 지침
- 이 저장소는 Flutter 앱이 아니라 외부 사용자에게 배포되는 **public Dart package (`analysis_server_plugin` 기반 Clean Architecture linter)**.
- 패키지 구현 경로는 `lib/src/rules/`, `lib/src/mixins/`, plugin entrypoint는 `lib/clean_architecture_linter.dart`다. 예제/fixture의 `lib/features/...`는 소비자 앱 lint semantics를 검증하기 위한 입력이며, agent 구현 레이아웃으로 해석하지 않는다.
- lint semantics와 agent 운영 규칙을 분리한다. public GitHub metadata에 private Multica `ITT-*` key를 노출하지 않고, PR은 human merge only로 둔다.
- 검증은 root `dart analyze`, root `dart test`, `cd example && dart analyze`, `cd poc_v2/consumer_riverpod_lint && dart analyze`를 기준으로 한다.
- 상세 규칙: `CLAUDE.md` 참조.


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

## PR 작성 규율 (org 템플릿 준수)
<!-- BEGIN agent-pr-discipline (managed) -->
- ittae 조직 PR 본문은 `ittae/.github`의 `.github/PULL_REQUEST_TEMPLATE.md` 구조를 그대로 채운다. **필수 hard path:** `scripts/git/pr-fetch-template-ittae.sh` → `pr-body-validate-ittae.sh` (+ `.github/scripts/pr_body_lint.sh`) → `pr-create-ittae.sh --body-file`. **금지:** `gh pr create --body "짧은 요약"` / English Summary·Test plan으로 먼저 연 뒤 수정(workspace#77).
- 필수 섹션: 요약 / 목표·이유 / 변경 사항 / 범위 밖 / 관련 이슈(`Closes ITT-child` vs `Related ITT-parent`) / 실제 동작 증거(실행 환경·명령·결과 수치, 검증 안 한 영역까지 명시) / 위험(Risk tier T0~T3, rollback, 사람 결정 필요) / **PR metadata 확인**(assignee·labels·reviewers read-back) / UI 증빙 / 체크리스트.
- **섹션 목록의 정본은 `ittae/.github`의 `tools/pr_body_lint.sh`(또는 repo `.github/scripts/pr_body_lint.sh`)다.** 이 문서와 갈리면 스크립트가 이긴다 — `pr-body-lint` 체크가 org 전체 PR에서 이 스크립트로 본문을 검사하며, 누락 시 `missing section: <이름>`으로 실패한다. **올리기 전 로컬 검증이 필수**이며 `pr-create-ittae.sh`가 create 전에 돌린다.
- 모르는 항목은 지우지 말고 "미확인"/"해당 없음". 제목은 `<type>: ITT-123 한국어 요약` 또는 `<type>: 한국어 요약`. 본문 한국어, code/path/error 원문 유지.
- **PR 완성 시 draft를 해제한다** (`gh pr ready`) — draft는 리뷰·sweep 승격·자동 병합 파이프라인 전체에서 제외된다. ready 전환까지가 작업 완료다.
- **머지는 모든 체크 green일 때만** — 실패/대기 중 머지 금지 (서버 강제 없음, main-guard가 사후 적발). 사용자 확인 전 merge 금지.
- **재작업 후 머지 게이트:** 수정 push 뒤에는 **현재 head** 기준 CI + AI 재리뷰가 끝나기 전에 머지 금지. AI 재리뷰 생략은 문서화된 optional-unavailable 사유를 남긴 경우만(사유 창작 금지). GitHub가 승인 리뷰를 요구하면(`REVIEW_REQUIRED` / CODEOWNERS) **현재 head Approve** 필수(작성자 self-approve 불가 → 사용자 UI 승인). `needs-rework` / `ai-rejected` / `hold`면 머지 금지.
- **`gh pr merge --admin` / 보호규칙 우회 기본 금지.** 사용자가 그 PR에 `admin merge` / `우회 머지`를 명시한 경우만. "마무리/병합해줘" ≠ 우회 허가. 상세: workspace `policies/ittae-pr-autopilot.md` § Agent/Hermes merge discipline.
<!-- END agent-pr-discipline -->
