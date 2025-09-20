# 🚀 실제 설정 방법 (간단함)

## 현실적인 3가지 옵션

### 1️⃣ **모든 규칙 적용 (기본)**

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

### 2️⃣ **핵심 규칙만 적용**

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint

# pubspec.yaml에서 변경
dependencies:
  clean_architecture_linter:
    git:
      url: https://github.com/your-repo/clean_architecture_linter
      path: lib/clean_architecture_linter_core.dart  # 핵심만
```

### 3️⃣ **엄격 모드 (빌드 차단)**

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
  treat-package-warnings-as-errors: true

# 또는 pubspec.yaml에서
dependencies:
  clean_architecture_linter:
    git:
      url: https://github.com/your-repo/clean_architecture_linter
      path: lib/clean_architecture_linter_strict.dart  # 엄격 모드
```

---

## 🎯 현실 체크

**사실**: `custom_lint_builder`는 `analysis_options.yaml`의 개별 규칙 ON/OFF 설정을 지원하지 않습니다.

**즉**: 다음은 **작동하지 않습니다**:
```yaml
custom_lint:
  rules:
    - domain_model_validation: false  # ❌ 작동 안함
```

**해결책**: 필요한 규칙만 포함된 버전을 선택하세요:
- 기본 버전: 모든 규칙 포함
- Core 버전: 핵심 5개 규칙만
- Strict 버전: 모든 규칙 + 더 엄격한 검사

**3줄 요약**:
1. **모든 규칙**: `custom_lint` 플러그인 추가
2. **핵심만**: `clean_architecture_linter_core` 사용
3. **빌드 차단**: `treat-package-warnings-as-errors: true`

**주의**: 개별 규칙 ON/OFF는 현재 지원되지 않습니다.