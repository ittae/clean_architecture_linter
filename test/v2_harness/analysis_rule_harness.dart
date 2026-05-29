import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
// analyzer does not yet expose a public test harness for v2 AnalysisRule
// visitors, so these tests use private visitor/context APIs. Keep this file in
// sync with analyzer upgrades.
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
    final rootPath = p.normalize(root.absolute.path);
    AnalysisContextCollection? collection;

    try {
      _writeFile(p.join(rootPath, 'pubspec.yaml'), '''
name: cal_v2_harness_app
environment:
  sdk: ^3.7.0
''');

      for (final entry in files.entries) {
        _writeFile(p.join(rootPath, entry.key), entry.value);
      }

      final definingPath = p.normalize(p.join(rootPath, definingFile));
      collection = AnalysisContextCollection(
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
      final unitContents = <String, String>{};
      final units = <RuleContextUnit>[];
      RuleContextUnit? definingUnit;

      for (final unitResult in result.units) {
        final unitPath = p.normalize(unitResult.path);
        final listener = RecordingDiagnosticListener();
        listeners[unitPath] = listener;
        unitContents[unitPath] = unitResult.content;

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
          unitPath,
          p.normalize(result.element.firstFragment.source.fullName),
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
        ruleContext.currentUnit = null;
      }

      ruleContext.currentUnit = null;
      AnalysisRuleVisitor(
        registry,
        shouldPropagateExceptions: true,
      ).afterLibrary();
      ruleContext.currentUnit = null;

      final diagnostics = listeners.entries
          .expand(
            (entry) => entry.value.diagnostics.map(
              (diagnostic) => V2RuleDiagnostic(
                path: entry.key,
                relativePath: _fixturePath(
                  p.relative(entry.key, from: rootPath),
                ),
                line: _lineNumberFor(
                  unitContents[entry.key]!,
                  diagnostic.offset,
                ),
                diagnostic: diagnostic,
              ),
            ),
          )
          .toList(growable: false);

      return V2RuleResult(rootPath: rootPath, diagnostics: diagnostics);
    } finally {
      await collection?.dispose();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    }
  }

  void _writeFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  int _lineNumberFor(String content, int offset) {
    var line = 1;
    for (var index = 0; index < offset && index < content.length; index++) {
      if (content.codeUnitAt(index) == 0x0A) {
        line++;
      }
    }
    return line;
  }

  String _fixturePath(String path) {
    return p.url.normalize(path.replaceAll('\\', '/'));
  }
}

class V2RuleResult {
  V2RuleResult({required this.rootPath, required this.diagnostics});

  final String rootPath;
  final List<V2RuleDiagnostic> diagnostics;

  void expectDiagnostics(List<ExpectedV2Diagnostic> expected) {
    final compareLine = expected.any((diagnostic) => diagnostic.line != null);
    final actual = diagnostics.map((diagnostic) {
      return _describe(diagnostic, includeLine: compareLine);
    }).toList()..sort();
    final expectedDescriptions = expected.map((diagnostic) {
      return _describeExpected(diagnostic, includeLine: compareLine);
    }).toList()..sort();

    expect(actual, expectedDescriptions);
  }

  void expectNoDiagnostics() {
    expect(diagnostics.map((diagnostic) => _describe(diagnostic)), isEmpty);
  }

  String _describe(V2RuleDiagnostic diagnostic, {bool includeLine = false}) {
    final line = includeLine ? '|${diagnostic.line}' : '';
    return '${diagnostic.relativePath}|${diagnostic.codeName}$line';
  }

  String _describeExpected(
    ExpectedV2Diagnostic diagnostic, {
    required bool includeLine,
  }) {
    final line = includeLine ? '|${diagnostic.line}' : '';
    final relativePath = p.url.normalize(
      diagnostic.relativePath.replaceAll('\\', '/'),
    );
    return '$relativePath|${diagnostic.codeName}$line';
  }
}

class V2RuleDiagnostic {
  V2RuleDiagnostic({
    required this.path,
    required this.relativePath,
    required this.line,
    required this.diagnostic,
  });

  final String path;
  final String relativePath;
  final int line;
  final Diagnostic diagnostic;

  String get codeName => diagnostic.diagnosticCode.name;
}

class ExpectedV2Diagnostic {
  const ExpectedV2Diagnostic({
    required this.relativePath,
    required this.codeName,
    this.line,
  });

  final String relativePath;
  final String codeName;
  final int? line;
}
