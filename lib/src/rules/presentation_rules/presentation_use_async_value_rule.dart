import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../../compat/analyzer_ast_compat.dart';
import '../../clean_architecture_linter_base.dart';
import '../../utils/riverpod_provider_detector.dart';

class PresentationUseAsyncValueRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'presentation_use_async_value',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.presentation_use_async_value',
  );

  PresentationUseAsyncValueRule()
    : super(
        name: 'presentation_use_async_value',
        description:
            'Requires presentation state errors/loading to use AsyncValue.',
      );

  /// Exact Freezed/state field names (lowercase) that store error state.
  ///
  /// Exact match only. A previous `contains` scan flagged non-error fields
  /// whose names merely embed the word "error" (e.g. `errorBoundaryEnabled`,
  /// `hasErrorPermission`).
  static const errorFieldNames = {
    'error',
    'errormessage',
    'errormsg',
    'errortext',
    'errordescription',
    'failure',
    'failuremessage',
    'exception',
    'exceptionmessage',
    'haserror',
    'iserror',
    'lasterror',
    'lasterrormessage',
  };

  /// Exact Freezed/state field names (lowercase) that store loading state.
  static const loadingFieldNames = {
    'isloading',
    'loading',
    'issubmitting',
    'submitting',
    'isfetching',
    'fetching',
    'isprocessing',
    'processing',
  };

  @override
  bool get canUseParsedResult => true;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _PresentationUseAsyncValueVisitor(this, context);
    registry.addClassDeclaration(this, visitor);
    registry.addCatchClause(this, visitor);
  }
}

class _PresentationUseAsyncValueVisitor extends SimpleAstVisitor<void> {
  _PresentationUseAsyncValueVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  String get _filePath =>
      context.currentUnit?.file.path ?? context.definingUnit.file.path;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (_shouldSkipFile) return;
    if (!_isFreezedState(node)) return;

    _checkForErrorFields(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    if (_shouldSkipFile) return;

    // Class-only ancestor lookup skipped catches inside
    // `extension on FooNotifier` (including part-file helpers).
    if (!_isInNotifierOrProviderScope(node)) return;

    if (_containsRethrow(node.body)) return;

    if (!_mapsExceptionToUiState(node)) {
      rule.reportAtNode(
        node,
        arguments: const [
          'Notifier/Provider catch did not map exception to UI state.',
          'Use AsyncValue.guard(), state = AsyncValue.error(...), '
              'state = AsyncData(...uiEffect...), or UI handling via when(error: ...).',
        ],
      );
    }
  }

  /// Whether [node] sits in a Notifier/Provider class body or an extension on
  /// one of those types.
  bool _isInNotifierOrProviderScope(AstNode node) {
    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode != null) return _isNotifierOrProviderClass(classNode);

    final extensionNode = node.thisOrAncestorOfType<ExtensionDeclaration>();
    if (extensionNode == null) return false;

