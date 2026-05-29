# v2 AnalysisRule test harness

`V2RuleHarness` runs analyzer `AnalysisRule` implementations through an
`AnalysisContextCollection` and the analyzer rule visitor registry. Tests pass a
small package-shaped file map and compare diagnostics by relative path and code.

```dart
final result = await V2RuleHarness(rule: PresentationNoThrowRule()).analyze(
  files: {
    'lib/features/todo/presentation/bad_notifier.dart': '''
class BadNotifier {
  void build() {
    throw StateError('bad');
  }
}
''',
  },
  definingFile: 'lib/features/todo/presentation/bad_notifier.dart',
);

result.expectDiagnostics([
  ExpectedV2Diagnostic(
    relativePath: 'lib/features/todo/presentation/bad_notifier.dart',
    codeName: 'presentation_no_throw',
  ),
]);
```

Phase 1의 첫 이주는 `presentation_no_throw` PoC를 정식 위치로 옮기면서
하네스와 회귀를 함께 만들었기 때문에 약 2시간이 걸렸다. 이후 rule 변환은
같은 fixture/assertion 패턴을 재사용할 수 있어 rule당 30-45분을 기본
견적으로 잡는다.
