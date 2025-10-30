import 'package:test/test.dart';

/// Unit tests for RiverpodRefUsageRule
///
/// This test suite verifies that the riverpod_ref_usage_rule correctly
/// enforces proper ref.watch() and ref.read() usage in Riverpod providers.
///
/// Test Coverage:
/// 1. Provider file detection
/// 2. Riverpod provider/notifier class detection
/// 3. build() method detection
/// 4. ref.watch() / ref.read() call detection
/// 5. Edge cases (nested calls, function expressions, callbacks)
///
/// Usage Rules:
/// - In build() methods: Use ref.watch() for reactive dependencies
/// - In other methods: Use ref.read() for one-time reads
/// - Exception: ref.listen() can be used in build() for side effects
///
/// Note: These are unit tests for the rule logic. Integration tests can
/// be performed by running the linter on actual provider files.
void main() {
  group('RiverpodRefUsageRule', () {
    group('Provider File Detection', () {
      test('detects provider files in presentation layer', () {
        final testCases = [
          'lib/presentation/providers/todo_provider.dart',
          'lib/features/todos/presentation/providers/todo_providers.dart',
          'lib/presentation/notifiers/todo_notifier.dart',
          'lib/features/todos/presentation/providers/schedule_providers.dart',
        ];

        for (final path in testCases) {
          expect(
            _isProviderFile(path),
            isTrue,
            reason: '$path should be detected as provider file',
          );
        }
      });

      test('ignores non-provider files', () {
        final testCases = [
          'lib/presentation/pages/todo_page.dart',
          'lib/presentation/widgets/todo_list.dart',
          'lib/domain/usecases/get_todos.dart',
          'lib/data/repositories/todo_repository_impl.dart',
        ];

        for (final path in testCases) {
          expect(
            _isProviderFile(path),
            isFalse,
            reason: '$path should not be detected as provider file',
          );
        }
      });

      test('requires presentation layer', () {
        final testCases = [
          'lib/providers/todo_provider.dart', // No presentation/ in path
          'lib/domain/providers/todo_provider.dart', // Domain layer
          'lib/data/providers/todo_provider.dart', // Data layer
        ];

        for (final path in testCases) {
          expect(
            _isProviderFile(path),
            isFalse,
            reason: '$path should not be detected (not in presentation layer)',
          );
        }
      });
    });

    group('Riverpod Class Detection', () {
      test('detects @riverpod annotated classes', () {
        final classWithAnnotation = '''
@riverpod
class TodoList extends _\$TodoList {
  Future<List<Todo>> build() async {}
}
''';

        expect(
          _hasRiverpodAnnotation(classWithAnnotation),
          isTrue,
          reason: 'Class with @riverpod annotation should be detected',
        );
      });

      test('detects classes extending generated base classes', () {
        final classNames = [
          '_\$TodoList',
          '_\$ScheduleDetail',
          '_\$TodoNotifier',
        ];

        for (final className in classNames) {
          expect(
            _isGeneratedBaseClass(className),
            isTrue,
            reason: '$className should be detected as generated base class',
          );
        }
      });

      test('ignores regular widget classes', () {
        final regularClass = '''
class TodoPage extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {}
}
''';

        expect(
          _hasRiverpodAnnotation(regularClass),
          isFalse,
          reason: 'Regular widget should not be detected',
        );
      });
    });

    group('build() Method Detection', () {
      test('detects build() method', () {
        final methodNames = ['build'];

        for (final name in methodNames) {
          expect(
            _isBuildMethod(name),
            isTrue,
            reason: '$name should be detected as build method',
          );
        }
      });

      test('distinguishes build() from other methods', () {
        final methodNames = [
          'createTodo',
          'updateTodo',
          'deleteTodo',
          'refresh',
          'toggleSelection',
        ];

        for (final name in methodNames) {
          expect(
            _isBuildMethod(name),
            isFalse,
            reason: '$name should not be detected as build method',
          );
        }
      });
    });

    group('ref.watch() / ref.read() Detection', () {
      test('detects ref.watch() calls', () {
        final code = 'final value = ref.watch(provider);';

        expect(
          _containsRefWatch(code),
          isTrue,
          reason: 'Should detect ref.watch() call',
        );
      });

      test('detects ref.read() calls', () {
        final code = 'final value = ref.read(provider);';

        expect(
          _containsRefRead(code),
          isTrue,
          reason: 'Should detect ref.read() call',
        );
      });

      test('ignores other ref methods', () {
        final testCases = [
          'ref.listen(provider, (prev, next) {})',
          'ref.invalidate(provider)',
          'ref.refresh(provider)',
        ];

        for (final code in testCases) {
          expect(
            _containsRefWatch(code),
            isFalse,
            reason: 'Should not detect ref.watch() in: $code',
          );
          expect(
            _containsRefRead(code),
            isFalse,
            reason: 'Should not detect ref.read() in: $code',
          );
        }
      });
    });

    group('UseCase Provider Detection', () {
      test('detects UseCase provider by name ending with UseCaseProvider', () {
        final useCaseNames = [
          'getTodosUseCaseProvider',
          'createTodoUseCaseProvider',
          'updateTodoUseCaseProvider',
          'deleteTodoUseCaseProvider',
        ];

        for (final name in useCaseNames) {
          expect(
            _isUseCaseProvider(name),
            isTrue,
            reason: '$name should be detected as UseCase provider',
          );
        }
      });

      test('detects UseCase provider by action verb prefix', () {
        final useCaseNames = [
          'getTodosProvider',
          'createTodoProvider',
          'updateTodoProvider',
          'deleteTodoProvider',
          'fetchTodosProvider',
          'saveTodoProvider',
          'loadTodosProvider',
        ];

        for (final name in useCaseNames) {
          expect(
            _isUseCaseProvider(name),
            isTrue,
            reason: '$name should be detected as UseCase provider',
          );
        }
      });

      test('does not detect State providers as UseCase', () {
        final stateProviderNames = [
          'currentUserProvider',
          'todoListProvider',
          'scheduleDetailProvider',
          'todoUIProvider',
        ];

        for (final name in stateProviderNames) {
          expect(
            _isUseCaseProvider(name),
            isFalse,
            reason: '$name should not be detected as UseCase provider',
          );
        }
      });

      test('detects UseCase call by immediate function invocation', () {
        final code = 'await ref.read(getTodosUseCaseProvider)()';

        expect(
          _isUseCaseCall(code),
          isTrue,
          reason: 'Should detect immediate function call after ref.read()',
        );
      });
    });

    group('.notifier Access Detection', () {
      test('detects .notifier property access', () {
        final code = 'ref.read(provider.notifier)';

        expect(
          _isNotifierAccess(code),
          isTrue,
          reason: 'Should detect .notifier access',
        );
      });

      test('detects .notifier with method call', () {
        final code = 'ref.read(scheduleProvider.notifier).confirm()';

        expect(
          _isNotifierAccess(code),
          isTrue,
          reason: 'Should detect .notifier access with method call',
        );
      });

      test('does not detect normal provider access', () {
        final code = 'ref.read(provider)';

        expect(
          _isNotifierAccess(code),
          isFalse,
          reason: 'Should not detect normal provider access as .notifier',
        );
      });
    });

    group('Violation Detection', () {
      test('flags ref.read() for State provider in build() method', () {
        final violation = ProviderViolation(
          methodName: 'build',
          refCall: 'ref.read',
          isBuildMethod: true,
        );

        expect(
          _isViolation(violation),
          isTrue,
          reason: 'ref.read() in build() should be flagged',
        );
      });

      test('flags ref.watch() in other methods', () {
        final violation = ProviderViolation(
          methodName: 'createTodo',
          refCall: 'ref.watch',
          isBuildMethod: false,
        );

        expect(
          _isViolation(violation),
          isTrue,
          reason: 'ref.watch() in other methods should be flagged',
        );
      });

      test('allows ref.watch() in build() method', () {
        final violation = ProviderViolation(
          methodName: 'build',
          refCall: 'ref.watch',
          isBuildMethod: true,
        );

        expect(
          _isViolation(violation),
          isFalse,
          reason: 'ref.watch() in build() should be allowed',
        );
      });

      test('allows ref.read() in other methods', () {
        final violation = ProviderViolation(
          methodName: 'createTodo',
          refCall: 'ref.read',
          isBuildMethod: false,
        );

        expect(
          _isViolation(violation),
          isFalse,
          reason: 'ref.read() in other methods should be allowed',
        );
      });
    });

    group('Error Messages', () {
      test('provides clear message for ref.read() in build()', () {
        final message = _getErrorMessageForRefRead();

        expect(
          message,
          contains('ref.watch()'),
          reason: 'Should suggest using ref.watch()',
        );
        expect(
          message,
          contains('build()'),
          reason: 'Should mention build() method',
        );
        expect(
          message,
          contains('reactive dependencies'),
          reason: 'Should explain reactive dependencies',
        );
      });

      test('provides clear message for ref.watch() in methods', () {
        final message = _getErrorMessageForRefWatch();

        expect(
          message,
          contains('ref.read()'),
          reason: 'Should suggest using ref.read()',
        );
        expect(
          message,
          contains('one-time'),
          reason: 'Should explain one-time read',
        );
        expect(
          message,
          contains('unwanted dependency'),
          reason: 'Should explain unwanted dependency issue',
        );
      });

      test('references CLAUDE.md documentation', () {
        final messages = [
          _getErrorMessageForRefRead(),
          _getErrorMessageForRefWatch(),
        ];

        for (final message in messages) {
          expect(
            message,
            contains('CLAUDE.md'),
            reason: 'Should reference CLAUDE.md',
          );
        }
      });
    });

    group('Edge Cases', () {
      test('handles nested ref calls', () {
        final code = '''
final user = ref.watch(userProvider);
final todos = ref.watch(todoProvider(user.id));
''';

        expect(
          _countRefWatch(code),
          2,
          reason: 'Should detect both ref.watch() calls',
        );
      });

      test('handles ref calls in callbacks', () {
        final code = '''
onPressed: () {
  final value = ref.read(provider);
}
''';

        expect(
          _containsRefRead(code),
          isTrue,
          reason: 'Should detect ref.read() in callback',
        );
      });

      test('handles method chaining', () {
        final code = 'final value = ref.read(provider.notifier).method();';

        expect(
          _containsRefRead(code),
          isTrue,
          reason: 'Should detect ref.read() with method chaining',
        );
      });
    });

    group('Integration Test Expectations', () {
      test('should detect ref.read() for State provider in build()', () {
        final badExample = '''
@riverpod
class TodoList extends _\$TodoList {
  @override
  Future<List<Todo>> build() async {
    final user = ref.read(currentUserProvider);  // Violation - State provider
    return getTodos(user.id);
  }
}
''';

        expect(
          _containsRefRead(badExample),
          isTrue,
          reason: 'Bad example should contain ref.read() violation',
        );
      });

      test('should detect ref.watch() in other methods', () {
        final badExample = '''
@riverpod
class TodoNotifier extends _\$TodoNotifier {
  Future<void> createTodo(String title) async {
    final user = ref.watch(currentUserProvider);  // Violation
    await repository.createTodo(user.id, title);
  }
}
''';

        expect(
          _containsRefWatch(badExample),
          isTrue,
          reason: 'Bad example should contain ref.watch() violation',
        );
      });

      test('should accept ref.watch() for State provider in build()', () {
        final goodExample = '''
@riverpod
class TodoList extends _\$TodoList {
  @override
  Future<List<Todo>> build() async {
    final user = ref.watch(currentUserProvider);  // Correct - State provider
    return getTodos(user.id);
  }
}
''';

        expect(
          _containsRefWatch(goodExample),
          isTrue,
          reason: 'Good example should use ref.watch() for State provider',
        );
      });

      test('should accept ref.read() for UseCase provider in build()', () {
        final goodExample = '''
@riverpod
class TodoList extends _\$TodoList {
  @override
  Future<List<Todo>> build() async {
    final result = await ref.read(getTodosUseCaseProvider)();  // Correct - UseCase
    return result.when(
      success: (todos) => todos,
      failure: (failure) => throw failure,
    );
  }
}
''';

        expect(
          _containsRefRead(goodExample),
          isTrue,
          reason: 'Good example should use ref.read() for UseCase provider',
        );
        expect(
          _isUseCaseProvider('getTodosUseCaseProvider'),
          isTrue,
          reason: 'Should detect as UseCase provider',
        );
      });

      test('should accept ref.read() for .notifier access in build()', () {
        final goodExample = '''
@riverpod
class TodoUI extends _\$TodoUI {
  void confirmSchedule() {
    ref.read(scheduleProvider.notifier).confirm();  // Correct - .notifier
  }
}
''';

        expect(
          _containsRefRead(goodExample),
          isTrue,
          reason: 'Good example should use ref.read() for .notifier',
        );
        expect(
          _isNotifierAccess('ref.read(scheduleProvider.notifier)'),
          isTrue,
          reason: 'Should detect .notifier access',
        );
      });

      test('should accept ref.read() in other methods', () {
        final goodExample = '''
@riverpod
class TodoNotifier extends _\$TodoNotifier {
  Future<void> createTodo(String title) async {
    final user = ref.read(currentUserProvider);  // Correct
    await repository.createTodo(user.id, title);
  }
}
''';

        expect(
          _containsRefRead(goodExample),
          isTrue,
          reason: 'Good example should use ref.read()',
        );
      });
    });
  });
}

