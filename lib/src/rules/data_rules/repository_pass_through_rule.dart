import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/repository_rule_visitor.dart';
import '../../mixins/return_type_validation_mixin.dart';

class RepositoryPassThroughRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor, ReturnTypeValidationMixin {
  const RepositoryPassThroughRule() : super(code: _code);

  static const _code = LintCode(
    name: 'repository_pass_through',
    problemMessage:
        'Repository must return Future<Entity> (pass-through pattern).',
    correctionMessage:
        'Return Future<Entity> directly. Errors pass through to AsyncValue.guard().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      _checkRepositoryMethod(node, reporter, resolver);
    });
  }

  void _checkRepositoryMethod(
    MethodDeclaration method,
    DiagnosticReporter reporter,
    CustomLintResolver resolver,
  ) {
    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null || !isRepositoryImplementation(classNode)) return;

    if (shouldSkipMethod(method)) return;

    final returnType = method.returnType;
    if (returnType == null) return;

    final returnTypeString = returnType.toString();

    if (returnTypeString == 'void') return;
    if (returnTypeString.startsWith('Stream<')) return;

    final isFuture =
        returnTypeString.startsWith('Future<') ||
        returnTypeString.startsWith('FutureOr<');

    if (!isFuture) {
      if (_looksLikeEntityType(returnTypeString)) {
        final code = LintCode(
          name: 'repository_pass_through',
          problemMessage:
              'Repository method "${method.name.lexeme}" should return Future<$returnTypeString>.',
          correctionMessage: 'Wrap in Future: Future<$returnTypeString>',
          errorSeverity: DiagnosticSeverity.WARNING,
        );
        reporter.atNode(returnType, code);
      }
      return;
    }

    final unit = method.thisOrAncestorOfType<CompilationUnit>();
    if (isResultReturnType(returnType, unit: unit)) {
      final code = LintCode(
        name: 'repository_pass_through',
        problemMessage:
            'Repository should NOT use Result pattern. Use pass-through pattern instead.',
        correctionMessage:
            'Return Future<Entity> directly. Let errors pass through to AsyncValue.guard().',
        errorSeverity: DiagnosticSeverity.WARNING,
      );
      reporter.atNode(returnType, code);
    }

    _checkUnnecessaryTryCatch(method, reporter);
  }

  void _checkUnnecessaryTryCatch(
    MethodDeclaration method,
    DiagnosticReporter reporter,
  ) {
    final body = method.body;
    final tryStatements = <TryStatement>[];

    if (body is BlockFunctionBody) {
      for (final statement in body.block.statements) {
        _collectTryStatements(statement, tryStatements);
      }
    }

    for (final tryStmt in tryStatements) {
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
        final code = LintCode(
          name: 'repository_pass_through',
          problemMessage: 'Repository should not handle/re-wrap exceptions. Use pass-through.',
          correctionMessage:
              'Do not convert/wrap exceptions in catch. Prefer logging + rethrow (or let it pass through).',
          errorSeverity: DiagnosticSeverity.WARNING,
        );
        reporter.atNode(tryStmt, code);
      }
    }
  }

  bool _isAllowedCatch(CatchClause catchClause) {
    // Allowed: logging + rethrow
    var hasRethrow = false;
    for (final statement in catchClause.body.statements) {
      if (_containsRethrow(statement)) {
        hasRethrow = true;
      }
      if (_containsReturn(statement)) {
        return false;
      }
      if (_containsThrowNewException(statement)) {
        return false;
      }
      if (!_containsRethrow(statement) && !_isLoggingStatement(statement)) {
        // Non-logging side effects in catch should be reviewed as non pass-through
        return false;
      }
    }

    return hasRethrow;
  }

  bool _looksLikeRewrappingOrConversion(CatchClause catchClause) {
    for (final statement in catchClause.body.statements) {
      if (_containsReturn(statement) || _containsThrowNewException(statement)) {
        return true;
      }
    }
    return false;
  }

  void _collectTryStatements(Statement statement, List<TryStatement> output) {
    if (statement is TryStatement) {
      output.add(statement);
      for (final inner in statement.body.statements) {
        _collectTryStatements(inner, output);
      }
      for (final catchClause in statement.catchClauses) {
        for (final inner in catchClause.body.statements) {
          _collectTryStatements(inner, output);
        }
      }
      final finallyBlock = statement.finallyBlock;
      if (finallyBlock != null) {
        for (final inner in finallyBlock.statements) {
          _collectTryStatements(inner, output);
        }
      }
      return;
    }

    if (statement is Block) {
      for (final inner in statement.statements) {
        _collectTryStatements(inner, output);
      }
    }
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

  bool _containsRethrow(Statement statement) {
    if (statement is ExpressionStatement &&
        statement.expression is RethrowExpression) {
      return true;
    }
    return statement.toSource().contains('rethrow');
  }

  bool _containsReturn(Statement statement) => statement is ReturnStatement;

  bool _containsThrowNewException(Statement statement) {
    return statement.toSource().trimLeft().startsWith('throw ');
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
