import 'package:analyzer/dart/ast/ast.dart';

String? formalParameterName(FormalParameter parameter) {
  final base = _baseFormalParameter(parameter);
  final Object? name = _readProperty(base, #name);
  final Object? lexeme = name == null ? null : _readProperty(name, #lexeme);
  return lexeme is String ? lexeme : null;
}

TypeAnnotation? formalParameterType(FormalParameter parameter) {
  final base = _baseFormalParameter(parameter);
  final Object? type = _readProperty(base, #type);
  return type is TypeAnnotation ? type : null;
}

bool isNamedBooleanArgument(
  AstNode argument, {
  required String name,
  required bool value,
}) {
  final source = argument.toSource();
  final colonIndex = source.indexOf(':');
  if (colonIndex <= 0) {
    return false;
  }

  final argumentName = source.substring(0, colonIndex).trim();
  final argumentValue = source.substring(colonIndex + 1).trim();
  return argumentName == name && argumentValue == value.toString();
}

Object _baseFormalParameter(FormalParameter parameter) {
  return _readProperty(parameter, #parameter) ?? parameter;
}

Object? _readProperty(Object target, Symbol getter) {
  try {
    final dynamic receiver = target;
    if (getter == #parameter) return receiver.parameter;
    if (getter == #name) return receiver.name;
    if (getter == #type) return receiver.type;
    if (getter == #lexeme) return receiver.lexeme;
    return null;
  } on NoSuchMethodError {
    return null;
  }
}
