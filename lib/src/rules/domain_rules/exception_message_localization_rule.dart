import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Suggests using localized (Korean) messages in Domain Exceptions.
///
/// Domain exceptions shown to users should use Korean messages for better UX.
///
/// ✅ Good: TodoNotFoundException('할 일을 찾을 수 없습니다')
/// ⚠️ Consider: TodoNotFoundException('Todo not found')
class ExceptionMessageLocalizationRule extends CleanArchitectureLintRule {
  const ExceptionMessageLocalizationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'exception_message_localization',
    problemMessage: 'Consider using Korean message for user-facing exceptions',
    correctionMessage:
        'Use Korean for better UX:\\n'
        '  ⚠️ English: TodoNotFoundException("Not found")\\n'
        '  ✅ Korean:  TodoNotFoundException("할 일을 찾을 수 없습니다")',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name2.lexeme;

      // Check if it's a Domain Exception (has feature prefix)
      if (_isDomainException(typeName)) {
        final args = node.argumentList.arguments;
        if (args.isNotEmpty) {
          final firstArg = args.first;
          if (firstArg is SimpleStringLiteral) {
            final message = firstArg.value;
            if (_isEnglishMessage(message)) {
              reporter.atNode(firstArg, _code);
            }
          }
        }
      }
    });
  }

  bool _isDomainException(String typeName) {
    return typeName.endsWith('Exception') &&
        typeName.length > 15 && // Has feature prefix
        !typeName.contains('Data') &&
        !typeName.contains('Cache') &&
        !typeName.contains('Database');
  }

  bool _isEnglishMessage(String message) {
    // Simple heuristic: if contains English words
    final englishPattern = RegExp(r'[a-zA-Z]{3,}');
    return englishPattern.hasMatch(message) && !_hasKorean(message);
  }

  bool _hasKorean(String message) {
    // Check for Korean characters
    return RegExp(r'[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]').hasMatch(message);
  }
}
