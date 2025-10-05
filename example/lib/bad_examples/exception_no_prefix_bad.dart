// ignore_for_file: unused_element

// ❌ BAD: Domain exceptions without feature prefix
// This will trigger: exception_naming_convention

// ❌ Missing feature prefix
class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
}

// ❌ Missing feature prefix
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
}

// ❌ Missing feature prefix
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
}

// ❌ Generic exception
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}
