// ❌ WRONG: Using ViewModel pattern instead of Freezed State + Riverpod
// This violates Clean Architecture presentation layer patterns

import 'package:flutter/foundation.dart';
import '../../../domain/entities/ranking.dart';
import '../../../domain/usecases/get_ranking_usecase.dart';

/// ❌ Violation 1: ViewModel class name pattern
///
/// This class uses the ViewModel suffix, which is not allowed.
/// Clean Architecture with Flutter requires Freezed State + Riverpod pattern instead.
class RankingViewModel extends ChangeNotifier {  // ❌ ViewModel suffix + extends ChangeNotifier
  final GetRankingUseCase _getRankingUseCase;

  List<Ranking> _rankings = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Ranking> get rankings => _rankings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RankingViewModel(this._getRankingUseCase);

  Future<void> loadRankings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();  // ❌ Manual state notification

    try {
      _rankings = await _getRankingUseCase.execute();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

/// ❌ Violation 2: Another ViewModel example
class UserProfileViewModel extends ChangeNotifier {  // ❌ ViewModel + ChangeNotifier
  String? _userName;
  bool _isEditing = false;

  String? get userName => _userName;
  bool get isEditing => _isEditing;

  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }

  void toggleEdit() {
    _isEditing = !_isEditing;
    notifyListeners();
  }
}

/// ❌ Violation 3: ChangeNotifier without ViewModel suffix
/// (Still violates no_presentation_models_rule)
class RankingController extends ChangeNotifier {  // ❌ extends ChangeNotifier
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }
}

/// ✅ CORRECT: Use Freezed State + Riverpod
///
/// Step 1: Define immutable state with @freezed
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
/// Step 2: Create notifier with @riverpod
/// ```dart
/// @riverpod
/// class RankingNotifier extends _$RankingNotifier {
///   @override
///   RankingState build() {
///     return const RankingState();
///   }
///
///   Future<void> loadRankings() async {
///     state = state.copyWith(isLoading: true, errorMessage: null);
///
///     try {
///       final rankings = await ref.read(getRankingUseCaseProvider).execute();
///       state = state.copyWith(rankings: rankings, isLoading: false);
///     } catch (e) {
///       state = state.copyWith(
///         errorMessage: e.toString(),
///         isLoading: false,
///       );
///     }
///   }
///
///   void clearError() {
///     state = state.copyWith(errorMessage: null);
///   }
/// }
/// ```
///
/// Benefits:
/// - Immutable state (no accidental mutations)
/// - Type-safe state updates
/// - No manual notifyListeners()
/// - Better testability
/// - Compile-time safety
