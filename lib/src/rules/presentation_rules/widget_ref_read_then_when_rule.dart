import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that `ref.read()` should NOT be followed by `.when()` in the same function.
///
/// This is an anti-pattern because:
/// 1. `ref.read()` is for one-time reads, not for reactive UI updates
/// 2. `.when()` should be used with `ref.watch()` in build() for reactive UI
/// 3. After `await ref.read(provider.notifier).method()`, the state is already settled
/// 4. Using `.when()` after the operation completes defeats the purpose of AsyncValue
///
/// ❌ Anti-pattern:
/// ```dart
/// void onButtonPressed() async {
///   await ref.read(todoProvider.notifier).createTodo(title);
///
///   // ❌ WRONG - Using when() after operation completes
///   final state = ref.read(todoProvider);
///   state.when(
///     data: (_) => showSuccessToast(),
///     error: (e, _) => showErrorToast(e),
///     loading: () {},  // This will never be called!
///   );
/// }
/// ```
///
/// ✅ Correct patterns:
///
/// **Pattern 1: Use ref.watch() + when() in build():**
/// ```dart
/// @override
/// Widget build(BuildContext context, WidgetRef ref) {
///   final todoAsync = ref.watch(todoProvider);
///
///   return todoAsync.when(
///     data: (todos) => ListView(...),
///     loading: () => CircularProgressIndicator(),
///     error: (e, s) => ErrorWidget(e),
///   );
/// }
/// ```
///
/// **Pattern 2: Use ref.listen() for side effects (Toast):**
/// ```dart
/// @override
/// Widget build(BuildContext context, WidgetRef ref) {
///   ref.listen(todoProvider, (previous, next) {
///     if (previous?.isLoading == true && next.hasValue) {
///       showSuccessToast();
///     }
///     if (previous?.isLoading == true && next.hasError) {
///       showErrorToast(next.error);
///     }
///   });
///
///   final todoAsync = ref.watch(todoProvider);
///   return todoAsync.when(...);
/// }
/// ```
///
/// **Pattern 3: Use try-catch for one-off operations:**
/// ```dart
/// void onButtonPressed() async {
///   try {
///     await ref.read(todoProvider.notifier).createTodo(title);
///     if (context.mounted) showSuccessToast();
///   } catch (e) {
///     if (context.mounted) showErrorToast(e);
///   }
/// }
/// ```
///
/// See CLAUDE.md § Riverpod State Management Patterns
class WidgetRefReadThenWhenRule extends CleanArchitectureLintRule {
  const WidgetRefReadThenWhenRule() : super(code: _code);

  static const _code = LintCode(
    name: 'widget_ref_read_then_when',
    problemMessage:
        'Do NOT use .when() after ref.read() in the same function. Use ref.watch() in build() or ref.listen() for side effects.',
    correctionMessage:
        'ref.read() + .when() is an anti-pattern. The correct approach depends on your use case:\n\n'
        '1. For UI rendering: Use ref.watch() + .when() in build()\n'
        '2. For side effects (Toast/Dialog): Use ref.listen() in build()\n'
        '3. For one-off operations: Use try-catch instead of .when()\n\n'
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

    // Only check Widget/Page files in presentation layer
    if (!_isWidgetOrPageFile(filePath)) return;

    // Track ref.read() and .when() calls per function
    context.registry.addMethodDeclaration((methodNode) {
      _checkMethodForAntiPattern(methodNode, reporter);
    });

    // Also check function expressions (callbacks, onPressed, etc.)
    context.registry.addFunctionExpression((funcNode) {
      _checkFunctionForAntiPattern(funcNode.body, reporter);
    });
  }

  /// Check method declaration for anti-pattern
  void _checkMethodForAntiPattern(
    MethodDeclaration methodNode,
    ErrorReporter reporter,
  ) {
    final body = methodNode.body;
    if (body is! BlockFunctionBody) return;

    _checkFunctionForAntiPattern(body.block, reporter);
  }

