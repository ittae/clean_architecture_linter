import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'root analysis_options.yaml does not enable the legacy analyzer.plugins slot',
    () {
      final options = _analysisOptionsFile();
      final contents = options.readAsStringSync();
      final analyzerBlock = _analyzerMapping(contents);

      expect(
        analyzerBlock,
        isNotNull,
        reason: 'expected an analyzer: mapping in ${options.path}',
      );
      expect(
        RegExp(r'^[ \t]+plugins:', multiLine: true).hasMatch(analyzerBlock!),
        isFalse,
        reason:
            'Dart 3.13.2+ reports analyzer.plugins as '
            'analysis_options_deprecated_plugins and fails `dart analyze`. '
            'This package is an analysis_server_plugin; leftover '
            'analyzer.plugins must not return.',
      );
    },
  );
}

File _analysisOptionsFile() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = File('${dir.path}/analysis_options.yaml');
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (candidate.existsSync() && pubspec.existsSync()) {
      return candidate;
    }
    dir = dir.parent;
  }
  fail(
    'analysis_options.yaml not found walking up from ${Directory.current.path}',
  );
}

/// Returns the indented body of the top-level `analyzer:` mapping, or null.
String? _analyzerMapping(String yaml) {
  final match = RegExp(
    r'^analyzer:\s*\n((?:[ \t].*\n|\s*\n)*)',
    multiLine: true,
  ).firstMatch(yaml);
  return match?.group(1);
}
