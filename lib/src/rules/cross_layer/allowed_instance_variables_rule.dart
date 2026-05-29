import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../clean_architecture_linter_base.dart';

/// Validates instance variables in UseCase, Repository, and DataSource classes.
///
/// The class/type detection, immutable-field requirement, Mock/Fake allowance,
/// and infrastructure SDK exceptions are copied from the v1 custom-lint rule.
class AllowedInstanceVariablesRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'allowed_instance_variables',
    'Invalid instance variable detected.',
    correctionMessage:
        'Use correct dependencies per layer and ensure fields are final/const.',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.allowed_instance_variables',
  );

  AllowedInstanceVariablesRule()
    : super(
        name: 'allowed_instance_variables',
        description:
            'Validates allowed instance variables for Clean Architecture classes.',
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
      _AllowedInstanceVariablesVisitor(this, context),
    );
  }
}

class _AllowedInstanceVariablesVisitor extends SimpleAstVisitor<void> {
  _AllowedInstanceVariablesVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final filePath =
        context.currentUnit?.file.path ?? context.definingUnit.file.path;

    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) return;

    final className = node.name.lexeme;
    final isUseCase = CleanArchitectureUtils.isUseCaseClass(className);
    final isRepository = CleanArchitectureUtils.isRepositoryImplClass(
      className,
    );
    final isDataSource =
        CleanArchitectureUtils.isDataSourceClass(className) &&
        node.abstractKeyword == null;

    if (!isUseCase && !isRepository && !isDataSource) return;

    for (final member in node.members) {
      if (member is! FieldDeclaration) continue;

      final isImmutable = member.fields.isFinal || member.fields.isConst;

      for (final variable in member.fields.variables) {
        final fieldType = member.fields.type;

        if (fieldType is NamedType) {
          final typeName = fieldType.name.lexeme;

          if (isUseCase) {
            _validateUseCaseField(variable, typeName, isImmutable);
          } else if (isRepository) {
            _validateRepositoryField(variable, typeName, isImmutable);
          } else if (isDataSource) {
            _validateDataSourceField(
              variable,
              typeName,
              isImmutable,
              className,
            );
          }
        } else if (!isImmutable) {
          rule.reportAtNode(variable);
        }
      }
    }
  }

  void _validateUseCaseField(
    VariableDeclaration variable,
    String typeName,
    bool isImmutable,
  ) {
    final hasDataSourceDependency =
        typeName.endsWith('DataSource') || typeName.endsWith('Datasource');
    final hasRepositoryDependency = typeName.endsWith('Repository');
    final hasServiceDependency = typeName.endsWith('Service');

    if (!isImmutable ||
        (!hasRepositoryDependency && !hasServiceDependency) ||
        hasDataSourceDependency) {
      rule.reportAtNode(variable);
    }
  }

  void _validateRepositoryField(
    VariableDeclaration variable,
    String typeName,
    bool isImmutable,
  ) {
    final hasUseCaseDependency =
        typeName.endsWith('UseCase') || typeName.endsWith('Usecase');
    final hasDataSourceDependency =
        typeName.endsWith('DataSource') || typeName.endsWith('Datasource');
    final isPrimitiveOrInfra = _isPrimitiveOrInfrastructureType(typeName);

    if (!isImmutable ||
        (!hasDataSourceDependency && !isPrimitiveOrInfra) ||
        hasUseCaseDependency) {
      rule.reportAtNode(variable);
    }
  }

  void _validateDataSourceField(
    VariableDeclaration variable,
    String typeName,
    bool isImmutable,
    String className,
  ) {
    final isDisallowed = _isDisallowedDataSourceDependency(typeName);
    final isMockOrFake =
        className.startsWith('Mock') || className.startsWith('Fake');
    final isInfrastructureType = _isPrimitiveOrInfrastructureType(typeName);

    if ((!isImmutable && !isMockOrFake && !isInfrastructureType) ||
        (isImmutable && isDisallowed)) {
      rule.reportAtNode(variable);
    }
  }

  bool _isPrimitiveOrInfrastructureType(String typeName) {
    const primitives = {
      'String',
      'int',
      'double',
      'bool',
      'num',
      'List',
      'Map',
      'Set',
      'Iterable',
    };

    if (primitives.contains(typeName)) return true;

    const infrastructurePatterns = [
      'Stream',
      'Future',
      'Completer',
      'Sink',
      'Subscription',
      'Dio',
      'Client',
      'Firebase',
      'Firestore',
      'Database',
      'Cache',
      'Storage',
      'Messaging',
      'Http',
      'BannerAd',
      'InterstitialAd',
      'RewardedAd',
      'NativeAd',
      'AppOpenAd',
      'AdWidget',
      'InAppPurchase',
      'ProductDetails',
      'PurchaseDetails',
    ];

    return infrastructurePatterns.any(typeName.contains);
  }

  bool _isDisallowedDataSourceDependency(String typeName) {
    if (_isPrimitiveOrInfrastructureType(typeName)) {
      return false;
    }

    if (typeName.endsWith('UseCase') ||
        typeName.endsWith('Usecase') ||
        typeName.endsWith('Repository') ||
        typeName.endsWith('Entity') ||
        typeName.endsWith('DataSource') ||
        typeName.endsWith('Datasource')) {
      return true;
    }

    if (typeName.endsWith('Service') ||
        typeName.endsWith('Manager') ||
        typeName.endsWith('Controller')) {
      return true;
    }

    return false;
  }
}
