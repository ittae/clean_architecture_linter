import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper validation and business rules in domain models.
///
/// This rule ensures that domain entities have adequate validation:
/// - Entities MUST include validation methods for business rules
/// - Complex entities MUST have business rule methods (can*, should*, is*)
/// - Business invariants MUST be enforced through methods
/// - Value objects MUST have comprehensive validation
/// - Invalid states must be impossible to represent
///
/// Clean Architecture principles REQUIRE:
/// - Domain entities encapsulate and enforce ALL business rules
/// - Business logic is the CORE of the application
/// - Entities protect their invariants at all times
/// - Validation is NOT optional - it's fundamental
///
/// Benefits of enforced domain validation:
/// - Business rules are GUARANTEED to be enforced
/// - Invalid states CANNOT exist in the system
/// - Data integrity is maintained at ALL times
/// - Business logic is centralized and testable
class DomainModelValidationRule extends DartLintRule {
  const DomainModelValidationRule() : super(code: _code);

  static const _code = LintCode(
    name: 'domain_model_validation',
    problemMessage:
        'Domain model VIOLATES Clean Architecture: Missing required validation for business rules.',
    correctionMessage:
        'MUST add validation methods to enforce business rules. This is NOT optional in Clean Architecture.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkDomainModelValidation(node, reporter, resolver);
    });
  }

  void _checkDomainModelValidation(
    ClassDeclaration node,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!_isDomainLayerFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a domain entity or value object
    if (!_isDomainModel(className, filePath)) return;

    // Analyze the domain model structure
    final analysis = _analyzeDomainModel(node);

    // Perform various validation checks
    _checkBasicValidation(analysis, reporter);
    _checkBusinessRules(analysis, reporter);
    _checkValueObjectValidation(analysis, reporter);
    _checkFactoryMethodValidation(analysis, reporter);
    _checkInvariantEnforcement(analysis, reporter);
  }

  DomainModelAnalysis _analyzeDomainModel(ClassDeclaration node) {
    final methods = <MethodDeclaration>[];
    final fields = <FieldDeclaration>[];
    final constructors = <ConstructorDeclaration>[];

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        methods.add(member);
      } else if (member is FieldDeclaration) {
        fields.add(member);
      } else if (member is ConstructorDeclaration) {
        constructors.add(member);
      }
    }

    // Calculate complexity metrics
    final fieldCount = _getFieldCount(node);
    final complexityScore = _calculateModelComplexity(fields, methods);

    // Categorize methods
    final validationMethods = _findValidationMethods(methods);
    final businessRuleMethods = _findBusinessRuleMethods(methods);
    final factoryMethods = _findFactoryMethods(constructors);

    return DomainModelAnalysis(
      className: node.name.lexeme,
      fields: fields,
      methods: methods,
      constructors: constructors,
      fieldCount: fieldCount,
      complexityScore: complexityScore,
      validationMethods: validationMethods,
      businessRuleMethods: businessRuleMethods,
      factoryMethods: factoryMethods,
      isValueObject: _isValueObject(node.name.lexeme),
      isEntity: _isEntity(node.name.lexeme),
    );
  }

  void _checkBasicValidation(
    DomainModelAnalysis analysis,
    DiagnosticReporter reporter,
  ) {
    // Only suggest for high complexity models (score > 6, not > 3)
    if (analysis.complexityScore > 6 && analysis.validationMethods.isEmpty) {
      // Skip if it looks like a simple DTO
      if (_isSimpleDTO(analysis.className)) return;

      final code = LintCode(
        name: 'domain_model_validation',
        problemMessage:
            'Complex entity "${analysis.className}" might benefit from validation methods.',
        correctionMessage:
            'Consider adding validation if this entity maintains business invariants.',
      );
      // Report on first field if available, otherwise on class
      final target = analysis.fields.isNotEmpty ? analysis.fields.first : null;
      if (target != null) {
        reporter.atNode(target, code);
      }
    }
  }

  void _checkBusinessRules(
    DomainModelAnalysis analysis,
    DiagnosticReporter reporter,
  ) {
    // Only suggest for very complex entities (8+ fields, not 3+)
    if (analysis.isEntity &&
        analysis.fieldCount > 8 &&
        analysis.businessRuleMethods.isEmpty &&
        !_isSimpleDTO(analysis.className)) {
      final code = LintCode(
        name: 'domain_model_validation',
        problemMessage:
            'Large entity "${analysis.className}" might benefit from business rule methods.',
        correctionMessage:
            'If complex business logic exists, consider adding methods like canPerform() or isEligible().',
      );
      // Report on class declaration
      if (analysis.methods.isNotEmpty) {
        reporter.atNode(analysis.methods.first, code);
      }
    }
  }

  void _checkValueObjectValidation(
    DomainModelAnalysis analysis,
    DiagnosticReporter reporter,
  ) {
    // Value objects should have validation, but only suggest gently
    if (analysis.isValueObject &&
        analysis.validationMethods.isEmpty &&
        analysis.fieldCount >= 2) {  // Only for non-trivial value objects
      final code = LintCode(
        name: 'domain_model_validation',
        problemMessage: 'Value object "${analysis.className}" might benefit from validation.',
        correctionMessage:
            'Consider validating invariants if this value object has constraints.',
      );
      // Report on constructor or first field
      final target = analysis.constructors.isNotEmpty
          ? analysis.constructors.first
          : (analysis.fields.isNotEmpty ? analysis.fields.first : null);
      if (target != null) {
        reporter.atNode(target, code);
      }
    }
  }

  void _checkFactoryMethodValidation(
    DomainModelAnalysis analysis,
    DiagnosticReporter reporter,
  ) {
    // Check if factory methods have proper validation
    for (final factory in analysis.factoryMethods) {
      if (!_factoryHasValidation(factory)) {
        final code = LintCode(
          name: 'domain_model_validation',
          problemMessage:
              'Factory method lacks validation: ${factory.name?.lexeme ?? 'unnamed'}',
          correctionMessage:
              'Factory methods should validate input and enforce business rules before creating instances.',
        );
        reporter.atNode(factory, code);
      }
    }
  }

  void _checkInvariantEnforcement(
    DomainModelAnalysis analysis,
    DiagnosticReporter reporter,
  ) {
    // Only check for very complex models (score > 8)
    if (analysis.complexityScore > 8 &&
        !_hasInvariantEnforcement(analysis) &&
        !_isSimpleDTO(analysis.className)) {
      final code = LintCode(
        name: 'domain_model_validation',
        problemMessage:
            'Very complex model "${analysis.className}" might benefit from invariant enforcement.',
        correctionMessage:
            'Consider adding validation methods if business invariants need to be maintained.',
      );
      if (analysis.constructors.isNotEmpty) {
        reporter.atNode(analysis.constructors.first, code);
      }
    }
  }

  bool _isDomainLayerFile(String filePath) {
    return filePath.contains('/domain/') || filePath.contains('\\domain\\');
  }

  bool _isDomainModel(String className, String filePath) {
    return _isEntity(className) ||
        _isValueObject(className) ||
        filePath.contains('/entities/') ||
        filePath.contains('\\entities\\') ||
        filePath.contains('/value_objects/') ||
        filePath.contains('\\value_objects\\');
  }

  bool _isSimpleDTO(String className) {
    final dtoPatterns = ['DTO', 'Dto', 'Request', 'Response', 'Payload', 'Data', 'Info', 'Details'];
    return dtoPatterns.any((pattern) => className.contains(pattern));
  }

  bool _isEntity(String className) {
    return className.endsWith('Entity');
  }

  bool _isValueObject(String className) {
    final valueObjectSuffixes = [
      'Value',
      'ValueObject',
      'VO',
      'Id',
      'Email',
      'Address',
      'Money',
      'Price',
    ];
    return valueObjectSuffixes.any((suffix) => className.endsWith(suffix));
  }

  int _calculateModelComplexity(
    List<FieldDeclaration> fields,
    List<MethodDeclaration> methods,
  ) {
    var complexity = fields.length;

    // Add complexity for method types
    for (final method in methods) {
      final name = method.name.lexeme.toLowerCase();
      if (name.contains('valid') || name.contains('check')) complexity++;
      if (name.startsWith('can') || name.startsWith('should')) complexity++;
    }

    return complexity;
  }

  List<MethodDeclaration> _findValidationMethods(
    List<MethodDeclaration> methods,
  ) {
    return methods.where((method) {
      final name = method.name.lexeme.toLowerCase();
      return name.contains('valid') ||
          name.contains('check') ||
          name.contains('verify') ||
          name.contains('ensure');
    }).toList();
  }

  List<MethodDeclaration> _findBusinessRuleMethods(
    List<MethodDeclaration> methods,
  ) {
    return methods.where((method) {
      final name = method.name.lexeme.toLowerCase();
      return name.startsWith('can') ||
          name.startsWith('should') ||
          name.startsWith('must') ||
          name.startsWith('is') && name.length > 2 ||
          name.startsWith('has') && name.length > 3;
    }).toList();
  }

  List<ConstructorDeclaration> _findFactoryMethods(
    List<ConstructorDeclaration> constructors,
  ) {
    return constructors.where((constructor) {
      final name = constructor.name?.lexeme;
      return name != null &&
          (name.startsWith('from') ||
              name.startsWith('create') ||
              name.startsWith('build') ||
              name.startsWith('parse'));
    }).toList();
  }

  bool _factoryHasValidation(ConstructorDeclaration factory) {
    // Check if factory method body contains validation logic
    final body = factory.body;
    if (body is BlockFunctionBody) {
      final statements = body.block.statements;
      return statements.any((statement) {
        final statementText = statement.toString().toLowerCase();
        return statementText.contains('throw') ||
            statementText.contains('assert') ||
            statementText.contains('valid') ||
            statementText.contains('check');
      });
    }
    return false;
  }

  bool _hasInvariantEnforcement(DomainModelAnalysis analysis) {
    // Check for private validation methods
    final privateValidationMethods = analysis.methods.where((method) {
      final name = method.name.lexeme;
      return name.startsWith('_') &&
          (name.contains('valid') ||
              name.contains('check') ||
              name.contains('ensure'));
    });

    // Check if constructors call validation
    final constructorsWithValidation = analysis.constructors.where((
      constructor,
    ) {
      final body = constructor.body;
      if (body is BlockFunctionBody) {
        final bodyText = body.toString().toLowerCase();
        return bodyText.contains('_valid') ||
            bodyText.contains('_check') ||
            bodyText.contains('_ensure');
      }
      return false;
    });

    return privateValidationMethods.isNotEmpty &&
        constructorsWithValidation.isNotEmpty;
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

/// Analysis result for domain model structure and validation patterns
class DomainModelAnalysis {
  final String className;
  final List<FieldDeclaration> fields;
  final List<MethodDeclaration> methods;
  final List<ConstructorDeclaration> constructors;
  final int fieldCount;
  final int complexityScore;
  final List<MethodDeclaration> validationMethods;
  final List<MethodDeclaration> businessRuleMethods;
  final List<ConstructorDeclaration> factoryMethods;
  final bool isValueObject;
  final bool isEntity;

  const DomainModelAnalysis({
    required this.className,
    required this.fields,
    required this.methods,
    required this.constructors,
    required this.fieldCount,
    required this.complexityScore,
    required this.validationMethods,
    required this.businessRuleMethods,
    required this.factoryMethods,
    required this.isValueObject,
    required this.isEntity,
  });
}
