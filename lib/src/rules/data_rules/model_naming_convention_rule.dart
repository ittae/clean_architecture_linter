import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces Model naming convention: Models should not include DataSource implementation details.
///
/// In Clean Architecture, Models serve as an abstraction layer between DataSources and Entities.
/// Model names should remain independent of the underlying DataSource implementation
/// (Firestore, AWS, Supabase, REST API, etc.) to maintain implementation independence.
///
/// **Core Principle**: "Independence from implementation details"
/// - Model should be named after the Entity it represents
/// - Model should not expose which DataSource implementation is used
/// - This allows DataSource swapping without changing Model
///
/// ✅ Correct Pattern:
/// ```dart
/// // data/models/todo_model.dart
/// @freezed
/// class TodoModel with _$TodoModel {
///   const factory TodoModel({
///     required String id,
///     required String title,
///     required bool isCompleted,
///     required Todo entity,
///   }) = _TodoModel;
/// }
///
/// // data/datasources/todo_firestore_datasource.dart
/// class TodoFirestoreDataSource implements TodoRemoteDataSource {
///   Future<TodoModel> getTodo(String id) async {
///     final doc = await firestore.collection('todos').doc(id).get();
///     return TodoModel.fromJson(doc.data()!);  // ✅ Returns generic Model
///   }
/// }
///
/// // data/datasources/todo_supabase_datasource.dart
/// class TodoSupabaseDataSource implements TodoRemoteDataSource {
///   Future<TodoModel> getTodo(String id) async {
///     final data = await supabase.from('todos').select().eq('id', id).single();
///     return TodoModel.fromJson(data);  // ✅ Same Model, different source
///   }
/// }
/// ```
///
/// ❌ Wrong Pattern:
/// ```dart
/// // ❌ Model name exposes DataSource implementation
/// class TodoFirestoreModel { }
/// class TodoAwsModel { }
/// class TodoSupabaseModel { }
/// class TodoRestModel { }
/// class TodoGraphqlModel { }
///
/// // This violates Clean Architecture because:
/// // 1. Repository becomes dependent on DataSource implementation
/// // 2. Changing DataSource requires changing Model name
/// // 3. Implementation details leak into the architecture
/// ```
///
/// **Forbidden Suffixes** (DataSource implementations):
/// - Firestore, Firebase
/// - AWS, DynamoDB, S3
/// - Supabase, PostgreSQL, MySQL
/// - REST, API, Http, Dio
/// - GraphQL, gRPC
/// - Hive, Isar, Drift, SQLite
/// - Redis, Memcached
/// - And more...
///
/// See CLEAN_ARCHITECTURE_GUIDE.md for complete Model patterns.
class ModelNamingConventionRule extends CleanArchitectureLintRule {
  const ModelNamingConventionRule() : super(code: _code);

  static const _code = LintCode(
    name: 'model_naming_convention',
    problemMessage:
        'Model name should not include DataSource implementation details. '
        'Use entity-based naming instead.',
    correctionMessage: 'Remove DataSource implementation from Model name:\n'
        '  ❌ Bad:  class TodoFirestoreModel\n'
        '  ✅ Good: class TodoModel\n\n'
        'Models should be independent of DataSource implementation.',
  );

  /// Known DataSource implementation keywords that should not appear in Model names
  static const _forbiddenKeywords = [
    // Cloud Databases
    'firestore',
    'firebase',
    'supabase',

    // AWS Services
    'aws',
    'dynamodb',
    's3',
    'lambda',

    // SQL Databases
    'postgres',
    'postgresql',
    'mysql',
    'sqlite',
    'mssql',
    'oracle',

    // APIs
    'rest',
    'restful',
    'api',
    'http',
    'dio',
    'graphql',
    'grpc',

    // Local Storage
    'hive',
    'isar',
    'drift',
    'sqflite',
    'objectbox',
    'realm',
    'moor',

    // Cache
    'cache',
    'redis',
    'memcached',
    'sharedprefs',
    'preferences',

    // Other
    'remote',
    'local',
    'cloud',
    'server',
    'client',
    'network',
    'storage',
    'database',
    'db',
  ];

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      _checkModelNaming(node, reporter, resolver);
    });
  }

  void _checkModelNaming(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check Data layer files
    if (!CleanArchitectureUtils.isDataFile(filePath)) return;

    // Only check /models/ directory
    if (!filePath.contains('/models/')) return;

    final className = node.name.lexeme;

    // Only check classes that end with "Model"
    if (!className.endsWith('Model')) return;

    // Check if class name contains forbidden keywords
    final lowerClassName = className.toLowerCase();

    for (final keyword in _forbiddenKeywords) {
      if (lowerClassName.contains(keyword)) {
        // Extract the clean name suggestion
        final suggestedName = _suggestCleanName(className, keyword);

        final code = LintCode(
          name: 'model_naming_convention',
          problemMessage:
              'Model name "$className" should not include DataSource implementation "$keyword". '
              'This violates implementation independence.',
          correctionMessage:
              'Remove DataSource implementation from Model name:\n'
              '  ❌ Current:  class $className\n'
              '  ✅ Suggested: class $suggestedName\n\n'
              'Models should be independent of DataSource implementation.\n'
              'This allows swapping DataSources (e.g., Firestore → Supabase) without changing Models.\n\n'
              'Pattern: {Entity}Model\n'
              'Examples: TodoModel, UserModel, OrderModel\n\n'
              'See CLEAN_ARCHITECTURE_GUIDE.md for Model naming conventions.',
        );

        reporter.atNode(node, code);
        return; // Report only the first violation
      }
    }
  }

  /// Suggests a clean Model name by removing DataSource implementation keywords
  String _suggestCleanName(String className, String keyword) {
    final lowerClassName = className.toLowerCase();

    // Find the position of the keyword
    final keywordIndex = lowerClassName.indexOf(keyword);
    if (keywordIndex == -1) return className;

    // Remove the keyword (case-insensitive)
    final before = className.substring(0, keywordIndex);
    final after = className.substring(keywordIndex + keyword.length);

    final cleanName = before + after;

    // If result is empty or just "Model", suggest based on file name
    if (cleanName.isEmpty || cleanName == 'Model') {
      return 'EntityModel'; // Generic suggestion
    }

    return cleanName;
  }
}
