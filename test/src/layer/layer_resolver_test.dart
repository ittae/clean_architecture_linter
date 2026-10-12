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
};

class _FixtureSession {
  _FixtureSession._(this._collection, this._libraries, this._root);

  final AnalysisContextCollection _collection;
  final Map<String, ResolvedLibraryResult> _libraries;
  final Directory _root;

  static Future<_FixtureSession> open(Map<String, String> files) async {
    final root = await Directory.systemTemp.createTemp('cal_layer_resolver_');
    final rootPath = p.normalize(root.absolute.path);
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

    final collection = AnalysisContextCollection(
      includedPaths: [rootPath],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final libraries = <String, ResolvedLibraryResult>{};
    for (final relative in files.keys) {
      final absolute = p.normalize(p.join(rootPath, relative));
      final result = await collection
          .contextFor(absolute)
          .currentSession
          .getResolvedLibraryContaining(absolute);
      if (result is! ResolvedLibraryResult) {
        throw StateError('Failed to resolve $relative: $result');
      }
      libraries[relative] = result;
    }
    return _FixtureSession._(collection, libraries, root);
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
