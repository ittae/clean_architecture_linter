# 🚀 TaskMaster 빠른 시작 가이드
## Clean Architecture Linter 프로젝트

### ✅ 현재 상태
```
✅ TaskMaster 초기화 완료
✅ AI 모델 설정 완료 (Claude Code - Sonnet)
✅ 샘플 PRD로 10개 Tasks 생성 완료
✅ 의존성 관계 자동 설정 완료
```

---

## 📚 핵심 명령어 (매일 사용)

### 1. 다음 작업 시작
```bash
# 다음에 할 작업 확인
task-master next

# 작업 상세 정보
task-master show 1

# 작업 시작 표시
task-master set-status --id=1 --status=in-progress
```

### 2. 작업 중 노트 추가
```bash
# 구현 진행 상황 기록
task-master update-subtask --id=1.1 \
  --prompt="RuleUtils.isInDomainLayer() 메서드 활용하여 구현"
```

### 3. 작업 완료
```bash
# 테스트 실행 후 완료 처리
task-master set-status --id=1 --status=done

# 다음 작업으로 이동
task-master next
```

---

## 🎯 실전 워크플로우

### 시나리오 1: 새 기능 추가

**Step 1: PRD 작성**
```bash
# PRD 파일 생성
cat > .taskmaster/docs/prd_new_feature.txt << 'EOF'
# PRD: UseCase Validation Rule

## 목적
Domain Layer의 UseCase가 올바른 패턴을 따르는지 검증

## 요구사항
1. UseCase는 call() 메서드를 가져야 함
2. 파일명은 *_usecase.dart 형식
3. 단일 책임 원칙 준수

## 산출물
- lib/src/rules/domain_rules/usecase_validation_rule.dart
- 테스트 및 예제 코드
EOF
```

**Step 2: Tasks 생성**
```bash
# PRD 파싱 (기존 tasks에 추가)
task-master parse-prd .taskmaster/docs/prd_new_feature.txt --append

# 전체 tasks 확인
task-master list
```

**Step 3: 복잡한 Task 세분화**
```bash
# 특정 task를 subtask로 확장
task-master expand --id=11 --research

# ⚠️ --research는 시간이 오래 걸림 (1-2분)
# 빠르게 하려면 --research 제거
task-master expand --id=11
```

**Step 4: 개발 시작**
```bash
# Claude Code에서 작업 시작
# 방법 1: Slash command 사용 (추천)
/tm-next

# 방법 2: CLI 사용
task-master next
task-master set-status --id=11 --status=in-progress
```

### 시나리오 2: 버그 수정

```bash
# 긴급 Task 추가
task-master add-task \
  --prompt="BUG: presentation → data import 감지 안됨 (상대 경로 문제)" \
  --research

# 즉시 작업 시작
task-master next
task-master set-status --id=11 --status=in-progress

# 디버깅 노트 기록
task-master update-subtask --id=11 \
  --prompt="원인: relative import '../data/...' 패턴 누락
  해결: RegExp 패턴에 '../' 추가
  테스트: bad_examples에 relative import 케이스 추가"

# 완료
task-master set-status --id=11 --status=done
```

### 시나리오 3: 리팩토링 프로젝트

```bash
# 리팩토링 PRD 작성
cat > .taskmaster/docs/prd_refactoring.txt << 'EOF'
# PRD: Rule Utils 공통화

## 배경
13개 lint rules에 중복 코드 존재

## 목표
- 공통 로직 RuleUtils로 추출
- 코드 중복 50% 감소

## 작업 범위
1. RuleUtils 설계
2. 13개 rule 리팩토링
3. 회귀 테스트
EOF

# Tasks 생성 및 확장
task-master parse-prd .taskmaster/docs/prd_refactoring.txt --append
task-master expand --all  # 모든 새 tasks 확장
```

---

## 🔥 Claude Code 통합

### Custom Slash Commands

**1. `/tm-next` - 다음 작업 시작**
```markdown
<!-- .claude/commands/tm-next.md -->
다음 TaskMaster 작업을 시작합니다.

Steps:
1. `task-master next` 실행
2. Task 상세 정보 확인: `task-master show <id>`
3. 구현 계획 제시
4. 사용자 승인 후 구현
```

**2. `/tm-done` - 작업 완료**
```markdown
<!-- .claude/commands/tm-done.md -->
현재 작업을 완료하고 다음 작업을 제안합니다.

Arguments: $ARGUMENTS (task id)

Steps:
1. 테스트 실행 및 검증
2. `task-master set-status --id=$ARGUMENTS --status=done`
3. 다음 작업 제안: `task-master next`
```

