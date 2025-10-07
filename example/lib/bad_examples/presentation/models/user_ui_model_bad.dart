// ❌ WRONG: Creating presentation models directory
// This violates Clean Architecture presentation layer patterns

import '../../../domain/entities/user.dart';

/// ❌ Violation: presentation/models/ directory
///
/// This file is in presentation/models/ directory, which is not allowed.
/// Presentation layer should use states/ directory with Freezed State
/// containing Domain Entities directly.
///
/// The existence of presentation/models/ suggests creating UI-specific
/// models instead of using Domain Entities in State.
class UserUIModel {
  final String displayName;
  final String formattedEmail;
  final bool isOnline;

  const UserUIModel({
    required this.displayName,
    required this.formattedEmail,
    required this.isOnline,
  });

  /// ❌ Converting Domain Entity to Presentation Model (anti-pattern)
  factory UserUIModel.fromEntity(User user) {
    return UserUIModel(
      displayName: user.name.toUpperCase(),  // UI formatting
      formattedEmail: user.email.toLowerCase(),
      isOnline: user.lastLoginAt != null &&
          DateTime.now().difference(user.lastLoginAt!) < const Duration(hours: 1),
    );
  }
}

/// ❌ Another example of presentation model
class RankingUIModel {
  final String rankText;
  final String scoreDisplay;
  final String statusIcon;

  const RankingUIModel({
    required this.rankText,
    required this.scoreDisplay,
    required this.statusIcon,
  });
}

/// ✅ CORRECT: Use Freezed State with Domain Entities
///
/// Location: presentation/states/user_state.dart
///
/// ```dart
/// @freezed
/// class UserState with _$UserState {
///   const factory UserState({
///     User? user,  // ✅ Use Domain Entity directly
///     @Default(false) bool isLoading,
///   }) = _UserState;
/// }
///
/// // ✅ UI-specific logic as extensions on Entity
/// extension UserUIExtension on User {
///   String get displayName => name.toUpperCase();
///   String get formattedEmail => email.toLowerCase();
///   bool get isOnline =>
///       lastLoginAt != null &&
///       DateTime.now().difference(lastLoginAt!) < const Duration(hours: 1);
/// }
/// ```
///
/// Benefits:
/// - No data duplication between Entity and Model
/// - Single source of truth (Domain Entity)
/// - UI formatting logic as extensions
/// - State contains Entities directly
/// - Simpler architecture
