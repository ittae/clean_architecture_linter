import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that Presentation State should use AsyncValue for error handling.
///
/// In Clean Architecture with Riverpod, error states should be managed through
/// AsyncValue pattern, not by storing error fields in State classes. This
/// ensures proper error handling and UI state management.
///
/// Error handling flow:
/// - Notifier: Returns Future → Riverpod auto-wraps in AsyncValue
/// - State: Pure data, no error fields
/// - Widget: Uses AsyncValue.when() to handle loading/error/data states
///
/// ✅ Correct Pattern:
/// ```dart
/// // presentation/states/todo_notifier.dart
/// @riverpod
/// class TodoNotifier extends _$TodoNotifier {
///   @override
///   Future<List<Todo>> build() async {
///     // ✅ Return Future - Riverpod wraps in AsyncValue
///     return repository.getTodos();
///   }
/// }
///
/// // presentation/widgets/todo_list.dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   final todosAsync = ref.watch(todoNotifierProvider);
///
///   // ✅ Use AsyncValue.when() for error handling
///   return todosAsync.when(
///     data: (todos) => ListView(...),
///     loading: () => CircularProgressIndicator(),
///     error: (error, stack) => ErrorWidget(error),
///   );
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ Storing error in State
/// @freezed
/// class TodoState with _$TodoState {
///   const factory TodoState({
///     @Default([]) List<Todo> todos,
///     String? errorMessage,  // ❌ Don't store errors in State
///     bool isLoading,        // ❌ AsyncValue handles loading state
///   }) = _TodoState;
/// }
/// ```
///
/// See ERROR_HANDLING_GUIDE.md for complete error handling patterns.
class PresentationUseAsyncValueRule extends CleanArchitectureLintRule {
  const PresentationUseAsyncValueRule() : super(code: _code);

  static const _code = LintCode(
    name: 'presentation_use_async_value',
    problemMessage: 'Presentation State should NOT store error fields. Use AsyncValue for error handling.',
    correctionMessage: 'Remove error fields from State and use AsyncValue pattern:\\n'
        '  ❌ Bad:  @freezed class State { String? errorMessage; }\\n'
        '  ✅ Good: @riverpod Future<T> build() => repository.getData()\\n\\n'
        'AsyncValue automatically handles loading, error, and data states.\\n'
        'See ERROR_HANDLING_GUIDE.md',
  );

  /// Error-related field names to detect
  static const errorFieldNames = {
    'error',
    'errorMessage',
    'errorMsg',
    'failure',
    'exception',
  };

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkStateClass(node, reporter, resolver);
    });
  }

  void _checkStateClass(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check Presentation State files
    if (!CleanArchitectureUtils.isPresentationFile(filePath)) return;

    // Check if class is a Freezed State (has @freezed annotation)
    if (!_isFreezedState(node)) return;

    // Check for error fields in the class
    _checkForErrorFields(node, reporter);
  }

  /// Check if class has @freezed annotation
  bool _isFreezedState(ClassDeclaration node) {
    for (final metadata in node.metadata) {
      final name = metadata.name.name;
      if (name == 'freezed' || name == 'Freezed') {
        return true;
      }
    }
    return false;
  }

  /// Check for error-related fields in the class
  void _checkForErrorFields(ClassDeclaration node, ErrorReporter reporter) {
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme.toLowerCase();

          // Check if field name contains error-related keywords
          if (_isErrorField(fieldName)) {
            final code = LintCode(
              name: 'presentation_use_async_value',
              problemMessage: 'State should NOT have error field "${variable.name.lexeme}". Use AsyncValue instead.',
              correctionMessage: 'Remove error field and use AsyncValue pattern:\\n\\n'
                  'Instead of storing errors in State:\\n'
                  '  ❌ @freezed class TodoState { String? ${variable.name.lexeme}; }\\n\\n'
                  'Use Riverpod AsyncValue:\\n'
                  '  ✅ @riverpod\\n'
                  '     class TodoNotifier extends _\$TodoNotifier {\\n'
                  '       @override\\n'
                  '       Future<List<Todo>> build() async {\\n'
                  '         return repository.getTodos();\\n'
                  '       }\\n'
                  '     }\\n\\n'
                  'AsyncValue handles loading, error, and data states automatically.',
            );
            reporter.atNode(variable, code);
          }
        }
      }

      // Also check factory constructor parameters
      if (member is ConstructorDeclaration) {
        _checkConstructorParameters(member, reporter);
      }
    }
  }

  /// Check factory constructor parameters for error fields
  void _checkConstructorParameters(ConstructorDeclaration constructor, ErrorReporter reporter) {
    for (final param in constructor.parameters.parameters) {
      String? paramName;
      AstNode? nameNode;

      if (param is DefaultFormalParameter) {
        paramName = param.parameter.name?.lexeme;
        nameNode = param.parameter;
      } else if (param is SimpleFormalParameter) {
        paramName = param.name?.lexeme;
        nameNode = param;
      } else if (param is FieldFormalParameter) {
        paramName = param.name.lexeme;
        nameNode = param;
      }

      if (paramName != null && nameNode != null && _isErrorField(paramName.toLowerCase())) {
        final code = LintCode(
          name: 'presentation_use_async_value',
          problemMessage: 'State should NOT have error parameter "$paramName". Use AsyncValue instead.',
          correctionMessage: 'Remove error parameter and use AsyncValue pattern:\\n'
              '  ❌ factory State({ String? $paramName })\\n'
              '  ✅ Use @riverpod Future<T> build() pattern\\n\\n'
              'See ERROR_HANDLING_GUIDE.md',
        );
        reporter.atNode(nameNode, code);
      }
    }
  }

  /// Check if field name is error-related
  bool _isErrorField(String fieldName) {
    // Direct match
    if (errorFieldNames.contains(fieldName)) {
      return true;
    }

    // Contains error-related keywords
    for (final keyword in errorFieldNames) {
      if (fieldName.contains(keyword)) {
        return true;
      }
    }

    return false;
  }
}
