import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';

/// Enforces NO Presentation Models or ViewModels pattern.
class NoPresentationModelsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_presentation_models',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.no_presentation_models',
  );

  NoPresentationModelsRule()
    : super(
        name: 'no_presentation_models',
        description: 'Disallows presentation models and ViewModel patterns.',
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
    final visitor = _NoPresentationModelsVisitor(this, context);
    registry.addCompilationUnit(this, visitor);
    registry.addClassDeclaration(this, visitor);
  }
}

class _NoPresentationModelsVisitor extends SimpleAstVisitor<void> {
  _NoPresentationModelsVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath)) return;

    final normalized = _filePath.replaceAll('\\', '/').toLowerCase();
    if (normalized.contains('/presentation/models/')) {
      rule.reportAtOffset(
        0,
        1,
        arguments: const [
          'Presentation models directory is not allowed',
          'Remove presentation/models/ directory. Use states/ directory with Freezed State containing Entities.',
        ],
      );
    }

    if (normalized.contains('/presentation/viewmodels/')) {
      rule.reportAtOffset(
        0,
        1,
        arguments: const [
          'ViewModels directory is not allowed',
          'Remove presentation/viewmodels/ directory. Use Freezed State with Riverpod instead.',
        ],
      );
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath)) return;

    final className = classDeclarationName(node) ?? '';
    if (className.endsWith('ViewModel')) {
      rule.reportAtNode(
        node,
        arguments: [
          'ViewModel pattern is not allowed: $className',
          'Use Freezed State with riverpod_generator (@riverpod annotation) instead.',
        ],
      );
    }

    final extendsClause = node.extendsClause;
    if (extendsClause == null) return;

    final superclass = extendsClause.superclass.toString();
    if (superclass.contains('ChangeNotifier')) {
      rule.reportAtNode(
        extendsClause,
        arguments: const [
          'ChangeNotifier pattern is not allowed',
          'Use Freezed State with Riverpod instead. Define state with @freezed and notifier with @riverpod.',
        ],
      );
    }
  }
}
