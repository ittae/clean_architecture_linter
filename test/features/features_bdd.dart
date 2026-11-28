// characterization: locks current behavior; not red-first proof of this change
//
// Runs every test/features/*.feature through the gherkin runner. The file name
// does not end in _test.dart, so a bare `dart test` and PR CI skip it. Run it
// with `dart test test/features/features_bdd.dart` or `./scripts/verify.sh`.
import 'dart:io';

import 'package:gherkin/gherkin.dart';
import 'package:test/test.dart';

import 'steps/lint_steps.dart';

class _ScenarioCounter extends Hook {
  int finished = 0;

  @override
  Future<void> onAfterScenario(
    TestConfiguration config,
    String scenario,
    Iterable<Tag> tags, {
    bool passed = true,
  }) async => finished++;
}

void main() {
  final directory = Directory('test/features');
  final names = [
    for (final file in directory.listSync().whereType<File>())
      if (file.path.endsWith('.feature')) file.uri.pathSegments.last,
  ]..sort();

  test('test/features holds a .feature file', () => expect(names, isNotEmpty));

  for (final name in names) {
    test('feature $name', () async {
      // The runner passes when it finds no feature or drops a scenario, so the
      // scenarios it finished are compared with the ones the file declares.
      final source = File('${directory.path}/$name').readAsStringSync();
      final declared = RegExp(
        r'^\s*Scenario:',
        multiLine: true,
      ).allMatches(source);
      final counter = _ScenarioCounter();
      await GherkinRunner().execute(
        TestConfiguration(
          features: [RegExp('^${RegExp.escape(name)}\$')],
          featureFileMatcher: IoFeatureFileAccessor(
            workingDirectory: directory,
          ),
          order: ExecutionOrder.alphabetical,
          defaultTimeout: const Duration(minutes: 2),
          stepDefinitions: lintSteps,
          createWorld: (_) async => LintWorld(),
          hooks: [counter],
          reporters: [StdoutReporter(MessageLevel.error), ProgressReporter()],
        ),
      );
      expect(declared, isNotEmpty, reason: '$name declares no Scenario');
      expect(counter.finished, declared.length, reason: '$name scenarios run');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
