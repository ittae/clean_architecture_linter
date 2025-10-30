import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper usage of ref.watch() vs ref.read() in Riverpod code.
///
/// **Correct Usage:**
/// - ✅ Provider build(): use `ref.watch()` for State providers (reactive dependencies)
/// - ✅ Provider build(): use `ref.read()` for UseCase providers (one-time function calls)
/// - ✅ Notifier methods: use `ref.read()` for all providers (one-time reads)
///
/// **Why This Matters:**
/// - `ref.watch()` creates reactive dependencies that rebuild when providers change
/// - `ref.read()` reads the current value without creating dependencies
/// - UseCase providers are called once and don't need reactive tracking
/// - State providers need `ref.watch()` to rebuild when data changes
///
/// ❌ Anti-patterns:
/// ```dart
/// // ❌ WRONG - ref.read() for State provider in build() misses reactive updates
/// @riverpod
/// class TodoList extends _$TodoList {
///   @override
///   Future<List<Todo>> build() async {
///     final user = ref.read(currentUserProvider);  // ❌ Won't rebuild on user change
///     return getTodos(user.id);
///   }
/// }
///
/// // ❌ WRONG - ref.watch() in method causes unnecessary rebuilds
/// @riverpod
/// class TodoNotifier extends _$TodoNotifier {
///   Future<void> createTodo(String title) async {
///     final user = ref.watch(currentUserProvider);  // ❌ Creates unwanted dependency
///     await repository.createTodo(user.id, title);
///   }
/// }
/// ```
///
/// ✅ Correct patterns:
/// ```dart
/// // ✅ CORRECT - ref.watch() for State provider in build()
/// @riverpod
/// class TodoList extends _$TodoList {
///   @override
///   Future<List<Todo>> build() async {
///     final user = ref.watch(currentUserProvider);  // ✅ Rebuilds when user changes
///     return getTodos(user.id);
///   }
/// }
///
/// // ✅ CORRECT - ref.read() for UseCase provider in build()
/// @riverpod
/// class TodoList extends _$TodoList {
///   @override
///   Future<List<Todo>> build() async {
///     final result = await ref.read(getTodosUseCaseProvider)();  // ✅ One-time UseCase call
///     return result.when(
///       success: (todos) => todos,
///       failure: (failure) => throw failure,
///     );
///   }
/// }
///
/// // ✅ CORRECT - ref.read() in methods for one-time access
/// @riverpod
/// class TodoNotifier extends _$TodoNotifier {
///   Future<void> createTodo(String title) async {
///     final user = ref.read(currentUserProvider);  // ✅ One-time read
///     await repository.createTodo(user.id, title);
///   }
/// }
///
/// // ✅ CORRECT - ref.read() for .notifier access
/// @riverpod
/// class TodoUI extends _$TodoUI {
///   void confirmSchedule() {
///     ref.read(scheduleProvider.notifier).confirm();  // ✅ .notifier always uses ref.read()
///   }
/// }
/// ```
///
/// See CLAUDE.md § Riverpod State Management Patterns for detailed guidance.
class RiverpodRefUsageRule extends CleanArchitectureLintRule {
  const RiverpodRefUsageRule() : super(code: _code);

  static const _code = LintCode(
    name: 'riverpod_ref_usage',
    problemMessage:
        'Incorrect ref usage: Use ref.watch() in build() and ref.read() in other methods.',
    correctionMessage:
        'ref.watch() vs ref.read() usage rules:\n\n'
        '✅ In build() methods: Use ref.watch() for reactive dependencies\n'
        '✅ In other methods: Use ref.read() for one-time reads\n\n'
        'See CLAUDE.md § Riverpod State Management Patterns',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Only check provider files in presentation layer
    if (!_isProviderFile(filePath)) return;

    context.registry.addClassDeclaration((classNode) {
      _checkProviderClass(classNode, reporter);
    });
  }

  /// Check if file is a provider file
  bool _isProviderFile(String filePath) {
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();

    if (!normalizedPath.contains('/presentation/')) return false;

    return normalizedPath.contains('/providers/') ||
        normalizedPath.endsWith('_provider.dart') ||
        normalizedPath.endsWith('_providers.dart') ||
        normalizedPath.endsWith('_notifier.dart') ||
        normalizedPath.endsWith('_notifiers.dart');
  }

