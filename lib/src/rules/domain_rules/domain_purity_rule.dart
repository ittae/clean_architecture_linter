import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class DomainPurityRule extends DartLintRule {
  const DomainPurityRule() : super(code: _code);

  static const _code = LintCode(
    name: 'domain_purity',
    problemMessage: 'Domain layer should not depend on external frameworks or UI libraries.',
    correctionMessage: 'Remove dependencies on Flutter, HTTP clients, or other external frameworks from domain layer.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      _checkImportPurity(node, reporter, resolver);
    });
  }

  void _checkImportPurity(
    ImportDirective node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    final filePath = resolver.path;

    // Only check files in domain layer
    if (!_isDomainLayerFile(filePath)) return;

    final importUri = node.uri.stringValue;
    if (importUri == null) return;

    // List of forbidden imports for domain layer
    final forbiddenPrefixes = [
      'package:flutter/',
      'package:http/',
      'package:dio/',
      'dart:io',
      'dart:html',
      'package:shared_preferences/',
      'package:sqflite/',
      'package:path_provider/',
      'package:cloud_firestore/',
    ];

    for (final prefix in forbiddenPrefixes) {
      if (importUri.startsWith(prefix)) {
        reporter.atNode(node, _code);
        break;
      }
    }
  }

  bool _isDomainLayerFile(String filePath) {
    return filePath.contains('/domain/') ||
           filePath.contains('\\domain\\');
  }
}