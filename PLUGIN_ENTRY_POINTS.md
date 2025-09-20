# 🔌 Plugin Entry Points 설명

## createPlugin 함수가 어떻게 선택되는가?

### 🎯 **custom_lint가 createPlugin을 찾는 순서**

1. **패키지명과 동일한 파일**: `lib/clean_architecture_linter.dart`
2. **해당 파일의 createPlugin() 함수**를 자동으로 사용

### 📁 **현재 파일 구조**

```
lib/
├── clean_architecture_linter.dart          ← 🎯 메인 (자동 선택됨)
├── clean_architecture_linter_core.dart     ← createCorePlugin()
└── clean_architecture_linter_strict.dart   ← createStrictPlugin()
```

### 🔄 **다른 버전 사용하는 방법**

#### 방법 1: 직접 import (프로그래매틱)
```dart
// 기본 버전
import 'package:clean_architecture_linter/clean_architecture_linter.dart';
final plugin = createPlugin();

// 코어 버전
import 'package:clean_architecture_linter/clean_architecture_linter_core.dart';
final plugin = createCorePlugin();

// 엄격 버전
import 'package:clean_architecture_linter/clean_architecture_linter_strict.dart';
final plugin = createStrictPlugin();
```

#### 방법 2: 패키지 교체 (실제 사용)
```yaml
# pubspec.yaml에서 다른 패키지 버전 사용
dependencies:
  # 기본: 모든 규칙
  clean_architecture_linter: ^0.1.0

  # 또는 핵심만: (가상의 별도 패키지)
  # clean_architecture_linter_core: ^0.1.0
```

### 🛠️ **실제 동작 방식**

1. **분석 서버 시작 시**: `custom_lint`가 `lib/clean_architecture_linter.dart`를 찾음
2. **createPlugin() 호출**: 해당 파일의 `createPlugin()` 함수 실행
3. **규칙 로드**: 반환된 `PluginBase`에서 `getLintRules()` 호출
4. **분석 실행**: 각 규칙들이 코드를 검사

### 💡 **핵심 포인트**

- **오직 하나의 createPlugin()만 사용됨**: `lib/패키지명.dart` 파일의 것
- **다른 파일들은 라이브러리 형태로 제공**: 직접 import해서 사용 가능
- **자동 선택 불가**: pubspec.yaml에서 entry point 지정 기능 없음

### 🎯 **결론**

**Q**: createPlugin은 어떤 기준으로 특정 파일에서 제공되는가?
**A**: **패키지명과 동일한 파일명**(`lib/clean_architecture_linter.dart`)에서 자동으로 선택됩니다.

다른 버전을 원한다면:
1. 별도 패키지로 분리하거나
2. 직접 import해서 프로그래매틱하게 사용해야 합니다.