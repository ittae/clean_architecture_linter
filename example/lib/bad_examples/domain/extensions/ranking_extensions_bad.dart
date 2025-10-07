// ❌ WRONG: Separate extensions/ directory for domain entity extensions
// This violates Clean Architecture extension patterns

import '../entities/ranking.dart';

/// ❌ Violation: domain/extensions/ directory
///
/// This file is in a separate extensions/ directory, which is not allowed.
/// Domain entity extensions should be defined in the same file as the entity.

/// ❌ Wrong: Separate extension file for business logic
extension RankingExtensions on Ranking {
  bool get isHighAttendance => attendeeCount > 5;

  bool get isPopular => attendeeCount > 10;

  String get attendanceLevel {
    if (attendeeCount > 10) return 'High';
    if (attendeeCount > 5) return 'Medium';
    return 'Low';
  }
}

/// ❌ Wrong: Another extension in separate file
extension RankingCalculations on Ranking {
  double get attendanceRate {
    // Some calculation
    return attendeeCount / 100.0;
  }
}

/// ✅ CORRECT: Define extensions in Entity file
///
/// Location: domain/entities/ranking.dart
///
/// ```dart
/// @freezed
/// class Ranking with _$Ranking {
///   const factory Ranking({
///     required String id,
///     required int attendeeCount,
///   }) = _Ranking;
/// }
///
/// // ✅ Business logic extensions in same file as Entity
/// extension RankingX on Ranking {
///   bool get isHighAttendance => attendeeCount > 5;
///   bool get isPopular => attendeeCount > 10;
///
///   String get attendanceLevel {
///     if (attendeeCount > 10) return 'High';
///     if (attendeeCount > 5) return 'Medium';
///     return 'Low';
///   }
///
///   double get attendanceRate => attendeeCount / 100.0;
/// }
/// ```
