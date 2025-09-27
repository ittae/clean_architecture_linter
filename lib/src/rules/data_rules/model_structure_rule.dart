import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Enforces proper data model structure in Clean Architecture.
///
/// This rule ensures that data models:
/// - Have proper serialization methods (fromJson, toJson)
/// - Provide conversion methods to domain entities
/// - Don't contain business logic
/// - Are clearly distinguished from domain entities
/// - Handle external data format properly
///
/// Data models are responsible for:
/// - Representing external data format (JSON, XML, etc.)
/// - Serialization/deserialization
/// - Converting to domain entities
/// - Handling external API contracts
///
/// They should NOT contain:
/// - Business logic
/// - Domain rules
/// - Complex validations
class ModelStructureRule extends DartLintRule {
  const ModelStructureRule() : super(code: _code);

  static const _code = LintCode(
    name: 'model_structure',
    problemMessage: 'Data model violates Clean Architecture principles.',
    correctionMessage: 'Ensure data model has serialization, domain conversion, and no business logic.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkModelStructure(node, reporter, resolver);
    });

    context.registry.addImportDirective((node) {
      _checkModelImports(node, reporter, resolver);
    });
  }

  void _checkModelStructure(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in data layer models
    if (!_isDataLayerModelFile(filePath)) return;

    final className = node.name.lexeme;

    // Check if this is a data model
    if (!_isDataModel(className, filePath)) return;

    final violations = <ModelViolation>[];

    // Analyze model structure
    final analysis = _analyzeModelClass(node);

    // 1. Check serialization requirements
    violations.addAll(_checkSerialization(analysis, className));

    // 2. Check domain conversion methods
    violations.addAll(_checkDomainConversion(analysis, className));

    // 3. Check for business logic contamination
    violations.addAll(_checkBusinessLogicContamination(analysis, className));

    // 4. Check model purity (no domain imports)
    violations.addAll(_checkModelPurity(node, className));

    // Report violations
    for (final violation in violations) {
      final code = _createLintCode(violation);
      reporter.atNode(violation.node ?? node, code);
    }
  }

  void _checkModelImports(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!_isDataLayerModelFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // Data models should not import domain entities
    if (importUri.contains('/domain/entities/') || importUri.contains('/domain/models/')) {
      final code = LintCode(
        name: 'model_structure',
        problemMessage: 'Data model imports domain entities directly',
        correctionMessage: 'Data models should not depend on domain entities. Use conversion methods instead.',
      );
      reporter.atNode(node, code);
    }
  }

  ModelAnalysis _analyzeModelClass(ClassDeclaration node) {
    final methods = <MethodDeclaration>[];
    final fields = <FieldDeclaration>[];
    final constructors = <ConstructorDeclaration>[];
    bool hasFromJson = false;
    bool hasToJson = false;
    bool hasDomainConversion = false;
    bool hasBusinessLogic = false;

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        methods.add(member);

        final methodName = member.name.lexeme;
        if (methodName == 'toJson') hasToJson = true;
        if (methodName.contains('toEntity') || methodName.contains('toDomain')) {
          hasDomainConversion = true;
        }
        if (_isBusinessLogicMethod(methodName)) hasBusinessLogic = true;
      } else if (member is FieldDeclaration) {
        fields.add(member);
      } else if (member is ConstructorDeclaration) {
        constructors.add(member);
        final name = member.name?.lexeme;
        if (name == 'fromJson') hasFromJson = true;
      }
    }

    return ModelAnalysis(
      className: node.name.lexeme,
      methods: methods,
      fields: fields,
      constructors: constructors,
      hasFromJson: hasFromJson,
      hasToJson: hasToJson,
      hasDomainConversion: hasDomainConversion,
      hasBusinessLogic: hasBusinessLogic,
    );
  }

  List<ModelViolation> _checkSerialization(
    ModelAnalysis analysis,
    String className,
  ) {
    final violations = <ModelViolation>[];

    if (!analysis.hasFromJson) {
      violations.add(ModelViolation(
        type: ViolationType.serialization,
        message: 'Data model "$className" missing fromJson constructor',
        suggestion: 'Add fromJson constructor to handle external data deserialization',
      ));
    }

    if (!analysis.hasToJson) {
      violations.add(ModelViolation(
        type: ViolationType.serialization,
        message: 'Data model "$className" missing toJson method',
        suggestion: 'Add toJson method for data serialization',
      ));
    }

    return violations;
  }

  List<ModelViolation> _checkDomainConversion(
    ModelAnalysis analysis,
    String className,
  ) {
    final violations = <ModelViolation>[];

    if (!analysis.hasDomainConversion) {
      violations.add(ModelViolation(
        type: ViolationType.domainConversion,
        message: 'Data model "$className" missing domain conversion method',
        suggestion: 'Add toEntity() or toDomain() method to convert to domain objects',
      ));
    }

    return violations;
  }

  List<ModelViolation> _checkBusinessLogicContamination(
    ModelAnalysis analysis,
    String className,
  ) {
    final violations = <ModelViolation>[];

    if (analysis.hasBusinessLogic) {
      violations.add(ModelViolation(
        type: ViolationType.businessLogic,
        message: 'Data model "$className" contains business logic',
        suggestion: 'Remove business logic from data model. Move to domain layer.',
      ));
    }

    for (final method in analysis.methods) {
      final bodyString = method.body.toString();
      if (_containsComplexBusinessLogic(bodyString)) {
        violations.add(ModelViolation(
          type: ViolationType.businessLogic,
          message: 'Method "${method.name.lexeme}" contains complex business logic',
          suggestion: 'Data models should only handle data transformation, not business rules',
          node: method,
        ));
      }
    }

    return violations;
  }

  List<ModelViolation> _checkModelPurity(
    ClassDeclaration node,
    String className,
  ) {
    final violations = <ModelViolation>[];

    // Check inheritance - should not extend domain objects
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superName = extendsClause.superclass.name2.lexeme;
      if (_isDomainType(superName)) {
        violations.add(ModelViolation(
          type: ViolationType.purity,
          message: 'Data model extends domain class: $superName',
          suggestion: 'Data models should not inherit from domain objects',
          node: extendsClause,
        ));
      }
    }

    return violations;
  }

  LintCode _createLintCode(ModelViolation violation) {
    return LintCode(
      name: 'model_structure',
      problemMessage: violation.message,
      correctionMessage: violation.suggestion,
    );
  }

  bool _isDataLayerModelFile(String filePath) {
    return (filePath.contains('/data/') || filePath.contains('\\data\\')) &&
        (filePath.contains('/models/') ||
            filePath.contains('\\models\\') ||
            filePath.contains('model') ||
            filePath.contains('dto'));
  }

  bool _isDataModel(String className, String filePath) {
    return className.endsWith('Model') ||
        className.endsWith('Dto') ||
        className.endsWith('Response') ||
        className.endsWith('Request') ||
        filePath.contains('/models/') ||
        filePath.contains('\\models\\');
  }

  bool _isBusinessLogicMethod(String methodName) {
    final businessPatterns = [
      'validate',
      'calculate',
      'compute',
      'process',
      'canPerform',
      'shouldAllow',
      'isValid',
      'apply',
      'execute',
      'handle'
    ];
    final lower = methodName.toLowerCase();
    return businessPatterns.any((pattern) => lower.contains(pattern));
  }

  bool _containsComplexBusinessLogic(String bodyString) {
    // Check for complex conditional logic that suggests business rules
    final patterns = [
      r'if.*&&.*\|\|', // Complex conditions
      r'switch.*case.*case.*case', // Multiple business cases
      r'validate.*throw', // Business validation
    ];

    for (final pattern in patterns) {
      if (RegExp(pattern).hasMatch(bodyString)) {
        return true;
      }
    }
    return false;
  }

  bool _isDomainType(String typeName) {
    return typeName.endsWith('Entity') || typeName.endsWith('ValueObject') || typeName.endsWith('DomainModel');
  }
}

class ModelAnalysis {
  final String className;
  final List<MethodDeclaration> methods;
  final List<FieldDeclaration> fields;
  final List<ConstructorDeclaration> constructors;
  final bool hasFromJson;
  final bool hasToJson;
  final bool hasDomainConversion;
  final bool hasBusinessLogic;

  ModelAnalysis({
    required this.className,
    required this.methods,
    required this.fields,
    required this.constructors,
    required this.hasFromJson,
    required this.hasToJson,
    required this.hasDomainConversion,
    required this.hasBusinessLogic,
  });
}

class ModelViolation {
  final ViolationType type;
  final String message;
  final String suggestion;
  final AstNode? node;

  ModelViolation({
    required this.type,
    required this.message,
    required this.suggestion,
    this.node,
  });
}

enum ViolationType {
  serialization,
  domainConversion,
  businessLogic,
  purity,
}
