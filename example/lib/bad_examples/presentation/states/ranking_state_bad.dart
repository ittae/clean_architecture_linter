// ❌ WRONG: Using Equatable instead of Freezed for presentation state
// This violates Clean Architecture presentation layer patterns

import 'package:equatable/equatable.dart';  // ❌ Equatable import
import '../../../domain/entities/ranking.dart';

/// ❌ Violation 1: Using Equatable instead of @freezed
///
/// This class uses Equatable for immutability and equality,
/// but Clean Architecture with Flutter requires @freezed instead.
class RankingEquatable extends Equatable {  // ❌ extends Equatable
  final List<Ranking> rankings;
  final bool isLoading;
  final String? errorMessage;

  const RankingEquatable({
    required this.rankings,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [rankings, isLoading, errorMessage];  // ❌ Manual props

  // ❌ Manual copyWith instead of generated
  RankingEquatable copyWith({
    List<Ranking>? rankings,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RankingEquatable(
      rankings: rankings ?? this.rankings,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ❌ Violation 2: Using Equatable in implements clause
class UserState implements Equatable {  // ❌ implements Equatable
  final String userId;
  final bool isActive;

  const UserState({
    required this.userId,
    required this.isActive,
  });

  @override
  List<Object?> get props => [userId, isActive];

  @override
  bool? get stringify => true;
}

/// ✅ CORRECT: Use Freezed for presentation state
///
/// ```dart
/// @freezed
/// class RankingState with _$RankingState {
///   const factory RankingState({
///     @Default([]) List<Ranking> rankings,
///     @Default(false) bool isLoading,
///     String? errorMessage,
///   }) = _RankingState;
/// }
/// ```
///
/// Benefits of @freezed:
/// - Auto-generated copyWith
/// - Immutability by default
/// - Pattern matching support
/// - Union types for state variants
/// - No manual props override needed
