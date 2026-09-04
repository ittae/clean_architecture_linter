import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import 'riverpod_ref_after_async_gap_rule.dart';

/// Reports unguarded `state = …` writes after an async gap in Riverpod
/// provider classes.
///
/// Riverpod 3 throws `UnmountedRefException` when `state` is written after
/// the provider was disposed, so every `await` before a `state` write is a
/// crash path unless guarded:
///
/// ```dart
/// // Reported: the notifier may be disposed while awaiting.
/// state = await AsyncValue.guard(() => repository.load());
///
/// // Fixed: await into a local, then guard before writing.
/// final next = await AsyncValue.guard(() => repository.load());
/// if (!ref.mounted) return;
/// state = next;
/// ```
///
/// This rule is **opt-in** (registered as a lint rule, disabled by default).
/// The `state = await …` idiom is widespread in existing apps, and enabling
/// this check by default would turn a routine package upgrade into a CI
/// failure under `--fatal-infos`. Enable it per project:
///
/// ```yaml
/// plugins:
///   clean_architecture_linter:
///     diagnostics:
///       riverpod_state_after_async_gap: true
/// ```
///
/// `ref.*` calls after a gap are reported by the default-on
/// `riverpod_ref_after_async_gap` rule; both share
/// [RiverpodRefAfterAsyncGapVisitor].
class RiverpodStateAfterAsyncGapRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'riverpod_state_after_async_gap',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.INFO,
    uniqueName: 'LintCode.riverpod_state_after_async_gap',
  );

  RiverpodStateAfterAsyncGapRule()
    : super(
        name: 'riverpod_state_after_async_gap',
        description:
            'Advises against assigning to state after an async gap (await or Future continuations) in Riverpod provider classes. Opt-in.',
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
    final visitor = RiverpodRefAfterAsyncGapVisitor(
      this,
      context,
      tracking: const RefGapTracking(refCalls: false, stateAssignments: true),
    );
    registry.addClassDeclaration(this, visitor);
    registry.addExtensionDeclaration(this, visitor);
  }
}
