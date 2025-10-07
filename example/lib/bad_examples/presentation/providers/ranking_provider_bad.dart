// ❌ WRONG: Using manual providers instead of @riverpod annotation
// This violates Clean Architecture presentation layer patterns

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/ranking.dart';
import '../../../domain/usecases/get_ranking_usecase.dart';

/// ❌ Violation 1: Manual StateNotifierProvider
///
/// This code manually creates a StateNotifierProvider.
/// Clean Architecture with Flutter requires @riverpod annotation instead.
final rankingNotifierProvider =
    StateNotifierProvider<RankingNotifier, AsyncValue<List<Ranking>>>((ref) {  // ❌ StateNotifierProvider
  final getRankingUseCase = ref.read(getRankingUseCaseProvider);
  return RankingNotifier(getRankingUseCase);
});

/// ❌ Violation 2: Manual ChangeNotifierProvider
final userNotifierProvider =
    ChangeNotifierProvider<UserNotifier>((ref) {  // ❌ ChangeNotifierProvider
  return UserNotifier();
});

/// ❌ Violation 3: Manual StateProvider
final counterProvider = StateProvider<int>((ref) => 0);  // ❌ StateProvider

/// ❌ Violation 4: Manual FutureProvider
final rankingFutureProvider = FutureProvider<List<Ranking>>((ref) async {  // ❌ FutureProvider
  final getRankingUseCase = ref.read(getRankingUseCaseProvider);
  return getRankingUseCase.execute();
});

/// ❌ Violation 5: Manual StreamProvider
final rankingStreamProvider = StreamProvider<List<Ranking>>((ref) {  // ❌ StreamProvider
  return Stream.periodic(
    const Duration(seconds: 5),
    (_) => <Ranking>[],
  );
});

/// Example notifier class
class RankingNotifier extends StateNotifier<AsyncValue<List<Ranking>>> {
  final GetRankingUseCase getRankingUseCase;

  RankingNotifier(this.getRankingUseCase) : super(const AsyncValue.loading());

  Future<void> loadRankings() async {
    state = const AsyncValue.loading();
    try {
      final rankings = await getRankingUseCase.execute();
      state = AsyncValue.data(rankings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// Example ChangeNotifier
class UserNotifier extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

/// Placeholder providers
final getRankingUseCaseProvider = Provider<GetRankingUseCase>((ref) {
  throw UnimplementedError();
});

/// ✅ CORRECT: Use @riverpod annotation
///
/// ```dart
/// @riverpod
/// class RankingNotifier extends _$RankingNotifier {
///   @override
///   FutureOr<List<Ranking>> build() async {
///     return _getRankingUseCase.execute();
///   }
///
///   Future<void> refresh() async {
///     state = const AsyncValue.loading();
///     state = await AsyncValue.guard(() => _getRankingUseCase.execute());
///   }
/// }
/// ```
///
/// Benefits of @riverpod:
/// - Type-safe generated providers
/// - Auto-dispose by default
/// - Family and autoDispose modifiers
/// - Better dependency injection
/// - Compile-time safety
