# 클린 아키텍처 린터

[![pub package](https://img.shields.io/pub/v/clean_architecture_linter.svg)](https://pub.dev/packages/clean_architecture_linter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 🇰🇷 한국어 README | 🇺🇸 [English README](README.md)

Flutter/Dart 프로젝트에서 **클린 아키텍처 원칙을 자동으로 강제**하는 포괄적인 커스텀 린트 패키지입니다. 자유롭게 코드를 작성하면 린터가 실시간 피드백과 실행 가능한 수정 방법으로 완벽한 클린 아키텍처 준수를 안내합니다.

## ✨ 주요 기능

- 🛡️ **자동 클린 아키텍처 보호** - 자유롭게 코드 작성, 린터가 위반사항 감지
- 🎯 **29개의 전문화된 규칙** - 모든 클린 아키텍처 계층 포괄
- 🚀 **Flutter 최적화** - Flutter 개발 패턴에 특화
- 📚 **교육적** - 수정 가이드를 통해 클린 아키텍처 학습
- ⚡ **실시간 피드백** - 즉각적인 경고와 실행 가능한 해결책
- 🔧 **제로 설정** - 기본값으로 즉시 작동
- 🧪 **테스트 인식** - 테스트 파일과 개발 컨텍스트에 대한 스마트 예외처리

## 📋 규칙 개요 (29개 규칙)

### 🌐 핵심 클린 아키텍처 원칙 (6개 규칙)
1. **Layer Dependency** - 의존성 방향 강제 (안쪽으로만)
2. **Domain Purity** - 도메인 계층의 외부 프레임워크 의존성 방지
3. **Dependency Inversion** - 추상화 기반 의존성 검증
4. **Repository Interface** - 적절한 리포지토리 추상화 보장
5. **Circular Dependency** - 계층 간 순환 의존성 방지
6. **Boundary Crossing** - 적절한 계층 경계 교차 검증

### 🎯 도메인 계층 규칙 (4개 규칙)
7. **UseCase No Result Return** - UseCase는 Result 타입 언래핑
8. **UseCase Must Convert Failure** - UseCase는 Failure를 Exception으로 변환
9. **Exception Naming Convention** - 도메인 예외에 기능 접두사
10. **Exception Message Localization** - 일관된 예외 메시지

### 💾 데이터 계층 규칙 (13개 규칙)
11. **Model Structure** - Entity 구성을 포함하는 Freezed 모델
12. **Model Field Duplication** - 모델에 중복 엔티티 필드 없음
13. **Model Conversion Methods** - 확장에 필수 `toEntity()` 메서드
14. **Model Entity Direct Access** - 직접 `.entity` 접근 대신 `.toEntity()` 사용
15. **Model Naming Convention** - 모델은 `Model` 접미사로 끝나야 함
16. **DataSource Abstraction** - 데이터 소스용 추상 인터페이스
17. **DataSource No Result Return** - DataSource는 예외 발생
18. **Repository Implementation** - RepositoryImpl은 도메인 인터페이스 구현 필수
19. **Repository Must Return Result** - Repository는 Result 타입으로 래핑
20. **Repository No Throw** - Repository는 예외를 Result로 변환
21. **DataSource Exception Types** - 정의된 데이터 계층 예외만 사용
22. **Failure Naming Convention** - Failure 클래스에 기능 접두사

### 🎨 프레젠테이션 계층 규칙 (7개 규칙)
23. **No Presentation Models** - ViewModel 대신 Freezed State 사용
24. **Extension Location** - 클래스와 동일 파일에 확장 정의
25. **Freezed Usage** - Equatable 대신 Freezed 사용
26. **Riverpod Generator** - `@riverpod` 어노테이션 사용
27. **Presentation No Data Exceptions** - 도메인 예외만 사용
28. **Presentation Use AsyncValue** - 에러 처리에 AsyncValue 사용
29. **Presentation No Throw** - 프레젠테이션 계층에서 예외 throw 금지

### 🧪 선택사항: 테스트 커버리지 규칙
**Test Coverage** - UseCase, Repository, DataSource, Notifier에 대한 테스트 파일 강제 (기본값: 비활성화)

> 📖 **구현 가이드**: 자세한 패턴과 예제는 [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md)를 참조하세요.

## 🚀 빠른 시작

### 📋 요구사항

- **Dart SDK**: 3.6.0+
- **Flutter**: 3.0+ (Flutter 프로젝트의 경우 선택사항)

### 1. 프로젝트에 추가

```yaml
# pubspec.yaml
dev_dependencies:
  clean_architecture_linter: ^1.0.3
  custom_lint: ^0.7.6
```

### 2. custom lint 활성화

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
  exclude:
    - test/**
    - "**/*.test.dart"    # 테스트 파일 제외
    - "**/*.g.dart"       # 생성된 파일 제외
    - "**/*.freezed.dart" # Freezed 파일 제외
    - "**/*.mocks.dart"   # Mock 파일 제외
```

### 3. 린터 실행

```bash
dart pub get
dart pub custom_lint
```

완료되었습니다! 이제 린터가 자동으로 코드베이스에 클린 아키텍처 원칙을 강제합니다.

## 🎛️ 설정

### 선택사항: 테스트 커버리지

`clean_architecture_linter_require_test` 규칙은 **기본적으로 비활성화**되어 있습니다. 중요한 컴포넌트에 대한 테스트 파일을 강제하려면 활성화하세요:

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - clean_architecture_linter_require_test: true
```

## 🚦 사용법

### 폴더 구조

클린 아키텍처를 따라 Flutter 프로젝트를 구성하세요:

```
lib/
├── {feature_name}/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   ├── data/
│   │   ├── datasources/
│   │   ├── models/
│   │   └── repositories/
│   └── presentation/
│       ├── providers/
│       ├── widgets/
│       └── pages/
```

### 린터 실행

```bash
# custom_lint가 아직 활성화되지 않은 경우
dart pub global activate custom_lint

# 린터 실행
dart run custom_lint
```

### IDE 통합

린터는 다음 환경에서 자동으로 작동합니다:
- Dart/Flutter 확장이 설치된 **VS Code**
- Flutter 플러그인이 설치된 **IntelliJ IDEA** / **Android Studio**

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

**단일 책임을 가진 UseCase**
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
    // UI 계층의 비즈니스 로직 - 잘못됨!
    final isValid = email.contains('@') && email.length > 5;
    return Text(isValid ? 'Valid' : 'Invalid');
  }
}
```

**예외를 던지는 Repository**
```dart
// ❌ avoid_exception_throwing_in_repository에 걸림
class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserEntity> getUser(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('ID cannot be empty'); // Result를 반환해야 함
    }
    // ...
  }
}
```

**계층 의존성 위반**
```dart
// ❌ avoid_layer_dependency_violation에 걸림
// 도메인 계층 파일에서:
import 'package:myapp/data/models/user_model.dart'; // Domain이 Data를 임포트!

