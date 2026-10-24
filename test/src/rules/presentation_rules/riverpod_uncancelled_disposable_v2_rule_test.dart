import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_uncancelled_disposable_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

const _path =
    'lib/features/pomodoro/presentation/providers/pomodoro_notifier.dart';

void main() {
  group('RiverpodUncancelledDisposableRule v2', () {
    test(
      'flags a timer started in build() but not cancelled in onDispose',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodUncancelledDisposableRule(),
            ).analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final timer = ref.watch(timerServiceProvider);
    timer.start(onComplete: _onComplete);
    ref.onDispose(() {
      _listener?.dispose();
    });
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: _path,
            codeName: 'riverpod_uncancelled_disposable',
          ),
        ]);
      },
    );

    test('does not flag a timer cancelled in onDispose', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final timer = ref.watch(timerServiceProvider);
    timer.start(onComplete: _onComplete);
    ref.onDispose(() {
      timer.cancel();
    });
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectNoDiagnostics();
    });

    test('flags an AppLifecycleListener that is not disposed', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final listener = AppLifecycleListener(onResume: _onResume);
    ref.onDispose(() {});
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: _path,
          codeName: 'riverpod_uncancelled_disposable',
        ),
      ]);
    });

    test('does not flag a listener disposed in onDispose', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final listener = AppLifecycleListener(onResume: _onResume);
    ref.onDispose(() => listener.dispose());
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectNoDiagnostics();
    });

    test('flags a stream subscription that is not cancelled', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final sub = someStream.listen(_onData);
    ref.onDispose(() {});
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: _path,
          codeName: 'riverpod_uncancelled_disposable',
        ),
      ]);
    });

    test(
      'does not flag assigned listen((e){}) when the subscription is cancelled',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodUncancelledDisposableRule(),
            ).analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final sub = someStream.listen((data) {});
    ref.onDispose(() {
      sub.cancel();
    });
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectNoDiagnostics();
      },
    );

    test('does not flag ref.listen (Riverpod-owned subscription)', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    ref.listen(otherProvider, (prev, next) {});
    ref.onDispose(() {});
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectNoDiagnostics();
    });

    test(
      'flags assigned Timer.periodic that is not cancelled in onDispose',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodUncancelledDisposableRule(),
            ).analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final t = Timer.periodic(const Duration(seconds: 1), (_) {});
    ref.onDispose(() {});
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: _path,
            codeName: 'riverpod_uncancelled_disposable',
          ),
        ]);
      },
    );

    test(
      'does not flag assigned Timer.periodic cancelled in onDispose',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodUncancelledDisposableRule(),
            ).analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final t = Timer.periodic(const Duration(seconds: 1), (_) {});
    ref.onDispose(() {
      t.cancel();
    });
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectNoDiagnostics();
      },
    );

    test('flags fire-and-forget Timer.periodic without assignment', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    Timer.periodic(const Duration(seconds: 1), (_) {});
    ref.onDispose(() {});
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: _path,
          codeName: 'riverpod_uncancelled_disposable',
        ),
      ]);
    });

    test(
      'matches the real bug: field timer not cancelled while listener is',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodUncancelledDisposableRule(),
            ).analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Timer? _timer;
  AppLifecycleListener? _listener;

  Future<void> build() async {
    _timer = ref.watch(timerServiceProvider);
    _timer?.start(onComplete: _onComplete);
    _listener = AppLifecycleListener(onResume: _onResume);
    ref.onDispose(() {
      _listener?.dispose();
    });
  }
}
''',
              },
              definingFile: _path,
            );

        // Only the timer is uncancelled; the listener is disposed.
        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: _path,
            codeName: 'riverpod_uncancelled_disposable',
          ),
        ]);
      },
    );

    test(
      'does not flag a timer cancelled through this.ref.onDispose',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodUncancelledDisposableRule(),
            ).analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {});
    this.ref.onDispose(() {
      timer.cancel();
    });
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectNoDiagnostics();
      },
    );

    test('does not flag this.timer.cancel inside onDispose', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Timer? timer;

  Future<void> build() async {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {});
    ref.onDispose(() {
      this.timer.cancel();
    });
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectNoDiagnostics();
    });

    test('flags timer.start with a positional callback', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final timer = ref.watch(timerServiceProvider);
    timer.start(() {});
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: _path,
          codeName: 'riverpod_uncancelled_disposable',
          problemMessage:
              'Timer/resource "timer" is started but not cancelled in ref.onDispose.',
        ),
      ]);
    });

    test('flags an unassigned Timer constructor call', () async {
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              _path: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    Timer(const Duration(seconds: 1), () {});
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: _path,
          codeName: 'riverpod_uncancelled_disposable',
          problemMessage:
              'Timer/resource is started but not cancelled in ref.onDispose.',
        ),
      ]);
    });

    test(
      'flags a resolved Timer constructor that build does not cancel',
      () async {
        final result =
            await V2RuleHarness(
              rule: RiverpodUncancelledDisposableRule(),
            ).analyze(
              files: {
                _path: '''
class riverpod {
  const riverpod();
}

class Timer {
  Timer(Duration duration, void Function() callback);
  Timer.periodic(Duration duration, void Function(Object tick) callback);
  void cancel() {}
}

