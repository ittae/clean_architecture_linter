import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:clean_architecture_linter/src/compat/analyzer_ast_compat.dart';
import 'package:test/test.dart';

void main() {
  group('analyzer AST compat', () {
    test('reads formal parameter names from modern analyzer nodes', () {
      final unit = parseString(
        content: '''
class TodoModel {
  const TodoModel({required String title});
}
''',
      ).unit;

      final parameter = _firstFormalParameter(unit);

      expect(formalParameterName(parameter), 'title');
      expect(formalParameterType(parameter)?.toSource(), 'String');
    });

    test('matches named boolean arguments without source string parsing', () {
      final unit = parseString(
        content: '''
@Riverpod(keepAlive: /* comment */ true)
class TodoListNotifier {}
''',
      ).unit;

      final argument = _firstAnnotationArgument(unit);

      expect(
        isNamedBooleanArgument(argument, name: 'keepAlive', value: true),
        isTrue,
      );
      expect(
        isNamedBooleanArgument(argument, name: 'keepAlive', value: false),
        isFalse,
      );
    });
  });
}

FormalParameter _firstFormalParameter(CompilationUnit unit) {
  final visitor = _FirstNodeVisitor<FormalParameter>();
  visitor.visitAllNodes(unit);
  return visitor.node!;
}

AstNode _firstAnnotationArgument(CompilationUnit unit) {
  final visitor = _FirstNodeVisitor<Annotation>();
  visitor.visitAllNodes(unit);
  return visitor.node!.arguments!.arguments.first;
}

class _FirstNodeVisitor<T extends AstNode> extends BreadthFirstVisitor<void> {
  T? node;

  @override
  void visitNode(AstNode node) {
    this.node ??= node is T ? node : null;
    if (this.node == null) {
      super.visitNode(node);
    }
  }
}
