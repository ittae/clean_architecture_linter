## 이 레포 고유 지침
- 이 저장소는 Flutter 앱이 아니라 외부 사용자에게 배포되는 **public Dart package (`analysis_server_plugin` 기반 Clean Architecture linter)**.
- 패키지 구현 경로는 `lib/src/rules/`, `lib/src/mixins/`, plugin entrypoint는 `lib/clean_architecture_linter.dart`다. 예제/fixture의 `lib/features/...`는 소비자 앱 lint semantics를 검증하기 위한 입력이며, agent 구현 레이아웃으로 해석하지 않는다.
- lint semantics와 agent 운영 규칙을 분리한다. public GitHub metadata에 private Multica `ITT-*` key를 노출하지 않고, PR은 human merge only로 둔다.
- 검증은 root `dart analyze`, root `dart test`, `cd example && dart analyze`, `cd poc_v2/consumer_riverpod_lint && dart analyze`를 기준으로 한다.
- 상세 규칙 / Vision / rule 등록: `CLAUDE.md` 참조.

<!-- BEGIN agent-owner-brief (managed) -->
## 성준님 브리프 (작업 전에 먼저 읽는다)

정본은 workspace `policies/owner-brief.md`다. 다른 지침과 충돌하면 결정 규칙은 이 블록을 따르고, 금지 사항은 `policies/owner-rules.md`를 따른다.

**목표.** 성준님이 손대지 않아도 돌아가는 앱이 순이익을 내게 한다. 사업의 월 순이익이 500만원이 되면 성준님은 퇴사한다. 지금 앱 매출은 0이다. 모든 작업은 이 거리를 줄이거나, 성준님의 손을 덜거나, 사용자가 좋아할 이유를 늘려야 한다.

**돈의 원칙.** 돈은 사용자가 원해서 내는 것이다. 사용자를 속이는 결제 화면, 해지를 막는 흐름, 과한 알림은 만들지 않는다. 사용자의 말(리뷰·추천)이 매출보다 먼저 오른다.

**완료의 기준.**
- `## Result`의 `evidence:` 줄이 `done_evidence`를 충족한다. 이 줄이 비어 있으면 완료가 아니다.
- 작업하는 동안 성준님이 손댄 횟수가 0이다.
- 성준님께 보내는 결과는 화면 캡처, 짧은 영상, 숫자 한 줄 중 하나다. 1분 안에 판단할 수 있어야 한다. 성준님의 시간은 주 4시간뿐이다. 코드와 diff는 보내지 않는다.

**초점** (갱신일 2026-10-22. 이 날짜에서 8일이 지나면 이 목록은 무시한다)
- ittae 0.5, 11월 초: 1인 창업자와 크리에이터를 위한 매니저 앱. 아침에는 하루가 이미 정리돼 있고, 때맞춰 알림이 오고, 밤에는 확인만 누른다. 결제할 수 있어야 한다.
- nebtoon: 스토어에 한 번 제출한다. 기능은 추가하지 않는다.
- h.itae 카드뉴스: 지금처럼 봇이 운영한다.
- 위 세 가지 밖의 작업과, 지표를 움직이지 못하는 시스템 개선은 하지 않는다.

**스스로 결정한다.**
1. 지표 셋(순이익, 성준님의 손, 사용자의 말) 중 무엇을 움직이는지 한 줄로 쓰지 못하면 하지 않는다.
2. 되돌릴 수 있는 결정은 묻지 않고 한다. 되돌릴 수 없는 일(키, prd 데이터, 스토어 제출, 결제 실행)에서만 멈춘다.
3. 두 방법이 비슷하면 성준님의 손이 덜 가는 쪽을 고른다. 돈과 성준님의 손이 충돌해도 손을 지킨다.
4. 수익이 나기 전의 저장소에서는 다듬기보다 출시가 먼저다.
5. 막혀도 묻지 않는다. `blocked` 또는 `needs-info`를 남기고 멈춘다. 성준님께 가져가는 안건은 자본 배분, 인력, 최종 승인 세 가지뿐이다.

**시작하기 전에.** 같은 goal의 열린 이슈나 PR이 있으면 `no-op`으로 끝낸다. 브리프와 이슈의 Constraints를 첫 답글에 되읽는다. 자기 lane에 해당하는 `docs/known-mistakes.md` 항목을 읽는다. 같은 방법이 두 번 실패하면 방법을 바꾸고 `mistake:` 줄을 남긴다.
<!-- END agent-owner-brief -->

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
- 텍스트 검색은 `rg`, 파일명·최근 변경은 `fd`(`find` 금지), 구조(AST) 매칭은 `ast-grep`. Dart는 완전한 문맥 + `--selector`로 쓴다: `ast-grep run -l dart -p 'void f(){ print($A); }' --selector call_expression lib` (맨 `print($A)`는 0건, exit 1은 매치 없음). `customLanguages`로 `dart`를 재등록하지 않는다(상세: workspace `policies/worker-contract.md` §2).
- 파일을 통째로 읽지 않는다. 위치를 특정한 뒤 필요한 범위만 읽고, 툴 결과 JSON/YAML은 `jq`/`yq`로 필요한 필드만 남긴다. GitHub는 `gh`, HTTP 스모크는 `xh`(없으면 `curl`), Multica는 `multica` CLI만.
- 이 필터 규율은 조회(read)에만 적용한다. 상태를 바꾸는 명령(`git push`, `gh pr create/edit/merge`, `--apply`, 배포·설정 생성)은 출력을 `| tail`/`| head`로 자르지 않는다. 에러는 잘린 부분에 숨고 마지막 줄은 성공처럼 보인다.
- 쓰기 명령은 실행 뒤 목적지를 조회해 확인한다. `push` 성공은 PR 반영이 아니다 — `gh pr view <n> --json state,commits`.
<!-- END agent-search-discipline -->

