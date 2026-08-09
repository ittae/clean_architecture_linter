<!--
에이전트 PR 작성 기준: 사용자에게 보이는 설명은 한국어로, code/command/file path/ITT key는 원문 유지.
-->

## 🌷 요약

- **머지 대상 아닌 임시 검증 PR입니다.** `$RUNNER_TEMP` 전환이 self-hosted 러너 2개(ittae, ittae-light) 동시 실행 상황에서 실제로 격리되는지 확인하기 위해, PR #47과 별개의 concurrency 그룹을 가진 두 번째 relay 이벤트를 만듭니다.

## 🧭 목표 / 이유

- PR #47에 이미 `concurrency: group: multica-relay-${{ pr_number }}`가 있어 **같은 PR 안에서는** relay job이 겹치지 않습니다. 두 러너가 실제로 동시에 서로 다른 job을 처리하는 상황을 재현하려면 **다른 PR 번호**(= 다른 concurrency 그룹)가 필요해서 이 PR을 만들었습니다.
- base를 `main`이 아니라 PR #47의 브랜치로 잡아서, diff는 마커 파일 1개로만 좁혔습니다 — PR #47의 나머지 변경사항과 중복 diff가 안 보이게 하기 위함입니다.

## 🔧 변경 사항

- `CONCURRENCY_TEST_MARKER.md` 신규 추가: 내용 없는 타임스탬프 마커. 이 PR의 유일한 목적은 relay 워크플로를 한 번 더 트리거하는 것입니다.

## 🚫 범위 밖

- 실제 코드/워크플로 변경 — 이 PR은 순수하게 두 번째 relay 이벤트를 만들기 위한 트리거입니다.
- 머지 — 검증 후 닫고 브랜치 삭제합니다.

## 🐙 관련 이슈

- 해당 없음

## 🧪 실제 동작 증거 (Real Behavior Proof, 필수)

- 실제 실행 환경: self-hosted 러너(ittae 또는 ittae-light, 배정은 GitHub 스케줄러가 결정), 이 PR과 PR #47의 relay job을 근접 시각에 트리거
- 실행한 명령 / 조작: 이 PR 오픈 직후 로그에서 `Using RUNNER_TEMP=...` 줄로 실제 배정된 러너와 경로를 PR #47 쪽과 대조
- 결과 증거: (오픈 후 채워짐)
- 검증한 시나리오: 두 PR의 relay job이 서로 다른 `$RUNNER_TEMP` 경로를 쓰는지, 서로의 응답/stderr 파일을 침범하지 않는지
- 검증하지 않은 영역: 진짜 밀리초 단위 동시 실행(두 PR 이벤트가 GitHub 큐잉을 통과하는 시점 차이는 완전히 통제 불가)

## 🧯 위험 / 리뷰 초점 / 되돌리기

- Risk tier: `T0 docs/test only`
- 위험 영역:
  - [ ] auth / permission / privacy
  - [ ] payment / monetization / IAP / AdMob
  - [ ] data migration / storage
  - [ ] dependency / build / CI / deploy
  - [ ] broad refactor / behavior change
  - [ ] user-facing copy / brand quality
  - [x] 없음
- AI 리뷰어가 특히 봐야 할 점: 해당 없음(머지 대상 아님)
- 리뷰하지 않아도 되는 영역: 전체
- 읽는 순서: 해당 없음
- Rollback plan: PR 닫고 브랜치·마커 파일 삭제
- 사람 결정 필요:
  - [x] 없음 — 에이전트 판단으로 진행 가능

## 🧷 PR metadata 확인

- Assignee: `@me`
- Labels: 미확인 — 생성 후 read-back으로 기록
- Reviewers: 미확인
- Read-back:
  ```bash
  gh pr view <number> --json url,assignees,labels,reviewRequests
  ```

## 🖼️ UI / 시각 변경 증빙

- [x] 이 PR은 위 성격의 UI/시각 변경을 포함하지 않음

## ✅ PR 체크리스트

- [x] PR title이 `<type>: 한국어 요약` 형식이고, 동사가 들어간 완전한 요약이다.
- [x] 사용자에게 보이는 PR 본문은 한국어로 작성했다.
- [x] 내부 코드네임·축약어를 본문에서 풀어 썼거나 정의 문서를 링크했다.
- [x] 변경 사항 bullet이 파일명 나열이 아니라 검증 가능한 동작 주장이다.
- [x] 목표, 변경 사항, 범위 밖, 실제 동작 증거, 위험/되돌리기를 채웠다.
- [x] Multica 이슈가 있으면... — 해당 없음
- [x] user-owned repo PR이면 `--assignee @me`를 적용했다.
- [x] labels/reviewers 누락 시 사유를 숨기지 않고 기록했다.
- [x] PR 생성/보정 후 metadata read-back 결과를 본문 또는 댓글에 기록했다.
- [x] UI/시각 변경이면 screenshot/preview 또는 미첨부 사유를 적었다.

