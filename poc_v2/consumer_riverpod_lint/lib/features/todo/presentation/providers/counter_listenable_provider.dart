import 'package:riverpod/riverpod.dart';

final counterProvider = Provider<int>((ref) => 0);

/// Riverpod 3.4 `ProviderListenable.listenable` watched from `build()`.
/// `riverpod_ref_usage` must not treat this as a `ref.read` in `build()`.
class CounterListenable {
  CounterListenable(this.ref);

  final Ref ref;

  int build() {
    final listenable = ref.watch(counterProvider.listenable);
    return listenable.value;
  }
}