**3. `/tm-note` - 작업 노트 추가**
```markdown
<!-- .claude/commands/tm-note.md -->
현재 작업에 구현 노트를 추가합니다.

Arguments: $ARGUMENTS (task id and note)

Steps:
1. `task-master update-subtask --id=<id> --prompt="$ARGUMENTS"`
```

### 사용 예시
```bash
# Claude Code에서
/tm-next                          # 다음 작업 시작
/tm-note 1.1 "RuleUtils 활용"     # 노트 추가
/tm-done 1.1                      # 작업 완료
```

---

## 📊 진행 상황 확인

### Dashboard 보기
```bash
# 전체 진행 상황
task-master list

# 특정 상태만 필터링
task-master list --status=in-progress
task-master list --status=done
task-master list --priority=high
```

### 의존성 확인
```bash
# 의존성 검증
task-master validate-dependencies

# 특정 task의 의존성 확인
task-master show 5
```

---

## 🛠️ 유용한 Tips

### 1. Task 우선순위 변경
```bash
task-master update-task --id=3 --prompt="우선순위를 high로 변경"
```

### 2. Task 상태 변경
```bash
# 여러 상태 사용 가능
task-master set-status --id=2 --status=pending      # 대기
task-master set-status --id=2 --status=in-progress  # 진행중
task-master set-status --id=2 --status=done         # 완료
task-master set-status --id=2 --status=blocked      # 블록됨
task-master set-status --id=2 --status=deferred     # 연기
task-master set-status --id=2 --status=cancelled    # 취소
```

### 3. Task 의존성 추가
```bash
# Task 5는 Task 3이 완료되어야 시작 가능
task-master add-dependency --id=5 --depends-on=3
```

### 4. Git 연동
```bash
# Commit에 Task ID 포함
git commit -m "feat: add repository validation (task 1.2)"

# PR 생성
gh pr create \
  --title "Repository Validation Rule (tasks 1-6)" \
  --body "$(task-master show 1 --markdown)"
```

### 5. 병렬 개발 (Git Worktree)
```bash
# Feature별 독립 작업 공간
git worktree add ../linter-feat-a feature/repository-rule
git worktree add ../linter-feat-b feature/usecase-rule

# 각 worktree에서 독립적으로 task 진행
cd ../linter-feat-a && task-master next  # Task 1.x
cd ../linter-feat-b && task-master next  # Task 11.x
```

---

## ⚠️ 주의사항

### 1. AI 명령은 시간이 걸림
```bash
# 빠른 버전 (AI 호출 없음)
task-master expand --id=1

# 느린 버전 (1-2분, AI research 활용)
task-master expand --id=1 --research

# 복잡도 분석도 마찬가지
task-master analyze-complexity          # 빠름
task-master analyze-complexity --research  # 느림 (1-2분)
```

### 2. tasks.json 직접 수정 금지
```bash
# ❌ 직접 수정 금지
vi .taskmaster/tasks/tasks.json

# ✅ 명령어 사용
task-master update-task --id=1 --prompt="..."
task-master add-task --prompt="..."
```

### 3. Task 파일 재생성
```bash
# tasks.json이 수정되면 markdown 파일 재생성
task-master generate
```

---

## 📖 추가 리소스

- **상세 가이드**: `.taskmaster/TASKMASTER_실무_가이드.md`
- **TaskMaster 문서**: `.taskmaster/CLAUDE.md`
- **프로젝트 가이드**: `CLAUDE.md`

---

## 🎓 학습 경로

### 단계 1: 기본 익히기 (1일)
```bash
1. task-master list
2. task-master next
3. task-master show <id>
4. task-master set-status --id=<id> --status=done
```

### 단계 2: PRD 작성 (2-3일)
```bash
1. 실제 기능/버그를 PRD로 작성
2. task-master parse-prd 실행
3. 생성된 tasks 확인 및 수정
```

### 단계 3: 고급 기능 (1주)
```bash
1. Task 확장 (expand)
2. 복잡도 분석 (analyze-complexity)
3. 의존성 관리 (add-dependency)
4. Claude Code 통합 (slash commands)
```

### 단계 4: 워크플로우 최적화 (지속적)
```bash
1. Custom slash commands 작성
2. Git 연동 자동화
3. 병렬 개발 패턴 활용
```

---

## 🚀 지금 바로 시작하기

```bash
# 현재 프로젝트에 이미 샘플 tasks가 있습니다!
task-master list

# 첫 작업 시작
task-master next
task-master show 1
task-master set-status --id=1 --status=in-progress

# 또는 Claude Code에서
/tm-next
```

**Happy Coding! 🎉**
