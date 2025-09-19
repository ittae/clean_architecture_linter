# 클린 아키텍처 린터 규칙 가이드

이 문서는 클린 아키텍처 린터의 39개 린트 규칙에 대한 종합 가이드로, Uncle Bob의 클린 아키텍처 원칙에 따라 구성되었습니다.

## 🏗️ 규칙 구성 이해하기

규칙들은 클린 아키텍처 원칙에 따라 **6개 주요 카테고리**로 구성됩니다:

### 1. 🎯 도메인 레이어 규칙 (11개)
**목적**: 핵심 비즈니스 로직의 순수성과 적절한 추상화 강제
**위치**: `lib/src/rules/domain_rules/`
**Uncle Bob 인용**: *"엔티티는 기업 차원의 비즈니스 규칙을 캡슐화한다."*

### 2. 💾 데이터 레이어 규칙 (7개)
**목적**: 리포지토리 구현과 데이터 접근 패턴 검증
**포함**: 리포지토리 패턴 + 경계 데이터 규칙
**Uncle Bob 인용**: *"단순한 데이터 구조가 경계를 넘나든다."*

### 3. 🎨 프레젠테이션 레이어 규칙 (3개)
**목적**: UI와 전달 메커니즘 분리 강제
**위치**: `lib/src/rules/presentation_rules/`
**Uncle Bob 인용**: *"컨트롤러, 프레젠터, 게이트웨이는 모두 인터페이스 어댑터 계층에 있다."*

### 4. 🔗 인터페이스 어댑터 규칙 (3개)
**목적**: 데이터 형식 변환 패턴 검증
**위치**: `lib/src/rules/adapter_rules/`
**Uncle Bob 인용**: *"엔티티와 유스케이스에 가장 편리한 형식에서 데이터를 변환한다."*

### 5. ⚙️ 프레임워크 & 드라이버 규칙 (4개)
**목적**: 가장 바깥 계층에서 프레임워크 세부사항 격리
**위치**: `lib/src/rules/framework_rules/`
**Uncle Bob 인용**: *"가장 바깥 계층은 일반적으로 프레임워크와 도구들로 구성된다."*

### 6. 🌐 아키텍처 경계 규칙 (11개)
**목적**: 횡단 관심사와 Uncle Bob의 핵심 원칙 강제
**위치**: `lib/src/rules/` (루트 레벨)
**Uncle Bob 인용**: *"소스 코드 의존성은 오직 안쪽으로만 향할 수 있다."*

---

## 📋 상세 규칙 레퍼런스

### 🎯 도메인 레이어 규칙 (11개)

#### 엔티티 & 비즈니스 규칙
- **`entity_business_rules`** - 엔티티가 기업 비즈니스 규칙만 포함하도록 보장
- **`entity_stability`** - 엔티티의 안정성과 최소 변경 빈도 검증
- **`entity_immutability`** - 불변 도메인 엔티티 강제 (final 필드, setter 없음)
- **`business_logic_isolation`** - 외부 계층으로의 비즈니스 로직 누출 방지

#### 유스케이스 & 애플리케이션 규칙
- **`usecase_orchestration`** - 유스케이스의 엔티티 오케스트레이션 검증
- **`usecase_application_rules`** - 유스케이스가 애플리케이션 특화 규칙을 포함하도록 보장
- **`usecase_independence`** - 외부 관심사로부터 유스케이스 독립성 강제
- **`usecase_single_responsibility`** - 유스케이스의 단일 책임 원칙 검증

#### 도메인 인터페이스 & 추상화
- **`repository_interface`** - 도메인에서 적절한 리포지토리 추상화 검증
- **`domain_model_validation`** - 도메인 모델의 적절한 검증 로직 보장
- **`domain_purity`** - 도메인에서 외부 프레임워크 의존성 방지
- **`dependency_inversion`** - 도메인 계층의 의존성 방향 검증

### 💾 데이터 레이어 규칙 (7개)

#### 리포지토리 & 데이터 소스 구현
- **`repository_implementation`** - 리포지토리 구현 패턴 검증
- **`datasource_naming`** - 데이터 소스의 적절한 명명 규칙 강제
- **`model_structure`** - 데이터 모델의 적절한 직렬화 메소드 보장

#### 경계 데이터 관리
- **`data_boundary_crossing`** - 적절한 경계 데이터 전달 검증 (DTO vs 엔티티)
- **`database_row_boundary`** - 데이터베이스 행 구조의 내부 전달 방지
- **`dto_boundary_pattern`** - 경계 전달을 위한 DTO 패턴 강제
- **`entity_boundary_isolation`** - 외부 계층으로부터 엔티티 격리

### 🎨 프레젠테이션 레이어 규칙 (3개)

- **`ui_dependency_injection`** - UI에서 비즈니스 로직 직접 인스턴스화 방지
- **`state_management`** - 적절한 상태 관리 패턴 검증 (BLoC, Provider 등)
- **`presentation_logic_separation`** - UI 위젯에서 프레젠테이션 로직 분리 강제

### 🔗 인터페이스 어댑터 규칙 (3개)

- **`data_conversion_adapter`** - 계층 간 데이터 형식 변환 검증
- **`mvc_architecture`** - 어댑터 계층에서 MVC 패턴 강제
- **`external_service_adapter`** - 외부 서비스 어댑터 패턴과 인터페이스 검증

### ⚙️ 프레임워크 & 드라이버 규칙 (4개)

