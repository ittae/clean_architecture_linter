import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

import '../../../lib/src/mixins/return_type_validation_mixin.dart';

class _TestRule with ReturnTypeValidationMixin {}

MethodDeclaration _getMethod(String source, String methodName) {
  final unit = parseString(content: source).unit;
  for (final declaration in unit.declarations) {
    if (declaration is ClassDeclaration) {
      for (final member in declaration.members) {
        if (member is MethodDeclaration && member.name.lexeme == methodName) {
          return member;
        }
      }
    }
  }
  throw StateError('Method not found: $methodName');
}

CompilationUnit _getUnit(String source) => parseString(content: source).unit;

void main() {
  group('ReturnTypeValidationMixin', () {
    late _TestRule testRule;

    setUp(() {
      testRule = _TestRule();
    });

    test('detects direct Result type', () {
      const source = '''
class Result<T, F> {}
class Todo {}
class Failure {}
class GetTodoUseCase {
  Future<Result<Todo, Failure>> call() async => Result<Todo, Failure>();
}
''';
      final unit = _getUnit(source);
      final method = _getMethod(source, 'call');
      expect(testRule.isResultReturnType(method.returnType!, unit: unit), isTrue);
    });

    test('detects typedef alias to Result', () {
      const source = '''
class Result<T, F> {}
class Todo {}
class Failure {}
typedef Outcome<T> = Result<T, Failure>;
class GetTodoUseCase {
  Outcome<Todo> call() => Result<Todo, Failure>();
}
''';
      final unit = _getUnit(source);
      final method = _getMethod(source, 'call');
      expect(testRule.isResultReturnType(method.returnType!, unit: unit), isTrue);
    });

    test('detects typedef alias inside Future wrapper', () {
      const source = '''
class Result<T, F> {}
class Todo {}
class Failure {}
typedef Outcome<T> = Result<T, Failure>;
class GetTodoUseCase {
  Future<Outcome<Todo>> call() async => Result<Todo, Failure>();
}
''';
      final unit = _getUnit(source);
      final method = _getMethod(source, 'call');
      expect(testRule.isResultReturnType(method.returnType!, unit: unit), isTrue);
    });

    test('does not flag normal Future<Entity>', () {
      const source = '''
class Todo {}
class GetTodoUseCase {
  Future<Todo> call() async => Todo();
}
''';
      final unit = _getUnit(source);
      final method = _getMethod(source, 'call');
      expect(testRule.isResultReturnType(method.returnType!, unit: unit), isFalse);
    });
  });
}
