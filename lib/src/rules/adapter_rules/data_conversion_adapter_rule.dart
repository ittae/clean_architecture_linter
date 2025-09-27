import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper data conversion in Interface Adapter layer.
///
/// This rule ensures that adapters properly convert data formats:
/// - Convert from entity/use case format to external format (database, web, etc.)
/// - Convert from external format to entity/use case format
/// - Isolate internal structures from external formats
/// - No business logic in adapters (only conversion)
/// - No knowledge of business rules in adapters
///
/// Interface Adapters should:
/// - Handle format conversion only
/// - Be the sole layer that knows about external formats
/// - Shield internal layers from external data structures
/// - Convert data without applying business rules
class DataConversionAdapterRule extends DartLintRule {
  const DataConversionAdapterRule() : super(code: _code);

  static const _code = LintCode(
    name: 'data_conversion_adapter',
    problemMessage: 'Interface Adapter must focus on data conversion between internal and external formats.',
    correctionMessage: 'Remove business logic from adapter. Focus only on data format conversion.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkDataConversionAdapter(node, reporter, resolver);
    });

    context.registry.addMethodDeclaration((node) {
      _checkAdapterMethod(node, reporter, resolver);
    });
  }

  void _checkDataConversionAdapter(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isAdapterLayerFile(filePath)) return;

    final className = node.name.lexeme;
    if (!_isAdapterClass(className, filePath)) return;

    // Check for business logic in adapter
    _checkForBusinessLogic(node, reporter);

    // Check for proper conversion methods
    _checkConversionMethods(node, reporter);

    // Check adapter dependencies
    _checkAdapterDependencies(node, reporter);
  }

  void _checkAdapterMethod(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isAdapterLayerFile(filePath)) return;

    final methodName = method.name.lexeme;

    // Check if method implements business logic (bad)
    if (_implementsBusinessLogic(method, methodName)) {
      final code = LintCode(
        name: 'data_conversion_adapter',
        problemMessage: 'Adapter method contains business logic: $methodName',
        correctionMessage: 'Move business logic to use case or entity. Adapter should only convert data formats.',
      );
      reporter.atNode(method, code);
    }

    // Check for entity knowledge beyond conversion
    if (_hasEntityKnowledge(method, methodName)) {
      final code = LintCode(
        name: 'data_conversion_adapter',
        problemMessage: 'Adapter has too much entity knowledge: $methodName',
        correctionMessage: 'Adapters should only know entity structure for conversion, not business rules.',
      );
      reporter.atNode(method, code);
    }
  }

  void _checkForBusinessLogic(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        // Check for validation logic (should be in entities/use cases)
        if (_isValidationMethod(methodName)) {
          final code = LintCode(
            name: 'data_conversion_adapter',
            problemMessage: 'Adapter contains validation logic: $methodName',
            correctionMessage: 'Move validation to entity or use case. Adapter should only convert formats.',
          );
          reporter.atNode(member, code);
        }

        // Check for calculation logic
        if (_isCalculationMethod(methodName)) {
          final code = LintCode(
            name: 'data_conversion_adapter',
            problemMessage: 'Adapter contains calculation logic: $methodName',
            correctionMessage: 'Move calculations to entity or use case. Adapter should only convert formats.',
          );
          reporter.atNode(member, code);
        }

        // Check for business rule enforcement
        if (_isBusinessRuleMethod(methodName)) {
          final code = LintCode(
            name: 'data_conversion_adapter',
            problemMessage: 'Adapter enforces business rules: $methodName',
            correctionMessage: 'Move business rules to entity. Adapter should only convert data.',
          );
          reporter.atNode(member, code);
        }
      }
    }
  }

  void _checkConversionMethods(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    final methods = node.members.whereType<MethodDeclaration>().toList();

    // Check if adapter has proper conversion methods
    final hasToExternal = methods.any((m) => _isToExternalMethod(m.name.lexeme));
    final hasFromExternal = methods.any((m) => _isFromExternalMethod(m.name.lexeme));

    if (!hasToExternal && !hasFromExternal) {
      final code = LintCode(
        name: 'data_conversion_adapter',
        problemMessage: 'Adapter lacks conversion methods',
        correctionMessage: 'Add methods to convert between internal and external formats (e.g., toDto(), fromDto()).',
      );
      reporter.atNode(node, code);
    }

    // Check for proper method signatures
    for (final method in methods) {
      if (_isConversionMethod(method.name.lexeme)) {
        _checkConversionMethodSignature(method, reporter);
      }
    }
  }

  void _checkAdapterDependencies(
    ClassDeclaration node,
    ErrorReporter reporter,
  ) {
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final type = member.fields.type;
        if (type is NamedType) {
          final typeName = type.name2.lexeme;

          // Check for use case dependencies (usually bad)
          if (_isUseCaseType(typeName)) {
            final code = LintCode(
              name: 'data_conversion_adapter',
              problemMessage: 'Adapter should not depend on use cases: $typeName',
              correctionMessage: 'Adapters should receive data from use cases via parameters, not inject them.',
            );
            reporter.atNode(type, code);
          }

          // Check for entity dependencies (should be minimal)
          if (_isEntityType(typeName) && member.fields.isFinal) {
            final code = LintCode(
              name: 'data_conversion_adapter',
              problemMessage: 'Adapter should not store entities as dependencies: $typeName',
              correctionMessage: 'Adapters should receive entities as parameters for conversion, not store them.',
            );
            reporter.atNode(type, code);
          }
        }
      }
    }
  }

  void _checkConversionMethodSignature(
    MethodDeclaration method,
    ErrorReporter reporter,
  ) {
    final parameters = method.parameters?.parameters ?? [];

    // Conversion methods should typically have parameters
    if (parameters.isEmpty && !method.isStatic) {
      final code = LintCode(
        name: 'data_conversion_adapter',
        problemMessage: 'Conversion method should accept data to convert',
        correctionMessage: 'Add parameter with data to be converted (entity, dto, etc.).',
      );
      reporter.atNode(method, code);
    }

    // Check return type suggests conversion output
    final returnType = method.returnType;
    if (returnType == null) {
      final code = LintCode(
        name: 'data_conversion_adapter',
        problemMessage: 'Conversion method should specify return type',
        correctionMessage: 'Specify return type for converted data (DTO, Entity, Map, etc.).',
      );
      reporter.atNode(method, code);
    }
  }

  bool _implementsBusinessLogic(MethodDeclaration method, String methodName) {
    // Check method body for business logic patterns
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString();

      // Business logic patterns
      final businessPatterns = [
        'if (',
        'switch (',
        'while (',
        'for (',
        'validate',
        'calculate',
        'process',
        'apply',
        'enforce',
        'check',
      ];

      // Simple conversion shouldn't have complex logic
      final hasComplexLogic =
          businessPatterns.any((pattern) => bodyString.split(pattern).length > 3); // More than 2 occurrences

      return hasComplexLogic;
    }
    return false;
  }

  bool _hasEntityKnowledge(MethodDeclaration method, String methodName) {
    final body = method.body;
    if (body is BlockFunctionBody) {
      final bodyString = body.toString();

      // Patterns that suggest deep entity knowledge
      final entityKnowledgePatterns = [
        'isValid',
        'isActive',
        'canBeProcessed',
        'businessRule',
        'domainRule',
        'invariant',
        'calculateTotal',
        'applyDiscount',
        'processPayment',
      ];

      return entityKnowledgePatterns.any((pattern) => bodyString.contains(pattern));
    }
    return false;
  }

  bool _isValidationMethod(String methodName) {
    final validationPatterns = [
      'validate',
      'isValid',
      'check',
      'verify',
      'ensure',
      'assert',
      'confirm',
    ];
    return validationPatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _isCalculationMethod(String methodName) {
    final calcPatterns = [
      'calculate',
      'compute',
      'sum',
      'total',
      'add',
      'subtract',
      'multiply',
      'divide',
      'process',
      'apply',
      'transform',
    ];
    return calcPatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _isBusinessRuleMethod(String methodName) {
    final rulePatterns = [
      'businessRule',
      'domainRule',
      'enforce',
      'policy',
      'constraint',
      'invariant',
      'authorize',
      'permit',
      'allow',
    ];
    return rulePatterns.any((pattern) => methodName.toLowerCase().contains(pattern));
  }

  bool _isToExternalMethod(String methodName) {
    final toExternalPatterns = [
      'toDto',
      'toJson',
      'toXml',
      'toMap',
      'toDatabase',
      'toExternal',
      'serialize',
      'asDto',
      'asJson',
      'asMap',
    ];
    return toExternalPatterns.any((pattern) => methodName.contains(pattern));
  }

  bool _isFromExternalMethod(String methodName) {
    final fromExternalPatterns = [
      'fromDto',
      'fromJson',
      'fromXml',
      'fromMap',
      'fromDatabase',
      'fromExternal',
      'deserialize',
      'parseDto',
      'parseJson',
      'parseMap',
    ];
    return fromExternalPatterns.any((pattern) => methodName.contains(pattern));
  }

  bool _isConversionMethod(String methodName) {
    return _isToExternalMethod(methodName) ||
        _isFromExternalMethod(methodName) ||
        methodName.contains('convert') ||
        methodName.contains('map') ||
        methodName.contains('transform');
  }

  bool _isUseCaseType(String typeName) {
    return typeName.endsWith('UseCase') || typeName.endsWith('Service') || typeName.endsWith('Interactor');
  }

  bool _isEntityType(String typeName) {
    return typeName.endsWith('Entity') || typeName.endsWith('DomainObject') || typeName.endsWith('Aggregate');
  }

  bool _isAdapterLayerFile(String filePath) {
    final adapterPaths = [
      '/adapters/',
      '\\adapters\\',
      '/interface_adapters/',
      '\\interface_adapters\\',
      '/controllers/',
      '\\controllers\\',
      '/presenters/',
      '\\presenters\\',
      '/gateways/',
      '\\gateways\\',
      '/mappers/',
      '\\mappers\\',
    ];

    return adapterPaths.any((path) => filePath.contains(path));
  }

  bool _isAdapterClass(String className, String filePath) {
    final adapterPatterns = [
      'Adapter',
      'Controller',
      'Presenter',
      'Gateway',
      'Mapper',
      'Converter',
      'Translator',
      'Transformer',
    ];

    return adapterPatterns.any((pattern) => className.contains(pattern)) || _isAdapterLayerFile(filePath);
  }
}
