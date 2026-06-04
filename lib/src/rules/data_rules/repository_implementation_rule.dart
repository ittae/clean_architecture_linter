import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';

/// Enforces data RepositoryImpl classes implementing domain repository interfaces.
class RepositoryImplementationRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'repository_implementation',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.repository_implementation',
  );

  RepositoryImplementationRule()
    : super(
        name: 'repository_implementation',
        description:
            'Requires RepositoryImpl classes in data layer and repository interfaces in domain layer.',
      );

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(
      this,
      _RepositoryImplementationVisitor(this, context),
    );
  }
}

class _RepositoryImplementationVisitor extends SimpleAstVisitor<void> {
  _RepositoryImplementationVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    final className = classDeclarationName(node) ?? '';

    if (CleanArchitectureUtils.isDataFile(filePath)) {
      _checkDataLayerRepository(node, className);

      if (className.endsWith('Repository') &&
          !className.endsWith('RepositoryImpl')) {
        _checkMisplacedInterface(node, className);
      }
    }

    if (CleanArchitectureUtils.isDomainFile(filePath) &&
        className.endsWith('RepositoryImpl')) {
      _checkMisplacedImplementation(node, className);
    }
  }

  void _checkDataLayerRepository(ClassDeclaration node, String className) {
    if (!className.endsWith('RepositoryImpl')) return;

    final implementsClause = node.implementsClause;
    if (implementsClause == null || implementsClause.interfaces.isEmpty) {
      rule.reportAtNode(
        node,
        arguments: [
          'Repository implementation must implement a domain repository interface: $className',
          'Add implements clause with domain repository interface. Example: class UserRepositoryImpl implements UserRepository',
        ],
      );
      return;
    }

    final hasRepositoryInterface = implementsClause.interfaces.any((interface) {
      final interfaceName = interface.name.lexeme;
      return interfaceName.endsWith('Repository') &&
          !interfaceName.endsWith('RepositoryImpl');
    });

    if (!hasRepositoryInterface) {
      final implementedInterfaces = implementsClause.interfaces
          .map((interface) => interface.name.lexeme)
          .join(', ');
      rule.reportAtNode(
        node,
        arguments: [
          'Repository implementation should implement a domain repository interface: $className implements $implementedInterfaces',
          'Implement the corresponding domain repository interface. Example: class UserRepositoryImpl implements UserRepository',
        ],
      );
    }
  }

  void _checkMisplacedInterface(ClassDeclaration node, String className) {
    if (node.abstractKeyword == null) return;

    rule.reportAtNode(
      node,
      arguments: [
        'Repository interface should be in domain layer, not data layer: $className',
        'Move abstract repository interface to domain layer. Data layer should only contain RepositoryImpl classes.',
      ],
    );
  }

  void _checkMisplacedImplementation(ClassDeclaration node, String className) {
    rule.reportAtNode(
      node,
      arguments: [
        'Repository implementation should be in data layer, not domain layer: $className',
        'Move $className to data layer. Domain layer should only contain abstract repository interfaces.',
      ],
    );
  }
}
