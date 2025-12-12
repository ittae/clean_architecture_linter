import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that Presentation State should use AsyncValue for error handling.
///
/// In Clean Architecture with Riverpod, error states should be managed through
/// AsyncValue pattern, not by storing error fields in State classes. This rule
/// detects common anti-patterns where error information is manually stored.
///
/// **This rule is intentionally conservative** - it only flags obvious error fields
/// to avoid false positives. For comprehensive guidance on state management patterns,
/// see CLAUDE.md § Riverpod State Management Patterns.
///
/// ✅ Recommended Pattern (3-Tier Architecture):
/// ```dart
/// // Tier 1: Entity Provider (AsyncNotifier)
/// @riverpod
/// class TodoList extends _$TodoList {
///   @override
///   Future<List<Todo>> build() async {
///     final result = await ref.read(getTodosUseCaseProvider)();
///     return result.when(
///       success: (todos) => todos,
///       failure: (failure) => throw failure,
///     );
///   }
/// }
///
/// // Tier 2: UI State Provider (UI-only state)
/// @freezed
/// class TodoUIState with _$TodoUIState {
///   const factory TodoUIState({
///     @Default([]) List<String> selectedIds,  // ✅ UI state only
///   }) = _TodoUIState;
/// }
///
/// // Widget uses AsyncValue.when()
/// final todosAsync = ref.watch(todoListProvider);
/// todosAsync.when(
///   data: (todos) => ListView(...),
///   loading: () => CircularProgressIndicator(),
///   error: (error, stack) => ErrorWidget(error),
/// );
/// ```
///
/// ❌ Anti-pattern (detected by this rule):
/// ```dart
/// @freezed
/// class TodoState with _$TodoState {
///   const factory TodoState({
///     @Default([]) List<Todo> todos,
///     String? errorMessage,  // ❌ Storing error in State
///     Failure? failure,      // ❌ Storing failure in State
///   }) = _TodoState;
/// }
/// ```
///
/// **Note**: This rule does NOT enforce the 3-tier architecture strictly.
/// It only flags obvious error storage anti-patterns. For best practices,
/// see CLAUDE.md § Riverpod State Management Patterns.
class PresentationUseAsyncValueRule extends CleanArchitectureLintRule {
  const PresentationUseAsyncValueRule() : super(code: _code);

  static const _code = LintCode(
    name: 'presentation_use_async_value',
    problemMessage:
        'State should NOT store error fields. Use AsyncValue for error handling.',
    correctionMessage:
        'Remove error field. Use AsyncNotifier with AsyncValue.when() pattern instead.',
  );

  /// Error-related field names to detect (conservative list)
  ///
  /// This list intentionally excludes generic names like 'isLoading' to avoid
  /// false positives. We only flag obvious error storage patterns.
  static const errorFieldNames = {
    'error',
    'errorMessage',
    'errorMsg',
    'errorText',
    'errorDescription',
    'failure',
    'failureMessage',
    'exception',
    'exceptionMessage',
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
              problemMessage:
                  'State should NOT have error field "${variable.name.lexeme}". Use AsyncValue instead.',
              correctionMessage:
                  'Remove error field. Use AsyncNotifier with AsyncValue.when() pattern instead.',
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
  void _checkConstructorParameters(
    ConstructorDeclaration constructor,
    ErrorReporter reporter,
  ) {
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

      if (paramName != null &&
          nameNode != null &&
          _isErrorField(paramName.toLowerCase())) {
        final code = LintCode(
          name: 'presentation_use_async_value',
          problemMessage:
              'State should NOT have error parameter "$paramName". Use AsyncValue instead.',
          correctionMessage:
              'Remove error parameter. Use AsyncNotifier with AsyncValue.when() pattern instead.',
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
