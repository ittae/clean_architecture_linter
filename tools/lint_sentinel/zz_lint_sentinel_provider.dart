// Plugin-load sentinel for clean_architecture_linter consumers.
//
// Copy this file, unchanged, to
//   lib/zz_lint_sentinel/presentation/providers/zz_lint_sentinel_provider.dart
// in the consumer app. Nothing imports it, so it is never compiled into the
// app. It deliberately violates two rules so that a `dart analyze
// --format=machine` run that actually received the plugin's diagnostics always
// reports at least one row for this path:
//
//   - riverpod_keep_alive (INFO): keepAlive on a feature-scoped name
//   - presentation_no_throw (WARNING): throw inside the presentation layer
//
// A run with zero rows for this path means the analysis_server_plugin isolate
// did not deliver (or only partially delivered) its diagnostics before
// `dart analyze` returned. Treat that run as inconclusive, not as clean.
// See tools/lint_sentinel/README.md for the CI recipe.
class Riverpod {
  const Riverpod({required bool keepAlive});
}

/// A domain-style exception: programming errors such as StateError are
/// exempt from presentation_no_throw, so the sentinel must throw its own type.
class ZzLintSentinelException implements Exception {
  const ZzLintSentinelException();
}

@Riverpod(keepAlive: true)
class ZzLintSentinelTodoListNotifier {
  Future<void> build() async {
    throw const ZzLintSentinelException();
  }
}
