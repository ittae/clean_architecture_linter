import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:clean_architecture_linter/src/layer/layer_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Design for this resolver: https://github.com/ittae/clean_architecture_linter/pull/192
void main() {
  late _FixtureSession session;
  late LayerResolver resolver;

  setUpAll(() async {
    session = await _FixtureSession.open(_files);
  });

  setUp(() {
    resolver = LayerResolver(packageName: 'cal_v2_harness_app');
  });

  tearDownAll(() async {
    await session.dispose();
  });

  test('classifies a domain library and its feature', () {
    final location = resolver.resolveLibrary(
      session.library('lib/features/todo/domain/entities/todo.dart'),
    );

    expect(location.kind, LayerKind.domain);
    expect(location.feature, 'todo');
    expect(location.useCaseLibrary, isFalse);
    expect(location.infrastructurePackage, isFalse);
    expect(
      location.libraryUri,
      Uri.parse(
        'package:cal_v2_harness_app/features/todo/domain/entities/todo.dart',
      ),
    );
  });

  test('classifies a data library', () {
    final location = resolver.resolveLibrary(
      session.library('lib/features/todo/data/models/todo_model.dart'),
    );

    expect(location.kind, LayerKind.data);
    expect(location.feature, 'todo');
  });

  test('classifies a presentation library', () {
    final location = resolver.resolveLibrary(
      session.library('lib/features/todo/presentation/todo_page.dart'),
    );

    expect(location.kind, LayerKind.presentation);
    expect(location.feature, 'todo');
  });

  test('marks a use case library inside domain', () {
    final location = resolver.resolveLibrary(
      session.library('lib/features/todo/domain/usecases/get_todo.dart'),
    );

    expect(location.kind, LayerKind.domain);
    expect(location.useCaseLibrary, isTrue);
    expect(location.feature, 'todo');
  });

  test('barrel re-export keeps the declaring library layer', () {
    final barrel = resolver.resolveLibrary(
      session.library('lib/features/todo/todo.dart'),
    );
    final model = session.typeNamed(
      'lib/features/todo/presentation/todo_page.dart',
      'TodoModel',
    );

    expect(barrel.kind, LayerKind.unknown);
    expect(barrel.feature, 'todo');
    expect(model, isNotNull);
    expect(resolver.resolveElement(model!)!.kind, LayerKind.data);
    expect(
      resolver.resolveElement(model)!.libraryUri.path,
      'cal_v2_harness_app/features/todo/data/models/todo_model.dart',
    );
  });

  test('part file uses the parent library URI', () {
    final viaPartPath = resolver.resolveLibrary(
      session.library('lib/features/todo/data/todo_part.dart'),
    );
    final declaredInPart = session
        .library('lib/features/todo/domain/todo.dart')
        .getClass('TodoPart');

    expect(viaPartPath.kind, LayerKind.domain);
    expect(
      viaPartPath.libraryUri.path,
      'cal_v2_harness_app/features/todo/domain/todo.dart',
    );
    expect(declaredInPart, isNotNull);
    expect(resolver.resolveElement(declaredInPart!)!.kind, LayerKind.domain);
    expect(
      resolver.resolveElement(declaredInPart)!.libraryUri,
      viaPartPath.libraryUri,
    );
  });

  test('package and relative URIs name the same library', () {
    final relative = session.imported(
      'lib/features/todo/presentation/reader.dart',
      '../domain/entities/todo.dart',
    );
    final packaged = session.imported(
      'lib/features/todo/presentation/reader.dart',
      'package:cal_v2_harness_app/features/todo/domain/entities/todo.dart',
    );

    expect(relative, isNotNull);
    expect(packaged, isNotNull);
    expect(relative!.uri, packaged!.uri);
    expect(resolver.resolveLibrary(relative).kind, LayerKind.domain);
    expect(
      identical(
        resolver.resolveLibrary(relative),
        resolver.resolveLibrary(packaged),
      ),
      isTrue,
    );
  });

  test('code outside known folders is unknown', () {
    final mainLibrary = resolver.resolveLibrary(
      session.library('lib/main.dart'),
    );
    final core = resolver.resolveLibrary(
      session.library('lib/core/config.dart'),
    );

    expect(mainLibrary.kind, LayerKind.unknown);
    expect(mainLibrary.feature, isNull);
    expect(core.kind, LayerKind.unknown);
    expect(core.feature, isNull);
    expect(mainLibrary.useCaseLibrary, isFalse);
  });

  test('dart:io is external', () {
    final io = session.imported('lib/main.dart', 'dart:io');

    expect(io, isNotNull);
    expect(io!.isInSdk, isTrue);
    expect(resolver.resolveLibrary(io).kind, LayerKind.external);
    expect(resolver.resolveLibrary(io).infrastructurePackage, isFalse);
  });

  // characterization: locks current behavior; not red-first proof of this change.
  test('another package with a domain folder is external', () {
    final location = resolver.resolveLibrary(
      session.library('deps/other_pkg/lib/domain/entity.dart'),
    );

    expect(
      location.libraryUri,
      Uri.parse('package:other_pkg/domain/entity.dart'),
    );
    expect(location.kind, LayerKind.external);
    expect(location.feature, isNull);
    expect(location.infrastructurePackage, isFalse);
  });

  test('an omitted packageName treats package URIs as external', () {
    final unnamed = LayerResolver();
    final own = unnamed.resolveLibrary(
      session.library('lib/features/todo/domain/entities/todo.dart'),
    );
    final other = unnamed.resolveLibrary(
      session.library('deps/other_pkg/lib/domain/entity.dart'),
    );

    expect(own.kind, LayerKind.external);
    expect(other.kind, LayerKind.external);
    expect(other.infrastructurePackage, isFalse);
  });

  // characterization: locks current behavior; not red-first proof of this change.
  test('package:dio is an infrastructure package', () {
    final location = resolver.resolveLibrary(
      session.library('deps/dio/lib/dio.dart'),
    );

    expect(location.libraryUri, Uri.parse('package:dio/dio.dart'));
    expect(location.kind, LayerKind.external);
    expect(location.infrastructurePackage, isTrue);
  });

  test('a package under review named dio is classified by its folders', () {
    final reviewingDio = LayerResolver(packageName: 'dio');
    final location = reviewingDio.resolveLibrary(
      session.library('deps/dio/lib/features/todo/domain/entities/todo.dart'),
    );

    expect(
      location.libraryUri,
      Uri.parse('package:dio/features/todo/domain/entities/todo.dart'),
    );
    expect(location.kind, LayerKind.domain);
    expect(location.feature, 'todo');
    expect(location.useCaseLibrary, isFalse);
    expect(location.infrastructurePackage, isFalse);
  });

  test(
    'a package under review named firebase_demo is classified by its folders',
    () {
      final reviewingFirebase = LayerResolver(packageName: 'firebase_demo');
      final location = reviewingFirebase.resolveLibrary(
        session.library(
          'deps/firebase_demo/lib/features/todo/domain/todo.dart',
        ),
      );

      expect(
        location.libraryUri,
        Uri.parse('package:firebase_demo/features/todo/domain/todo.dart'),
      );
      expect(location.kind, LayerKind.domain);
      expect(location.feature, 'todo');
      expect(location.infrastructurePackage, isFalse);
    },
  );

  // characterization: locks current behavior; not red-first proof of this change.
  test('classifies an infrastructure folder inside the current package', () {
    final location = resolver.resolveLibrary(
      session.library('lib/features/todo/infrastructure/todo_gateway.dart'),
    );

    expect(location.kind, LayerKind.infrastructure);
    expect(location.feature, 'todo');
    expect(location.infrastructurePackage, isFalse);
  });

  // characterization: locks current behavior; not red-first proof of this change.
  test('classifies a services folder as infrastructure', () {
    final location = resolver.resolveLibrary(
      session.library('lib/features/todo/services/todo_service.dart'),
    );

    expect(location.kind, LayerKind.infrastructure);
    expect(location.feature, 'todo');
    expect(location.infrastructurePackage, isFalse);
  });

  test('a capital Domain folder is not the domain layer', () {
    final location = resolver.resolveLibrary(
      session.library('lib/features/todo/Domain/todo_case.dart'),
    );

    expect(location.kind, LayerKind.unknown);
    expect(location.feature, 'todo');
  });

  test('caches a library location by canonical URI', () {
    final library = session.library('lib/main.dart');
    final first = resolver.resolveLibrary(library);
    final second = resolver.resolveLibrary(library);
    final domain = resolver.resolveLibrary(
      session.library('lib/features/todo/domain/entities/todo.dart'),
    );

    expect(identical(first, second), isTrue);
    expect(identical(first, domain), isFalse);
    expect(identical(resolver.resolveLibrary(library), first), isTrue);
  });
}

