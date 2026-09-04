// Smoke fixture for the opt-in `riverpod_state_after_async_gap` rule.
// `analysis_options.yaml` enables it via `diagnostics:`; without that entry
// `dart analyze` must report nothing here (registerLintRule default = off).
abstract class _$StateGapNotifier {}

class StateGapNotifier extends _$StateGapNotifier {
  int state = 0;

  Future<void> load() async {
    await Future<void>.delayed(Duration.zero);
    state = 1; // riverpod_state_after_async_gap when enabled
  }
}
