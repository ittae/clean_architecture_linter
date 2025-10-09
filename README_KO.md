# 클린 아키텍처 린터

[![pub package](https://img.shields.io/pub/v/clean_architecture_linter.svg)](https://pub.dev/packages/clean_architecture_linter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Flutter 프로젝트에서 클린 아키텍처 원칙을 강제하는 포괄적인 커스텀 린트 패키지입니다. Uncle Bob의 클린 아키텍처를 따르는 Flutter 애플리케이션에서 적절한 아키텍처 경계와 패턴을 유지하도록 특별히 설계된 **최초이자 유일한** 린트 도구입니다.

## 🚀 주요 기능

- 🛡️ **자동 클린 아키텍처 보호** - 자유롭게 코드 작성, 린터가 위반사항 감지
- 🎯 **27개의 전문화된 규칙** - 모든 클린 아키텍처 계층 포괄
- 🚀 **Flutter 최적화** - Flutter 개발 패턴에 특화
- 📚 **교육적** - 수정 가이드를 통해 클린 아키텍처 학습
- ⚡ **실시간 피드백** - 즉각적인 경고와 실행 가능한 해결책
- 🔧 **제로 설정** - 기본값으로 즉시 작동
- 🧪 **테스트 인식** - 테스트 파일과 개발 컨텍스트에 대한 스마트 예외처리

## 📋 규칙 개요 (27개 규칙)

### 🌐 핵심 클린 아키텍처 원칙 (6개 규칙)
1. **Layer Dependency** - 의존성 방향 강제 (안쪽으로만)
2. **Domain Purity** - 도메인 계층의 외부 프레임워크 의존성 방지
3. **Dependency Inversion** - 추상화 기반 의존성 검증
4. **Repository Interface** - 적절한 리포지토리 추상화 보장
5. **Circular Dependency** - 계층 간 순환 의존성 방지
6. **Boundary Crossing** - 적절한 계층 경계 교차 검증

### 🎯 도메인 계층 규칙 (5개 규칙)
7. **Entity Business Logic** - 엔티티가 비즈니스 규칙 포함 (빈약한 도메인 모델 방지)
8. **UseCase No Result Return** - UseCase는 Result 타입 언래핑
9. **UseCase Must Convert Failure** - UseCase는 Failure를 Exception으로 변환
10. **Exception Naming Convention** - 도메인 예외에 기능 접두사
11. **Exception Message Localization** - 일관된 예외 메시지

### 💾 데이터 계층 규칙 (10개 규칙)
12. **Model Structure** - Entity 구성을 포함하는 Freezed 모델
13. **Model Field Duplication** - 모델에 중복 엔티티 필드 없음
14. **Model Conversion Methods** - 필수 `toEntity()` 및 `fromEntity()`
15. **DataSource Abstraction** - 데이터 소스용 추상 인터페이스
16. **DataSource No Result Return** - DataSource는 예외 발생
17. **Repository Implementation** - RepositoryImpl은 도메인 인터페이스 구현 필수
18. **Repository Must Return Result** - Repository는 Result 타입으로 래핑
19. **Repository No Throw** - Repository는 예외를 Result로 변환
20. **DataSource Exception Types** - 정의된 데이터 계층 예외만 사용
21. **Failure Naming Convention** - Failure 클래스에 기능 접두사

### 🎨 프레젠테이션 계층 규칙 (6개 규칙)
22. **No Presentation Models** - ViewModel 대신 Freezed State 사용
23. **Extension Location** - 클래스와 동일 파일에 확장 정의
24. **Freezed Usage** - Equatable 대신 Freezed 사용
25. **Riverpod Generator** - `@riverpod` 어노테이션 사용
26. **Presentation No Data Exceptions** - 도메인 예외만 사용
27. **Presentation Use AsyncValue** - 에러 처리에 AsyncValue 사용

### 🧪 선택사항: 테스트 커버리지 규칙
**Test Coverage** - UseCase, Repository, DataSource, Notifier에 대한 테스트 파일 강제 (기본값: 비활성화)

> 📖 **구현 가이드**: 자세한 패턴과 예제는 [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md)를 참조하세요.

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