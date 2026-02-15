import 'package:analyzer/dart/ast/ast.dart';

import '../clean_architecture_linter_base.dart';

mixin ReturnTypeValidationMixin {
  /// Checks if the given [returnType] is a Result/Either (including typedef aliases).
  bool isResultReturnType(TypeAnnotation returnType, {CompilationUnit? unit}) {
    if (CleanArchitectureUtils.isResultType(returnType)) {
      return true;
    }

    if (unit == null) return false;

    // Typedef alias: direct named type
    if (returnType is NamedType) {
      final aliasName = returnType.name.lexeme;
      if (_isResultAlias(aliasName, unit)) {
        return true;
      }

      // Typedef alias inside generic wrappers (e.g., Future<Outcome<T>>)
      final typeArgs = returnType.typeArguments?.arguments;
      if (typeArgs != null) {
        for (final arg in typeArgs) {
          if (arg is NamedType && _isResultAlias(arg.name.lexeme, unit)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  bool isVoidReturnType(TypeAnnotation returnType) {
    return CleanArchitectureUtils.isVoidType(returnType);
  }

  bool shouldSkipMethod(MethodDeclaration method) {
    final methodName = method.name.lexeme;
    if (methodName.startsWith('_')) return true;

    if (method.isOperator || method.isSetter || method.isGetter) return true;

    final returnType = method.returnType;
    if (returnType != null && isVoidReturnType(returnType)) return true;

    return false;
  }

  TypeAnnotation? getMethodReturnType(MethodDeclaration method) {
    return method.returnType;
  }

  bool _isResultAlias(String aliasName, CompilationUnit unit) {
    final aliasMap = <String, String>{};

    for (final declaration in unit.declarations) {
      if (declaration is GenericTypeAlias) {
        final name = declaration.name.lexeme;
        final rhs = declaration.type.toSource();
        aliasMap[name] = rhs;
      }
    }

    if (aliasMap.isEmpty) return false;

    final visited = <String>{};
    return _resolvesToResultLike(aliasName, aliasMap, visited);
  }

  bool _resolvesToResultLike(
    String typeName,
    Map<String, String> aliasMap,
    Set<String> visited,
  ) {
    if (!visited.add(typeName)) return false;

    final resolved = aliasMap[typeName];
    if (resolved == null) return false;

    if (_containsResultKeywords(resolved)) return true;

    for (final alias in aliasMap.keys) {
      if (resolved.contains(alias) &&
          _resolvesToResultLike(alias, aliasMap, visited)) {
        return true;
      }
    }

    return false;
  }

  bool _containsResultKeywords(String typeSource) {
    return typeSource.contains('Result<') ||
        typeSource.contains('Either<') ||
        typeSource.contains('Task<') ||
        typeSource.contains('TaskEither<');
  }
}