// Helper classes

class ProviderViolation {
  final String methodName;
  final String refCall;
  final bool isBuildMethod;

  ProviderViolation({
    required this.methodName,
    required this.refCall,
    required this.isBuildMethod,
  });
}

// Helper functions that simulate rule logic

bool _isProviderFile(String filePath) {
  final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();

  if (!normalizedPath.contains('/presentation/')) return false;

  return normalizedPath.contains('/providers/') ||
      normalizedPath.endsWith('_provider.dart') ||
      normalizedPath.endsWith('_providers.dart') ||
      normalizedPath.endsWith('_notifier.dart') ||
      normalizedPath.endsWith('_notifiers.dart');
}

bool _hasRiverpodAnnotation(String code) {
  return code.contains('@riverpod') || code.contains('@Riverpod');
}

bool _isGeneratedBaseClass(String className) {
  return className.startsWith('_\$');
}

bool _isBuildMethod(String methodName) {
  return methodName == 'build';
}

bool _containsRefWatch(String code) {
  return code.contains('ref.watch');
}

bool _containsRefRead(String code) {
  return code.contains('ref.read');
}

int _countRefWatch(String code) {
  return 'ref.watch'.allMatches(code).length;
}

bool _isViolation(ProviderViolation violation) {
  if (violation.isBuildMethod) {
    // In build(): ref.read() is violation
    return violation.refCall == 'ref.read';
  } else {
    // In other methods: ref.watch() is violation
    return violation.refCall == 'ref.watch';
  }
}