## 검증 규율 (analyze 먼저, test 나중)
<!-- BEGIN agent-verify-discipline (managed) -->
- 코드 작성/수정 직후 정적 분석을 **테스트보다 먼저** 돌린다. 통과 후에만 필요한 테스트를 타겟 실행.
  - **Dart/Flutter (`analysis_options.yaml`에 `plugins:` 있는 repo):** 게이트는 VS Code/Cursor **Problems**와 동일 소스인 `dart analyze`다 (`riverpod_lint`, `clean_architecture_linter` 등). **`flutter analyze`만으로 통과 선언·PR 금지** — 플러그인 진단을 놓쳐 Problems가 남은 채로 CI green이 된다. Multica/Codex/Cursor 에이전트도 동일. SoT는 repo 종류로 갈린다. **sentinel 없는 repo:** `dart analyze --fatal-infos`(또는 그것을 호출하는 `./scripts/verify.sh` / `--quick`)의 exit 0이 통과 증거다. **lint sentinel(`lib/zz_lint_sentinel/`)이 있는 repo:** 통과 증거는 `bash scripts/analyze.sh`의 exit 0뿐이고, `verify.sh`는 그 래퍼를 호출할 때만 인정한다. `scripts/analyze.sh`는 clean_architecture_linter `tools/lint_sentinel/check.sh`의 사본이며, 래퍼가 아직 없으면 그 파일을 `scripts/analyze.sh`로 복사한 뒤 호출한다. sentinel이 있는 repo에서만 단독 `dart analyze`는 통과 증거가 아니다: 플러그인이 전달되면 sentinel 2행(`riverpod_keep_alive`·`presentation_no_throw`, 경로 `lib/zz_lint_sentinel/`)만 허용 진단이고 그 외는 0건이어야 하며, 0행·exit 0은 깨끗함이 아니라 플러그인 미수신(실패, 재시도는 래퍼가 수행)이다.
  - **Dart/Flutter (`plugins:` 없는 repo):** 플러그인 진단이 없으므로 게이트는 `dart analyze --fatal-infos`(또는 그것을 호출하는 `./scripts/verify.sh`) exit 0. `--fatal-infos` 없는 `dart analyze`와 `flutter analyze --no-fatal-infos` 결과는 통과 증거로 쓰지 않는다.
  - TS/Node: `tsc --noEmit` + eslint · Python: `ruff`+`mypy`
- analyze 이슈(Problems)는 test 전에 **0건**(sentinel repo는 위 2행 제외). "flutter analyze OK"만 증거로 쓰지 않는다.
- 실행 검증도 전체가 아니라 바뀐 부분만 타겟한다.
<!-- END agent-verify-discipline -->

## PR 작성 규율 (public package)
<!-- BEGIN agent-pr-discipline (managed) -->
- `clean_architecture_linter`는 public package다. branch, commit, PR title/body/comment, release note 등 public GitHub metadata에 private Multica `ITT-*` key를 넣지 않는다.
- PR 본문은 org template를 사용하고 workspace `pr-fetch-template-ittae.sh` → validate → `pr-create-ittae.sh --body-file` 경로로 생성한다. private Multica 이슈 키는 public metadata에 넣지 않는다. 해당 없는 섹션은 지우고, "미확인" 또는 "해당 없음" placeholder는 쓰지 않는다.
- 한 스토리이고 effective 800 cap 안이면 workspace `scripts/git/pr-create-ittae.sh` 단일 PR. 레이어가 여러 개이거나 그 cap을 넘기면 workspace `scripts/git/stack-submit-ittae.sh`만 사용한다. bare `gh stack submit`와 브랜치 인자 `gh stack link`는 금지. 정본: workspace `policies/ittae-gh-stack.md`.
- 실제 검증 명령·결과와 미검증 범위, public API/lint semantics risk, rollback을 본문에 기록한다.
- PR은 ready까지 전환하되 agent가 merge, approve, force-push, protection 변경을 하지 않는다. 이 package는 human merge only다.
<!-- END agent-pr-discipline -->

## 프로젝트 지침 정본
<!-- BEGIN agent-project-reference (managed) -->
- 이 tool-specific 지침과 함께 root `AGENTS.md`의 project role·trust boundary·검증 계약을 반드시 따른다.
- 더 깊은 project context가 필요하면 root `CLAUDE.md`를 읽고, 충돌 시 repository required gate와 scoped project rule을 우선한다.
<!-- END agent-project-reference -->
