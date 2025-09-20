import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Configuration for Clean Architecture Linter
///
/// Allows customization of layer paths and rule severity levels
/// for different project structures.
class CleanArchitectureConfig {
  final LayerPaths layerPaths;
  final Map<String, RuleSeverity> ruleSeverities;
  final bool enableAllRules;

  const CleanArchitectureConfig({
    this.layerPaths = const LayerPaths(),
    this.ruleSeverities = const {},
    this.enableAllRules = true,
  });

  /// Creates config from analysis_options.yaml
  factory CleanArchitectureConfig.fromOptions(CustomLintConfigs configs) {
    // For now, return default config
    // Full configuration support requires parsing analysis_options.yaml
    return const CleanArchitectureConfig();
  }


  /// Gets the severity for a specific rule
  RuleSeverity getSeverityForRule(String ruleName) {
    return ruleSeverities[ruleName] ?? RuleSeverity.warning;
  }

  /// Checks if a rule is enabled
  bool isRuleEnabled(String ruleName) {
    if (!enableAllRules) {
      return ruleSeverities.containsKey(ruleName) &&
             ruleSeverities[ruleName] != RuleSeverity.none;
    }
    return ruleSeverities[ruleName] != RuleSeverity.none;
  }
}

/// Custom layer paths configuration
class LayerPaths {
  final List<String> domainPaths;
  final List<String> dataPaths;
  final List<String> presentationPaths;
  final List<String> entityPaths;
  final List<String> useCasePaths;
  final List<String> repositoryPaths;
  final List<String> dataSourcePaths;

  const LayerPaths({
    this.domainPaths = const ['/domain/', '/core/domain/'],
    this.dataPaths = const ['/data/', '/infrastructure/'],
    this.presentationPaths = const ['/presentation/', '/ui/', '/features/'],
    this.entityPaths = const ['/entities/', '/models/entities/'],
    this.useCasePaths = const ['/usecases/', '/use_cases/'],
    this.repositoryPaths = const ['/repositories/'],
    this.dataSourcePaths = const ['/datasources/', '/data_sources/'],
  });

  factory LayerPaths.fromJson(Map<dynamic, dynamic> json) {
    return LayerPaths(
      domainPaths: _parseStringList(json['domain_paths']) ??
                    const ['/domain/', '/core/domain/'],
      dataPaths: _parseStringList(json['data_paths']) ??
                 const ['/data/', '/infrastructure/'],
      presentationPaths: _parseStringList(json['presentation_paths']) ??
                        const ['/presentation/', '/ui/', '/features/'],
      entityPaths: _parseStringList(json['entity_paths']) ??
                   const ['/entities/', '/models/entities/'],
      useCasePaths: _parseStringList(json['usecase_paths']) ??
                    const ['/usecases/', '/use_cases/'],
      repositoryPaths: _parseStringList(json['repository_paths']) ??
                       const ['/repositories/'],
      dataSourcePaths: _parseStringList(json['datasource_paths']) ??
                       const ['/datasources/', '/data_sources/'],
    );
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return null;
  }

  /// Check if a file path belongs to domain layer
  bool isDomainLayer(String filePath) {
    return domainPaths.any((path) =>
      filePath.contains(path) || filePath.contains(path.replaceAll('/', '\\')));
  }

  /// Check if a file path belongs to data layer
  bool isDataLayer(String filePath) {
    return dataPaths.any((path) =>
      filePath.contains(path) || filePath.contains(path.replaceAll('/', '\\')));
  }

  /// Check if a file path belongs to presentation layer
  bool isPresentationLayer(String filePath) {
    return presentationPaths.any((path) =>
      filePath.contains(path) || filePath.contains(path.replaceAll('/', '\\')));
  }

  /// Check if a file is an entity
  bool isEntityFile(String filePath) {
    if (!isDomainLayer(filePath)) return false;
    return entityPaths.any((path) =>
      filePath.contains(path) || filePath.contains(path.replaceAll('/', '\\'))) ||
      filePath.endsWith('_entity.dart') ||
      filePath.endsWith('entity.dart');
  }

  /// Check if a file is a use case
  bool isUseCaseFile(String filePath) {
    if (!isDomainLayer(filePath)) return false;
    return useCasePaths.any((path) =>
      filePath.contains(path) || filePath.contains(path.replaceAll('/', '\\'))) ||
      filePath.endsWith('_usecase.dart') ||
      filePath.endsWith('_use_case.dart');
  }

  /// Check if a file is a repository
  bool isRepositoryFile(String filePath, {bool implementation = false}) {
    final inRepoPath = repositoryPaths.any((path) =>
      filePath.contains(path) || filePath.contains(path.replaceAll('/', '\\')));

    if (implementation) {
      return isDataLayer(filePath) && inRepoPath;
    }
    return isDomainLayer(filePath) && inRepoPath;
  }

  /// Check if a file is a data source
  bool isDataSourceFile(String filePath) {
    if (!isDataLayer(filePath)) return false;
    return dataSourcePaths.any((path) =>
      filePath.contains(path) || filePath.contains(path.replaceAll('/', '\\'))) ||
      filePath.contains('datasource') ||
      filePath.contains('data_source');
  }
}

/// Rule severity levels
enum RuleSeverity {
  none,
  info,
  warning,
  error;

  static RuleSeverity fromString(String value) {
    switch (value.toLowerCase()) {
      case 'none':
      case 'disabled':
        return RuleSeverity.none;
      case 'info':
      case 'hint':
        return RuleSeverity.info;
      case 'warning':
      case 'warn':
        return RuleSeverity.warning;
      case 'error':
        return RuleSeverity.error;
      default:
        return RuleSeverity.warning;
    }
  }

  /// Convert to LintCode problem message prefix
  String get messagePrefix {
    switch (this) {
      case RuleSeverity.error:
        return '[ERROR] ';
      case RuleSeverity.warning:
        return '[WARNING] ';
      case RuleSeverity.info:
        return '[INFO] ';
      case RuleSeverity.none:
        return '';
    }
  }
}

/// Mixin to add configuration support to lint rules
mixin ConfigurableLintRule on DartLintRule {
  CleanArchitectureConfig? _config;

  CleanArchitectureConfig get config {
    _config ??= const CleanArchitectureConfig();
    return _config!;
  }

  void initializeConfig(CustomLintConfigs configs) {
    _config = CleanArchitectureConfig.fromOptions(configs);
  }

  /// Check if the current rule is enabled
  bool get isRuleEnabled => config.isRuleEnabled(code.name);

  /// Get severity for the current rule
  RuleSeverity get severity => config.getSeverityForRule(code.name);

  /// Get layer paths configuration
  LayerPaths get layerPaths => config.layerPaths;
}