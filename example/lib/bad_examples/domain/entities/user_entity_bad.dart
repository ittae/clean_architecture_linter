// ❌ WRONG: Entity without sealed modifier
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity_bad.freezed.dart';

/// ❌ Violation: Missing sealed modifier
@freezed
class UserEntityNoSealed with _$UserEntityNoSealed {
  const factory UserEntityNoSealed({
    required String id,
    required String name,
    required String email,
  }) = _UserEntityNoSealed;
}

/// ✅ Correct: Has sealed modifier and business logic extension
@freezed
sealed class UserEntityCorrect with _$UserEntityCorrect {
  const factory UserEntityCorrect({
    required String id,
    required String name,
    required String email,
  }) = _UserEntityCorrect;
}

extension UserEntityCorrectX on UserEntityCorrect {
  bool get hasValidEmail => email.contains('@');
}
