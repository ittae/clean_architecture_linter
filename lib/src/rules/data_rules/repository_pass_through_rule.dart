import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';
import '../../mixins/return_type_validation_mixin.dart';

/// Enforces repository pass-through return and error handling patterns.
class RepositoryPassThroughRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'repository_pass_through',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.repository_pass_through',
  );

  RepositoryPassThroughRule()
    : super(
        name: 'repository_pass_through',
        description:
            'Requires repositories to return Future<Entity> directly and let errors pass through.',
      );

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodDeclaration(
      this,
      _RepositoryPassThroughVisitor(this, context),
    );
  }
}

class _RepositoryPassThroughVisitor extends SimpleAstVisitor<void>
    with RepositoryRuleVisitor, ReturnTypeValidationMixin {
  _RepositoryPassThroughVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null || !isRepositoryImplementation(classNode)) return;

    if (shouldSkipMethod(node)) return;

    final returnType = node.returnType;
    if (returnType == null) return;

    final returnTypeString = returnType.toString();
    if (returnTypeString == 'void') return;
    if (returnTypeString.startsWith('Stream<')) return;

    final unit = node.thisOrAncestorOfType<CompilationUnit>();
    if (isResultReturnType(returnType, unit: unit)) {
      rule.reportAtNode(
        returnType,
        arguments: [
          'Repository should NOT use Result pattern. Use pass-through pattern instead.',
          'Return Future<Entity> directly. Let errors pass through to AsyncValue.guard().',
        ],
      );
      return;
    }

    final isFuture =
        returnTypeString.startsWith('Future<') ||
        returnTypeString.startsWith('FutureOr<');

    if (!isFuture) {
      if (_looksLikeEntityType(returnTypeString)) {
        rule.reportAtNode(
          returnType,
          arguments: [
            'Repository method "${node.name.lexeme}" should return Future<$returnTypeString>.',
            'Wrap in Future: Future<$returnTypeString>',
          ],
        );
      }
      return;
    }

    _checkUnnecessaryTryCatch(node);
  }

  void _checkUnnecessaryTryCatch(MethodDeclaration method) {
    final body = method.body;
    if (body is! BlockFunctionBody) return;

    final collector = _TryStatementCollector();
    body.block.accept(collector);

    for (final tryStmt in collector.tryStatements) {
      if (tryStmt.catchClauses.isEmpty) continue;

      var shouldReport = false;
      for (final catchClause in tryStmt.catchClauses) {
        if (_isAllowedCatch(catchClause)) {
          continue;
        }

        if (_looksLikeRewrappingOrConversion(catchClause)) {
          shouldReport = true;
          break;
        }
      }

      if (shouldReport) {
        rule.reportAtNode(
          tryStmt,
          arguments: [
            'Repository should not handle/re-wrap exceptions. Use pass-through.',
            'Do not convert/wrap exceptions in catch. Prefer logging + rethrow (or let it pass through).',
          ],
        );
      }
    }
  }

  bool _isAllowedCatch(CatchClause catchClause) {
    final catchBody = _CatchBodyVisitor();
    catchClause.body.accept(catchBody);

    if (catchBody.hasReturn || catchBody.hasThrowExpression) {
      return false;
    }

    if (!catchBody.hasRethrow) {
      return false;
    }

    for (final statement in catchClause.body.statements) {
      if (!_isDirectRethrowStatement(statement) &&
          !_isLoggingStatement(statement)) {
        return false;
      }
    }

    return true;
  }

  bool _looksLikeRewrappingOrConversion(CatchClause catchClause) {
    final catchBody = _CatchBodyVisitor();
    catchClause.body.accept(catchBody);
    return catchBody.hasReturn || catchBody.hasThrowExpression;
  }

  bool _isLoggingStatement(Statement statement) {
    final src = statement.toSource();
    const loggingHints = [
      'logger.',
      'log(',
      'debugPrint(',
      'print(',
      'Sentry.captureException(',
      'Sentry.captureMessage(',
      'captureException(',
      'captureMessage(',
    ];
    return loggingHints.any(src.contains);
  }

  bool _isDirectRethrowStatement(Statement statement) {
    return statement is ExpressionStatement &&
        statement.expression is RethrowExpression;
  }

  bool _looksLikeEntityType(String typeName) {
    if (_isPrimitiveOrCollection(typeName)) return false;

    if (typeName == 'void' ||
        typeName == 'dynamic' ||
        typeName == 'Object' ||
        typeName == 'Never') {
      return false;
    }

    return typeName.isNotEmpty && typeName[0] == typeName[0].toUpperCase();
  }

  bool _isPrimitiveOrCollection(String typeName) {
    const primitives = {
      'int',
      'double',
      'num',
      'String',
      'bool',
      'void',
      'dynamic',
      'Object',
      'Null',
    };

    if (primitives.contains(typeName)) return true;

    if (typeName.endsWith('?')) {
      final baseType = typeName.substring(0, typeName.length - 1);
      if (primitives.contains(baseType)) return true;
    }

    if (typeName.startsWith('List<') ||
        typeName.startsWith('Set<') ||
        typeName.startsWith('Iterable<')) {
      final inner = _extractGenericType(typeName);
      return inner != null && _isPrimitiveOrCollection(inner);
    }

    if (typeName.startsWith('Map<')) {
      final types = _extractMapTypes(typeName);
      if (types != null) {
        return _isPrimitiveOrCollection(types.$1) &&
            _isPrimitiveOrCollection(types.$2);
      }
    }

    return false;
  }

  String? _extractGenericType(String typeName) {
    final start = typeName.indexOf('<');
    final end = typeName.lastIndexOf('>');
    if (start != -1 && end != -1 && end > start) {
      return typeName.substring(start + 1, end).trim();
    }
    return null;
  }

  (String, String)? _extractMapTypes(String typeName) {
    final inner = _extractGenericType(typeName);
    if (inner == null) return null;

    final commaIndex = inner.indexOf(',');
    if (commaIndex == -1) return null;

    final keyType = inner.substring(0, commaIndex).trim();
    final valueType = inner.substring(commaIndex + 1).trim();
    return (keyType, valueType);
  }
}

class _TryStatementCollector extends RecursiveAstVisitor<void> {
  final tryStatements = <TryStatement>[];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitTryStatement(TryStatement node) {
    tryStatements.add(node);
    super.visitTryStatement(node);
  }
}

class _CatchBodyVisitor extends RecursiveAstVisitor<void> {
  var hasRethrow = false;
  var hasReturn = false;
  var hasThrowExpression = false;

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitTryStatement(TryStatement node) {}

  @override
  void visitRethrowExpression(RethrowExpression node) {
    hasRethrow = true;
    super.visitRethrowExpression(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    hasReturn = true;
    super.visitReturnStatement(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    hasThrowExpression = true;
    super.visitThrowExpression(node);
  }
}