    return _isNotifierOrProviderExtension(extensionNode);
  }

  bool _isNotifierOrProviderExtension(ExtensionDeclaration node) {
    final extendedType = node.onClause?.extendedType;
    if (extendedType is! NamedType) return false;

    final targetName = extendedType.name.lexeme;
    // Flutter notifiers end in "Notifier" but are not Riverpod state layer.
    // Keep the same exclusions as [isRiverpodNotifierExtension].
    if (riverpodWidgetSuperclasses.contains(targetName) ||
        nonRiverpodNotifierSuperclasses.contains(targetName) ||
        targetName.endsWith('ChangeNotifier') ||
        targetName.endsWith('ValueNotifier')) {
      return false;
    }
    if (targetName.contains('Notifier') || targetName.contains('Provider')) {
      return true;
    }

    final unit = node.thisOrAncestorOfType<CompilationUnit>();
    if (unit == null) return false;

    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration &&
          classDeclarationName(declaration) == targetName) {
        return _isNotifierOrProviderClass(declaration);
      }
    }

    return false;
  }

  bool get _shouldSkipFile {
    return CleanArchitectureUtils.shouldExcludeFile(_filePath) ||
        !CleanArchitectureUtils.isPresentationFile(_filePath);
  }

  bool _isFreezedState(ClassDeclaration node) {
    for (final metadata in node.metadata) {
      final name = metadata.name.name;
      if (name == 'freezed' || name == 'Freezed') {
        return true;
      }
    }
    return false;
  }

  bool _isNotifierOrProviderClass(ClassDeclaration node) {
    final className = classDeclarationName(node) ?? '';
    if (className.contains('Notifier') || className.contains('Provider')) {
      return true;
    }

    for (final metadata in node.metadata) {
      final name = metadata.name.name;
      if (name == 'riverpod' || name == 'Riverpod') {
        return true;
      }
    }

    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superName = extendsClause.superclass.name.lexeme;
      if (superName.contains('Notifier') ||
          superName.contains('Provider') ||
          superName.startsWith('_\$')) {
        return true;
      }
    }

    return false;
  }

  /// Whether the catch body rethrows without local UI mapping.
  bool _containsRethrow(Block block) {
    final finder = _RethrowFinder();
    block.accept(finder);
    return finder.found;
  }

  /// Whether [catchClause] maps the exception into UI-visible state.
  ///
  /// Accepted patterns (AST, not source-string contains):
  /// 1. Classic AsyncValue sinks: `AsyncValue.guard` / `AsyncValue.error` /
  ///    `AsyncError` / `when(error: ...)`.
  /// 2. `state = ...` whose RHS references a catch parameter (exception or
  ///    stackTrace) — covers intentional partial-failure mapping.
  /// 3. `state = ...` whose RHS includes a `uiEffect:` named argument —
  ///    ittae policy keeps list/timer data and surfaces the failure as a
  ///    toast/effect instead of covering the whole tree with AsyncError.
  bool _mapsExceptionToUiState(CatchClause catchClause) {
    final catchParamNames = <String>{
      if (catchClause.exceptionParameter case final param?) param.name.lexeme,
      if (catchClause.stackTraceParameter case final param?) param.name.lexeme,
    };

    final scanner = _CatchUiMappingScanner(catchParamNames: catchParamNames);
    catchClause.body.accept(scanner);
    return scanner.found;
  }

  void _checkForErrorFields(ClassDeclaration node) {
    for (final member in classMembers(node)) {
      if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          final fieldNameLower = fieldName.toLowerCase();

          if (_isErrorField(fieldNameLower)) {
            rule.reportAtNode(
              variable,
              arguments: [
                'State should NOT have error field "$fieldName". Use AsyncValue instead.',
                'Remove error field. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages error states.',
              ],
            );
          }

          if (_isLoadingField(fieldNameLower)) {
            rule.reportAtNode(
              variable,
              arguments: [
                'State should NOT have loading field "$fieldName". Use AsyncValue instead.',
                'Remove loading field. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages loading states.',
              ],
            );
          }
        }
      }

      if (member is ConstructorDeclaration) {
        _checkConstructorParameters(member);
      }
    }
  }

  void _checkConstructorParameters(ConstructorDeclaration constructor) {
    for (final param in constructor.parameters.parameters) {
      String? paramName;
      AstNode? nameNode;

      paramName = formalParameterName(param);
      nameNode = param;

      if (paramName == null) continue;

      final paramNameLower = paramName.toLowerCase();

      if (_isErrorField(paramNameLower)) {
        rule.reportAtNode(
          nameNode,
          arguments: [
            'State should NOT have error parameter "$paramName". Use AsyncValue instead.',
            'Remove error parameter. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages error states.',
          ],
        );
      }

      if (_isLoadingField(paramNameLower)) {
        rule.reportAtNode(
          nameNode,
          arguments: [
            'State should NOT have loading parameter "$paramName". Use AsyncValue instead.',
            'Remove loading parameter. Use AsyncNotifier with AsyncValue.when() pattern. AsyncValue automatically manages loading states.',
          ],
        );
      }
    }
  }

  bool _isErrorField(String fieldNameLower) {
    return PresentationUseAsyncValueRule.errorFieldNames.contains(
      fieldNameLower,
    );
  }

  bool _isLoadingField(String fieldNameLower) {
    return PresentationUseAsyncValueRule.loadingFieldNames.contains(
      fieldNameLower,
    );
  }
}

