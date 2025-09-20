# 🚀 Clean Architecture Linter 간단 설정

## 모든 규칙을 강제하고 싶다면?

### 1️⃣ **analysis_options.yaml 한 줄 추가**

```yaml
analyzer:
  plugins:
    - custom_lint
```

**끝!** 모든 Clean Architecture 규칙이 자동으로 ERROR 레벨로 적용됩니다.

### 2️⃣ **특정 규칙만 끄고 싶다면?**

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    # 이 규칙만 비활성화
    - domain_model_validation: false
```

### 3️⃣ **완전 엄격 모드 (빌드 차단)**

```yaml
analyzer:
  plugins:
    - custom_lint
  treat-package-warnings-as-errors: true
```

이제 Clean Architecture 위반 시 **빌드가 실패**합니다.

---

## 🎯 요약

- **기본**: `custom_lint` 플러그인만 추가하면 모든 규칙 적용
- **엄격**: `treat-package-warnings-as-errors: true` 추가
- **예외**: 특정 규칙을 `false`로 설정

**3줄로 끝!** 더 이상 복잡한 설정은 필요 없습니다.