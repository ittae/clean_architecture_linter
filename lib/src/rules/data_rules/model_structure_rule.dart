import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class ModelStructureRule extends DartLintRule {
  const ModelStructureRule() : super(code: _code);

  static const _code = LintCode(
    name: 'model_structure',
    problemMessage: 'Data models should have proper serialization methods.',
    correctionMessage: 'Add fromJson() constructor and toJson() method to data models.',
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

    // Check for serialization methods
    final hasFromJson = _hasFromJsonConstructor(node);
    final hasToJson = _hasToJsonMethod(node);

    if (!hasFromJson || !hasToJson) {
      reporter.atNode(node, _code);
    }
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

  bool _hasFromJsonConstructor(ClassDeclaration node) {
    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        final name = member.name?.lexeme;
        if (name == 'fromJson') {
          // Check if it takes a Map parameter
          final parameters = member.parameters.parameters;
          if (parameters.length == 1) {
            final param = parameters.first;
            if (param is SimpleFormalParameter) {
              final type = param.type;
              if (type is NamedType) {
                final typeName = type.name2.lexeme;
                if (typeName == 'Map' || typeName.contains('Map')) {
                  return true;
                }
              }
            }
          }
        }
      }
    }
    return false;
  }

  bool _hasToJsonMethod(ClassDeclaration node) {
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final name = member.name.lexeme;
        if (name == 'toJson') {
          // Check if it returns Map
          final returnType = member.returnType;
          if (returnType is NamedType) {
            final typeName = returnType.name2.lexeme;
            if (typeName == 'Map' || typeName.contains('Map')) {
              return true;
            }
          } else if (returnType == null) {
            // Dynamic return type, assume it's correct
            return true;
          }
        }
      }
    }
    return false;
  }
}