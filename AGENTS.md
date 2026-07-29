<!-- AGENT_POLICY_MANAGED_BLOCK:START -->
# AGENTS.md

이 문서는 Codex/Copilot 계열 코딩 에이전트 공통 규칙이다.

## 공통 안전 규칙 (절대 우선)
- 삭제는 기본 허용이다. 작업에 필요하면 `rm`, `rmdir`, `git rm`을 사용한다. 절대 금지하지 않는다.
- 삭제 전 대상 경로를 특정한다. 추측으로 광범위 삭제하지 않는다.
- `rm -rf` / `find ... -delete` / `xargs rm` 등 재귀·일괄 삭제는 **대상이 명확할 때만** 사용한다.
- 고위험 경로는 사용자 확인 후: 홈 루트(`~`), 레포 `.git/`, 시크릿/ creds, 공유 runner·worktree 루트, 프로덕션 데이터.
- 복구가 중요하면 `trash`를 우선 고려하되, 도구/작업 흐름상 `rm`이 맞으면 `rm`을 쓴다.
- 대규모·모호한 정리 전: 영향 범위와 롤백 방법을 한 줄로 남긴다.

## 작업 품질 규칙
- 최소 수정 원칙: 필요한 범위만 변경
- 변경 전 1줄 계획, 변경 후 요약(무엇/왜/영향)
- 테스트/린트 가능하면 실행 후 결과 공유
- 기존 코드 스타일/아키텍처를 우선 존중하고, 리팩토링은 요청된 범위 내에서만 수행

## 관측·탐색 규율 (추정 금지의 구체적 실행)
- **잘린 출력으로 성공/실패를 판정하지 않는다.** `| tail`, `| head`를 거치면 exit code는 파이프의 것(대개 0)이라 실패를 가린다. 판정은 산출물 존재 확인 또는 전체 로그로 한다.
- **"없다 / 아니다 / 한 적 없다"에는 관측 범위를 붙인다.** "X가 없다"가 아니라 "이 디렉터리에 X가 없다". 한 곳의 부재를 전체의 부재로 일반화하지 않는다.
- **파일을 생성·수정하는 명령 전에 기존 방법을 1회 검색한다.** `rg`/`fd`로 그 일을 이미 하는 스크립트·설정·관행이 repo에 있는지 확인한다. 정본 도구를 두고 맨손 명령을 치면 기존 설정을 덮어쓴다.
- **Mac mini 기본 CLI 라우팅:** 텍스트=`rg`, 파일명=`fd`, AST/구조=`ast-grep`/`sg`, JSON=`jq`, YAML=`yq`, GitHub=`gh`, HTTP 스모크=`xh`(없으면 curl). Multica 플랫폼은 `multica` CLI만. `grep -r`/`find` 기본 탐색 금지. 툴 JSON은 raw로 넣지 말고 필터.
- **설정 생성기는 "생성"이 아니라 "덮어쓰기"로 취급한다.** `flutterfire config` 같은 도구는 기존 파일을 재작성한다. 실행 후 반드시 `git status`/`git diff`로 의도치 않은 변경을 확인한다.
- **로그는 원인부터 읽는다.** 에러 요약은 끝에 있어도 원인은 앞에 있다. 잘린 뒷부분만 보고 추론하면 헛다리를 짚는다.

## 설계 판단 규율
- **기각 근거가 무너지면 기각을 재검토한다.** 설계 문서에 "채택하지 않은 것" 목록을 적었으면, 새 검증 결과가 나올 때마다 그 목록을 다시 읽고 각 사유가 아직 유효한지 확인한다.
- **검증하지 않은 리스크를 근거로 기각하지 않는다.** 그래도 기각한다면 "미검증 추정"이라고 명시한다.
- **일반 패턴을 적용하기 전에 이 환경의 특수 제약을 먼저 나열한다.** 1인 개발, 개발 머신 = CI 러너, worktree 기반, 에이전트 다수 동시 작업. 일반적으로 옳은 패턴(예: "PR 산출물은 CI에서 만든다")이 여기서는 불필요한 비용일 수 있다.
- **도구를 평가하기 전에 "기존 자산으로 되는가"를 먼저 묻는다.**

## 개발 필수 베이스라인 (모든 개발 프로젝트)
- Clean Architecture 경계 유지 (모듈/레이어 책임 분리)
- 상태 관리 책임 분리 (state, side-effect, UI binding 분리)
- 에러 핸들링 표준화 (예외를 삼키지 말고 명시적으로 처리/전파)
- 사용자 노출 문자열 하드코딩 금지, 다국어(i18n) 리소스 사용

## Git/PR 규칙
- 브랜치/커밋/PR 단위를 작게 유지
- 커밋 메시지는 목적이 드러나게 작성
- PR 요약에 변경 범위, 리스크, 롤백 포인트 포함

## 검증 우선순위
1. 정적 분석/타입 체크
2. 단위 테스트
3. 통합/시나리오 테스트
4. 실행 검증(필요 시)

## 보고 형식 (짧고 명확하게)
- What changed
- Why
- Risk
- Next step

## 코드베이스 작업 원칙
- 먼저 구조를 파악하고, 변경 파일 수를 최소화
- 광범위 rename/reformat/restructure는 명시 요청 없으면 금지
- 성능/보안/안정성에 영향 있는 변경은 근거를 남길 것

## 실행 규칙
- 빌드/테스트/린트가 있으면 가능한 범위에서 실행
- 실패 시 즉시 원인 가설 + 재현 경로 + 다음 액션 보고