  /// Check function body for ref.read() followed by .when()
  void _checkFunctionForAntiPattern(
    AstNode functionBody,
    ErrorReporter reporter,
  ) {
    final refReadCalls = <MethodInvocation>[];
    final whenCalls = <MethodInvocation>[];
    final variableAssignments = <String, MethodInvocation>{};

    // Collect all relevant nodes
    _collectNodes(
      functionBody,
      refReadCalls,
      whenCalls,
      variableAssignments,
    );

    // Check for anti-pattern
    if (refReadCalls.isEmpty || whenCalls.isEmpty) return;

    for (final whenCall in whenCalls) {
      // Check if when() is called on ref.read() result
      if (_isWhenCalledOnRefRead(whenCall, refReadCalls, variableAssignments)) {
        final code = LintCode(
          name: 'widget_ref_read_then_when',
          problemMessage:
              'Anti-pattern: Using .when() after ref.read() in the same function',
          correctionMessage:
              'ref.read() is for one-time reads. Using .when() after it defeats the purpose.\n\n'
              '❌ Current pattern:\n'
              '   final state = ref.read(provider);\n'
              '   state.when(...)  // Wrong - state is already settled\n\n'
              '✅ Better patterns:\n\n'
              '1. For reactive UI (in build()):\n'
              '   final stateAsync = ref.watch(provider);\n'
              '   return stateAsync.when(\n'
              '     data: (data) => UI(data),\n'
              '     loading: () => Loader(),\n'
              '     error: (e, s) => ErrorWidget(e),\n'
              '   );\n\n'
              '2. For side effects like Toast (in build()):\n'
              '   ref.listen(provider, (previous, next) {\n'
              '     if (previous?.isLoading == true && next.hasValue) {\n'
              '       showSuccessToast();\n'
              '     }\n'
              '   });\n\n'
              '3. For one-off operations:\n'
              '   try {\n'
              '     await ref.read(provider.notifier).method();\n'
              '     showSuccessToast();\n'
              '   } catch (e) {\n'
              '     showErrorToast(e);\n'
              '   }\n\n'
              'See CLAUDE.md § Riverpod State Management Patterns',
          errorSeverity: ErrorSeverity.WARNING,
        );
        reporter.atNode(whenCall, code);
      }
    }
  }

  /// Recursively collect ref.read(), .when(), and variable assignments
  void _collectNodes(
    AstNode node,
    List<MethodInvocation> refReadCalls,
    List<MethodInvocation> whenCalls,
    Map<String, MethodInvocation> variableAssignments,
  ) {
    // Check current node
    if (node is MethodInvocation) {
      if (node.methodName.name == 'read') {
        final target = node.target;
        if (target is SimpleIdentifier && target.name == 'ref') {
          refReadCalls.add(node);
        }
      }
      if (node.methodName.name == 'when') {
        whenCalls.add(node);
      }
    } else if (node is VariableDeclaration) {
      final initializer = node.initializer;
      if (initializer is MethodInvocation) {
        variableAssignments[node.name.lexeme] = initializer;
      }
    } else if (node is AssignmentExpression) {
      final leftHandSide = node.leftHandSide;
      final rightHandSide = node.rightHandSide;
      if (leftHandSide is SimpleIdentifier &&
          rightHandSide is MethodInvocation) {
        variableAssignments[leftHandSide.name] = rightHandSide;
      }
    }

    // Visit children
    for (final child in node.childEntities) {
      if (child is AstNode) {
        _collectNodes(child, refReadCalls, whenCalls, variableAssignments);
      }
    }
  }

  /// Check if when() is called on a ref.read() result
  bool _isWhenCalledOnRefRead(
    MethodInvocation whenCall,
    List<MethodInvocation> refReadCalls,
    Map<String, MethodInvocation> variableAssignments,
  ) {
    final target = whenCall.target;

    // Pattern 1: ref.read(provider).when()
    if (target is MethodInvocation && _isRefRead(target)) {
      return true;
    }

    // Pattern 2: final state = ref.read(provider); state.when()
    if (target is SimpleIdentifier) {
      final varName = target.name;
      final assignment = variableAssignments[varName];
      if (assignment != null && _isRefRead(assignment)) {
        return true;
      }
    }

    // Pattern 3: final state = ref.read(provider); ... state.when()
    // Check if any refRead was assigned to a variable with the same name
    if (target is SimpleIdentifier) {
      final varName = target.name;
      // Check if varName was used to store a ref.read() result
      for (final refRead in refReadCalls) {
        final parent = refRead.parent;
        if (parent is VariableDeclaration && parent.name.lexeme == varName) {
          return true;
        }
        if (parent is AssignmentExpression) {
          final leftHandSide = parent.leftHandSide;
          if (leftHandSide is SimpleIdentifier &&
              leftHandSide.name == varName) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if method invocation is ref.read()
  bool _isRefRead(MethodInvocation node) {
    if (node.methodName.name != 'read') return false;

    final target = node.target;
    if (target is SimpleIdentifier && target.name == 'ref') {
      return true;
    }

    return false;
  }

  /// Check if file is a Widget or Page file
  bool _isWidgetOrPageFile(String filePath) {
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();

    if (!normalizedPath.contains('/presentation/')) return false;

    return normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/pages/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/views/') ||
        normalizedPath.endsWith('_page.dart') ||
        normalizedPath.endsWith('_screen.dart') ||
        normalizedPath.endsWith('_view.dart') ||
        normalizedPath.endsWith('_widget.dart');
  }
}