class Duration {
  const Duration({this.seconds = 0});
  final int seconds;
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {});
    final kept = Timer.periodic(const Duration(seconds: 1), (_) {});
    Timer(const Duration(seconds: 1), () {});
    ref.onDispose(() {
      timer.cancel();
    });
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectDiagnostics([
          const ExpectedV2Diagnostic(
            relativePath: _path,
            codeName: 'riverpod_uncancelled_disposable',
            problemMessage:
                'Timer/resource "kept" is started but not cancelled in ref.onDispose.',
          ),
          const ExpectedV2Diagnostic(
            relativePath: _path,
            codeName: 'riverpod_uncancelled_disposable',
            problemMessage:
                'Timer/resource is started but not cancelled in ref.onDispose.',
          ),
        ]);
      },
    );

    group('onDispose cleanup forms', () {
      const timer = '  Timer? _timer;\n';
      const start =
          '  Future<void> build() async {\n'
          '    _timer = Timer.periodic(const Duration(seconds: 1), (_) {});\n';
      const cancelHelper = '  void _cleanup() {\n    _timer?.cancel();\n  }\n';
      // (name, class members, whether the timer is reported)
      const cases = <(String, String, bool)>[
        (
          'accepts a timer.cancel tear-off',
          '$start    ref.onDispose(_timer.cancel);\n  }',
          false,
        ),
        (
          'accepts a this.timer.cancel tear-off',
          '$start    ref.onDispose(this._timer.cancel);\n  }',
          false,
        ),
        (
          'accepts a listener.dispose tear-off',
          '  Future<void> build() async {\n'
              '    final listener = AppLifecycleListener(onResume: _onResume);\n'
              '    ref.onDispose(listener.dispose);\n'
              '  }',
          false,
        ),
        (
          'accepts a helper tear-off that cancels',
          '$timer$start    ref.onDispose(_cleanup);\n  }\n$cancelHelper',
          false,
        ),
        (
          'accepts a this-prefixed helper tear-off that cancels',
          '$timer$start    ref.onDispose(this._cleanup);\n  }\n$cancelHelper',
          false,
        ),
        (
          'accepts a helper call that cancels through another helper',
          '$timer$start    ref.onDispose(() => this._cleanup());\n  }\n'
              '  void _cleanup() => _stop();\n'
              '  void _stop() => _timer?.cancel();',
          false,
        ),
        (
          'accepts mutually recursive helpers that cancel',
          '$timer$start    ref.onDispose(_a);\n  }\n'
              '  void _a() => _b();\n'
              '  void _b() {\n    _a();\n    _timer?.cancel();\n  }',
          false,
        ),
        (
          'accepts a this.cancel tear-off whose helper cancels',
          '$timer$start    ref.onDispose(this.cancel);\n  }\n'
              '  void cancel() {\n    _timer?.cancel();\n  }',
          false,
        ),
        (
          'flags a helper that is only passed to another function in onDispose',
          '$timer$start    ref.onDispose(() => registry.add(_cleanup));\n  }\n$cancelHelper',
          true,
        ),
        (
          'flags a timer when onDispose only cascades on another object',
          '$timer$start    ref.onDispose(() => other..cancel());\n  }\n'
              '  void cancel() {\n    _timer?.cancel();\n  }',
          true,
        ),
        (
          'flags a helper tear-off that does not cancel',
          '$timer$start    ref.onDispose(_cleanup);\n  }\n  void _cleanup() {}',
          true,
        ),
        (
          'flags a this-prefixed helper tear-off that does not cancel',
          '$timer$start    ref.onDispose(this._cleanup);\n  }\n  void _cleanup() {}',
          true,
        ),
        (
          'flags a cancelling helper that is not registered in onDispose',
          '$timer$start    ref.onDispose(() {});\n  }\n$cancelHelper',
          true,
        ),
      ];

      for (final (name, members, flagged) in cases) {
        test(name, () async {
          final result =
              await V2RuleHarness(
                rule: RiverpodUncancelledDisposableRule(),
              ).analyze(
                files: {
                  _path:
                      'class riverpod {\n  const riverpod();\n}\n\n'
                      '@riverpod\nclass PomodoroNotifier {\n$members\n}\n',
                },
                definingFile: _path,
              );

          flagged
              ? result.expectDiagnostics([
                  const ExpectedV2Diagnostic(
                    relativePath: _path,
                    codeName: 'riverpod_uncancelled_disposable',
                  ),
                ])
              : result.expectNoDiagnostics();
        });
      }
    });

    test('skips non-provider files', () async {
      const widgetPath =
          'lib/features/pomodoro/presentation/widgets/pomodoro_widget.dart';
      final result =
          await V2RuleHarness(
            rule: RiverpodUncancelledDisposableRule(),
          ).analyze(
            files: {
              widgetPath: '''
class riverpod {
  const riverpod();
}

@riverpod
class PomodoroNotifier {
  Future<void> build() async {
    final timer = ref.watch(timerServiceProvider);
    timer.start(onComplete: _onComplete);
    ref.onDispose(() {});
  }
}
''',
            },
            definingFile: widgetPath,
          );

      result.expectNoDiagnostics();
    });
  });
}
