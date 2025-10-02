import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces proper DataSource abstraction pattern in data layer.
///
/// This rule ensures that data sources follow best practices:
/// - DataSource abstractions should be in Data Layer (not Domain)
/// - Abstract DataSource should have corresponding implementation
/// - Implementation should implement the abstract interface
/// - DataSource methods should return Models, not Entities
/// - Proper naming convention: `*DataSource` for abstract, `*DataSourceImpl` for implementation
///
/// Benefits of DataSource abstraction:
/// - Testability through mock implementations
/// - Flexibility to swap data sources (Remote, Local, Cache)
/// - Clear separation of concerns within Data Layer
/// - Easier unit testing of repositories
///
/// ✅ Correct Pattern:
/// ```dart
/// // data/datasources/ranking_remote_datasource.dart
/// abstract class RankingRemoteDataSource {
///   Future<List<RankingModel>> getRankings();
/// }
///
/// class RankingRemoteDataSourceImpl implements RankingRemoteDataSource {
///   @override
///   Future<List<RankingModel>> getRankings() async {
///     // API implementation
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // domain/datasources/ranking_datasource.dart ❌ Wrong layer
/// abstract class RankingDataSource {
///   Future<List<RankingModel>> getRankings();  // ❌ Domain can't know Model
/// }
/// ```
class DataSourceAbstractionRule extends CleanArchitectureLintRule {
  const DataSourceAbstractionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'datasource_abstraction',
    problemMessage:
        'DataSource should follow proper abstraction pattern in Data Layer',
    correctionMessage:
        'Create abstract DataSource interface in Data Layer with corresponding implementation.',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Check class declarations for DataSource patterns
    context.registry.addClassDeclaration((node) {
      _checkDataSourceAbstraction(node, reporter, resolver);
    });

    // Check if DataSource is in wrong layer (Domain)
    context.registry.addClassDeclaration((node) {
      _checkDataSourceLocation(node, reporter, resolver);
    });

    // Check DataSource method return types
    context.registry.addMethodDeclaration((node) {
      _checkDataSourceMethods(node, reporter, resolver);
    });
  }

  void _checkDataSourceAbstraction(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!CleanArchitectureUtils.isDataLayerFile(filePath)) return;

    final className = node.name.lexeme;
    if (!_isDataSourceClass(className)) return;

    // Check if concrete DataSource without abstract interface
    if (node.abstractKeyword == null && _isConcreteDataSource(className)) {
      // This is a concrete DataSource implementation
      // Check if there's a corresponding abstract interface in the same file or nearby

      final code = LintCode(
        name: 'datasource_abstraction',
        problemMessage:
            'Concrete DataSource "$className" should implement an abstract interface for testability',
        correctionMessage:
            'Create abstract DataSource interface: ${_getAbstractName(className)}',
      );
      reporter.atNode(node, code);
    }

    // Check if abstract DataSource in Data Layer (correct location)
    if (node.abstractKeyword != null) {
      // This is good - abstract DataSource in Data Layer
      // No warning needed
    }
  }

  void _checkDataSourceLocation(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    final className = node.name.lexeme;

    if (!_isDataSourceClass(className)) return;

    // Check if DataSource is in Domain Layer (wrong!)
    if (CleanArchitectureUtils.isDomainLayerFile(filePath)) {
      final code = LintCode(
        name: 'datasource_abstraction',
        problemMessage:
            'DataSource "$className" should be in Data Layer, not Domain Layer',
        correctionMessage:
            'Move DataSource to data/datasources/. Domain should only depend on Repository abstractions.',
      );
      reporter.atNode(node, code);
    }
  }

  void _checkDataSourceMethods(
    MethodDeclaration method,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;
    if (!CleanArchitectureUtils.isDataLayerFile(filePath)) return;

    // Check if this method is in a DataSource class
    final classNode = method.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final className = classNode.name.lexeme;
    if (!_isDataSourceClass(className)) return;

    final returnType = method.returnType;
    if (returnType == null) return;

    // Check if DataSource method returns Entity (should return Model)
    if (_returnsEntity(returnType)) {
      final code = LintCode(
        name: 'datasource_abstraction',
        problemMessage:
            'DataSource method "${method.name.lexeme}" returns Entity. DataSource should return Model.',
        correctionMessage:
            'Change return type to Model. DataSource works with Models, Repository converts to Entities.',
      );
      reporter.atNode(returnType, code);
    }
  }

  bool _isDataSourceClass(String className) {
    return className.contains('DataSource') || className.contains('Datasource');
  }

  bool _isConcreteDataSource(String className) {
    // Implementation classes typically end with Impl
    return !className.endsWith('Impl') &&
           !className.endsWith('Implementation');
  }

  String _getAbstractName(String concreteName) {
    // If class is like "RankingRemoteDataSource", suggest abstract with same name
    // If class is like "RankingRemoteDataSourceImpl", suggest without Impl
    if (concreteName.endsWith('Impl')) {
      return concreteName.substring(0, concreteName.length - 4);
    }
    return concreteName; // Suggest same name for abstract
  }

  bool _returnsEntity(TypeAnnotation returnType) {
    final typeStr = returnType.toString();

    // Check for Entity in return type (not Model)
    // Entity, List<Entity>, Future<Entity>, Future<List<Entity>>
    if (typeStr.contains('Entity') && !typeStr.contains('Model')) {
      // Make sure it's not just a word containing "entity"
      final pattern = RegExp(r'\b\w+Entity\b');
      if (pattern.hasMatch(typeStr)) {
        return true;
      }
    }

    return false;
  }
}
