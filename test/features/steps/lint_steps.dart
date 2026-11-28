import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:clean_architecture_linter/src/rules/cross_layer/layer_dependency_rule.dart';
import 'package:clean_architecture_linter/src/rules/data_rules/repository_pass_through_rule.dart';
import 'package:clean_architecture_linter/src/rules/domain_rules/domain_purity_rule.dart';
import 'package:clean_architecture_linter/src/rules/presentation_rules/presentation_no_throw_rule.dart';
import 'package:gherkin/gherkin.dart';

import '../../v2_harness/analysis_rule_harness.dart';

/// Rules a `.feature` file may name, keyed by diagnostic code. These are the
/// slice contract rules of `tools/slice_contracts.json`, one per rule slice.
final Map<String, AnalysisRule Function()> featureRules = {
  'layer_dependency': LayerDependencyRule.new,
  'domain_purity': DomainPurityRule.new,
  'repository_pass_through': RepositoryPassThroughRule.new,
  'presentation_no_throw': PresentationNoThrowRule.new,
};

/// Per-scenario state: the consumer files written so far and the last result.
class LintWorld extends World {
  final Map<String, String> files = {};
  List<String>? reported;
}

String _describe(String code, int line, String path) => '$code@$path:$line';

final List<StepDefinitionGeneric> lintSteps = [
  given2<String, String, LintWorld>('the file {string} contains:', (
    path,
    content,
    context,
  ) async {
    context.world.files[path] = content;
  }),
  when2<String, String, LintWorld>('the rule {string} analyzes {string}', (
    code,
    path,
    context,
  ) async {
    final createRule = featureRules[code];
    if (createRule == null) {
      throw StateError(
        'Unknown rule "$code". Known: ${featureRules.keys.join(', ')}',
      );
    }
    final result = await V2RuleHarness(
      rule: createRule(),
    ).analyze(files: context.world.files, definingFile: path);
    context.world.reported = [
      for (final d in result.diagnostics)
        _describe(d.codeName, d.line, d.relativePath),
    ]..sort();
  }),
  then3<String, int, String, LintWorld>(
    'the only diagnostic is {string} at line {int} of {string}',
    (code, line, path, context) async {
      context.expect(_reported(context.world), [_describe(code, line, path)]);
    },
  ),
  then<LintWorld>('no diagnostic is reported', (context) async {
    context.expect(_reported(context.world), <String>[]);
  }),
];

List<String> _reported(LintWorld world) {
  final reported = world.reported;
  if (reported == null) {
    throw StateError('No rule has analyzed a file yet. Add a When step.');
  }
  return reported;
}
