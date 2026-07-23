import 'package:analyzer/dart/ast/ast.dart';

/// AST API compatibility shims for analyzer 9-13.
///
/// These helpers keep rule code independent from analyzer AST surface changes
/// while `pubspec.yaml` allows a broad `analyzer: >=9.0.0 <14.0.0` range for
/// analyzer server plugin co-resolution. Re-check this module before widening
/// the analyzer upper bound.
String? formalParameterName(FormalParameter parameter) {
  final base = _baseFormalParameter(parameter);
  final Object? name = _readProperty(base, #name);
  final Object? lexeme = name == null
      ? null
      : _readProperty(name, #lexeme) ?? _readProperty(name, #name);
  return lexeme is String ? lexeme : null;
}

TypeAnnotation? formalParameterType(FormalParameter parameter) {
  final base = _baseFormalParameter(parameter);
  final Object? type = _readProperty(base, #type);
  return type is TypeAnnotation ? type : null;
}

String? classDeclarationName(ClassDeclaration declaration) {
  return _identifierName(_readProperty(declaration, #namePart)) ??
      _identifierName(_readProperty(declaration, #name));
}

Iterable<AstNode> classMembers(ClassDeclaration declaration) {
  return _membersFrom(declaration);
}

Iterable<AstNode> extensionMembers(ExtensionDeclaration declaration) {
  return _membersFrom(declaration);
}

bool isNamedBooleanArgument(
  AstNode argument, {
  required String name,
  required bool value,
}) {
  // The named-argument AST shape differs across analyzer majors:
  //   * analyzer <=12: NamedExpression -> name is a Label
  //     (Label.label.name), value via `expression`.
  //   * analyzer 13+:  NamedArgument   -> name is a Token (Token.lexeme),
  //     value via `argumentExpression`.
  // Read both shapes via guarded dynamic access on the typed node, which is
  // robust to comments/whitespace (e.g. `keepAlive: /* on */ true`) unlike
  // parsing toSource().
  if (_namedArgumentName(argument) != name) return false;
  final expression = _namedArgumentExpression(argument);
  return expression is BooleanLiteral && expression.value == value;
}

String? _namedArgumentName(AstNode argument) {
  final Object? nameNode = _readProperty(argument, #name);
  if (nameNode == null) return null;
  // analyzer 13+: name is a Token (lexeme); analyzer <=12: name is a Label.
  final Object? lexeme = _readProperty(nameNode, #lexeme);
  if (lexeme is String) return lexeme;
  final Object? label = _readProperty(nameNode, #label);
  final Object? labelName = label == null ? null : _readProperty(label, #name);
  return labelName is String ? labelName : null;
}

Expression? _namedArgumentExpression(AstNode argument) {
  // analyzer 13+ uses `argumentExpression`; analyzer <=12 uses `expression`.
  final Object? newShape = _readProperty(argument, #argumentExpression);
  if (newShape is Expression) return newShape;
  final Object? oldShape = _readProperty(argument, #expression);
  return oldShape is Expression ? oldShape : null;
}

Expression? callbackArgumentExpression(AstNode argument) {
  final Object? newShape = _readProperty(argument, #argumentExpression);
  if (newShape is Expression) return newShape;
  return argument is Expression ? argument : null;
}

Object _baseFormalParameter(FormalParameter parameter) {
  return _readProperty(parameter, #parameter) ?? parameter;
}

String? _identifierName(Object? node) {
  if (node == null) return null;
  final Object? lexeme = _readProperty(node, #lexeme);
  if (lexeme is String) return lexeme;
  final Object? typeName = _readProperty(node, #typeName);
  if (typeName != null) return _identifierName(typeName);
  final Object? name = _readProperty(node, #name);
  return name is String ? name : _identifierName(name);
}

Iterable<AstNode> _membersFrom(Object declaration) {
  final Object? directMembers = _readProperty(declaration, #members);
  if (directMembers is Iterable) return directMembers.whereType<AstNode>();

  final Object? body = _readProperty(declaration, #body);
  final Object? bodyMembers = body == null
      ? null
      : _readProperty(body, #members);
  if (bodyMembers is Iterable) return bodyMembers.whereType<AstNode>();

  return const <AstNode>[];
}

Object? _readProperty(Object target, Symbol getter) {
  try {
    final dynamic receiver = target;
    if (getter == #parameter) return receiver.parameter;
    if (getter == #name) return receiver.name;
    if (getter == #namePart) return receiver.namePart;
    if (getter == #type) return receiver.type;
    if (getter == #typeName) return receiver.typeName;
    if (getter == #body) return receiver.body;
    if (getter == #members) return receiver.members;
    if (getter == #lexeme) return receiver.lexeme;
    if (getter == #label) return receiver.label;
    if (getter == #argumentExpression) return receiver.argumentExpression;
    if (getter == #expression) return receiver.expression;
    return null;
  } on NoSuchMethodError {
    return null;
  } on UnsupportedError {
    return null;
  }
}