  /// Check provider/notifier class for ref usage violations
  void _checkProviderClass(ClassDeclaration classNode, ErrorReporter reporter) {
    // Check if this is a Riverpod provider/notifier class
    if (!_isRiverpodProviderClass(classNode)) return;

    // Check all methods in the class
    for (final member in classNode.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        final isBuildMethod = methodName == 'build';

        _checkMethodRefUsage(member, isBuildMethod, reporter);
      }
    }
  }

  /// Check if class is a Riverpod provider or notifier
  bool _isRiverpodProviderClass(ClassDeclaration node) {
    // Check for @riverpod annotation
    for (final metadata in node.metadata) {
      final name = metadata.name.name;
      if (name == 'riverpod' || name == 'Riverpod') {
        return true;
      }
    }

    // Check if class extends a Riverpod base class
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name2.lexeme;
      // Matches generated notifier base classes like _$TodoList, _$TodoNotifier
      if (superclassName.startsWith('_\$')) {
        return true;
      }
    }

    return false;
  }

  /// Check method for incorrect ref.watch() or ref.read() usage
  void _checkMethodRefUsage(
    MethodDeclaration methodNode,
    bool isBuildMethod,
    ErrorReporter reporter,
  ) {
    final body = methodNode.body;
    if (body is! BlockFunctionBody && body is! ExpressionFunctionBody) return;

    // Collect all ref.watch() and ref.read() calls
    final refWatchCalls = <MethodInvocation>[];
    final refReadCalls = <MethodInvocation>[];

    _collectRefCalls(body, refWatchCalls, refReadCalls);

    if (isBuildMethod) {
      // In build() method: flag ref.read() for State providers only
      // Allow ref.read() for UseCase providers and .notifier access
      for (final refReadCall in refReadCalls) {
        // Skip if this is a UseCase provider call or .notifier access
        if (_isUseCaseProviderCall(refReadCall) ||
            _isNotifierAccess(refReadCall)) {
          continue;
        }

        final code = LintCode(
          name: 'riverpod_ref_usage',
          problemMessage:
              'Use ref.watch() instead of ref.read() for State providers in build().',
          correctionMessage:
              'In build() methods, use ref.watch() for State providers:\n\n'
              '❌ Current:\n'
              '   final user = ref.read(userProvider);  // Won\'t rebuild\n\n'
              '✅ Correct:\n'
              '   final user = ref.watch(userProvider);  // Rebuilds when user changes\n\n'
              'Note: ref.read() is correct for UseCase providers:\n'
              '✅ Allowed:\n'
              '   await ref.read(getTodosUseCaseProvider)();  // One-time UseCase call\n'
              '   ref.read(provider.notifier).method();       // .notifier access\n\n'
              'See CLAUDE.md § Riverpod State Management Patterns',
          errorSeverity: ErrorSeverity.WARNING,
        );
        reporter.atNode(refReadCall, code);
      }
    } else {
      // In other methods: flag ref.watch() usage
      for (final refWatchCall in refWatchCalls) {
        final code = LintCode(
          name: 'riverpod_ref_usage',
          problemMessage:
              'Use ref.read() instead of ref.watch() in methods for one-time reads.',
          correctionMessage:
              'In methods other than build(), use ref.read() for one-time reads:\n\n'
              '❌ Current:\n'
              '   final value = ref.watch(provider);  // Creates unwanted dependency\n\n'
              '✅ Correct:\n'
              '   final value = ref.read(provider);  // One-time read\n\n'
              'ref.watch() in methods creates reactive dependencies that can cause\n'
              'unexpected rebuilds and side effects.\n\n'
              'ref.read() provides one-time access without creating dependencies.\n\n'
              'See CLAUDE.md § Riverpod State Management Patterns',
          errorSeverity: ErrorSeverity.WARNING,
        );
        reporter.atNode(refWatchCall, code);
      }
    }
  }

  /// Recursively collect ref.watch() and ref.read() calls
  void _collectRefCalls(
    AstNode node,
    List<MethodInvocation> refWatchCalls,
    List<MethodInvocation> refReadCalls,
  ) {
    // Check current node
    if (node is MethodInvocation) {
      final methodName = node.methodName.name;
      final target = node.target;

      // Check if this is ref.watch() or ref.read()
      if (target is SimpleIdentifier && target.name == 'ref') {
        if (methodName == 'watch') {
          refWatchCalls.add(node);
        } else if (methodName == 'read') {
          refReadCalls.add(node);
        }
      }
    }

    // Visit children
    for (final child in node.childEntities) {
      if (child is AstNode) {
        _collectRefCalls(child, refWatchCalls, refReadCalls);
      }
    }
  }

  /// Check if ref.read() is calling a UseCase provider
  ///
  /// UseCase providers are identified by:
  /// 1. Name ends with "UseCaseProvider" (e.g., getTodosUseCaseProvider)
  /// 2. Followed immediately by a function call `()` (e.g., ref.read(useCaseProvider)())
  bool _isUseCaseProviderCall(MethodInvocation refReadCall) {
    // Get the provider argument
    final args = refReadCall.argumentList.arguments;
    if (args.isEmpty) return false;

    final firstArg = args.first;
    String? providerName;

    // Extract provider name from various patterns
    if (firstArg is SimpleIdentifier) {
      // Pattern: ref.read(getTodosUseCaseProvider)
      providerName = firstArg.name;
    } else if (firstArg is MethodInvocation) {
      // Pattern: ref.read(getTodosUseCaseProvider(...))
      providerName = firstArg.methodName.name;
    } else if (firstArg is FunctionExpressionInvocation) {
      // Pattern: ref.read(provider(args))
      final function = firstArg.function;
      if (function is SimpleIdentifier) {
        providerName = function.name;
      }
    }

    // Check if provider name indicates a UseCase
    if (providerName != null && _isUseCaseProviderName(providerName)) {
      return true;
    }

    // Check if ref.read() is immediately followed by a function call
    // Pattern: ref.read(provider)()
    final parent = refReadCall.parent;
    if (parent is FunctionExpressionInvocation) {
      return true;
    }

    // Check if it's an await followed by function call
    // Pattern: await ref.read(provider)()
    if (parent is AwaitExpression) {
      final grandParent = parent.parent;
      if (grandParent is FunctionExpressionInvocation) {
        return true;
      }
    }

    return false;
  }

  /// Check if provider name indicates a UseCase
  bool _isUseCaseProviderName(String name) {
    final lowerName = name.toLowerCase();

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

  /// Check if ref.read() is accessing .notifier
  ///
  /// Pattern: ref.read(provider.notifier)
  bool _isNotifierAccess(MethodInvocation refReadCall) {
    final args = refReadCall.argumentList.arguments;
    if (args.isEmpty) return false;

    final firstArg = args.first;

    // Check for property access pattern: provider.notifier
    if (firstArg is PropertyAccess) {
      final propertyName = firstArg.propertyName.name;
      if (propertyName == 'notifier') {
        return true;
      }
    }

    // Check for prefixed identifier pattern
    if (firstArg is PrefixedIdentifier) {
      final identifier = firstArg.identifier.name;
      if (identifier == 'notifier') {
        return true;
      }
    }

    return false;
  }
}
