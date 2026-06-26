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

    test('does not flag a timer cancelled via onDispose tear-off', () async {
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
    ref.onDispose(timer.cancel);
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

    test('does not flag a listener disposed via onDispose tear-off', () async {
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
    ref.onDispose(listener.dispose);
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

    test('does not flag Riverpod-owned ref.listen callbacks', () async {
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
    ref.listen(counterProvider, (previous, next) {
      state = next;
    });
  }
}
''',
            },
            definingFile: _path,
          );

      result.expectNoDiagnostics();
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
      'does not flag a field timer cancelled via property tear-off',
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
  late final Timer _timer;

  Future<void> build() async {
    _timer = ref.watch(timerServiceProvider);
    _timer.start(onComplete: _onComplete);
    ref.onDispose(this._timer.cancel);
  }
}
''',
              },
              definingFile: _path,
            );

        result.expectNoDiagnostics();
      },
    );

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
