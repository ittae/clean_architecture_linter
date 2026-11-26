import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:clean_architecture_linter/src/utils/project_path.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ProjectPaths.scopeToPackageLib', () {
    test('keeps relative paths and strips ancestor folders after lib', () {
      expect(
        ProjectPaths.scopeToPackageLib(r'lib\features\todo\domain\a.dart'),
        'lib/features/todo/domain/a.dart',
      );
      expect(
        ProjectPaths.scopeToPackageLib('/tmp/data/ui/app/lib/features/a.dart'),
        '/features/a.dart',
      );
      expect(
        ProjectPaths.scopeToPackageLib('/tmp/no_lib/features/a.dart'),
        '/tmp/no_lib/features/a.dart',
      );
      expect(
        ProjectPaths.scopeToPackageLib(
          'C:/data/app/lib/features/todo/domain/a.dart',
        ),
        '/features/todo/domain/a.dart',
      );
    });
  });

  group('ProjectPaths.urisOf', () {
    test('keeps conditional URIs once and skips an empty URI', () {
      final configured = _directive('''
import 'a.dart' if (dart.library.io) 'b.dart' if (dart.library.html) 'b.dart';
''');
      expect(ProjectPaths.urisOf(configured), ['a.dart', 'b.dart']);

      final empty = _directive("import '';");
      expect(ProjectPaths.urisOf(empty), isEmpty);
    });
  });

  group('ProjectPaths on a package', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('cal_project_path_');
      File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: 'sample_app'
environment:
  sdk: ^3.11.0
''');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('reads the package name and resolves in-package URIs', () {
      final file = _write(
        root,
        'lib/features/todo/presentation/page.dart',
        'class Page {}',
      );
      expect(ProjectPaths.packageNameNear(file), 'sample_app');
      expect(
        ProjectPaths.projectRootNear(file),
        p.normalize(root.path).replaceAll('\\', '/'),
      );

      final model = p
          .normalize(p.join(root.path, 'lib/features/todo/data/model.dart'))
          .replaceAll('\\', '/');
      expect(
        ProjectPaths.resolveProjectFile(
          uri: 'package:sample_app/features/todo/data/model.dart',
          currentFile: file,
          packageName: 'sample_app',
        ),
        model,
      );
      expect(
        ProjectPaths.resolveProjectFile(
          uri: '../data/model.dart',
          currentFile: file,
          packageName: 'sample_app',
        ),
        model,
      );
    });

    test('rejects foreign, dart, empty, and escaping URIs', () {
      final file = _write(root, 'lib/a.dart', 'class A {}');
      String? resolve(String uri, {String? packageName = 'sample_app'}) {
        return ProjectPaths.resolveProjectFile(
          uri: uri,
          currentFile: file,
          packageName: packageName,
        );
      }

      expect(resolve(''), isNull);
      expect(resolve('dart:io'), isNull);
      expect(resolve('asset:foo'), isNull);
      expect(resolve('package:other/a.dart'), isNull);
      expect(resolve('package:sample_app'), isNull);
      expect(resolve('package:sample_app/../secret.dart'), isNull);
      expect(resolve('package:sample_app/foo/../../secret.dart'), isNull);
      expect(resolve('package:sample_app/a.dart', packageName: null), isNull);
      expect(resolve('../../../../../../etc/passwd'), isNull);
      expect(
        ProjectPaths.resolveProjectFile(
          uri: 'b.dart',
          currentFile: 'noslash.dart',
          packageName: 'sample_app',
        ),
        isNull,
      );
    });

    test('resolves a library file whose name contains two dots', () {
      final file = _write(root, 'lib/a.dart', 'class A {}');
      final dotted = p
          .normalize(p.join(root.path, 'lib/a..b.dart'))
          .replaceAll('\\', '/');
      expect(
        ProjectPaths.resolveProjectFile(
          uri: 'package:sample_app/a..b.dart',
          currentFile: file,
          packageName: 'sample_app',
        ),
        dotted,
      );
    });

    test('uses the parent library for part of', () {
      final part = _write(
        root,
        'lib/features/todo/data/part.dart',
        "part of '../domain/todo.dart';",
      );
      final parent = p
          .normalize(p.join(root.path, 'lib/features/todo/domain/todo.dart'))
          .replaceAll('\\', '/');
      expect(
        ProjectPaths.libraryFilePath(
          part,
          _unit("part of '../domain/todo.dart';"),
        ),
        parent,
      );
      expect(
        ProjectPaths.libraryFilePath(part, _unit('part of library_name;')),
        part.replaceAll('\\', '/'),
      );
      expect(
        ProjectPaths.libraryFilePath(part, _unit("part of '';")),
        part.replaceAll('\\', '/'),
      );
      expect(
        ProjectPaths.libraryFilePath(
          part,
          _unit("part of 'package:other/domain/todo.dart';"),
        ),
        part.replaceAll('\\', '/'),
      );
      expect(
        ProjectPaths.libraryFilePath(part, _unit('class T {}')),
        part.replaceAll('\\', '/'),
      );
    });

    test('follows barrel exports and stops at generated files and cycles', () {
      final barrel = _write(root, 'lib/features/todo/todo.dart', '''
export 'data/model.dart' hide Model;
export 'data/model.g.dart' show Model;
export 'package:meta/meta.dart';
''');
      _write(root, 'lib/features/todo/data/model.dart', '''
export 'detail.dart';
export '../todo.dart';
''');
      _write(root, 'lib/features/todo/data/detail.dart', 'class Detail {}');
      _write(root, 'lib/features/todo/data/model.g.dart', '''
export 'hidden.dart';
''');
      _write(root, 'lib/features/todo/data/hidden.dart', 'class Hidden {}');

      final reach = ProjectPaths.exportReach(
        dartFile: barrel,
        packageName: 'sample_app',
      );
      expect(reach.uris, contains('data/model.dart'));
      expect(reach.uris, contains('package:meta/meta.dart'));
      expect(reach.uris, contains('detail.dart'));
      expect(reach.uris, isNot(contains('hidden.dart')));
      expect(
        reach.files.any((file) => file.endsWith('/data/model.dart')),
        isTrue,
      );
      expect(
        reach.files.any((file) => file.endsWith('/data/detail.dart')),
        isTrue,
      );
      expect(
        reach.files.any((file) => file.endsWith('/data/hidden.dart')),
        isFalse,
      );

      final shallow = ProjectPaths.exportReach(
        dartFile: barrel,
        packageName: 'sample_app',
        maxDepth: 0,
      );
      expect(shallow.uris, isNot(contains('detail.dart')));
    });
  });

  group('ProjectPaths without a package', () {
    test('returns null when no pubspec exists', () {
      final dir = Directory.systemTemp.createTempSync('cal_project_path_none_');
      try {
        final file = p.join(dir.path, 'lib', 'a.dart');
        expect(ProjectPaths.packageNameNear(file), isNull);
        expect(ProjectPaths.projectRootNear('/no_such_pkg/a.dart'), isNull);
        expect(
          ProjectPaths.resolveProjectFile(
            uri: 'b.dart',
            currentFile: file,
            packageName: null,
          ),
          p.normalize(p.join(dir.path, 'lib', 'b.dart')).replaceAll('\\', '/'),
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('ignores a missing file, a directory, and an unreadable pubspec', () {
      final dir = Directory.systemTemp.createTempSync('cal_project_path_bad_');
      try {
        final missing = p.join(dir.path, 'missing.dart');
        expect(
          ProjectPaths.exportReach(dartFile: missing, packageName: null).uris,
          isEmpty,
        );
        expect(
          ProjectPaths.exportReach(dartFile: dir.path, packageName: null).files,
          isEmpty,
        );

        final dartDir = Directory(p.join(dir.path, 'not_source.dart'))
          ..createSync();
        expect(
          ProjectPaths.exportReach(
            dartFile: dartDir.path,
            packageName: null,
          ).uris,
          isEmpty,
        );

        final package = Directory(p.join(dir.path, 'pkg'))..createSync();
        final pubspecPath = p.join(package.path, 'pubspec.yaml');
        Directory(pubspecPath).createSync();
        final source = p.join(package.path, 'lib', 'a.dart');
        expect(ProjectPaths.packageNameNear(source), isNull);

        Directory(pubspecPath).deleteSync();
        File(pubspecPath).writeAsBytesSync([0xFF, 0xFE]);
        expect(ProjectPaths.packageNameNear(source), isNull);

        final lib = Directory(p.join(package.path, 'lib'))..createSync();
        final barrel = File(p.join(lib.path, 'barrel.dart'));
        barrel.writeAsBytesSync([0x80, 0xFF]);
        File(p.join(lib.path, 'bad.dart')).writeAsBytesSync([0x80, 0xFF]);
        expect(
          ProjectPaths.exportReach(
            dartFile: barrel.path,
            packageName: null,
          ).uris,
          isEmpty,
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}

NamespaceDirective _directive(String source) {
  return _unit(source).directives.whereType<NamespaceDirective>().single;
}

CompilationUnit _unit(String source) {
  return parseString(content: source, throwIfDiagnostics: false).unit;
}

String _write(Directory root, String relative, String source) {
  final file = File(p.join(root.path, relative));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(source);
  return file.path.replaceAll('\\', '/');
}
