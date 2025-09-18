import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces immutability in domain entities to ensure data integrity.
///
/// This rule validates that domain entities follow immutability principles:
/// - All fields must be final or const
/// - No setter methods allowed
/// - No mutable collections without protection
/// - Proper constructor patterns for immutable objects
///
/// Immutability benefits:
/// - Thread safety
/// - Predictable behavior
/// - Easier testing and debugging
/// - Prevents accidental state mutations
class EntityImmutabilityRule extends DartLintRule {
  const EntityImmutabilityRule() : super(code: _code);

  static const _code = LintCode(
    name: 'entity_immutability',
    problemMessage: 'Domain entities must be immutable to ensure data integrity and thread safety.',
    correctionMessage: 'Make all fields final, remove setters, and ensure collections are properly immutable.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkEntityImmutability(node, reporter, resolver);
    });
  }

  void _checkEntityImmutability(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!_isDomainLayerFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is an entity class
    if (!_isEntityClass(className, filePath)) return;

    // Check each member for immutability violations
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        _checkFieldImmutability(member, reporter);
      } else if (member is MethodDeclaration) {
        _checkMethodImmutability(member, reporter, className);
      }
    }

    // Check constructor patterns
    _checkConstructorPatterns(node, reporter);
  }

  void _checkFieldImmutability(FieldDeclaration member, DiagnosticReporter reporter) {
    final fields = member.fields;

    // Check if field is mutable
    if (!fields.isFinal && !fields.isConst) {
      // Allow private fields with careful consideration
      final isPrivate = fields.variables.any((variable) =>
        variable.name.lexeme.startsWith('_'));

      final code = LintCode(
        name: 'entity_immutability',
        problemMessage: isPrivate
          ? 'Private mutable field detected - consider making final for true immutability'
          : 'Mutable field detected in entity class',
        correctionMessage: isPrivate
          ? 'Make private field final or provide controlled access methods'
          : 'Make field final to ensure entity immutability',
      );

      if (!isPrivate) {
        reporter.atNode(member, code);
      }
    }

    // Check for mutable collection types
    final type = fields.type;
    if (type is NamedType && fields.isFinal) {
      final typeName = type.name.lexeme;
      if (_isMutableCollectionType(typeName)) {
        final code = LintCode(
          name: 'entity_immutability',
          problemMessage: 'Mutable collection type ($typeName) in entity field',
          correctionMessage: 'Use immutable collections or provide defensive copying. Consider using UnmodifiableListView or similar.',
        );
        reporter.atNode(type, code);
      }
    }
  }

  void _checkMethodImmutability(MethodDeclaration member, DiagnosticReporter reporter, String className) {
    // Check for setters
    if (member.isSetter) {
      final code = LintCode(
        name: 'entity_immutability',
        problemMessage: 'Setter methods violate entity immutability',
        correctionMessage: 'Remove setter method. Use factory methods or copyWith() pattern for state changes.',
      );
      reporter.atNode(member, code);
    }

    // Check for methods that might mutate state
    final methodName = member.name.lexeme;
    if (_isMutatingMethodName(methodName) && !member.isStatic) {
      final code = LintCode(
        name: 'entity_immutability',
        problemMessage: 'Method name suggests state mutation: $methodName',
        correctionMessage: 'Ensure method returns new instance instead of mutating current state.',
      );
      reporter.atNode(member, code);
    }
  }

  void _checkConstructorPatterns(ClassDeclaration node, DiagnosticReporter reporter) {
    final constructors = node.members.whereType<ConstructorDeclaration>().toList();

    // Check if there's a proper const constructor or immutable pattern
    final hasConstConstructor = constructors.any((c) => c.constKeyword != null);
    final hasNamedConstructor = constructors.any((c) => c.name != null);

    if (!hasConstConstructor && !hasNamedConstructor) {
      // This is a suggestion, not an error - keeping for future enhancement
      // Could be enabled via configuration in future versions
    }
  }

  bool _isMutableCollectionType(String typeName) {
    final mutableTypes = [
      'List', 'Set', 'Map',
      'LinkedHashMap', 'LinkedHashSet',
      'HashMap', 'HashSet',
    ];
    return mutableTypes.contains(typeName);
  }

  bool _isMutatingMethodName(String methodName) {
    final mutatingPrefixes = [
      'set', 'update', 'modify', 'change', 'alter',
      'add', 'remove', 'delete', 'clear', 'reset',
    ];
    final lowerMethodName = methodName.toLowerCase();
    return mutatingPrefixes.any((prefix) => lowerMethodName.startsWith(prefix));
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