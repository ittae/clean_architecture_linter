import 'package:clean_architecture_linter/src/rules/presentation_rules/riverpod_generator_rule.dart';
import 'package:test/test.dart';

import '../../../v2_harness/analysis_rule_harness.dart';

void main() {
  group('RiverpodGeneratorRule v2', () {
    test('reports manual providers in presentation providers', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
Object StateNotifierProvider(Object create) => create;
final todoProvider = StateNotifierProvider((ref) => Object());
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_provider.dart',
          codeName: 'riverpod_generator',
          problemMessage:
              'Manual provider "StateNotifierProvider" detected. Use @riverpod annotation instead.',
          correctionMessage:
              'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
        ),
      ]);
    });

    test('ignores non-provider presentation files', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/pages/todo_page.dart': '''
Object StateProvider(Object create) => create;
final todoProvider = StateProvider((ref) => Object());
''',
        },
        definingFile: 'lib/features/todo/presentation/pages/todo_page.dart',
      );

      result.expectNoDiagnostics();
    });

    test('skips generated files', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.g.dart': '''
Object FutureProvider(Object create) => create;
final todoProvider = FutureProvider((ref) => Object());
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.g.dart',
      );

      result.expectNoDiagnostics();
    });

    test('reports non-codegen NotifierProvider constructor', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
class NotifierProvider<A, B> {
  const NotifierProvider(Object create);
}

final todoProvider = NotifierProvider<Object, Object>(Object());
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_provider.dart',
          codeName: 'riverpod_generator',
          problemMessage:
              'Manual provider "NotifierProvider" detected. Use @riverpod annotation instead.',
          correctionMessage:
              'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
        ),
      ]);
    });

    test('reports non-codegen AsyncNotifierProvider constructor', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
class AsyncNotifierProvider<A, B> {
  const AsyncNotifierProvider(Object create);
}

final todoProvider = AsyncNotifierProvider<Object, Object>(Object());
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_provider.dart',
          codeName: 'riverpod_generator',
          problemMessage:
              'Manual provider "AsyncNotifierProvider" detected. Use @riverpod annotation instead.',
          correctionMessage:
              'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
        ),
      ]);
    });

    test('reports idiomatic NotifierProvider.autoDispose', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
class NotifierProvider {
  static Object autoDispose(Object create) => create;
}

final todoProvider = NotifierProvider.autoDispose(Object());
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_provider.dart',
          codeName: 'riverpod_generator',
          problemMessage:
              'Manual provider "NotifierProvider.autoDispose" detected. Use @riverpod annotation instead.',
          correctionMessage:
              'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
        ),
      ]);
    });

    test('reports idiomatic AsyncNotifierProvider.family', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
class AsyncNotifierProvider {
  static Object family(Object create) => create;
}

final todoProvider = AsyncNotifierProvider.family(Object());
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_provider.dart',
          codeName: 'riverpod_generator',
          problemMessage:
              'Manual provider "AsyncNotifierProvider.family" detected. Use @riverpod annotation instead.',
          correctionMessage:
              'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
        ),
      ]);
    });

    test('reports idiomatic NotifierProvider.autoDispose.family', () async {
      final result = await V2RuleHarness(rule: RiverpodGeneratorRule()).analyze(
        files: {
          'lib/features/todo/presentation/providers/todo_provider.dart': '''
class _AutoDispose {
  Object family(Object create) => create;
}

class NotifierProvider {
  static final autoDispose = _AutoDispose();
}

final todoProvider = NotifierProvider.autoDispose.family(Object());
''',
        },
        definingFile:
            'lib/features/todo/presentation/providers/todo_provider.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath:
              'lib/features/todo/presentation/providers/todo_provider.dart',
          codeName: 'riverpod_generator',
          problemMessage:
              'Manual provider "NotifierProvider.autoDispose.family" detected. Use @riverpod annotation instead.',
          correctionMessage:
              'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration.',
        ),
      ]);
    });
  });
}
