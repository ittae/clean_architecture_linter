import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Warns against unnecessary usage of `@Riverpod(keepAlive: true)`.
class RiverpodKeepAliveRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'riverpod_keep_alive',
    'Verify that "keepAlive: true" is necessary. Only use for app-wide persistent state.',
    correctionMessage:
        'Valid uses: auth state, app settings, global cache. Invalid: avoiding dispose errors (fix async flow instead).',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.riverpod_keep_alive',
  );

  RiverpodKeepAliveRule()
    : super(
        name: 'riverpod_keep_alive',
        description: 'Warns when keepAlive is used outside global state.',
      );

  static const _validKeepAlivePatterns = [
    'auth',
    'user',
    'session',
    'settings',
    'preferences',
    'config',
    'theme',
    'locale',
    'cache',
    'analytics',
    'notification',
    'connectivity',
    'permission',
    'account',
  ];

  static const _validPathPatterns = [
    '/auth/',
    '/core/auth/',
    '/features/auth/',
  ];

  static const _infrastructurePatterns = [
    'datasource',
    'repository',
    'usecase',
    'service',
    'client',
    'api',
  ];

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addAnnotation(this, _RiverpodKeepAliveVisitor(this, context));
  }
}

class _RiverpodKeepAliveVisitor extends SimpleAstVisitor<void> {
  _RiverpodKeepAliveVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitAnnotation(Annotation node) {
    if (!_shouldCheckFile) return;
    if (node.name.name != 'Riverpod') return;

    final arguments = node.arguments;
    if (arguments == null) return;

    var hasKeepAliveTrue = false;
    for (final arg in arguments.arguments) {
      if (arg is NamedArgument &&
          arg.name.lexeme == 'keepAlive' &&
          arg.argumentExpression is BooleanLiteral &&
          (arg.argumentExpression as BooleanLiteral).value) {
        hasKeepAliveTrue = true;
        break;
      }
    }
    if (!hasKeepAliveTrue) return;

    final parent = node.parent;
    if (parent is! ClassDeclaration) return;

    final className = parent.namePart.typeName.lexeme.toLowerCase();
    final isInfrastructure = RiverpodKeepAliveRule._infrastructurePatterns.any(
      className.contains,
    );
    if (isInfrastructure) return;

    final isValidUseCase = RiverpodKeepAliveRule._validKeepAlivePatterns.any(
      className.contains,
    );
    final normalized = _filePath.replaceAll('\\', '/').toLowerCase();
    final isValidPath = RiverpodKeepAliveRule._validPathPatterns.any(
      normalized.contains,
    );

    if (!isValidUseCase && !isValidPath) {
      rule.reportAtNode(node);
    }
  }

  bool get _shouldCheckFile {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath)) return false;
    final normalized = _filePath.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/presentation/') ||
        normalized.contains('/providers/');
  }
}
