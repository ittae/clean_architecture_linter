import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import 'riverpod_ref_after_async_gap_rule.dart';

/// Reports unguarded `state = …` writes and `state` reads after an async gap
/// in Riverpod provider classes.
///
/// Riverpod 3 checks `_throwIfInvalidUsage()` in both the `state` setter and
/// getter, so once the provider is disposed every `state` access after an
/// `await` throws `UnmountedRefException`. The guard therefore belongs right
/// after the await, before the first `state` access:
///
/// ```dart
/// // Reported: the notifier may be disposed while awaiting.
/// state = await AsyncValue.guard(() => repository.load());
///
/// // Reported: the read throws too, and this guard arrives too late.
/// await repository.save(next);
/// final current = state.session;
/// if (!ref.mounted) return;
/// state = state.copyWith(session: next);
///
/// // Fixed: await into a local, guard, then touch state.
/// final next = await AsyncValue.guard(() => repository.load());
/// if (!ref.mounted) return;
/// state = next;
/// ```
///
/// `state = state.copyWith(…)` after a gap is one finding (the write); a
/// statement with several reads is one finding. Same-statement reads that
/// evaluate after an `await` (`await foo() ?? state`) are reported;
/// receiver-first `state.foo(await x)` is not. Locals and parameters named
/// `state` are ignored; `this.state` is not. Calls to private helpers that
/// touch `state` are not followed.
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
            'Advises against assigning to or reading state after an async gap (await or Future continuations) in Riverpod provider classes. Opt-in.',
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
      tracking: const RefGapTracking(
        refCalls: false,
        stateAssignments: true,
        stateReads: true,
      ),
    );
    registry.addClassDeclaration(this, visitor);
    registry.addExtensionDeclaration(this, visitor);
  }
}