class UserEntity extends UserModel { // 잘못된 의존성 방향
  // ...
}
```

**예외 접두사 누락**
```dart
// ❌ ensure_exception_prefix에 걸림
class NetworkException extends Exception { // UserNetworkException이어야 함
  // ...
}
```

### 🔄 일반적인 패턴

**Result 타입을 사용한 올바른 에러 처리**
```dart
// ✅ 좋음: Result 패턴 사용
sealed class Result<T, E> {}
class Success<T, E> extends Result<T, E> {
  final T value;
  Success(this.value);
}
class Failure<T, E> extends Result<T, E> {
  final E error;
  Failure(this.error);
}

// Repository 구현
class UserRepositoryImpl implements UserRepository {
  @override
  Future<Result<UserEntity, UserException>> getUser(String id) async {
    try {
      final userData = await dataSource.getUser(id);
      return Success(userData.toEntity());
    } catch (e) {
      return Failure(UserDataException(e.toString()));
    }
  }
}
```

**올바른 예외 네이밍**
```dart
// ✅ 좋음: 적절한 예외 접두사
class UserNetworkException extends Exception {
  final String message;
  UserNetworkException(this.message);
}

class UserValidationException extends Exception {
  final String field;
  UserValidationException(this.field);
}
```

더 자세한 예제와 설명은 포괄적인 [예제 가이드](doc/EXAMPLES.md)를 참조하세요.

## 🛠️ 개발

### 프로젝트 구조

```
clean_architecture_linter/
├── lib/
│   ├── src/
│   │   └── rules/
│   │       ├── domain_rules/
│   │       ├── data_rules/
│   │       └── presentation_rules/
│   └── clean_architecture_linter.dart
├── example/
├── test/
└── README.md
```

### 기여하기

1. 저장소를 포크하세요
2. 기능 브랜치를 생성하세요
3. 새 규칙에 대한 테스트를 추가하세요
4. 코드를 포맷하세요: `dart format .`
5. 모든 테스트가 통과하는지 확인하세요
6. Pull Request를 제출하세요

자세한 가이드라인은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참조하세요.

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

**Flutter 커뮤니티를 위해 ❤️로 만들어졌습니다**
