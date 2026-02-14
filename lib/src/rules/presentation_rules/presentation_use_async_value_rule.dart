import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces that Presentation State should use AsyncValue for error and loading handling.
///
/// In Clean Architecture with Riverpod, error and loading states should be managed
/// through AsyncValue pattern, not by storing error/loading fields in State classes.
/// This rule detects common anti-patterns where error or loading information is
/// manually stored in state.
///
/// **Key Principle**: AsyncValue automatically manages loading/error/data states.
/// Adding `isLoading` or `errorMessage` fields to your Freezed State is redundant
/// and can lead to inconsistent state.
///
/// ✅ Recommended Pattern (AsyncNotifier + UI State separation):
/// ```dart
/// // Entity Provider - AsyncValue manages loading/error/data
/// @riverpod
/// class TodoList extends _$TodoList {
///   @override
///   Future<List<Todo>> build() async {
///     return ref.read(getTodosUseCaseProvider)();
///   }
/// }
///
/// // UI State Provider - UI-only state (no error/loading)
/// @freezed
/// class TodoUIState with _$TodoUIState {
///   const factory TodoUIState({
///     @Default([]) List<String> selectedIds,  // ✅ UI state only
///     @Default(false) bool isEditing,         // ✅ UI state only
///   }) = _TodoUIState;
/// }
///
/// // Widget uses AsyncValue.when()
/// final todosAsync = ref.watch(todoListProvider);
/// todosAsync.when(
///   data: (todos) => ListView(...),
///   loading: () => CircularProgressIndicator(),  // ✅ Auto-managed
///   error: (error, stack) => ErrorWidget(error), // ✅ Auto-managed
/// );
/// ```
///
/// ❌ Anti-patterns (detected by this rule):
/// ```dart
/// @freezed
/// class TodoState with _$TodoState {
///   const factory TodoState({
///     @Default([]) List<Todo> todos,
///     @Default(false) bool isLoading,  // ❌ AsyncValue manages this
///     String? errorMessage,            // ❌ AsyncValue manages this
///     Failure? failure,                // ❌ AsyncValue manages this
///   }) = _TodoState;
/// }
/// ```
///
/// See STATE_MANAGEMENT_GUIDE.md and UNIFIED_ERROR_GUIDE.md for complete patterns.
class PresentationUseAsyncValueRule extends CleanArchitectureLintRule {
  const PresentationUseAsyncValueRule() : super(code: _code);

  static const _code = LintCode(
    name: 'presentation_use_async_value',
    problemMessage:
        'State should NOT store error/loading fields. Use AsyncValue instead.',
    correctionMessage:
        'Remove this field. Use AsyncNotifier with AsyncValue.when() pattern. '
        'AsyncValue automatically manages loading/error/data states.',
  );

  /// Error-related field names to detect
  ///
  /// These fields indicate manual error handling instead of using AsyncValue.
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

  /// Loading-related field names to detect
  ///
  /// These fields indicate manual loading state management instead of AsyncValue.
  static const loadingFieldNames = {
    'isLoading',
    'loading',
    'isSubmitting',
    'submitting',
    'isFetching',
    'fetching',
    'isProcessing',
    'processing',
  };

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkStateClass(node, reporter, resolver);
    });
  }

  void _checkStateClass(
    ClassDeclaration node,
    DiagnosticReporter reporter,
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

  /// Check for error/loading-related fields in the class
  void _checkForErrorFields(ClassDeclaration node, DiagnosticReporter reporter) {
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          final fieldNameLower = fieldName.toLowerCase();

          // Check if field name is error-related
          if (_isErrorField(fieldNameLower)) {
            final code = LintCode(
              name: 'presentation_use_async_value',
              problemMessage:
                  'State should NOT have error field "$fieldName". Use AsyncValue instead.',
              correctionMessage:
                  'Remove error field. Use AsyncNotifier with AsyncValue.when() pattern. '
                  'AsyncValue automatically manages error states.',
            );
            reporter.atNode(variable, code);
          }

          // Check if field name is loading-related
          if (_isLoadingField(fieldNameLower)) {
            final code = LintCode(
              name: 'presentation_use_async_value',
              problemMessage:
                  'State should NOT have loading field "$fieldName". Use AsyncValue instead.',
              correctionMessage:
                  'Remove loading field. Use AsyncNotifier with AsyncValue.when() pattern. '
                  'AsyncValue automatically manages loading states.',
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

  /// Check factory constructor parameters for error/loading fields
  void _checkConstructorParameters(
    ConstructorDeclaration constructor,
    DiagnosticReporter reporter,
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

      if (paramName == null || nameNode == null) continue;

      final paramNameLower = paramName.toLowerCase();

      // Check error fields
      if (_isErrorField(paramNameLower)) {
        final code = LintCode(
          name: 'presentation_use_async_value',
          problemMessage:
              'State should NOT have error parameter "$paramName". Use AsyncValue instead.',
          correctionMessage:
              'Remove error parameter. Use AsyncNotifier with AsyncValue.when() pattern. '
              'AsyncValue automatically manages error states.',
        );
        reporter.atNode(nameNode, code);
      }

      // Check loading fields
      if (_isLoadingField(paramNameLower)) {
        final code = LintCode(
          name: 'presentation_use_async_value',
          problemMessage:
              'State should NOT have loading parameter "$paramName". Use AsyncValue instead.',
          correctionMessage:
              'Remove loading parameter. Use AsyncNotifier with AsyncValue.when() pattern. '
              'AsyncValue automatically manages loading states.',
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

  /// Check if field name is loading-related
  bool _isLoadingField(String fieldName) {
    // Direct match
    if (loadingFieldNames.contains(fieldName)) {
      return true;
    }

    // Contains loading-related keywords
    for (final keyword in loadingFieldNames) {
      if (fieldName.contains(keyword)) {
        return true;
      }
    }

    return false;
  }
}
