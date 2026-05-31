# 클린 아키텍처 린터

[![pub package](https://img.shields.io/pub/v/clean_architecture_linter.svg)](https://pub.dev/packages/clean_architecture_linter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 🇰🇷 한국어 README | 🇺🇸 [English README](README.md)

Flutter/Dart 프로젝트에서 **클린 아키텍처 원칙을 자동으로 강제**하는 포괄적인 커스텀 린트 패키지입니다. 자유롭게 코드를 작성하면 린터가 실시간 피드백과 실행 가능한 수정 방법으로 완벽한 클린 아키텍처 준수를 안내합니다.

## ✨ 주요 기능

- 🛡️ **자동 클린 아키텍처 보호** - 자유롭게 코드 작성, 린터가 위반사항 감지
- 🎯 **33개의 전문화된 규칙** - 모든 클린 아키텍처 계층 포괄
- 🚀 **Flutter 최적화** - Flutter 개발 패턴에 특화
- 📚 **교육적** - 수정 가이드를 통해 클린 아키텍처 학습
- ⚡ **실시간 피드백** - 즉각적인 경고와 실행 가능한 해결책
- 🔧 **제로 설정** - 기본값으로 즉시 작동
- 🧪 **테스트 인식** - 테스트 파일과 개발 컨텍스트에 대한 스마트 예외처리
- 🎨 **Riverpod 상태 관리** - 3-tier provider 아키텍처 강제 (Entity → UI → Computed)

## 📋 규칙 개요 (33개 규칙)

### 🌐 핵심 클린 아키텍처 원칙 (6개 규칙)
1. **Layer Dependency** - 의존성 방향 강제 (안쪽으로만)
2. **Domain Purity** - 도메인 계층의 외부 프레임워크 의존성 방지
3. **Dependency Inversion** - 추상화 기반 의존성 검증
4. **Repository Interface** - 적절한 리포지토리 추상화 보장
5. **Circular Dependency** - 계층 간 순환 의존성 방지
6. **Boundary Crossing** - 적절한 계층 경계 교차 검증

### 🎯 도메인 계층 규칙 (2개 규칙)
7. **UseCase No Result Return** - UseCase는 Result 타입 언래핑
8. **Exception Naming Convention** - 도메인 예외에 기능 접두사

### 💾 데이터 계층 규칙 (10개 규칙)
9. **Model Structure** - Entity 구성을 포함하는 Freezed 모델
10. **Model Field Duplication** - 모델에 중복 엔티티 필드 없음
11. **Model Conversion Methods** - 확장에 필수 `toEntity()` 메서드
12. **Model Naming Convention** - 모델은 `Model` 접미사로 끝나야 함
13. **DataSource Abstraction** - 데이터 소스용 추상 인터페이스
14. **DataSource No Result Return** - DataSource는 예외 발생
15. **Repository Implementation** - RepositoryImpl은 도메인 인터페이스 구현 필수
16. **Repository Pass Through** - Repository는 `Future<Entity>` 반환 (Result 패턴 사용 시 경고)
17. **Repository No Throw** - Repository는 pass-through 패턴 사용 (AppException 타입 허용)
18. **DataSource Exception Types** - 정의된 데이터 계층 예외만 사용
19. **Model Entity Direct Access** - 직접 `.entity` 접근 대신 `.toEntity()` 사용

### 🎨 프레젠테이션 계층 규칙 (13개 규칙)
20. **No Presentation Models** - ViewModel 대신 Freezed State 사용
21. **Extension Location** - 클래스와 동일 파일에 확장 정의
22. **Freezed Usage** - Equatable 대신 Freezed 사용
23. **Riverpod Generator** - `@riverpod` 어노테이션 사용
24. **Presentation No Data Exceptions** - 도메인 예외만 사용
25. **Presentation Use AsyncValue** - 에러 처리에 AsyncValue 사용 (3-tier 아키텍처)
26. **Presentation No Throw** - 프레젠테이션 계층에서 예외 throw 금지
27. **Widget No UseCase Call** - Widget은 UseCase를 직접 호출하지 않음 (Provider 사용)
28. **Widget Ref Read Then When** - ref.read() 후 .when() 사용 금지 (안티패턴)
29. **Riverpod Ref Usage** - build()에서 ref.watch(), 메서드에서 ref.read() (UseCase 감지 포함)
30. **Riverpod Provider Naming** - Provider 함수는 타입 접미사 포함 필수 (repository/usecase/datasource)
31. **Ref Mounted Usage** - `ref.mounted` 사용 금지 (AsyncValue 또는 네비게이션 전 async 완료 권장)
32. **Riverpod Keep Alive** - `keepAlive: true`는 전역 상태에만 사용 (auth, settings, cache)

### 🔧 Cross-Layer 규칙 (1개 규칙)
33. **Allowed Instance Variables** - 무상태 아키텍처 강제 (UseCase/Repository/DataSource)

### 🧪 선택사항: 테스트 커버리지 규칙
**Test Coverage** - UseCase, Repository, DataSource, Notifier에 대한 테스트 파일 강제 (기본값: 비활성화)

> 📖 **구현 가이드**: 자세한 패턴과 예제는 [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md)를 참조하세요.
>
> 🎨 **Riverpod 상태 관리**: 3-tier provider 아키텍처 가이드는 [CLAUDE.md § Riverpod State Management Patterns](CLAUDE.md#riverpod-state-management-patterns)를 참조하세요.

## 🚀 빠른 시작

> 🚀 **v2.0 (upcoming)**: 다음 major release는 `custom_lint`에서 공식 [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin) 기반으로 전환됩니다 — `custom_lint` 의존성 불필요, `pubspec_overrides.yaml` 워크어라운드 불필요, lint는 `dart analyze`로 실행. 아래 설치 단계는 **현재 pub.dev release(v1.3.2)** 기준입니다. v2.0 release 후에는 [MIGRATION.md](MIGRATION.md)를 따르세요.

### 📋 요구사항

- **Dart SDK**: 3.6.0+
- **Flutter**: 3.0+ (Flutter 프로젝트의 경우 선택사항)
- **Riverpod**: 프레젠테이션 계층 규칙에 필수 (riverpod_generator 권장)

### 1. 프로젝트에 추가

```yaml
# pubspec.yaml
dev_dependencies:
  clean_architecture_linter: ^1.3.0
  custom_lint: ^0.8.0
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

## 🧩 호환성 — analyzer 9 / Riverpod 3+ (임시 워크어라운드)

> **요약**: `dart pub get` 이 `custom_lint` 와 `riverpod_lint` / `riverpod_generator` / `freezed` 를 언급하며 "version solving failed" 로 실패하면, 아래 `pubspec_overrides.yaml` 을 추가하세요.

### 증상

```
Because riverpod_lint >=3.1.1 depends on analyzer ^9.0.0
and custom_lint >=0.8.1 depends on analyzer ^8.0.0,
custom_lint >=0.8.1 is incompatible with riverpod_lint >=3.1.1.
```

### 원인

pub.dev 의 stable `custom_lint` / `custom_lint_builder` (0.8.1) 가 `analyzer ^8.0.0` 에 고정되어 있습니다. `main` 브랜치에는 `analyzer ^9.0.0` 기반의 `0.8.2` 코드가 들어가 있지만, **upstream 저장소 [invertase/dart_custom_lint](https://github.com/invertase/dart_custom_lint) 가 2026년 5월에 publish 없이 archive 처리되었습니다** ([archive 공지](https://github.com/invertase/dart_custom_lint#:~:text=no%20longer%20under%20active%20development), [관련 논의 #379](https://github.com/invertase/dart_custom_lint/issues/379)). 원작자는 공식 [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin) 으로의 이주를 권고했습니다. 우리 v2.0 마이그레이션이 완료되기 전까지, `clean_architecture_linter` 와 최신 `riverpod_generator 4.x`, `riverpod_lint 3.1.x`, `freezed 3.x`, `json_serializable 6.13+` 를 결합할 유일한 방법은 아래 override 입니다.

### 워크어라운드 — `pubspec_overrides.yaml`

`pubspec.yaml` 옆에 다음 파일을 추가하세요.

> **CI 관련 주의:** Flutter 기본 `.gitignore` 에는 `pubspec_overrides.yaml` 이 보통 포함되어 있습니다. CI 에서도 override 가 적용되게 하려면 `.gitignore` 에서 해당 라인을 제거하거나 `git add -f pubspec_overrides.yaml` 로 강제 스테이징하세요. 그렇지 않으면 로컬에서는 override 가 적용되지만 CI 는 pub.dev 기준으로 해소해서 동일한 충돌이 다시 납니다.

```yaml
# pubspec_overrides.yaml
dependency_overrides:
  clean_architecture_linter:
    git:
      url: https://github.com/ittae/clean_architecture_linter
      ref: main
  custom_lint:
    git:
      url: https://github.com/invertase/dart_custom_lint
      ref: main
      path: packages/custom_lint
  custom_lint_builder:
    git:
      url: https://github.com/invertase/dart_custom_lint
      ref: main
      path: packages/custom_lint_builder
  custom_lint_core:
    git:
      url: https://github.com/invertase/dart_custom_lint
      ref: main
      path: packages/custom_lint_core
  custom_lint_visitor:
    git:
      url: https://github.com/invertase/dart_custom_lint
      ref: main
      path: packages/custom_lint_visitor
```

### 검증

```bash
dart pub get
dart analyze
dart run custom_lint
```

`analyzer 9.0.0`, `custom_lint 0.8.2 (git)`, 그리고 최신 `riverpod_generator` / `riverpod_lint` / `freezed` 가 함께 해결되어야 합니다.

### 언제 제거할 수 있나요?

upstream 저장소가 **archive** 되었기 때문에 `custom_lint 0.8.2` release 는 영원히 나오지 않습니다. 따라서 이 override 는 publish 를 기다리는 임시 조치가 아니라, **`clean_architecture_linter v2.0` 이 공식 [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin) 으로 완전 이주할 때까지의 다리** 입니다. 진행 상황은 repo 이슈에서 추적하세요.

가는 동안 두 개의 정리 체크포인트:

1. **`clean_architecture_linter` 의 patch (예: `1.3.2`) 가 `analyzer: '>=8.4.0 <10.0.0'` 으로 pub.dev 에 publish 되는 시점**부터 `clean_architecture_linter` git override 만 먼저 제거 가능하고, `custom_lint*` override 만 남겨두면 됩니다. 현재 pub.dev 의 `1.3.1` 은 여전히 `analyzer: ^8.4.0` 이라 그 patch 가 나오기 전까지는 git override 가 필요합니다.
2. **v2.0 release 시점**에는 `custom_lint*` 의존성 체인 자체가 사라지고 `pubspec_overrides.yaml` 을 통째로 삭제할 수 있습니다.

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

**데이터베이스를 사용하는 데이터 모델 (ObjectBox 예시)**
```dart
// lib/data/models/user_model.dart
import 'package:objectbox/objectbox.dart';  // ✅ 허용됨

@Entity()  // ✅ @freezed 대신 데이터베이스 어노테이션 사용
class UserModel {
  @Id()
  int id = 0;

  String name;
  String email;

  UserModel({required this.name, required this.email});

  // ✅ Private 데이터베이스 접근은 허용됨
  static Box<UserModel> get _box => objectBoxService.store.box<UserModel>();

  // 변환 메서드
  UserEntity toEntity() => UserEntity(
    id: id.toString(),
    name: name,
    email: email,
  );
}
```

> **참고**: 데이터베이스 라이브러리(ObjectBox, Realm, Isar, Drift)를 사용할 때, Model은 **mutable**이며 `@freezed` 대신 데이터베이스 전용 어노테이션을 사용합니다. 이는 표준 Freezed 패턴의 예외입니다.

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

**Result 패턴을 사용하는 Repository**
```dart
// ❌ 이 패턴은 경고됨 - 대신 pass-through 패턴 사용
class UserRepositoryImpl implements UserRepository {
  @override
  Future<Result<UserEntity, Failure>> getUser(String id) async {
    try {
      final model = await dataSource.getUser(id);
      return Success(model.toEntity());
    } catch (e) {
      return Failure(UserFailure.fromException(e));
    }
  }
}

// ✅ 올바름: Pass-through 패턴
class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserEntity> getUser(String id) async {
    final model = await dataSource.getUser(id);  // 에러는 pass-through
    return model.toEntity();
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

**Pass-through 에러 처리 (권장)**
```dart
// ✅ 좋음: Pass-through 패턴
// DataSource가 AppException을 throw
class UserRemoteDataSource {
  Future<UserModel> getUser(String id) async {
    try {
      final response = await client.get('/users/$id');
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw e.toAppException();  // AppException으로 변환
    }
  }
}

// Repository는 pass-through (try-catch 없음)
class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserEntity> getUser(String id) async {
    final model = await dataSource.getUser(id);  // 에러는 pass-through
    return model.toEntity();
  }
}

// UseCase는 비즈니스 검증 추가
class GetUserUseCase {
  Future<UserEntity> call(String id) {
    if (id.isEmpty) {
      throw const InvalidInputException.withCode('errorValidationIdRequired');
    }
    return repository.getUser(id);  // Pass-through
  }
}

// Presentation은 AsyncValue.guard() 사용
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  Future<User> build(String id) => ref.read(getUserUseCaseProvider)(id);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(getUserUseCaseProvider)(id));
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
