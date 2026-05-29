import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:test/test.dart';

import 'analysis_rule_harness.dart';

void main() {
  group('V2RuleHarness', () {
    test('reports diagnostics with relative path and line', () async {
      final result = await V2RuleHarness(rule: _HarnessSmokeRule()).analyze(
        files: {
          'lib/src/example.dart': '''
class Example {
  void allowed() {}

  void flagged() {}
}
''',
        },
        definingFile: 'lib/src/example.dart',
      );

      result.expectDiagnostics([
        const ExpectedV2Diagnostic(
          relativePath: 'lib/src/example.dart',
          codeName: 'harness_smoke',
          line: 4,
        ),
      ]);
    });
  });
}

class _HarnessSmokeRule extends AnalysisRule {
  _HarnessSmokeRule()
    : super(
        name: 'harness_smoke',
        description: 'Exercises the v2 analysis rule harness.',
      );

  @override
  DiagnosticCode get diagnosticCode =>
      const LintCode('harness_smoke', 'Harness smoke diagnostic.');

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodDeclaration(this, _HarnessSmokeVisitor(this));
  }
}

class _HarnessSmokeVisitor extends SimpleAstVisitor<void> {
  _HarnessSmokeVisitor(this.rule);

  final _HarnessSmokeRule rule;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'flagged') {
      rule.reportAtNode(node);
    }
  }
}
