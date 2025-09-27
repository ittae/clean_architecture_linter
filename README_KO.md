# 클린 아키텍처 린터

[![pub package](https://img.shields.io/pub/v/clean_architecture_linter.svg)](https://pub.dev/packages/clean_architecture_linter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Flutter 프로젝트에서 클린 아키텍처 원칙을 강제하는 포괄적인 커스텀 린트 패키지입니다. Uncle Bob의 클린 아키텍처를 따르는 Flutter 애플리케이션에서 적절한 아키텍처 경계와 패턴을 유지하도록 특별히 설계된 **최초이자 유일한** 린트 도구입니다.

## 🚀 주요 기능

- **39개의 포괄적인 린트 규칙**으로 클린 아키텍처의 모든 측면을 커버
- **도메인 계층 규칙** (11개): 비즈니스 로직 순수성과 적절한 추상화 보장
- **데이터 계층 규칙** (7개): 리포지토리 구현과 데이터 모델 검증
- **프레젠테이션 계층 규칙** (3개): UI/비즈니스 로직 분리 강제
- **인터페이스 어댑터 규칙** (3개): 적절한 데이터 변환 패턴 검증
- **프레임워크 규칙** (4개): 프레임워크 세부사항을 외부 계층에 유지
- **경계 규칙** (11개): 적절한 경계 교차 패턴 강제
- **실시간 피드백**: IDE에서 즉시 확인 (VS Code, IntelliJ IDEA, Android Studio)
- **설정 가능한 규칙**: 필요에 따라 특정 규칙 활성화/비활성화
- **제로 디펜던시**: 앱에 의존성 없이 개발 의존성으로만 작동

## 📋 클린 아키텍처 계층별 규칙

### 🎯 도메인 계층 (핵심 비즈니스 규칙)
*비즈니스 로직과 규칙을 포함하는 가장 안쪽 계층*

**엔티티 & 비즈니스 규칙 (4개):**
- `entity_business_rules` - 엔티티가 기업 비즈니스 규칙만 포함하도록 보장
- `entity_stability` - 엔티티 안정성과 불변성 검증
- `entity_immutability` - 불변 도메인 엔티티 강제
- `business_logic_isolation` - 외부 계층으로의 비즈니스 로직 누출 방지

**유스케이스 & 애플리케이션 규칙 (4개):**
- `usecase_orchestration` - 유스케이스 오케스트레이션 패턴 검증
- `usecase_application_rules` - 유스케이스가 애플리케이션 특화 규칙을 포함하도록 보장
- `usecase_independence` - 유스케이스 독립성 강제
- `usecase_single_responsibility` - 단일 책임 원칙 검증

**도메인 인터페이스 & 검증 (3개):**
- `repository_interface` - 적절한 리포지토리 추상화 검증
- `domain_model_validation` - 적절한 도메인 검증 보장
- `domain_purity` - 외부 프레임워크 의존성 방지
- `dependency_inversion` - 의존성 방향 검증

### 💾 데이터 계층 (데이터 접근 & 외부 인터페이스)
*리포지토리 구현과 데이터 소스 관리*

**리포지토리 & 데이터 소스 규칙 (3개):**
- `repository_implementation` - 리포지토리 구현 패턴 검증
- `datasource_naming` - 적절한 명명 규칙 강제
- `model_structure` - 데이터 모델의 적절한 구조 보장

**경계 데이터 규칙 (4개):**
- `data_boundary_crossing` - 적절한 경계 데이터 전달 검증
- `database_row_boundary` - 데이터베이스 행 구조의 내부 전달 방지
- `dto_boundary_pattern` - 경계 교차를 위한 DTO 패턴 강제
- `entity_boundary_isolation` - 외부 계층으로부터 엔티티 격리

### 🎨 프레젠테이션 계층 (UI & 전달 메커니즘)
*사용자 인터페이스와 전달 메커니즘*

**UI & 상태 관리 (3개):**
- `ui_dependency_injection` - 비즈니스 로직 직접 인스턴스화 방지
- `state_management` - 적절한 상태 관리 패턴 검증
- `presentation_logic_separation` - UI/비즈니스 로직 분리 강제

### 🔗 인터페이스 어댑터 (데이터 형식 변환)
*컨트롤러, 프레젠터, 게이트웨이*

**데이터 변환 & MVC (3개):**
- `data_conversion_adapter` - 데이터 형식 변환 검증
- `mvc_architecture` - 어댑터에서 MVC 패턴 강제
- `external_service_adapter` - 외부 서비스 어댑터 패턴 검증

### ⚙️ 프레임워크 & 드라이버 (외부 세부사항)
*웹 프레임워크, 데이터베이스, 외부 에이전시*

**프레임워크 격리 (4개):**
- `framework_isolation` - 가장 바깥 계층에서 프레임워크 세부사항 격리
- `database_detail` - 프레임워크 계층에서 데이터베이스 세부사항 유지
- `web_framework_detail` - 웹 프레임워크 특화 사항 격리
- `glue_code` - 글루 코드 패턴 검증

### 🌐 아키텍처 경계 (횡단 관심사)
*여러 계층에 걸쳐 Uncle Bob의 원칙을 강제하는 규칙*

**의존성 & 계층 규칙 (5개):**
- `layer_dependency` - 의존성 규칙 강제 (안쪽으로만)
- `circular_dependency` - 순환 의존성 방지
- `core_dependency` - 핵심 의존성 패턴 검증
- `abstraction_level` - 적절한 추상화 수준 보장
- `flexible_layer_detection` - 유연한 계층 아키텍처 지원

**경계 교차 패턴 (6개):**
- `boundary_crossing` - 적절한 경계 교차 검증
- `dependency_inversion_boundary` - 경계에서 의존성 역전 강제
- `interface_boundary` - 인터페이스 경계 패턴 검증
- `polymorphic_flow_control` - 다형적 흐름 제어 역전 보장
- `abstraction_progression` - 계층 간 추상화 진행 검증
- `clean_architecture_benefits` - 아키텍처가 기대 효과를 제공하도록 보장

> 📖 **상세 규칙 가이드**: [RULES_KO.md](RULES_KO.md)에서 39개 규칙에 대한 포괄적인 문서, Uncle Bob 인용구, 구현 가이드를 확인하세요.

## 📦 설치

`pubspec.yaml`에 `clean_architecture_linter`를 개발 의존성으로 추가하세요:

```yaml
dev_dependencies:
  clean_architecture_linter: ^0.1.0
  custom_lint: ^0.6.7
```

## ⚙️ 설정

`analysis_options.yaml`을 생성하거나 업데이트하세요:

```yaml
analyzer:
  plugins:
    - custom_lint
  exclude:
    - test/**  
    - "**/*.test.dart"    # 테스트 파일 제외
    - "**/*.g.dart"       # 생성된 파일 제외
    - "**/*.freezed.dart" # Freezed 파일 제외
    - "**/*.mocks.dart"   # Mock 파일 제외

custom_lint:
  rules:
    # 도메인 계층 규칙 (11개)
    - entity_business_rules
    - entity_stability
    - entity_immutability
    - business_logic_isolation
    - usecase_orchestration
    - usecase_application_rules
    - usecase_independence
    - usecase_single_responsibility
    - repository_interface
    - domain_model_validation
    - domain_purity
    - dependency_inversion

    # 데이터 계층 규칙 (7개)
    - repository_implementation
    - datasource_naming
    - model_structure
    - data_boundary_crossing
    - database_row_boundary
    - dto_boundary_pattern
    - entity_boundary_isolation

    # 프레젠테이션 계층 규칙 (3개)
    - ui_dependency_injection
    - state_management
    - presentation_logic_separation

    # 인터페이스 어댑터 규칙 (3개)
    - data_conversion_adapter
    - mvc_architecture
    - external_service_adapter

    # 프레임워크 규칙 (4개)
    - framework_isolation
    - database_detail
    - web_framework_detail
    - glue_code

    # 경계 규칙 (11개)
    - layer_dependency
    - circular_dependency
    - core_dependency
    - abstraction_level
    - flexible_layer_detection
    - boundary_crossing
    - dependency_inversion_boundary
    - interface_boundary
    - polymorphic_flow_control
    - abstraction_progression
    - clean_architecture_benefits
```

## 🚦 사용법

### 폴더 구조

클린 아키텍처를 따라 Flutter 프로젝트를 구성하세요:

```
lib/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
└── presentation/
    ├── providers/
    ├── widgets/
    └── pages/
```

### 린터 실행

```bash
# custom_lint가 설치되지 않았다면 먼저 활성화
dart pub global activate custom_lint

# 린터 실행
dart pub custom_lint
```

### IDE 통합

다음 IDE에서 자동으로 작동합니다:
- **VS Code**: Dart/Flutter 확장과 함께
- **IntelliJ IDEA** / **Android Studio**: Flutter 플러그인과 함께

## 📚 예제

### ✅ 좋은 예제

**도메인 엔티티 (불변)**
```dart
// lib/domain/entities/user_entity.dart
class UserEntity {
  final String id;
  final String name;
  final String email;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
  });

  bool isValidEmail() {
    return email.contains('@');
  }
}
```

**리포지토리 인터페이스**
```dart
// lib/domain/repositories/user_repository.dart
abstract class UserRepository {
  Future<UserEntity> getUser(String id);
  Future<void> saveUser(UserEntity user);
}
```

**단일 책임을 가진 유스케이스**
```dart
// lib/domain/usecases/get_user_usecase.dart
class GetUserUseCase {
  final UserRepository repository;

  GetUserUseCase(this.repository);

  Future<UserEntity> call(String userId) {
    return repository.getUser(userId);
  }
}
```

### ❌ 나쁜 예제 (린터에 걸림)

**가변 도메인 엔티티**
```dart
// ❌ entity_immutability에 걸림
class UserEntity {
  String name; // final이 아닌 필드

  void setName(String newName) { // 엔티티의 setter
    name = newName;
  }
}
```

**외부 의존성이 있는 도메인 계층**
```dart
// ❌ domain_purity에 걸림
import 'package:http/http.dart'; // 외부 프레임워크 임포트

class UserEntity {
  final String name;
}
```

**비즈니스 로직이 있는 UI**
```dart
// ❌ business_logic_isolation에 걸림
class UserWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // UI 계층의 비즈니스 로직
    final user = UserRepository().getUser('123');
    return Text(user.name);
  }
}
```

## 🛠️ 개발

### 프로젝트 구조

```
clean_architecture_linter/
├── lib/
│   ├── src/
│   │   └── rules/
│   │       ├── domain_rules/
│   │       ├── data_rules/
│   │       ├── presentation_rules/
│   │       ├── adapter_rules/
│   │       └── framework_rules/
│   └── clean_architecture_linter.dart
├── example/
├── test/
└── README.md
```

### 기여하기

1. 저장소를 포크하세요
2. 기능 브랜치를 만드세요
3. 새 규칙에 대한 테스트를 추가하세요
4. 모든 테스트가 통과하는지 확인하세요
5. Pull Request를 제출하세요

## 💡 단계별 도입 가이드

### 신규 프로젝트
```yaml
custom_lint:
  rules:
    # 핵심 규칙부터 시작
    - entity_immutability
    - domain_purity
    - layer_dependency
    - business_logic_isolation
```

### 기존 프로젝트 리팩토링
```yaml
custom_lint:
  rules:
    # 구조적 문제부터 해결
    - circular_dependency
    - layer_dependency
    # 점진적으로 패턴 개선
    - repository_interface
    - data_boundary_crossing
```

### 팀 교육용
```yaml
custom_lint:
  rules:
    # Uncle Bob의 핵심 원칙들
    - entity_business_rules
    - usecase_orchestration
    - dependency_inversion_boundary
    - clean_architecture_benefits
```

## 📄 라이센스

이 프로젝트는 MIT 라이센스 하에 있습니다 - 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 🙏 지원

- ⭐ 도움이 되셨다면 이 저장소에 별점을 주세요!
- 🐛 [버그 신고](https://github.com/ittae/clean_architecture_linter/issues)
- 💡 [기능 요청](https://github.com/ittae/clean_architecture_linter/issues)
- 📖 [문서 읽기](https://github.com/ittae/clean_architecture_linter)

## 🎯 로드맵

- [ ] 커스텀 명명 패턴을 위한 설정 시스템
- [ ] 다양한 상태 관리 솔루션 지원
- [ ] CI/CD 워크플로우와의 통합
- [ ] 커스텀 규칙 생성 가이드
- [ ] 성능 최적화

---

**Flutter 클린 아키텍처 커뮤니티를 위해 ❤️로 만들어졌습니다**