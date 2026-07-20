<!--
에이전트 PR 작성 기준:
- 사용자에게 보이는 설명은 한국어로 작성합니다.
- code, command, file path, API name, status, error, Conventional Commit type, ITT key는 원문을 유지합니다.
- 모르는 항목은 지우지 말고 "미확인" 또는 "해당 없음"으로 적습니다.
- 작은 PR 권장: 한 번에 200줄 이하, 이상적으로 50줄 내외.
-->

## 🌷 요약

<!-- 사용자가 10초 안에 이해할 수 있게 1~3줄로 요약합니다. -->

-

## 🧭 목표 / 이유

<!-- 이 PR이 왜 필요한지, 사용자/운영/제품에 어떤 변화가 생기는지 적습니다. -->

-

## 🔧 변경 사항

<!-- 실제로 바꾼 것을 bullet로 적습니다. 파일명보다 동작/정책/계약 중심으로 설명합니다. -->

-

## 🚫 범위 밖

<!-- 이번 PR에서 의도적으로 하지 않은 일. 에이전트가 범위를 넘지 않았는지 검토하기 위한 섹션입니다. -->

-

## 🐙 관련 이슈

<!-- GitHub issue는 GitHub native keyword를 사용: Closes #123 / Fixes #123 -->
<!-- Multica issue는 아래 형식을 사용. 실행 child만 Closes, 부모/목표/맥락 이슈는 Related. -->
<!-- Closes ITT-123 -->
<!-- Related ITT-456 -->

## 🧪 실제 동작 증거 (Real Behavior Proof, 필수)

> CI, unit test, lint 결과만으로는 충분하지 않습니다.
> 실제 실행 로그, 스크린샷, 녹화, 터미널 출력, 또는 실제 환경 관측 결과를 첨부하세요.

- 실제 실행 환경:
- 실행한 명령 / 조작:
- 결과 증거:
- 검증한 시나리오:
- 검증하지 않은 영역:
- 증거가 부족하다면 그 이유:

## 🧯 위험 / 리뷰 초점 / 되돌리기

<!-- 에이전트는 위험을 낮게 보더라도 근거를 적습니다. -->

- Risk tier: `T0 docs/test only` | `T1 low-risk code` | `T2 product/runtime behavior` | `T3 security/payment/data/deploy/store`
- 위험 영역:
  - [ ] auth / permission / privacy
  - [ ] payment / monetization / IAP / AdMob
  - [ ] data migration / storage
  - [ ] dependency / build / CI / deploy
  - [ ] broad refactor / behavior change
  - [ ] user-facing copy / brand quality
  - [ ] 없음
- AI 리뷰어가 특히 봐야 할 점:
- 리뷰하지 않아도 되는 영역:
- Rollback plan:
- 사람 결정 필요:
  - [ ] 없음 — 에이전트 판단으로 진행 가능
  - [ ] 제품 / UX 결정 필요
  - [ ] 비용 / 수익 영향 결정 필요
  - [ ] 보안 / 데이터 위험 승인 필요
  - [ ] 릴리즈 타이밍 결정 필요

## 🧷 PR metadata 확인

<!-- user-owned repo PR은 생성 기본값을 보정하고 read-back 결과를 적습니다. -->

- Assignee: `@me` 또는 `<login>`
- Labels: `<labels>` 또는 `없음 — 사유: <missing/permission/unavailable>`
- Reviewers: `<reviewers>` 또는 `reviewer unavailable`
- Read-back:
  ```bash
  gh pr view <number> --json url,assignees,labels,reviewRequests
  ```

## 🖼️ UI / 시각 변경 증빙

> 적용 기준은 저장소 이름이 아니라 변경 성격입니다. Flutter, React, web/mobile UI, screenshot 생성, design/layout/component 변경처럼 결과를 눈으로 봐야 판단되는 변경이면 저장소와 무관하게 시각 증빙이 필요합니다.

- [ ] 이 PR은 위 성격의 UI/시각 변경을 포함하지 않음
- [ ] UI/시각 변경 포함 → 아래 중 하나를 채움
  - screenshot/preview 첨부: <이미지 또는 링크>
  - 미첨부 사유: <왜 첨부가 불가능/불필요한지>

## ✅ PR 체크리스트

- [ ] PR title이 `<type>: ITT-123 한국어 요약` 또는 `<type>: 한국어 요약` 형식이다.
- [ ] 사용자에게 보이는 PR 본문은 한국어로 작성했다.
- [ ] 목표, 변경 사항, 범위 밖, 실제 동작 증거, 위험/되돌리기를 채웠다.
- [ ] Multica 이슈가 있으면 branch 이름·title·body 중 하나 이상에 `ITT-123` 키가 있고, `Closes ITT-child` / `Related ITT-parent`를 구분했다.
- [ ] user-owned repo PR이면 `--assignee @me` 또는 생성 직후 assignee 보정을 적용했다.
- [ ] labels/reviewers 누락 시 사유를 숨기지 않고 기록했다.
- [ ] PR 생성/보정 후 metadata read-back 결과를 본문 또는 댓글에 기록했다.
- [ ] UI/시각 변경이면 screenshot/preview 또는 미첨부 사유를 적었다.
