import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../compat/analyzer_ast_compat.dart';
import '../../clean_architecture_linter_base.dart';

/// Warns against unnecessary usage of `@Riverpod(keepAlive: true)`.
///
/// The check is a name/path heuristic (severity INFO). A provider passes when
/// any of the following holds:
///
/// - its name contains an app-wide state keyword
///   (`_validKeepAlivePatterns`: auth, user, session, settings, preferences,
///   config, theme, locale, cache, analytics, notification, connectivity,
///   permission, account) or an app-lifetime keyword (startup, bootstrap,
///   listener, manager, storage, timezone);
/// - its name contains an infrastructure keyword
///   (`_infrastructurePatterns`: datasource, repository, usecase, service,
///   client, api);
/// - its file lives under an auth path (`_validPathPatterns`).
///
/// Providers whose name carries no lifetime signal (for example a global asset
/// cache called `palettes`) are reported on purpose: the heuristic cannot tell
/// them apart from a feature-scoped provider. Keep
/// `// ignore: clean_architecture_linter/riverpod_keep_alive` on that line
/// together with a doc comment explaining why the state must outlive the
/// screen. Rules do not read doc comments, so the reason stays reviewable
/// without turning prose into lint input.
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
    // App-lifetime providers: one-shot startup work watched from main.dart,
    // app-wide stream subscriptions, singleton managers and platform handles.
    'startup',
    'bootstrap',
    'listener',
    'manager',
    'storage',
    'timezone',
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
      if (isNamedBooleanArgument(arg, name: 'keepAlive', value: true)) {
        hasKeepAliveTrue = true;
        break;
      }
    }
    if (!hasKeepAliveTrue) return;

    // Riverpod 3 allows `@Riverpod(keepAlive: true)` on both a Notifier class
    // and a functional provider (`Future<Config> config(Ref ref)`), so the
    // heuristic name comes from either the class or the function declaration.
    final declarationName = _annotatedDeclarationName(node.parent);
    if (declarationName == null) return;

    final normalizedName = declarationName.toLowerCase();
    final isInfrastructure = RiverpodKeepAliveRule._infrastructurePatterns.any(
      normalizedName.contains,
    );
    if (isInfrastructure) return;

    final isValidUseCase = RiverpodKeepAliveRule._validKeepAlivePatterns.any(
      normalizedName.contains,
    );
    final normalized = _filePath.replaceAll('\\', '/').toLowerCase();
    final isValidPath = RiverpodKeepAliveRule._validPathPatterns.any(
      normalized.contains,
    );

    if (!isValidUseCase && !isValidPath) {
      rule.reportAtNode(node);
    }
  }

  /// The declaration name a Riverpod annotation is attached to, whether the
  /// provider is a Notifier class or a functional `@riverpod` provider.
  String? _annotatedDeclarationName(AstNode? parent) {
    if (parent is ClassDeclaration) return classDeclarationName(parent);
    if (parent is FunctionDeclaration) return parent.name.lexeme;
    return null;
  }

  bool get _shouldCheckFile {
    if (CleanArchitectureUtils.shouldExcludeFile(_filePath)) return false;
    final normalized = _filePath.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/presentation/') ||
        normalized.contains('/providers/');
  }
}
