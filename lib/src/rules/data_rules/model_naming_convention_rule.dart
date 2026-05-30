import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Enforces Model naming convention independent from DataSource details.
class ModelNamingConventionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'model_naming_convention',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.model_naming_convention',
  );

  ModelNamingConventionRule()
    : super(
        name: 'model_naming_convention',
        description:
            'Prevents model names from exposing DataSource implementation details.',
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
    registry.addClassDeclaration(
      this,
      _ModelNamingConventionVisitor(this, context),
    );
  }
}

class _ModelNamingConventionVisitor extends SimpleAstVisitor<void> {
  _ModelNamingConventionVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  static const _forbiddenKeywords = [
    'firestore',
    'firebase',
    'supabase',
    'aws',
    'dynamodb',
    's3',
    'lambda',
    'postgres',
    'postgresql',
    'mysql',
    'sqlite',
    'mssql',
    'oracle',
    'rest',
    'restful',
    'api',
    'http',
    'dio',
    'graphql',
    'grpc',
    'hive',
    'isar',
    'drift',
    'sqflite',
    'objectbox',
    'realm',
    'moor',
    'cache',
    'redis',
    'memcached',
    'sharedprefs',
    'preferences',
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

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final filePath = _filePath;
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    if (!CleanArchitectureUtils.isDataFile(filePath)) return;

    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    if (!normalizedPath.contains('/models/')) return;

    final className = node.name.lexeme;
    if (!className.endsWith('Model')) return;

    final lowerClassName = className.toLowerCase();
    for (final keyword in _forbiddenKeywords) {
      if (!lowerClassName.contains(keyword)) continue;

      final suggestedName = _suggestCleanName(className, keyword);
      rule.reportAtNode(
        node,
        arguments: [
          'Model name "$className" should not include DataSource implementation "$keyword". This violates implementation independence.',
          'Rename to "$suggestedName". Models should be independent of DataSource implementation.',
        ],
      );
      return;
    }
  }

  String _suggestCleanName(String className, String keyword) {
    final lowerClassName = className.toLowerCase();
    final keywordIndex = lowerClassName.indexOf(keyword);
    if (keywordIndex == -1) return className;

    final before = className.substring(0, keywordIndex);
    final after = className.substring(keywordIndex + keyword.length);
    final cleanName = before + after;

    if (cleanName.isEmpty || cleanName == 'Model') {
      return 'EntityModel';
    }

    return cleanName;
  }
}
