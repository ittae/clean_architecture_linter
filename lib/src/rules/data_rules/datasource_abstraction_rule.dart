import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:path/path.dart' as path;

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';

/// Enforces proper DataSource abstraction patterns in the data layer.
class DataSourceAbstractionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'datasource_abstraction',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.datasource_abstraction',
  );

  DataSourceAbstractionRule()
    : super(
        name: 'datasource_abstraction',
        description:
            'Requires DataSource abstractions, correct layer placement, and Model return types.',
      );

  static String testFilePathForTesting(String libFilePath) {
    return _expectedDataSourceTestFilePath(libFilePath);
  }

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _DataSourceAbstractionVisitor(this, context);
    registry.addClassDeclaration(this, visitor);
    registry.addMethodDeclaration(this, visitor);
  }
}

class _DataSourceAbstractionVisitor extends SimpleAstVisitor<void> {
  _DataSourceAbstractionVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    _checkDataSourceLocation(node, filePath);
    _checkDataSourceAbstraction(node, filePath);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    _checkDataSourceMethod(node, filePath);
  }

  void _checkDataSourceAbstraction(ClassDeclaration node, String filePath) {
    if (!CleanArchitectureUtils.isDataFile(filePath)) return;

    final className = classDeclarationName(node) ?? '';
    if (!CleanArchitectureUtils.isDataSourceClass(className)) return;

    if (node.abstractKeyword != null) return;
    if (!_isConcreteDataSource(node)) return;
    if (_hasTestFile(filePath)) return;

    rule.reportAtNode(
      node,
      arguments: [
        'Concrete DataSource "$className" should implement an abstract interface for testability',
        'Create abstract DataSource interface: ${_getAbstractName(className)} or add test file',
      ],
    );
  }

  void _checkDataSourceLocation(ClassDeclaration node, String filePath) {
    final className = classDeclarationName(node) ?? '';
    if (!CleanArchitectureUtils.isDataSourceClass(className)) return;

    if (CleanArchitectureUtils.isDomainFile(filePath)) {
      rule.reportAtNode(
        node,
        arguments: [
          'DataSource "$className" should be in Data Layer, not Domain Layer',
          'Move DataSource to data/datasources/. Domain should only depend on Repository abstractions.',
        ],
      );
    }
  }

  void _checkDataSourceMethod(MethodDeclaration method, String filePath) {
    if (!CleanArchitectureUtils.isDataFile(filePath)) return;

    final methodName = method.name.lexeme;
    if (methodName.startsWith('_')) return;

    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final className = classDeclarationName(classNode) ?? '';
    if (!CleanArchitectureUtils.isDataSourceClass(className)) return;

    final returnType = method.returnType;
    if (returnType == null) return;

    if (_returnsEntity(returnType)) {
      rule.reportAtNode(
        returnType,
        arguments: [
          'DataSource method "$methodName" returns Entity. DataSource should return Model.',
          'Change return type to Model. DataSource works with Models, Repository converts to Entities.',
        ],
      );
    }
  }

  bool _isConcreteDataSource(ClassDeclaration node) {
    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        final interfaceName = interface.name.lexeme;
        if (CleanArchitectureUtils.isDataSourceClass(interfaceName)) {
          return false;
        }
      }
    }

    return node.abstractKeyword == null;
  }

  String _getAbstractName(String concreteName) {
    if (concreteName.endsWith('Impl')) {
      return concreteName.substring(0, concreteName.length - 4);
    }
    return concreteName;
  }

  bool _returnsEntity(TypeAnnotation returnType) {
    final typeText = returnType.toSource();
    if (!typeText.contains('Entity') || typeText.contains('Model')) {
      return false;
    }

    if (typeText.contains('Box<') ||
        typeText.contains('ObjectBoxEntity') ||
        typeText.contains('RealmEntity') ||
        typeText.contains('IsarEntity') ||
        typeText.contains('DriftEntity')) {
      return false;
    }

    return RegExp(r'\b\w+Entity\b').hasMatch(typeText);
  }

  bool _hasTestFile(String libFilePath) {
    final testPath = _expectedDataSourceTestFilePath(libFilePath);
    return File(testPath).existsSync();
  }
}

String _expectedDataSourceTestFilePath(String libFilePath) {
  final normalized = libFilePath.replaceAll('\\', '/');
  if (normalized.startsWith('lib/')) {
    return path.join(
      'test',
      path.setExtension(normalized.substring('lib/'.length), '_test.dart'),
    );
  }

  final libIndex = normalized.lastIndexOf('/lib/');
  if (libIndex == -1) {
    return path.setExtension(normalized, '_test.dart');
  }

  final projectRoot = normalized.substring(0, libIndex);
  final relativePath = normalized.substring(libIndex + '/lib/'.length);

  return path.join(
    projectRoot,
    'test',
    path.setExtension(relativePath, '_test.dart'),
  );
}