## Flutter 특화 규칙 (해당 프로젝트일 때)
- Feature 단위로 파일 배치 (`domain/data/presentation`)
- 상태관리는 Riverpod 패턴 준수 (Provider/Notifier 책임 분리)
- 테스트 우선순위: unit -> widget -> integration
- `flutter analyze`/`flutter test` 중 가능한 최소 검증은 반드시 실행

## 완료 조건 (Definition of Done)
- [ ] Clean Architecture 경계 준수
- [ ] 상태 관리 책임 분리
- [ ] 에러 핸들링 명시
- [ ] i18n 적용(하드코딩 문자열 제거)

## 산출물 규칙
- 완료 보고에 다음을 반드시 포함:
  - changed files
  - validation results
  - known risks
  - rollback plan

## Project Context (from README.md)
- # Clean Architecture Linter
- ## ✨ Key Features
- - 🛡️ **Automatic Clean Architecture Protection** - Write code freely, linter catches violations
- - 🎯 **34 Specialized Rules** - Comprehensive coverage of all Clean Architecture layers
- - 🚀 **Flutter-Optimized** - Built specifically for Flutter development patterns
- - 🎨 **Riverpod State Management** - Enforces 3-tier provider architecture (Entity  UI  Computed)
- - 📚 **Educational** - Learn Clean Architecture through guided corrections
- - ⚡ **Real-time Feedback** - Immediate warnings with actionable solutions
- - 🔧 **Zero Configuration** - Works out of the box with sensible defaults
- - 🧪 **Test-Aware** - Smart exceptions for test files and development contexts
- ## 📋 Rules Overview (34 Rules)
- ### 🌐 Core Clean Architecture Principles (6 rules)
<!-- AGENT_POLICY_MANAGED_BLOCK:END -->

## 이 레포 고유 지침
- 이 저장소는 Flutter 앱이 아니라 **Dart package (custom_lint rules / analyzer plugin)**.
- 패키지 코드 경로: `lib/src/rules/`, `lib/src/mixins/` — managed block의 `lib/features/...` 레이아웃을 **이 패키지 자체**에 적용하지 말 것.
- Vision / rule 등록 / Riverpod 3-tier 상세: `CLAUDE.md` (managed block 이후 섹션) 참조.


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
- ittae 조직 PR 본문은 `ittae/.github`의 `.github/PULL_REQUEST_TEMPLATE.md` 구조를 그대로 채운다. **필수 hard path:** `scripts/git/pr-fetch-template-ittae.sh` → `pr-body-validate-ittae.sh` (+ `.github/scripts/pr_body_lint.sh`) → `pr-create-ittae.sh --body-file`. **금지:** `gh pr create --body "짧은 요약"` / English Summary·Test plan으로 먼저 연 뒤 수정(workspace#77). bare create 차단 보조: `scripts/git/guard-gh-pr-create.sh`.
- 필수 섹션: 요약 / 목표·이유 / 변경 사항 / 범위 밖 / 관련 이슈(`Closes ITT-child` vs `Related ITT-parent`) / 실제 동작 증거(실행 환경·명령·결과 수치, 검증 안 한 영역까지 명시) / 위험(Risk tier T0~T3, rollback, 사람 결정 필요) / **PR metadata 확인**(assignee·labels·reviewers read-back) / UI 증빙 / 체크리스트.
- **섹션 목록의 정본은 `ittae/.github`의 `tools/pr_body_lint.sh`(또는 repo `.github/scripts/pr_body_lint.sh`)다.** 이 문서와 갈리면 스크립트가 이긴다 — `pr-body-lint` 체크가 org 전체 PR에서 이 스크립트로 본문을 검사하며, 누락 시 `missing section: <이름>`으로 실패한다. **올리기 전 로컬 검증이 필수**이며 `pr-create-ittae.sh`가 create 전에 돌린다.
- 모르는 항목은 지우지 말고 "미확인"/"해당 없음". 제목은 `<type>: ITT-123 한국어 요약` 또는 `<type>: 한국어 요약`. 본문 한국어, code/path/error 원문 유지.
- **PR 완성 시 draft를 해제한다** (`gh pr ready`) — draft는 리뷰·sweep 승격·자동 병합 파이프라인 전체에서 제외된다. ready 전환까지가 작업 완료다.
- **머지는 모든 체크 green일 때만** — 실패/대기 중 머지 금지 (서버 강제 없음, main-guard가 사후 적발). 사용자 확인 전 merge 금지.
- **재작업 후 머지 게이트:** 수정 push 뒤에는 **현재 head** 기준 CI + AI 재리뷰가 끝나기 전에 머지 금지. AI 재리뷰 생략은 문서화된 optional-unavailable 사유를 남긴 경우만(사유 창작 금지). GitHub가 승인 리뷰를 요구하면(`REVIEW_REQUIRED` / CODEOWNERS) **현재 head Approve** 필수(작성자 self-approve 불가 → 사용자 UI 승인). `needs-rework` / `ai-rejected` / `hold`면 머지 금지.
- **`gh pr merge --admin` / 보호규칙 우회 기본 금지.** 사용자가 그 PR에 `admin merge` / `우회 머지`를 명시한 경우만. "마무리/병합해줘" ≠ 우회 허가. 상세: workspace `policies/ittae-pr-autopilot.md` § Agent/Hermes merge discipline.
<!-- END agent-pr-discipline -->
