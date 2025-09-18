import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class EntityImmutabilityRule extends DartLintRule {
  const EntityImmutabilityRule() : super(code: _code);

  static const _code = LintCode(
    name: 'entity_immutability',
    problemMessage: 'Domain entities should be immutable.',
    correctionMessage: 'Make all fields final and remove setters from entity classes.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkEntityImmutability(node, reporter, resolver);
    });
  }

  void _checkEntityImmutability(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!_isDomainLayerFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is an entity class
    if (!_isEntityClass(className, filePath)) return;

    // Check for mutable fields
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final fields = member.fields;
        if (!fields.isFinal && !fields.isConst) {
          // Check if it's a private field that might be acceptable
          final isPrivate = fields.variables.any((variable) =>
            variable.name.lexeme.startsWith('_'));

          if (!isPrivate) {
            reporter.atNode(member, _code);
          }
        }
      } else if (member is MethodDeclaration) {
        // Check for setters
        if (member.isSetter) {
          reporter.atNode(member, _code);
        }
      }
    }
  }

  bool _isDomainLayerFile(String filePath) {
    return filePath.contains('/domain/') ||
           filePath.contains('\\domain\\');
  }

  bool _isEntityClass(String className, String filePath) {
    return className.endsWith('Entity') ||
           filePath.contains('/entities/') ||
           filePath.contains('\\entities\\');
  }
}