class _RethrowFinder extends RecursiveAstVisitor<void> {
  var found = false;

  @override
  void visitRethrowExpression(RethrowExpression node) {
    found = true;
  }
}

/// Walks a catch body looking for accepted UI-error mapping patterns.
class _CatchUiMappingScanner extends RecursiveAstVisitor<void> {
  _CatchUiMappingScanner({required this.catchParamNames});

  final Set<String> catchParamNames;
  var found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isAsyncValueErrorApi(node)) {
      found = true;
      return;
    }
    if (_isWhenErrorHandler(node)) {
      found = true;
      return;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'AsyncError' || typeName == 'AsyncValue') {
      // AsyncError(...) / AsyncValue.error(...) as constructor forms.
      final name = node.constructorName.name?.name;
      if (typeName == 'AsyncError' || name == 'error') {
        found = true;
        return;
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (_isStateTarget(node.leftHandSide) &&
        _rhsMapsExceptionToUi(node.rightHandSide)) {
      found = true;
      return;
    }
    super.visitAssignmentExpression(node);
  }

  bool _isAsyncValueErrorApi(MethodInvocation node) {
    final method = node.methodName.name;
    if (method != 'guard' && method != 'error') return false;
    return _isAsyncValueTarget(node.target);
  }

  bool _isAsyncValueTarget(Expression? target) {
    if (target is SimpleIdentifier) {
      return target.name == 'AsyncValue';
    }
    if (target is PrefixedIdentifier) {
      return target.identifier.name == 'AsyncValue';
    }
    return false;
  }

  bool _isWhenErrorHandler(MethodInvocation node) {
    if (node.methodName.name != 'when') return false;
    for (final argument in node.argumentList.arguments) {
      if (namedArgumentName(argument) == 'error') return true;
    }
    return false;
  }

  bool _isStateTarget(Expression target) {
    if (target is SimpleIdentifier) {
      return target.name == 'state';
    }
    if (target is PropertyAccess) {
      return target.propertyName.name == 'state';
    }
    if (target is PrefixedIdentifier) {
      return target.identifier.name == 'state';
    }
    return false;
  }

  /// True when a `state = ...` RHS maps the failure into UI state.
  bool _rhsMapsExceptionToUi(Expression rhs) {
    final probe = _StateAssignmentProbe(catchParamNames: catchParamNames);
    rhs.accept(probe);
    return probe.usesCatchParam || probe.hasUiEffect;
  }
}

/// Collects signals from a `state =` right-hand side only.
class _StateAssignmentProbe extends RecursiveAstVisitor<void> {
  _StateAssignmentProbe({required this.catchParamNames});

  final Set<String> catchParamNames;
  var usesCatchParam = false;
  var hasUiEffect = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (catchParamNames.contains(node.name)) {
      final parent = node.parent;
      // Property/method selectors (.error, Log.error) are not catch-param refs.
      final isSelector =
          (parent is PropertyAccess && identical(parent.propertyName, node)) ||
          (parent is PrefixedIdentifier &&
              identical(parent.identifier, node)) ||
          (parent is MethodInvocation && identical(parent.methodName, node));
      if (!isSelector) {
        usesCatchParam = true;
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    // analyzer 13+: NamedArgument; name Token.lexeme via namedArgumentName.
    // uiEffect: null is a clear, not a failure mapping.
    if (namedArgumentName(node) == 'uiEffect' &&
        node.argumentExpression is! NullLiteral) {
      hasUiEffect = true;
    }
    super.visitNamedArgument(node);
  }
}
