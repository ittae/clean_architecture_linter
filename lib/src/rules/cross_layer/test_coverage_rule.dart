import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:path/path.dart' as path;

/// Enforces test coverage for critical Clean Architecture components.
///
/// The optional constructor flags preserve the v1 configuration surface. v2
/// plugin registration keeps this rule opt-in by not registering it in
/// `lib/main.dart` until analysis-server-plugin exposes rule config parity.
class TestCoverageRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'clean_architecture_linter_require_test',
    'Critical components should have corresponding test files.',
    correctionMessage:
        'Create a test file for this component or disable this rule.',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.clean_architecture_linter_require_test',
  );

  TestCoverageRule({
    this.checkUsecases = true,
    this.checkRepositories = true,
    this.checkDatasources = true,
    this.checkNotifiers = true,
  }) : super(
         name: 'clean_architecture_linter_require_test',
         description:
             'Requires tests for use cases, repositories, data sources, and notifiers.',
       );

  final bool checkUsecases;
  final bool checkRepositories;
  final bool checkDatasources;
  final bool checkNotifiers;

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _TestCoverageVisitor(this, context));
  }
}

class _TestCoverageVisitor extends SimpleAstVisitor<void> {
  _TestCoverageVisitor(this.rule, this.context);

  final TestCoverageRule rule;
  final RuleContext context;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final filePath =
        context.currentUnit?.file.path ?? context.definingUnit.file.path;
    final className = node.name.lexeme;

    final componentType = _identifyComponentType(filePath, className, node);
    if (componentType == null) return;

    final shouldCheck = switch (componentType) {
      ComponentType.useCase => rule.checkUsecases,
      ComponentType.repositoryImpl => rule.checkRepositories,
      ComponentType.dataSource => rule.checkDatasources,
      ComponentType.notifier => rule.checkNotifiers,
    };

    if (!shouldCheck) return;

    final testFilePath = _getExpectedTestFilePath(filePath);
    if (File(testFilePath).existsSync()) return;

    if (componentType == ComponentType.dataSource &&
        _hasAbstractInterface(node)) {
      return;
    }

    rule.reportAtNode(node);
  }

  ComponentType? _identifyComponentType(
    String filePath,
    String className,
    ClassDeclaration node,
  ) {
    final normalized = filePath.replaceAll('\\', '/').toLowerCase();

    if (normalized.contains('/test/')) {
      return null;
    }

    if (className.endsWith('UseCase')) {
      return ComponentType.useCase;
    }
    if (filePath.endsWith('_usecase.dart') &&
        normalized.contains('/usecases/')) {
      return null;
    }

    if (className.endsWith('RepositoryImpl') ||
        className.endsWith('RepositoryImplementation')) {
      return ComponentType.repositoryImpl;
    }

    if (_isDataSourceImplementation(className, node)) {
      return ComponentType.dataSource;
    }

    if (_isRiverpodNotifier(node, filePath)) {
      return ComponentType.notifier;
    }

    return null;
  }

  bool _isDataSourceImplementation(String className, ClassDeclaration node) {
    if (!className.contains('DataSource') &&
        !className.contains('Datasource')) {
      return false;
    }

    return node.abstractKeyword == null;
  }

  bool _isRiverpodNotifier(ClassDeclaration node, String filePath) {
    final hasRiverpodAnnotation = node.metadata.any((annotation) {
      final name = annotation.name.toString();
      return name == 'riverpod' || name == 'Riverpod';
    });

    if (hasRiverpodAnnotation) return true;

    final normalized = filePath.replaceAll('\\', '/').toLowerCase();
    if (normalized.contains('/providers/')) {
      final className = node.name.lexeme;
      if (className.endsWith('Notifier')) {
        return true;
      }
    }

    return false;
  }

  bool _hasAbstractInterface(ClassDeclaration node) {
    if (node.abstractKeyword != null) {
      return true;
    }

    final className = node.name.lexeme;
    if (className.endsWith('Impl')) {
      return true;
    }

    return false;
  }

  String _getExpectedTestFilePath(String libFilePath) {
    final normalized = libFilePath.replaceAll('\\', '/');
    final libIndex = normalized.indexOf('/lib/');
    if (libIndex == -1) {
      return normalized
          .replaceFirst('/lib/', '/test/')
          .replaceFirst('.dart', '_test.dart');
    }

    final projectRoot = normalized.substring(0, libIndex);
    final relativePath = normalized.substring(libIndex + 5);
    final testRelativePath = relativePath.replaceFirst('.dart', '_test.dart');

    return path.join(projectRoot, 'test', testRelativePath);
  }
}

enum ComponentType { useCase, repositoryImpl, dataSource, notifier }
