# 🏛️ Clean Architecture 팀 강제 가이드

## 🎯 우리 팀이 모든 규칙을 강제하고 싶다면?

### 방법 1: 분석 옵션 설정 (추천)

**프로젝트 루트의 `analysis_options.yaml`:**

```yaml
include: package:lints/recommended.yaml

analyzer:
  plugins:
    - custom_lint

  # 모든 lint 문제를 오류로 처리
  errors:
    # Custom lint 규칙들을 모두 error로 승격
    domain_purity: error
    consolidated_entity_rule: error
    consolidated_usecase_rule: error
    domain_model_validation: error
    business_logic_isolation: error
    dependency_inversion: error
    repository_interface: error

custom_lint:
  # 모든 규칙 활성화 (기본값)
```

### 방법 2: Git Hooks 활용 (강력 추천)

**`.git/hooks/pre-commit` 파일 생성:**

```bash
#!/bin/sh
echo "🔍 Clean Architecture 규칙 검사 중..."

# 모든 warning과 info도 error로 처리
dart analyze --fatal-infos --fatal-warnings

if [ $? -ne 0 ]; then
  echo ""
  echo "❌ Clean Architecture 규칙 위반 발견!"
  echo "💡 수정 방법:"
  echo "   1. 위의 오류 메시지를 확인하세요"
  echo "   2. Clean Architecture 원칙에 따라 코드를 수정하세요"
  echo "   3. 'dart analyze'로 재검사하세요"
  echo ""
  exit 1
fi

echo "✅ Clean Architecture 규칙 통과!"
```

**실행 권한 부여:**
```bash
chmod +x .git/hooks/pre-commit
```

### 방법 3: CI/CD 파이프라인 강제

**GitHub Actions 예시 (`.github/workflows/clean_architecture.yml`):**

```yaml
name: Clean Architecture Check

on: [push, pull_request]

jobs:
  clean-architecture:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - uses: dart-lang/setup-dart@v1
      with:
        sdk: stable

    - name: Install dependencies
      run: dart pub get

    - name: Check Clean Architecture (STRICT)
      run: |
        echo "🏛️ Checking Clean Architecture compliance..."
        dart analyze --fatal-infos --fatal-warnings

        if [ $? -ne 0 ]; then
          echo "❌ BUILD FAILED: Clean Architecture violations detected!"
          echo "🚫 This commit violates our architectural standards."
          echo "📋 Action required: Fix all violations before merging."
          exit 1
        fi

        echo "✅ Clean Architecture compliance verified!"
```

### 방법 4: IDE 설정 (VSCode)

**`.vscode/settings.json`:**

```json
{
  "dart.analysisExcludedFolders": [],
  "dart.showTodos": false,
  "dart.analysisServerFolding": false,

  // 모든 lint 문제를 error로 표시
  "dart.showLintNames": true,
  "dart.previewLsp": true,

  // 저장 시 자동 분석
  "editor.codeActionsOnSave": {
    "source.fixAll": true
  },

  // Clean Architecture 위반 시 빨간색으로 강조
  "workbench.colorCustomizations": {
    "editorError.foreground": "#ff0000",
    "editorWarning.foreground": "#ff6600"
  }
}
```

## 🚀 팀 적용 단계별 가이드

### Phase 1: 팀 합의 (1주)
```yaml
# 우선 info 레벨로 시작
analyzer:
  errors:
    domain_purity: info
    layer_dependency: info
```

### Phase 2: 경고 단계 (2-3주)
```yaml
# warning으로 상향
analyzer:
  errors:
    domain_purity: warning
    layer_dependency: warning
    dependency_inversion: warning
```

### Phase 3: 완전 강제 (4주 후)
```yaml
# 모든 규칙 error로 강제
analyzer:
  errors:
    domain_purity: error
    consolidated_entity_rule: error
    consolidated_usecase_rule: error
    domain_model_validation: error
    business_logic_isolation: error
    dependency_inversion: error
    repository_interface: error
```

## 💪 팀 강제 모드 활성화

**즉시 모든 규칙을 강제하고 싶다면:**

1. **`analysis_options.yaml` 업데이트:**
```yaml
include: package:clean_architecture_linter/example_configurations/team_strict.yaml
```

2. **Git Hook 설치:**
```bash
# 프로젝트 루트에서 실행
curl -o .git/hooks/pre-commit https://raw.githubusercontent.com/your-repo/clean_architecture_linter/main/scripts/strict-pre-commit.sh
chmod +x .git/hooks/pre-commit
```

3. **팀원들에게 공지:**
```
📢 팀 공지: Clean Architecture 강제 모드 활성화

🎯 목표: 완벽한 Clean Architecture 준수
⚡ 효과: 모든 아키텍처 위반이 빌드 실패로 처리됩니다

📋 행동 사항:
1. 커밋 전 'dart analyze' 실행 필수
2. 모든 Clean Architecture 경고 해결 필수
3. 질문이 있으면 #architecture 채널에서 문의

💡 도움말: CONFIGURATION.md 참고
```

## 🔧 고급 설정: 규칙별 세밀 조정

특정 규칙만 더 엄격하게 하고 싶다면:

```yaml
analyzer:
  errors:
    # 핵심 원칙은 절대 타협 불가
    domain_purity: error
    dependency_inversion: error
    layer_dependency: error

    # 구현 패턴은 경고로
    consolidated_usecase_rule: warning
    business_logic_isolation: warning

    # 개선 권장사항은 정보로
    domain_model_validation: info
```

## ✅ 성공 체크리스트

팀에서 Clean Architecture 강제가 성공적으로 적용되었다면:

- [ ] 모든 팀원이 커밋 전 `dart analyze` 통과
- [ ] CI/CD에서 아키텍처 위반 시 빌드 실패
- [ ] 새로운 코드가 모든 Clean Architecture 원칙 준수
- [ ] Legacy 코드도 점진적으로 개선 중
- [ ] 팀원들이 Clean Architecture 패턴을 자연스럽게 적용

**결론: 팀에서 모든 규칙을 강제하고 싶다면, 위의 방법들을 조합해서 사용하세요. 가장 효과적인 조합은 `analysis_options.yaml` + `Git Hooks` + `CI/CD` 입니다!**