- **`framework_isolation`** - 가장 바깥 계층에서 프레임워크 세부사항 격리
- **`database_detail`** - 프레임워크 계층에서 데이터베이스 구현 세부사항 유지
- **`web_framework_detail`** - 웹 프레임워크 특화 사항 격리 (HTTP, 라우팅)
- **`glue_code`** - 의존성 주입을 위한 글루 코드 패턴 검증

### 🌐 아키텍처 경계 규칙 (11개)

#### 핵심 의존성 관리
- **`layer_dependency`** - 의존성 규칙 강제 (의존성은 안쪽으로만)
- **`circular_dependency`** - 컴포넌트 간 순환 의존성 방지
- **`core_dependency`** - 핵심 의존성 패턴과 추상화 검증
- **`abstraction_level`** - 계층 간 적절한 추상화 수준 보장
- **`flexible_layer_detection`** - 유연한 계층 아키텍처 지원 (4개 이상 계층)

#### 경계 교차 패턴
- **`boundary_crossing`** - 적절한 경계 교차 메커니즘 검증
- **`dependency_inversion_boundary`** - 계층 경계에서 의존성 역전 강제
- **`interface_boundary`** - 인터페이스 경계 패턴과 계약 검증
- **`polymorphic_flow_control`** - 다형적 흐름 제어 역전 보장
- **`abstraction_progression`** - 구체적에서 추상적으로의 추상화 진행 검증
- **`clean_architecture_benefits`** - 아키텍처가 테스트 가능성과 유연성을 제공하도록 보장

---

## 🎯 클린 아키텍처 계층별 규칙 매핑

### 전통적인 3계층 매핑

| 클린 아키텍처 계층 | 규칙 수 | 주요 초점 |
|-------------------|---------|-----------|
| **도메인** (비즈니스 로직) | 11개 | 엔티티 무결성, 유스케이스 패턴, 비즈니스 규칙 격리 |
| **데이터** (리포지토리 구현) | 7개 | 데이터 접근 패턴, 경계 데이터 처리 |
| **프레젠테이션** (UI & 전달) | 3개 | UI 분리, 상태 관리 패턴 |

### 확장된 4+ 계층 매핑

| Uncle Bob의 계층 | 규칙 수 | 규칙 카테고리 |
|------------------|---------|---------------|
| **엔티티** | 4개 | 엔티티 비즈니스 규칙, 안정성, 불변성 |
| **유스케이스** | 4개 | 애플리케이션 비즈니스 규칙, 오케스트레이션 |
| **인터페이스 어댑터** | 10개 | 컨트롤러, 프레젠터, 게이트웨이 (데이터 + 어댑터 규칙) |
| **프레임워크 & 드라이버** | 4개 | 프레임워크 격리, 외부 세부사항 |
| **횡단 관심사** | 17개 | 경계, 의존성, 아키텍처 무결성 |

---

## 💡 빠른 시작 가이드

### 도메인 중심 개발용
다음 규칙 그룹을 먼저 활성화하세요:
```yaml
custom_lint:
  rules:
    # 핵심 도메인 규칙부터 시작
    - entity_immutability
    - business_logic_isolation
    - usecase_single_responsibility
    - domain_purity
    - layer_dependency
```

### 데이터 계층 개발용
다음 패턴에 집중하세요:
```yaml
custom_lint:
  rules:
    # 데이터 계층 필수 사항
    - repository_implementation
    - data_boundary_crossing
    - entity_boundary_isolation
    - dependency_inversion_boundary
```

### 완전한 클린 아키텍처 준수용
종합적인 검증을 위해 39개 규칙을 모두 활성화하세요.

---

## 🔍 규칙 활성화 전략

1. **1단계 - 핵심 규칙** (여기서 시작)
   - `layer_dependency`, `domain_purity`, `entity_immutability`

2. **2단계 - 경계 규칙** (점진적 추가)
   - `data_boundary_crossing`, `dependency_inversion_boundary`

3. **3단계 - 패턴 규칙** (포괄적)
   - 완전한 아키텍처 준수를 위한 나머지 모든 규칙

이런 단계적 접근법은 팀이 압도적인 위반 보고서 없이 클린 아키텍처를 점진적으로 도입할 수 있도록 도와줍니다.

---

## 🚀 실제 사용 시나리오

### 신규 프로젝트 시작시
```yaml
# 기본 설정으로 시작
custom_lint:
  rules:
    - domain_purity
    - entity_immutability
    - layer_dependency
    - business_logic_isolation
```

### 레거시 코드 리팩토링시
```yaml
# 점진적 개선을 위한 설정
custom_lint:
  rules:
    # 먼저 구조적 문제부터
    - circular_dependency
    - layer_dependency
    # 그 다음 패턴 개선
    - repository_interface
    - data_boundary_crossing
```

### 팀 교육용
```yaml
# 학습 중심 설정
custom_lint:
  rules:
    # Uncle Bob의 핵심 원칙들
    - entity_business_rules
    - usecase_orchestration
    - dependency_inversion_boundary
    - clean_architecture_benefits
```

---

## 📚 추가 학습 자료

- [클린 아키텍처 - Robert C. Martin](https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=202322454)
- [Flutter에서의 클린 아키텍처 적용 방법](https://github.com/ResoCoder/flutter-tdd-clean-architecture-course)
- [Uncle Bob의 클린 아키텍처 블로그](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

이 가이드가 클린 아키텍처 린터를 효과적으로 활용하는 데 도움이 되기를 바랍니다!