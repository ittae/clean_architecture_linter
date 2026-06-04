import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';

/// Enforces Freezed usage for data classes instead of Equatable.
class FreezedUsageRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'freezed_usage',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.freezed_usage',
  );

  FreezedUsageRule()
    : super(
        name: 'freezed_usage',
        description: 'Requires Freezed instead of Equatable for data classes.',
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
    final visitor = _FreezedUsageVisitor(this, context);
    registry.addImportDirective(this, visitor);
    registry.addClassDeclaration(this, visitor);
  }
}

class _FreezedUsageVisitor extends SimpleAstVisitor<void> {
  _FreezedUsageVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitImportDirective(ImportDirective node) {
    if (_shouldSkipFile) return;

    final importUri = node.uri.stringValue;
    if (importUri != null && importUri.contains('equatable')) {
      rule.reportAtNode(
        node,
        arguments: const [
          'Equatable import detected. Use Freezed instead.',
          'Remove equatable import and add freezed_annotation. Use @freezed for data classes.',
        ],
      );
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (_shouldSkipFile) return;

    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass.toString();
      if (superclass.contains('Equatable')) {
        rule.reportAtNode(
          extendsClause,
          arguments: [
            'Class "${classDeclarationName(node) ?? ''}" uses Equatable. Use @freezed instead.',
            'Replace "extends Equatable" with @freezed annotation. Remove props getter and use Freezed factory constructor.',
          ],
        );
      }
    }

    final implementsClause = node.implementsClause;
    if (implementsClause != null) {
      for (final interface in implementsClause.interfaces) {
        if (interface.toString().contains('Equatable')) {
          rule.reportAtNode(
            implementsClause,
            arguments: [
              'Class "${classDeclarationName(node) ?? ''}" implements Equatable. Use @freezed instead.',
              'Use @freezed annotation for immutable data classes.',
            ],
          );
          return;
        }
      }
    }
  }

  bool get _shouldSkipFile {
    return CleanArchitectureUtils.shouldExcludeFile(_filePath) ||
        !_isArchitectureLayer(_filePath.replaceAll('\\', '/').toLowerCase());
  }

  bool _isArchitectureLayer(String filePath) {
    return filePath.contains('/domain/') ||
        filePath.contains('/data/') ||
        filePath.contains('/presentation/');
  }
}