const _files = {
  'lib/main.dart': '''
import 'dart:io';

class App {
  void run(File file) {}
}
''',
  'lib/core/config.dart': '''
class Config {}
''',
  'lib/features/todo/domain/entities/todo.dart': '''
class Todo {}
''',
  'lib/features/todo/domain/usecases/get_todo.dart': '''
class GetTodo {
  void call() {}
}
''',
  'lib/features/todo/domain/todo.dart': '''
part '../data/todo_part.dart';

class TodoLibrary {}
''',
  'lib/features/todo/data/todo_part.dart': '''
part of '../domain/todo.dart';

class TodoPart {}
''',
  'lib/features/todo/data/models/todo_model.dart': '''
class TodoModel {}
''',
  'lib/features/todo/todo.dart': '''
export 'data/models/todo_model.dart';
''',
  'lib/features/todo/presentation/todo_page.dart': '''
import 'package:cal_v2_harness_app/features/todo/todo.dart';

void read(TodoModel model) {}
''',
  'lib/features/todo/presentation/reader.dart': '''
import '../domain/entities/todo.dart';
import 'package:cal_v2_harness_app/features/todo/domain/entities/todo.dart';

void read(Todo todo) {}
''',
  'lib/features/todo/Domain/todo_case.dart': '''
class TodoCase {}
''',
  'lib/features/todo/infrastructure/todo_gateway.dart': '''
class TodoGateway {}
''',
  'lib/features/todo/services/todo_service.dart': '''
class TodoService {}
''',
};

