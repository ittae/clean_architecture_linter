# TaskMaster MCP 실무 적용 가이드
## Clean Architecture Linter 프로젝트

### 📋 목차
1. [시작하기](#1-시작하기)
2. [PRD 작성](#2-prd-작성)
3. [Task 생성 및 관리](#3-task-생성-및-관리)
4. [개발 워크플로우](#4-개발-워크플로우)
5. [실전 예제](#5-실전-예제)

---

## 1. 시작하기

### 현재 설정 상태
```bash
✅ TaskMaster 초기화 완료
✅ AI 모델 설정: claude-code (Sonnet)
✅ 프로젝트 구조: .taskmaster/ 디렉토리 생성됨
⏳ 다음 단계: PRD 작성 → Task 생성
```

### 주요 명령어
```bash
# Task 목록 확인
task-master list

# 다음 작업 가져오기
task-master next

# Task 상세 정보
task-master show <id>

# Task 상태 변경
task-master set-status --id=<id> --status=done
```

---

## 2. PRD 작성

### 2.1 PRD 템플릿 생성

새로운 기능이나 개선사항이 있을 때마다 PRD 문서를 작성합니다.

**예제: 새로운 Lint Rule 추가**
```markdown
# PRD: Repository Implementation 검증 Rule 추가

## 목적
Data Layer의 Repository 구현체가 Clean Architecture 원칙을 준수하는지 검증하는 Lint Rule을 추가한다.

## 요구사항

### 1. Repository 인터페이스 검증
- Repository 인터페이스는 domain layer에 위치해야 함
- 인터페이스 naming convention: `*Repository`
- 반환 타입은 domain entities만 사용

### 2. Repository 구현체 검증
- 구현체는 data layer에 위치해야 함
- Naming convention: `*RepositoryImpl`
- DataSource만 의존성으로 가져야 함
- Model을 Entity로 변환해야 함

### 3. 테스트 작성
- 정상 케이스 테스트
- 위반 케이스 테스트
- Error message 검증

### 4. 문서화
- CLAUDE.md 업데이트
- README.md 예제 추가
- example/ 디렉토리에 good/bad examples 추가

## 성공 기준
- [ ] Lint rule이 Repository 위반 사항을 정확히 감지
- [ ] 모든 테스트 통과
- [ ] CI/CD 파이프라인 통과
- [ ] 문서화 완료
```

### 2.2 PRD 파일 저장 위치
```bash
# 프로젝트 전체 기능 추가
.taskmaster/docs/prd.txt

# 특정 기능별 PRD (관리 편의성)
.taskmaster/docs/prd_repository_rule.txt
.taskmaster/docs/prd_performance_improvement.txt
```

---

## 3. Task 생성 및 관리

### 3.1 PRD에서 Task 생성

```bash
# PRD 파싱하여 초기 Task 생성
task-master parse-prd .taskmaster/docs/prd_repository_rule.txt

# 기존 Task에 추가 (append)
task-master parse-prd .taskmaster/docs/prd_new_feature.txt --append
```

**생성되는 Task 구조 예시:**
```
1. Repository Lint Rule 구현
   1.1 인터페이스 검증 로직 작성
   1.2 구현체 검증 로직 작성
   1.3 의존성 검증 추가

2. 테스트 작성
   2.1 Unit 테스트 작성
   2.2 Integration 테스트 추가

3. 문서화
   3.1 CLAUDE.md 업데이트
   3.2 예제 코드 추가
```

### 3.2 복잡도 분석 및 Task 확장

```bash
# 1. 복잡도 분석 실행
task-master analyze-complexity --research

# 2. 복잡도 리포트 확인
task-master complexity-report

# 3. 특정 Task 확장 (subtask로 분해)
task-master expand --id=1 --research

# 4. 모든 Task 자동 확장
task-master expand --all --research
```

**확장된 Task 예시:**
```
1. Repository Lint Rule 구현
   1.1 인터페이스 검증 로직 작성
       1.1.1 파일 경로 검증 (domain layer)
       1.1.2 Naming convention 검증
       1.1.3 반환 타입 검증 (Entity only)
   1.2 구현체 검증 로직 작성
       1.2.1 파일 경로 검증 (data layer)
       1.2.2 Naming convention 검증 (Impl suffix)
       1.2.3 의존성 검증 (DataSource only)
       1.2.4 Model → Entity 변환 검증
```

### 3.3 Task 수정 및 관리

```bash
# Task 추가
task-master add-task --prompt="CI/CD 파이프라인에 새 rule 추가" --research

# 특정 Task 업데이트
task-master update-task --id=1.2 --prompt="DataSource 의존성 검증 로직 추가"

# Subtask에 구현 노트 추가
task-master update-subtask --id=1.1.1 --prompt="lib/src/utils/path_checker.dart 파일 사용"

# Task id 이후 전체 업데이트 (pivot 발생 시)
task-master update --from=2 --prompt="테스트 전략 변경: integration test 추가"
```

---

## 4. 개발 워크플로우

### 4.1 일일 개발 루틴

```bash
# 1. 오늘 할 작업 확인
task-master next

# 출력 예시:
# Next available task: 1.1.1 - 파일 경로 검증 (domain layer)
# Priority: high
# Estimated time: 2 hours

# 2. Task 상세 정보 확인
task-master show 1.1.1

# 3. 작업 시작 표시
task-master set-status --id=1.1.1 --status=in-progress

# 4. 개발 진행 중 노트 추가
task-master update-subtask --id=1.1.1 --prompt="RuleUtils.isInDomainLayer() 메서드 활용"

# 5. 작업 완료
task-master set-status --id=1.1.1 --status=done

# 6. 다음 작업으로 이동
task-master next
```

### 4.2 Claude Code와 통합

**Slash Command 생성: `/tm-next`**
```markdown
<!-- .claude/commands/tm-next.md -->
다음 TaskMaster 작업을 가져와서 구현합니다.

Steps:
1. `task-master next`로 다음 작업 확인
2. `task-master show <id>`로 상세 정보 확인
3. `task-master set-status --id=<id> --status=in-progress`로 진행 중 표시
4. 구현 계획 제시
5. 사용자 승인 후 구현 시작
```

**Slash Command 생성: `/tm-done`**
```markdown
<!-- .claude/commands/tm-done.md -->
현재 작업을 완료하고 다음 작업을 제안합니다.

Arguments: $ARGUMENTS (task id)

Steps:
1. 구현 완료 확인 (테스트 실행)
2. `task-master set-status --id=$ARGUMENTS --status=done`
3. `task-master next`로 다음 작업 제안
```

### 4.3 Git과 연동

```bash
# Commit 메시지에 Task ID 포함
git commit -m "feat: add repository path validation (task 1.1.1)"

# PR 생성 시 Task 정보 활용
gh pr create --title "Repository Lint Rule (tasks 1.1-1.2)" \
  --body "$(task-master show 1 --markdown)"
```

---

## 5. 실전 예제

### 예제 1: 새로운 Lint Rule 추가

**Step 1: PRD 작성**
```bash
cat > .taskmaster/docs/prd_usecase_rule.txt << 'EOF'
# PRD: UseCase Naming Convention Rule

## 목적
Domain Layer의 UseCase가 Clean Architecture naming convention을 따르는지 검증

## 요구사항
1. UseCase 클래스명은 동사로 시작 (Get*, Create*, Update*, Delete*)
2. 파일명은 snake_case (get_user_usecase.dart)
3. call() 메서드 필수 구현
4. 단일 책임 원칙 준수 (하나의 비즈니스 로직만)

## 산출물
- lib/src/rules/domain_rules/usecase_naming_rule.dart
- test/usecase_naming_rule_test.dart
- example/ 디렉토리에 예제 추가
EOF
```

**Step 2: Task 생성 및 확장**
```bash
# PRD 파싱
task-master parse-prd .taskmaster/docs/prd_usecase_rule.txt --append

# 복잡도 분석
task-master analyze-complexity --from=4 --research

# Task 확장
task-master expand --id=4 --research
```

**Step 3: 개발 시작**
```bash
# Claude Code에서
/tm-next

# 또는 CLI에서
task-master next
task-master show 4.1
task-master set-status --id=4.1 --status=in-progress
```

**Step 4: 구현 및 완료**
```bash
# 구현 노트 추가
task-master update-subtask --id=4.1 \
  --prompt="DartLintRule 상속, visitClassDeclaration 사용"

# 완료 처리
task-master set-status --id=4.1 --status=done
```

### 예제 2: 버그 수정 워크플로우

```bash
# 1. 긴급 Task 추가
task-master add-task \
  --prompt="BUG: presentation layer가 data model import 감지 안됨" \
  --research

# 2. 우선순위 높은 Task로 작업
task-master next

# 3. 디버깅 노트 기록
task-master update-subtask --id=5.1 \
  --prompt="import 구문 파싱 로직에서 relative path 처리 누락"

# 4. 수정 완료
task-master set-status --id=5.1 --status=done
```

### 예제 3: 리팩토링 프로젝트

**대규모 리팩토링 PRD**
```markdown
# PRD: Rule Utils 공통화

## 배경
13개 lint rules에 중복 코드 존재 (파일 경로 체크, naming 검증 등)

## 목표
- 공통 로직을 RuleUtils로 추출
- 코드 중복 50% 이상 감소
- 테스트 커버리지 유지

## 작업 범위
1. RuleUtils 클래스 설계
2. 기존 13개 rule 리팩토링
3. 회귀 테스트 실행
4. 성능 벤치마크
```

**Task 관리**
```bash
# PRD 파싱
task-master parse-prd .taskmaster/docs/prd_refactoring.txt

# 복잡도 분석 (리팩토링은 복잡도 높음)
task-master analyze-complexity --research

# 모든 Task 상세 확장
task-master expand --all --research

# 진행 상황 모니터링
task-master list --status=in-progress
task-master list --status=done
```

---

## 6. Tips & Best Practices

### 6.1 효율적인 Task 관리

```bash
# 특정 범위만 복잡도 분석
task-master analyze-complexity --from=3 --to=5 --research

# Blocked task 관리
task-master set-status --id=2.3 --status=blocked
# 나중에 unblock
task-master set-status --id=2.3 --status=pending

# Task 의존성 추가
task-master add-dependency --id=3.1 --depends-on=2.2
```

### 6.2 문서화 자동화

```bash
# Task 완료 시 자동으로 CHANGELOG 업데이트
task-master show 1 --markdown >> CHANGELOG.md
```

### 6.3 Parallel Development

```bash
# Git worktree로 병렬 작업
git worktree add ../linter-feature-a feature/usecase-rule
git worktree add ../linter-feature-b feature/repository-rule

# 각 worktree에서 독립적으로 TaskMaster 사용
cd ../linter-feature-a && task-master next  # Task 4.x 작업
cd ../linter-feature-b && task-master next  # Task 5.x 작업
```

---

## 7. 문제 해결

### 7.1 AI 명령 실패 시

```bash
# API 키 확인
cat .env | grep API_KEY

# 다른 모델로 전환
task-master models --set-fallback gemini-2.5-pro

# 연구 모드 없이 실행 (빠름)
task-master expand --id=1  # --research 플래그 제거
```

### 7.2 Task 파일 동기화 이슈

```bash
# Task markdown 재생성
task-master generate

# 의존성 문제 수정
task-master fix-dependencies

# ⚠️ 주의: tasks.json 직접 수정 금지!
```

---

## 8. 다음 단계

1. **첫 PRD 작성하기**
   - 현재 진행 중인 기능이나 버그 픽스를 PRD로 작성
   - `.taskmaster/docs/prd.txt`에 저장

2. **Task 생성 및 시작**
   ```bash
   task-master parse-prd .taskmaster/docs/prd.txt
   task-master analyze-complexity --research
   task-master expand --all --research
   task-master next
   ```

3. **개발 루틴 확립**
   - 매일 `task-master next`로 시작
   - 구현 노트를 `update-subtask`로 기록
   - 완료 시 `set-status --status=done`

4. **Claude Code 통합**
   - Custom slash commands 생성 (`/tm-next`, `/tm-done`)
   - MCP 활용하여 자동화

---

## 참고 자료

- TaskMaster 공식 문서: `.taskmaster/CLAUDE.md`
- 프로젝트 가이드: `CLAUDE.md`
- Clean Architecture 가이드: `docs/CLEAN_ARCHITECTURE_GUIDE.md`
