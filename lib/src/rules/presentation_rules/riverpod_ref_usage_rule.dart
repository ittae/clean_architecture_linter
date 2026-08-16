import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../compat/analyzer_ast_compat.dart';
import '../../utils/riverpod_provider_detector.dart';

/// Enforces proper usage of ref.watch() vs ref.read() in Riverpod code.
class RiverpodRefUsageRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'riverpod_ref_usage',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.riverpod_ref_usage',
  );

  RiverpodRefUsageRule()
    : super(
        name: 'riverpod_ref_usage',
        description: 'Checks ref.watch/ref.read usage in Riverpod classes.',
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
    final visitor = _RiverpodRefUsageVisitor(this, context);
    registry.addClassDeclaration(this, visitor);
    // Extension methods on Notifiers (common part-file helpers) need the same
    // ref.watch / ref.read discipline as class members.
    registry.addExtensionDeclaration(this, visitor);
  }
}

class _RiverpodRefUsageVisitor extends SimpleAstVisitor<void> {
  _RiverpodRefUsageVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_isProviderFile(_filePath)) return;
    if (!isRiverpodNotifierClass(node)) return;

    _scanMembers(classMembers(node));
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    if (!_isProviderFile(_filePath)) return;
    if (!isRiverpodNotifierExtension(node)) return;

    // Extension members are never the Riverpod `build()` override.
    _scanMembers(extensionMembers(node), isBuildMethod: false);
  }

  void _scanMembers(Iterable<AstNode> members, {bool? isBuildMethod}) {
    for (final member in members) {
      if (member is MethodDeclaration) {
        _checkMethodRefUsage(
          member,
          isBuildMethod ?? member.name.lexeme == 'build',
        );
      }
    }
  }

  bool _isProviderFile(String filePath) {
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return false;

    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalizedPath.contains('/presentation/')) return false;

    return normalizedPath.contains('/providers/') ||
        normalizedPath.endsWith('_provider.dart') ||
        normalizedPath.endsWith('_providers.dart') ||
        normalizedPath.endsWith('_notifier.dart') ||
        normalizedPath.endsWith('_notifiers.dart');
  }

  void _checkMethodRefUsage(MethodDeclaration methodNode, bool isBuildMethod) {
    final body = methodNode.body;
    if (body is! BlockFunctionBody && body is! ExpressionFunctionBody) return;

    final refWatchCalls = <MethodInvocation>[];
    final refReadCalls = <MethodInvocation>[];
    _collectRefCalls(body, refWatchCalls, refReadCalls);

    if (isBuildMethod) {
      for (final refReadCall in refReadCalls) {
        if (_isAllowedOneShotProviderCall(refReadCall) ||
            _isNotifierAccess(refReadCall)) {
          continue;
        }
        rule.reportAtNode(
          refReadCall,
          arguments: const [
            'Use ref.watch() instead of ref.read() for State providers in build().',
            'Change ref.read() to ref.watch() for reactive State provider dependencies.',
          ],
        );
      }
    } else {
      for (final refWatchCall in refWatchCalls) {
        rule.reportAtNode(
          refWatchCall,
          arguments: const [
            'Use ref.read() instead of ref.watch() in methods for one-time reads.',
            'Change ref.watch() to ref.read() for one-time provider access in methods.',
          ],
        );
      }
    }
  }

  void _collectRefCalls(
    AstNode node,
    List<MethodInvocation> refWatchCalls,
    List<MethodInvocation> refReadCalls,
  ) {
    if (node is MethodInvocation) {
      final methodName = node.methodName.name;
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'ref') {
        if (methodName == 'watch') {
          refWatchCalls.add(node);
        } else if (methodName == 'read') {
          refReadCalls.add(node);
        }
      }
    }

    for (final child in node.childEntities) {
      if (child is AstNode) {
        _collectRefCalls(child, refWatchCalls, refReadCalls);
      }
    }
  }

  bool _isAllowedOneShotProviderCall(MethodInvocation refReadCall) {
    final args = refReadCall.argumentList.arguments;
    if (args.isEmpty) return false;

    final firstArg = args.first;
    String? providerName;
    if (firstArg is SimpleIdentifier) {
      providerName = firstArg.name;
    } else if (firstArg is MethodInvocation) {
      providerName = firstArg.methodName.name;
    } else if (firstArg is FunctionExpressionInvocation) {
      final function = firstArg.function;
      if (function is SimpleIdentifier) providerName = function.name;
    }

    if (providerName != null && _isAllowedOneShotProviderName(providerName)) {
      return true;
    }

    final parent = refReadCall.parent;
    if (parent is FunctionExpressionInvocation) return true;
    if (parent is AwaitExpression &&
        parent.parent is FunctionExpressionInvocation) {
      return true;
    }

    return false;
  }

  bool _isAllowedOneShotProviderName(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('usecaseprovider')) return true;

    // Stable DI / infrastructure providers are one-shot dependencies, not
    // reactive UI state. Riverpod 3.3 still models them as Provider/Ref reads;
    // flagging them as "use ref.watch" is a common false positive.
    // Residual FN: names ending in Service/Api/Storage can still wrap reactive
    // state in some apps — prefer tighter suffixes or type-aware checks later.
    const stableDependencySuffixes = [
      'repositoryprovider',
      'datasourceprovider',
      'serviceprovider',
      'clientprovider',
      'apiprovider',
      'daoprovider',
      'loggerprovider',
      'analyticsprovider',
      'storageprovider',
    ];
    for (final suffix in stableDependencySuffixes) {
      if (lowerName.endsWith(suffix)) return true;
    }

    const useCasePrefixes = [
      'get',
      'create',
      'update',
      'delete',
      'fetch',
      'save',
      'load',
      'submit',
      'send',
      'retrieve',
    ];
    for (final prefix in useCasePrefixes) {
      if (lowerName.startsWith(prefix) && lowerName.endsWith('provider')) {
        return true;
      }
    }
    return false;
  }

  bool _isNotifierAccess(MethodInvocation refReadCall) {
    final args = refReadCall.argumentList.arguments;
    if (args.isEmpty) return false;

    final firstArg = args.first;
    if (firstArg is PropertyAccess) {
      return firstArg.propertyName.name == 'notifier';
    }
    if (firstArg is PrefixedIdentifier) {
      return firstArg.identifier.name == 'notifier';
    }
    return false;
  }
}
