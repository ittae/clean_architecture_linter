/// A focused custom lint package that enforces core Clean Architecture principles in Flutter projects.
///
/// This package provides essential lint rules to ensure proper dependency direction,
/// layer separation, and architectural boundaries following Clean Architecture patterns.
/// Simplified to focus on core principles with minimal false positives.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

// Core Clean Architecture Rules (6 essential rules)
import 'src/rules/layer_dependency_rule.dart';
import 'src/rules/domain_rules/domain_purity_rule.dart';
import 'src/rules/domain_rules/dependency_inversion_rule.dart';
import 'src/rules/domain_rules/repository_interface_rule.dart';
import 'src/rules/circular_dependency_rule.dart';
import 'src/rules/boundary_crossing_rule.dart';

/// Plugin entry point for Clean Architecture Linter.
PluginBase createPlugin() => _CleanArchitectureLinterPlugin();

class _CleanArchitectureLinterPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    // Core Clean Architecture Principles (6 essential rules)

    // 1. Dependency Direction Rule - 의존성 방향 검증
    LayerDependencyRule(),

    // 2. Domain Purity Rule - Domain 레이어 순수성
    DomainPurityRule(),

    // 3. Dependency Inversion Principle - 추상화에 의존
    DependencyInversionRule(),

    // 4. Repository Pattern - Repository 인터페이스 정의
    RepositoryInterfaceRule(),

    // 5. Circular Dependency Prevention - 순환 의존성 방지
    CircularDependencyRule(),

    // 6. Boundary Crossing Validation - 레이어 경계 검증
    BoundaryCrossingRule(),
  ];
}
