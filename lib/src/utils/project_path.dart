import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// Resolves import, export, and `part of` URIs against the package on disk.
///
/// Layer rules used to classify the literal URI. That misses `data/foo.dart`
/// (no leading slash), `part of` files that live in another folder, barrels,
/// and `package:` URIs of a different package that happen to share a suffix.
class ProjectPaths {
  static final _packageNamePattern = RegExp(
    '^name:\\s*[\'"]?([A-Za-z0-9_]+)',
    multiLine: true,
  );

  static final _windowsDrive = RegExp(r'^[A-Za-z]:/');

  /// Backslashes become `/`. Absolute paths keep only the suffix after the
  /// last `/lib/` segment so ancestor folders named `data` or `ui` are not
  /// architecture layers.
  static String scopeToPackageLib(String path) {
    final normalized = path.replaceAll('\\', '/');
    final absolute =
        normalized.startsWith('/') || _windowsDrive.hasMatch(normalized);
    if (!absolute) return normalized;
    final index = normalized.lastIndexOf('/lib/');
    if (index == -1) return normalized;
    return normalized.substring(index + 4);
  }

  /// Primary URI plus conditional `if (...)` configuration URIs.
  ///
  /// `show`, `hide`, `as`, and `deferred` do not change the library
  /// dependency, so combinators are not consulted.
  static List<String> urisOf(NamespaceDirective directive) {
    final uris = <String>[];
    final primary = directive.uri.stringValue;
    if (primary != null && primary.isNotEmpty) uris.add(primary);
    for (final configuration in directive.configurations) {
      final configured = configuration.uri.stringValue;
      if (configured != null &&
          configured.isNotEmpty &&
          !uris.contains(configured)) {
        uris.add(configured);
      }
    }
    return uris;
  }

  /// File path layer checks should use for [unit].
  ///
  /// A part is classified as its parent library. The part's own folder is
  /// not a layer.
  static String libraryFilePath(String filePath, CompilationUnit unit) {
    for (final directive in unit.directives) {
      if (directive is! PartOfDirective) continue;
      final uri = directive.uri?.stringValue;
      if (uri == null || uri.isEmpty) return filePath;
      final resolved = resolveProjectFile(
        uri: uri,
        currentFile: filePath,
        packageName: packageNameNear(filePath),
      );
      return resolved ?? filePath;
    }
    return filePath;
  }

  static String? packageNameNear(String filePath) {
    final root = projectRootNear(filePath);
    if (root == null) return null;
    final text = _readText(File(p.join(root, 'pubspec.yaml')));
    if (text == null) return null;
    return _packageNamePattern.firstMatch(text)?.group(1);
  }

  static String? projectRootNear(String filePath) {
    var directory = Directory(p.dirname(filePath.replaceAll('\\', '/')));
    for (var i = 0; i < 30; i++) {
      final pubspec = File(p.join(directory.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        return _forward(directory.path);
      }
      final parent = directory.parent;
      if (parent.path == directory.path) return null;
      directory = parent;
    }
    return null;
  }

  /// Absolute project file for [uri], or null for `dart:` and other packages.
  static String? resolveProjectFile({
    required String uri,
    required String currentFile,
    required String? packageName,
  }) {
    final normalizedUri = uri.replaceAll('\\', '/').trim();
    if (normalizedUri.isEmpty || normalizedUri.startsWith('dart:')) {
      return null;
    }

    final current = currentFile.replaceAll('\\', '/');
    final root = projectRootNear(current);

    if (normalizedUri.startsWith('package:')) {
      if (packageName == null || root == null) return null;
      final packagePath = normalizedUri.substring('package:'.length);
      final slash = packagePath.indexOf('/');
      if (slash <= 0) return null;
      if (packagePath.substring(0, slash) != packageName) return null;
      final rest = packagePath.substring(slash + 1);
      if (rest.isEmpty || rest.split('/').contains('..')) return null;
      return _insideRoot(root, '$root/lib/$rest');
    }

    if (normalizedUri.contains(':')) return null;

    final separator = current.lastIndexOf('/');
    if (separator <= 0) return null;
    final joined = _forward(
      p.join(current.substring(0, separator), normalizedUri),
    );
    if (root == null) return joined;
    return _insideRoot(root, joined);
  }

  /// Export targets of [dartFile], following barrels a few levels deep.
  ///
  /// [uris] are the literal export strings. [files] are those URIs resolved
  /// into this package. `show` and `hide` are ignored: the library dependency
  /// remains either way.
  static ExportReach exportReach({
    required String dartFile,
    required String? packageName,
    int maxDepth = 6,
  }) {
    final uris = <String>[];
    final files = <String>[];
    final visiting = <String>{};

    void walk(String file, int depth) {
      if (depth > maxDepth || !visiting.add(file)) return;
      if (!file.endsWith('.dart')) return;
      final source = _readDart(file);
      if (source == null) return;
      final unit = parseString(content: source, throwIfDiagnostics: false).unit;
      for (final directive in unit.directives) {
        if (directive is! ExportDirective) continue;
        for (final uri in urisOf(directive)) {
          if (!uris.contains(uri)) uris.add(uri);
          final resolved = resolveProjectFile(
            uri: uri,
            currentFile: file,
            packageName: packageName,
          );
          if (resolved == null || files.contains(resolved)) continue;
          files.add(resolved);
          if (_isGenerated(resolved)) continue;
          walk(resolved, depth + 1);
        }
      }
    }

    walk(dartFile, 0);
    return ExportReach(uris: uris, files: files);
  }

  static bool _isGenerated(String path) {
    final scoped = scopeToPackageLib(path);
    return scoped.endsWith('.freezed.dart') ||
        scoped.endsWith('.g.dart') ||
        scoped.endsWith('.mocks.dart');
  }

  static String? _readDart(String path) => _readText(File(path));

  static String? _readText(File file) {
    try {
      if (!file.existsSync()) return null;
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  static String? _insideRoot(String root, String candidate) {
    final normalizedRoot = _forward(root);
    final normalized = _forward(candidate);
    if (normalized == normalizedRoot ||
        normalized.startsWith('$normalizedRoot/')) {
      return normalized;
    }
    return null;
  }

  static String _forward(String path) {
    return p.normalize(path.replaceAll('\\', '/')).replaceAll('\\', '/');
  }
}

class ExportReach {
  const ExportReach({required this.uris, required this.files});

  final List<String> uris;
  final List<String> files;
}
