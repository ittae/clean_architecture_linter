import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/analysis_rule/rule_context.dart'
    show RuleContextWithResolvedResults;
import 'package:analyzer/src/lint/linter_visitor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class V2RuleHarness {
  V2RuleHarness({required this.rule});

  final AnalysisRule rule;

  Future<V2RuleResult> analyze({
    required Map<String, String> files,
    String definingFile = 'lib/main.dart',
  }) async {
    final root = await Directory.systemTemp.createTemp('cal_v2_harness_');
    final rootPath = root.absolute.path;

    _writeFile(p.join(rootPath, 'pubspec.yaml'), '''
name: cal_v2_harness_app
environment:
  sdk: ^3.7.0
''');

    for (final entry in files.entries) {
      _writeFile(p.join(rootPath, entry.key), entry.value);
    }

    final definingPath = p.normalize(p.join(rootPath, definingFile));
    final collection = AnalysisContextCollection(
      includedPaths: [rootPath],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final context = collection.contextFor(definingPath);
    final result = await context.currentSession.getResolvedLibraryContaining(
      definingPath,
    );

    if (result is! ResolvedLibraryResult) {
      throw StateError('Failed to resolve $definingFile: $result');
    }

    final listeners = <String, RecordingDiagnosticListener>{};
    final units = <RuleContextUnit>[];
    RuleContextUnit? definingUnit;

    for (final unitResult in result.units) {
      final listener = RecordingDiagnosticListener();
      listeners[unitResult.path] = listener;

      final contextUnit = RuleContextUnit(
        file: unitResult.file,
        content: unitResult.content,
        diagnosticReporter: DiagnosticReporter(
          listener,
          unitResult.unit.declaredFragment!.source,
        ),
        unit: unitResult.unit,
      );

      units.add(contextUnit);
      if (p.equals(
        unitResult.path,
        result.element.firstFragment.source.fullName,
      )) {
        definingUnit = contextUnit;
      }
    }

    definingUnit ??= units.first;

    final registry = RuleVisitorRegistryImpl(enableTiming: false);
    final ruleContext = RuleContextWithResolvedResults(
      units,
      definingUnit,
      result.typeProvider,
      result.element.typeSystem,
      null,
    );

    rule.registerNodeProcessors(registry, ruleContext);

    for (final unit in units) {
      rule.reporter = unit.diagnosticReporter;
      ruleContext.currentUnit = unit;
      unit.unit.accept(
        AnalysisRuleVisitor(registry, shouldPropagateExceptions: true),
      );
    }

    AnalysisRuleVisitor(
      registry,
      shouldPropagateExceptions: true,
    ).afterLibrary();

    final diagnostics = listeners.entries
        .expand(
          (entry) => entry.value.diagnostics.map(
            (diagnostic) => V2RuleDiagnostic(
              path: entry.key,
              relativePath: p.relative(entry.key, from: rootPath),
              diagnostic: diagnostic,
            ),
          ),
        )
        .toList(growable: false);

    return V2RuleResult(rootPath: rootPath, diagnostics: diagnostics);
  }

  void _writeFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}

class V2RuleResult {
  V2RuleResult({required this.rootPath, required this.diagnostics});

  final String rootPath;
  final List<V2RuleDiagnostic> diagnostics;

  void expectDiagnostics(List<ExpectedV2Diagnostic> expected) {
    final actual = diagnostics.map(_describe).toList()..sort();
    final expectedDescriptions =
        expected.map((diagnostic) {
            return '${diagnostic.relativePath}|${diagnostic.codeName}';
          }).toList()
          ..sort();

    expect(actual, expectedDescriptions);
  }

  void expectNoDiagnostics() {
    expect(diagnostics.map(_describe), isEmpty);
  }

  String _describe(V2RuleDiagnostic diagnostic) {
    return '${diagnostic.relativePath}|${diagnostic.codeName}';
  }
}

class V2RuleDiagnostic {
  V2RuleDiagnostic({
    required this.path,
    required this.relativePath,
    required this.diagnostic,
  });

  final String path;
  final String relativePath;
  final Diagnostic diagnostic;

  String get codeName => diagnostic.diagnosticCode.name;
}

class ExpectedV2Diagnostic {
  const ExpectedV2Diagnostic({
    required this.relativePath,
    required this.codeName,
  });

  final String relativePath;
  final String codeName;
}
