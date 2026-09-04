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
/// Stand-in for riverpod_annotation's `@Riverpod`, so the sentinel has no
/// package dependency. Only the `keepAlive` argument matters to the rule.
class Riverpod {
  /// Creates the annotation stand-in.
  const Riverpod({required this.keepAlive});

  /// Mirrors `Riverpod.keepAlive`.
  final bool keepAlive;
}

/// A domain-style exception: programming errors such as StateError are
/// exempt from presentation_no_throw, so the sentinel must throw its own type.
class ZzLintSentinelException implements Exception {
  /// Creates the sentinel exception.
  const ZzLintSentinelException();
}

/// Deliberately violates `riverpod_keep_alive` (feature-scoped name kept
/// alive) and `presentation_no_throw` (throws inside a notifier).
@Riverpod(keepAlive: true)
class ZzLintSentinelTodoListNotifier {
  /// Throws so `presentation_no_throw` reports this line.
  Future<void> build() {
    throw const ZzLintSentinelException();
  }
}