const _dependencyPackages = {
  'other_pkg': {'lib/domain/entity.dart': 'class OtherEntity {}\n'},
  'dio': {
    'lib/dio.dart': 'class Dio {}\n',
    'lib/features/todo/domain/entities/todo.dart': 'class DioTodo {}\n',
  },
  'firebase_demo': {
    'lib/features/todo/domain/todo.dart': 'class FirebaseDemoTodo {}\n',
  },
};

class _FixtureSession {
  _FixtureSession._(this._collection, this._libraries, this._root, this._deps);

  final AnalysisContextCollection _collection;
  final Map<String, ResolvedLibraryResult> _libraries;
  final Directory _root;
  final Directory _deps;

  static Future<_FixtureSession> open(Map<String, String> files) async {
    final root = await Directory.systemTemp.createTemp('cal_layer_resolver_');
    final deps = await Directory.systemTemp.createTemp(
      'cal_layer_resolver_deps_',
    );
    final rootPath = p.normalize(root.absolute.path);
    final depsPath = p.normalize(deps.absolute.path);
    _write(p.join(rootPath, 'pubspec.yaml'), '''
name: cal_v2_harness_app
environment:
  sdk: ^3.7.0
''');
    _write(p.join(rootPath, '.dart_tool', 'package_config.json'), '''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "cal_v2_harness_app",
      "rootUri": "../",
      "packageUri": "lib/",
      "languageVersion": "3.7"
    }
  ]
}
''');
    for (final entry in files.entries) {
      _write(p.join(rootPath, entry.key), entry.value);
    }
    final includedPaths = <String>[rootPath];
    for (final package in _dependencyPackages.entries) {
      final packageRoot = p.join(depsPath, package.key);
      _write(p.join(packageRoot, 'pubspec.yaml'), '''
name: ${package.key}
environment:
  sdk: ^3.7.0
''');
      _write(p.join(packageRoot, '.dart_tool', 'package_config.json'), '''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "${package.key}",
      "rootUri": "../",
      "packageUri": "lib/",
      "languageVersion": "3.7"
    }
  ]
}
''');
      for (final file in package.value.entries) {
        _write(p.join(packageRoot, file.key), file.value);
      }
      includedPaths.add(p.normalize(packageRoot));
    }

    final collection = AnalysisContextCollection(
      includedPaths: includedPaths,
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final libraries = <String, ResolvedLibraryResult>{};
    for (final relative in files.keys) {
      libraries[relative] = await _resolve(
        collection,
        p.normalize(p.join(rootPath, relative)),
        relative,
      );
    }
    for (final package in _dependencyPackages.entries) {
      for (final relative in package.value.keys) {
        final key = 'deps/${package.key}/$relative';
        libraries[key] = await _resolve(
          collection,
          p.normalize(p.join(depsPath, package.key, relative)),
          key,
        );
      }
    }
    return _FixtureSession._(collection, libraries, root, deps);
  }

  static Future<ResolvedLibraryResult> _resolve(
    AnalysisContextCollection collection,
    String absolute,
    String label,
  ) async {
    final result = await collection
        .contextFor(absolute)
        .currentSession
        .getResolvedLibraryContaining(absolute);
    if (result is! ResolvedLibraryResult) {
      throw StateError('Failed to resolve $label: $result');
    }
    return result;
  }

  LibraryElement library(String relativePath) {
    return _libraries[relativePath]!.element;
  }

  LibraryElement? imported(String relativePath, String uriText) {
    final result = _libraries[relativePath]!;
    for (final unit in result.units) {
      for (final directive in unit.unit.directives) {
        if (directive is ImportDirective &&
            directive.uri.stringValue == uriText) {
          return directive.libraryImport?.importedLibrary;
        }
      }
    }
    return null;
  }

  Element? typeNamed(String relativePath, String name) {
    final result = _libraries[relativePath]!;
    for (final unit in result.units) {
      final finder = _NamedElementFinder(name);
      unit.unit.accept(finder);
      if (finder.element != null) return finder.element;
    }
    return null;
  }

  Future<void> dispose() async {
    await _collection.dispose();
    if (_root.existsSync()) {
      _root.deleteSync(recursive: true);
    }
    if (_deps.existsSync()) {
      _deps.deleteSync(recursive: true);
    }
  }

  static void _write(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}

class _NamedElementFinder extends RecursiveAstVisitor<void> {
  _NamedElementFinder(this.name);

  final String name;
  Element? element;

  @override
  void visitNamedType(NamedType node) {
    if (node.name.lexeme == name) {
      element = node.element;
    }
    super.visitNamedType(node);
  }
}
