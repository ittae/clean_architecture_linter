import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:clean_architecture_linter/src/clean_architecture_linter_base.dart';
import 'package:clean_architecture_linter/src/compat/analyzer_ast_compat.dart';
import 'package:test/test.dart';

void main() {
  group('CleanArchitectureUtils path filters', () {
    test('keeps project yaml and excludes other yaml docs', () {
      expect(CleanArchitectureUtils.shouldExcludeFile('pubspec.yaml'), isFalse);
      expect(
        CleanArchitectureUtils.shouldExcludeFile('analysis_options.yaml'),
        isFalse,
      );
      expect(CleanArchitectureUtils.shouldExcludeFile('build.yaml'), isFalse);
      expect(
        CleanArchitectureUtils.shouldExcludeFile(
          'tool/dependency_validator.yaml',
        ),
        isFalse,
      );
      expect(
        CleanArchitectureUtils.shouldExcludeFile('docs/guide.yaml'),
        isTrue,
      );
      expect(
        CleanArchitectureUtils.shouldExcludeFile('config/app.yml'),
        isTrue,
      );
    });

    test('excludes generated suffixes beyond freezed and mocks', () {
      expect(
        CleanArchitectureUtils.shouldExcludeFile('lib/app.config.dart'),
        isTrue,
      );
      expect(
        CleanArchitectureUtils.shouldExcludeFile('lib/routes.gr.dart'),
        isTrue,
      );
      expect(
        CleanArchitectureUtils.shouldExcludeFile('lib/l10n.localizely.dart'),
        isTrue,
      );
      expect(
        CleanArchitectureUtils.shouldExcludeFile('lib/api/user.pb.dart'),
        isTrue,
      );
    });
  });

  group('CleanArchitectureUtils name and AST helpers', () {
    test('treats feature-prefixed names as specific', () {
      expect(CleanArchitectureUtils.isGenericPrefix('Data'), isTrue);
      expect(CleanArchitectureUtils.isGenericPrefix('Todo'), isFalse);
      expect(CleanArchitectureUtils.hasCapitalizedWord('Todo'), isTrue);
      expect(CleanArchitectureUtils.hasCapitalizedWord(''), isFalse);
      expect(CleanArchitectureUtils.hasCapitalizedWord('lowercase'), isFalse);
      expect(
        CleanArchitectureUtils.isGenericClassName('Exception', 'Exception'),
        isTrue,
      );
      expect(
        CleanArchitectureUtils.isGenericClassName('DataException', 'Exception'),
        isTrue,
      );
      expect(
        CleanArchitectureUtils.isGenericClassName('TodoException', 'Exception'),
        isFalse,
      );
      expect(
        CleanArchitectureUtils.isGenericClassName(
          'TodoRepository',
          'Exception',
        ),
        isFalse,
      );
    });

    test('identifies repository interfaces from the class AST', () {
      final unit = parseString(
        content: '''
abstract class TodoRepository {
  Future<void> save();
  String get label;
}

class TodoRepositoryImpl {
  Future<void> save() async {}
}

class Todo {}
''',
      ).unit;
      final classes = unit.declarations.whereType<ClassDeclaration>().toList();

      expect(CleanArchitectureUtils.isRepositoryInterface(classes[0]), isTrue);
      expect(CleanArchitectureUtils.isRepositoryInterface(classes[1]), isFalse);
      expect(CleanArchitectureUtils.isRepositoryInterface(classes[2]), isFalse);

      final methods = classMembers(
        classes[0],
      ).whereType<MethodDeclaration>().toList();
      expect(
        CleanArchitectureUtils.isRepositoryInterfaceMethod(methods[0]),
        isTrue,
      );
      expect(
        CleanArchitectureUtils.isRepositoryInterfaceMethod(methods[1]),
        isTrue,
      );
      final privateMethod = classMembers(
        parseString(
          content: 'class T { void _save() {} void save() {} }',
        ).unit.declarations.whereType<ClassDeclaration>().single,
      ).whereType<MethodDeclaration>().first;
      expect(CleanArchitectureUtils.isPrivateMethod(privateMethod), isTrue);
      expect(CleanArchitectureUtils.isPrivateMethod(methods[0]), isFalse);
    });

    test('recognizes exception types, parent classes, and rethrow', () {
      final unit = parseString(
        throwIfDiagnostics: false,
        content: '''
class TodoException extends Exception {}
class TodoFailure implements Exception {}
class TodoMixin with Exception {}
class Todo {}

void outside() {}

class Box {
  void run() {
    try {} catch (e) {
      throw e;
      // Parser recovers the keyword as the thrown expression. A bare
      // `rethrow;` is a RethrowExpression, which isRethrow does not accept.
      throw rethrow;
    }
  }
}
''',
      ).unit;
      final classes = unit.declarations.whereType<ClassDeclaration>().toList();

      expect(CleanArchitectureUtils.implementsException(classes[0]), isTrue);
      expect(CleanArchitectureUtils.implementsException(classes[1]), isTrue);
      expect(CleanArchitectureUtils.implementsException(classes[2]), isTrue);
      expect(CleanArchitectureUtils.implementsException(classes[3]), isFalse);

      final throws = _throws(unit);
      expect(CleanArchitectureUtils.isRethrow(throws[0]), isFalse);
      expect(throws[1].expression.toString(), 'rethrow');
      expect(CleanArchitectureUtils.isRethrow(throws[1]), isTrue);
      expect(
        classDeclarationName(
          CleanArchitectureUtils.findParentClass(throws[0])!,
        ),
        'Box',
      );
      final topLevel = unit.declarations
          .whereType<FunctionDeclaration>()
          .single;
      expect(CleanArchitectureUtils.findParentClass(topLevel), isNull);
    });

    group('isRethrow with standalone rethrow statement', () {
      late CompilationUnit unit;

      setUp(() {
        unit = parseString(
          throwIfDiagnostics: false,
          content: '''
class Box {
  void run() {
    try {} catch (e) {
      rethrow;
    }
    try {} catch (e) {
      throw e;
    }
    try {} catch (e) {
      throw Exception('x');
    }
  }
}
''',
        ).unit;
      });

      test('recognizes a bare `rethrow;` RethrowExpression', () {
        final rethrows = _rethrows(unit);

        expect(rethrows, hasLength(1));
        expect(CleanArchitectureUtils.isRethrow(rethrows.single), isTrue);
      });

      test('recognizes the ExpressionStatement wrapping `rethrow;`', () {
        final statement = _rethrows(unit).single.parent!;

        expect(statement, isA<ExpressionStatement>());
        expect(CleanArchitectureUtils.isRethrow(statement), isTrue);
      });

      test('does not treat `throw e;` or `throw Exception()` as rethrow', () {
        final throws = _throws(unit);

        expect(throws, hasLength(2));
        for (final node in throws) {
          expect(CleanArchitectureUtils.isRethrow(node), isFalse);
        }
        expect(CleanArchitectureUtils.isRethrow(throws[0].parent!), isFalse);
      });
    });
  });
}

List<RethrowExpression> _rethrows(CompilationUnit unit) {
  final visitor = _RethrowFinder();
  unit.accept(visitor);
  return visitor.nodes;
}

class _RethrowFinder extends RecursiveAstVisitor<void> {
  final nodes = <RethrowExpression>[];

  @override
  void visitRethrowExpression(RethrowExpression node) {
    nodes.add(node);
  }
}

List<ThrowExpression> _throws(CompilationUnit unit) {
  final visitor = _ThrowFinder();
  unit.accept(visitor);
  return visitor.nodes;
}

class _ThrowFinder extends RecursiveAstVisitor<void> {
  final nodes = <ThrowExpression>[];

  @override
  void visitThrowExpression(ThrowExpression node) {
    nodes.add(node);
  }
}
