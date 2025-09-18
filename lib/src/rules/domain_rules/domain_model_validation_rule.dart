import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class DomainModelValidationRule extends DartLintRule {
  const DomainModelValidationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'domain_model_validation',
    problemMessage: 'Domain models should have proper validation and business rules.',
    correctionMessage: 'Add validation methods or business rule methods to domain entities.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkDomainModelValidation(node, reporter, resolver);
    });
  }

  void _checkDomainModelValidation(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!_isDomainLayerFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a domain entity
    if (!_isDomainEntity(className, filePath)) return;

    // Look for validation or business rule methods
    final hasValidation = _hasValidationMethods(node);
    final hasBusinessRules = _hasBusinessRuleMethods(node);

    // If entity has multiple fields but no validation, report warning
    final fieldCount = _getFieldCount(node);
    if (fieldCount > 2 && !hasValidation && !hasBusinessRules) {
      reporter.atNode(node, _code);
    }
  }

  bool _isDomainLayerFile(String filePath) {
    return filePath.contains('/domain/') ||
           filePath.contains('\\domain\\');
  }

  bool _isDomainEntity(String className, String filePath) {
    return className.endsWith('Entity') ||
           filePath.contains('/entities/') ||
           filePath.contains('\\entities\\');
  }

  bool _hasValidationMethods(ClassDeclaration node) {
    return node.members.any((member) {
      if (member is MethodDeclaration) {
        final name = member.name.lexeme.toLowerCase();
        return name.contains('valid') ||
               name.contains('check') ||
               name.contains('verify');
      }
      return false;
    });
  }

  bool _hasBusinessRuleMethods(ClassDeclaration node) {
    return node.members.any((member) {
      if (member is MethodDeclaration) {
        final name = member.name.lexeme.toLowerCase();
        return name.startsWith('can') ||
               name.startsWith('should') ||
               name.startsWith('is') && name.length > 2;
      }
      return false;
    });
  }

  int _getFieldCount(ClassDeclaration node) {
    var count = 0;
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        count += member.fields.variables.length;
      }
    }
    return count;
  }
}