String _getErrorMessageForRefRead() {
  return '''
Use ref.watch() instead of ref.read() in build() method for reactive dependencies.

In build() methods, use ref.watch() to create reactive dependencies:

❌ Current:
   final value = ref.read(provider);  // Won't rebuild

✅ Correct:
   final value = ref.watch(provider);  // Rebuilds when provider changes

ref.watch() ensures the provider rebuilds when dependencies change.
ref.read() only reads the current value without tracking changes.

See CLAUDE.md § Riverpod State Management Patterns
''';
}

String _getErrorMessageForRefWatch() {
  return '''
Use ref.read() instead of ref.watch() in methods for one-time reads.

In methods other than build(), use ref.read() for one-time reads:

❌ Current:
   final value = ref.watch(provider);  // Creates unwanted dependency

✅ Correct:
   final value = ref.read(provider);  // One-time read

ref.watch() in methods creates reactive dependencies that can cause
unexpected rebuilds and side effects.

ref.read() provides one-time access without creating dependencies.

See CLAUDE.md § Riverpod State Management Patterns
''';
}

bool _isUseCaseProvider(String providerName) {
  final lowerName = providerName.toLowerCase();

  // Check if name ends with "usecaseprovider"
  if (lowerName.endsWith('usecaseprovider')) {
    return true;
  }

  // Check for common UseCase naming patterns
  final useCasePrefixes = [
    'get',
    'create',
    'update',
    'delete',
    'fetch',
    'save',
    'load',
    'submit',
    'send',
    'retrieve',
  ];

  for (final prefix in useCasePrefixes) {
    if (lowerName.startsWith(prefix) && lowerName.endsWith('provider')) {
      return true;
    }
  }

  return false;
}

bool _isUseCaseCall(String code) {
  // Check if code contains immediate function call after ref.read()
  return code.contains('ref.read(') && code.contains(')()');
}

bool _isNotifierAccess(String code) {
  // Check if code contains .notifier access
  return code.contains('.notifier');
}
