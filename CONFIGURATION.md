# Clean Architecture Linter Configuration Guide

## 📋 Overview

Clean Architecture Linter를 팀의 요구사항에 맞게 설정하는 방법을 설명합니다.

## 🚀 Quick Start

### 1. 엄격한 강제 (Strict Enforcement)
모든 Clean Architecture 원칙을 엄격하게 적용하고 싶은 팀:

```yaml
# analysis_options.yaml
include: package:clean_architecture_linter/example_configurations/strict_enforcement.yaml
```

### 2. 균형잡힌 접근 (Balanced Approach)
핵심 원칙은 강제하고 나머지는 경고로 설정:

```yaml
# analysis_options.yaml
include: package:clean_architecture_linter/example_configurations/balanced_enforcement.yaml
```

### 3. 학습 모드 (Learning Mode)
Clean Architecture를 처음 적용하는 팀:

```yaml
# analysis_options.yaml
include: package:clean_architecture_linter/example_configurations/learning_mode.yaml
```

## ⚙️ 커스텀 설정

### 규칙별 Severity 설정

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    # ERROR: 빌드를 중단시킴 (가장 엄격)
    - domain_purity: error
    - dependency_inversion: error

    # WARNING: 경고 표시하지만 빌드는 계속
    - consolidated_usecase_rule: warning
    - business_logic_isolation: warning

    # INFO: 정보성 메시지만 표시
    - domain_model_validation: info

    # DISABLED: 규칙 비활성화
    # - boundary_crossing: disabled
```

### 팀별 권장 설정

#### 🔴 **스타트업/신규 프로젝트 팀**
```yaml
custom_lint:
  rules:
    # 핵심만 강제
    - domain_purity: error
    - layer_dependency: error
    - circular_dependency: error

    # 나머지는 학습용
    - consolidated_entity_rule: warning
    - consolidated_usecase_rule: info
```

#### 🟡 **기존 프로젝트 마이그레이션 팀**
```yaml
custom_lint:
  rules:
    # 점진적 적용
    - domain_purity: warning
    - dependency_inversion: warning
    - business_logic_isolation: info

    # 새 코드에만 적용
    - consolidated_entity_rule: info
```

#### 🟢 **Clean Architecture 경험 팀**
```yaml
custom_lint:
  rules:
    # 모든 규칙 강제
    - domain_purity: error
    - consolidated_entity_rule: error
    - consolidated_usecase_rule: error
    - domain_model_validation: error
    - business_logic_isolation: error
```

## 📚 규칙별 상세 설명

### 🔴 Core Rules (반드시 지켜야 할 규칙)

| 규칙 | 설명 | 권장 Severity |
|------|------|---------------|
| `domain_purity` | 도메인 순수성 보장 | `error` |
| `dependency_inversion` | 의존성 역전 원칙 | `error` |
| `repository_interface` | 리포지토리 추상화 | `error` |
| `layer_dependency` | 레이어 의존성 방향 | `error` |

### 🟡 Best Practice Rules (권장 규칙)

| 규칙 | 설명 | 권장 Severity |
|------|------|---------------|
| `consolidated_entity_rule` | 엔티티 무결성 | `warning` |
| `consolidated_usecase_rule` | UseCase 단일 책임 | `warning` |
| `business_logic_isolation` | 비즈니스 로직 격리 | `warning` |

### 🟢 Enhancement Rules (개선 규칙)

| 규칙 | 설명 | 권장 Severity |
|------|------|---------------|
| `domain_model_validation` | 도메인 모델 검증 | `info` |
| `abstraction_level` | 추상화 수준 | `info` |

## 🛠️ 실전 사용 예시

### 예시 1: 새 프로젝트 시작
```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    # Phase 1: 기본 아키텍처 구조
    - domain_purity: error
    - layer_dependency: error

    # Phase 2: 추가할 예정 (주석 처리)
    # - consolidated_entity_rule: warning
    # - consolidated_usecase_rule: warning
```

### 예시 2: 기존 프로젝트 점진적 적용
```yaml
# Week 1-2: 기본 구조 파악
custom_lint:
  rules:
    - domain_purity: info
    - layer_dependency: warning

# Week 3-4: 경고 수준으로 상향
custom_lint:
  rules:
    - domain_purity: warning
    - layer_dependency: error
    - business_logic_isolation: info

# Week 5+: 점진적 강화
custom_lint:
  rules:
    - domain_purity: error
    - layer_dependency: error
    - business_logic_isolation: warning
    - consolidated_entity_rule: info
```

## 💡 팀 협업 Tips

1. **단계적 도입**: 한 번에 모든 규칙을 `error`로 설정하지 마세요
2. **팀 합의**: 각 규칙의 severity는 팀과 상의해서 결정하세요
3. **점진적 강화**: `info` → `warning` → `error` 순으로 단계적으로 강화하세요
4. **예외 상황**: Legacy 코드는 별도 설정을 고려하세요

## 🎯 결론

**엄격한 Clean Architecture 적용을 원하는 팀**은 `strict_enforcement.yaml`을 사용하거나, 다음과 같이 설정하세요:

```yaml
custom_lint:
  rules:
    - domain_purity: error
    - dependency_inversion: error
    - repository_interface: error
    - consolidated_entity_rule: error
    - consolidated_usecase_rule: error
    - domain_model_validation: error
    - business_logic_isolation: error
    - layer_dependency: error
    - circular_dependency: error
```

이렇게 하면 모든 Clean Architecture 원칙이 강제되어, 아키텍처 위반 시 빌드가 실패합니다.