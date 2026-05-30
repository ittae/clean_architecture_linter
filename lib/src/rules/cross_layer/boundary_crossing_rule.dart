import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces simplified boundary crossing patterns in Clean Architecture.
///
/// This v2 rule keeps the v1 scope intentionally narrow: import-only checks,
/// DI files excluded, and only concrete implementation dependencies reported.
class BoundaryCrossingRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'boundary_crossing',
    'Boundary crossing violation: {0}',
    correctionMessage:
        'Use Dependency Inversion Principle to cross architectural boundaries properly.',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.boundary_crossing',
  );

  BoundaryCrossingRule()
    : super(
        name: 'boundary_crossing',
        description:
            'Flags concrete implementation dependencies across layers.',
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
    registry.addImportDirective(this, _BoundaryCrossingVisitor(this, context));
  }
}

class _BoundaryCrossingVisitor extends SimpleAstVisitor<void> {
  _BoundaryCrossingVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) {
    final filePath =
        context.currentUnit?.file.path ?? context.definingUnit.file.path;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    if (_isDependencyInjectionFile(filePath)) {
      return;
    }

    final sourceLayer = _identifyLayer(filePath);
    final targetLayer = _identifyLayer(importUri);

    if (sourceLayer == null || targetLayer == null) return;

    if (_isConcreteDependency(importUri, sourceLayer, targetLayer)) {
      rule.reportAtNode(
        node,
        arguments: [
          '${sourceLayer.name} layer depends on concrete '
              '${targetLayer.name} implementation: $importUri',
        ],
      );
    }
  }

  bool _isConcreteDependency(
    String importUri,
    ArchitecturalLayer source,
    ArchitecturalLayer target,
  ) {
    if (importUri.contains('_impl.dart') ||
        importUri.contains('_implementation.dart') ||
        importUri.contains('/impl/')) {
      return true;
    }

    if (source.name == 'domain' &&
        (target.name == 'data' || target.name == 'presentation')) {
      return true;
    }

    return false;
  }

  ArchitecturalLayer? _identifyLayer(String path) {
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();

    if (normalizedPath.contains('/domain/')) {
      return const ArchitecturalLayer('domain', 4);
    }

    if (normalizedPath.contains('/data/')) {
      return const ArchitecturalLayer('data', 2);
    }

    if (normalizedPath.contains('/presentation/') ||
        normalizedPath.contains('/ui/') ||
        normalizedPath.contains('/widgets/') ||
        normalizedPath.contains('/screens/') ||
        normalizedPath.contains('/pages/') ||
        normalizedPath.contains('/views/')) {
      return const ArchitecturalLayer('presentation', 1);
    }

    return null;
  }

  bool _isDependencyInjectionFile(String filePath) {
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();

    const diPatterns = [
      '/providers.dart',
      '/provider.dart',
      '/providers/',
      '/di.dart',
      '/di/',
      '/injection.dart',
      '/injection_container.dart',
      '/dependency_injection.dart',
      '/get_it.dart',
      '/locator.dart',
      '/service_locator.dart',
      'main.dart',
    ];

    return diPatterns.any(
      (pattern) =>
          normalizedPath.endsWith(pattern) || normalizedPath.contains(pattern),
    );
  }
}

class ArchitecturalLayer {
  final String name;
  final int level;

  const ArchitecturalLayer(this.name, this.level);
}
