<!-- AGENT_POLICY_MANAGED_BLOCK:START -->
# GEMINI.md

Gemini CLI 작업 시 적용되는 규칙.

## 공통 안전 규칙 (절대 우선)
- 절대 실행 금지: `rm`, `rmdir`, `git rm`
- 우회성 삭제도 금지: `rm -rf`, `find ... -delete`, `xargs rm` 등
- 삭제가 필요하면 즉시 중단 후 사용자 확인 + 안전 대안 제시 (`trash` 우선)
- 대규모/파괴적 변경 전: 영향 범위, 롤백 방법, 승인 여부를 먼저 확인

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

## 작업 방식
- 긴 컨텍스트를 읽더라도 결론/액션 먼저 제시
- 코드 제안은 바로 실행 가능한 형태 우선
- 모호성은 추정하지 말고 확인 질문으로 처리

## 품질 기준
- 기존 아키텍처/스타일 유지
- 에러 케이스와 경계 조건을 함께 고려
- 필요 시 테스트 아이디어까지 제안

## Flutter 특화 규칙 (해당 프로젝트일 때)
- 하드코딩 문자열 대신 l10n 사용
- 과도한 위젯 rebuild 유발 패턴 회피
- 기능 변경 시 최소 검증 명령(예: analyze/test) 제안 또는 실행

## 완료 조건 (Definition of Done)
- [ ] 아키텍처 경계 유지
- [ ] 상태 관리 책임 분리
- [ ] 에러 경로 처리 명시
- [ ] i18n 적용

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

## 검색·컨텍스트 규율 (토큰 효율)
<!-- BEGIN agent-search-discipline (managed) -->
- 코드/텍스트 검색은 `rg`, 파일 탐색은 `fd`, 구조(AST) 매칭은 `ast-grep`/`sg` (`grep -r`/`find`/정규식 대신).
- 파일을 통째로 읽지 않는다. `rg`/`ast-grep`로 위치를 특정한 뒤 필요한 심볼/라인 범위만 읽는다.
- 툴 결과 JSON/YAML을 raw로 컨텍스트에 넣지 않는다. `jq`/`yq`로 필요한 필드만 필터한다.
- GitHub는 `gh`, HTTP 스모크는 `xh`(없으면 `curl`). Multica 플랫폼은 `multica` CLI만.
- 광범위 매칭을 통째로 프롬프트에 넣지 않는다. 범위를 좁히거나 count만 확인한다.
- 목적: 토큰 낭비·환각(길 잃음) 방지. Multica 할당 에이전트도 workspace context/agent instructions의 Mac mini CLI routing과 동일 적용.
<!-- END agent-search-discipline -->
