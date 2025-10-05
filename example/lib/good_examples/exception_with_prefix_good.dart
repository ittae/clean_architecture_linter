// ignore_for_file: unused_element

// ✅ GOOD: Domain exceptions with feature prefix

// ✅ Todo feature exceptions
class TodoNotFoundException implements Exception {
  final String message;
  TodoNotFoundException(this.message);
}

class TodoValidationException implements Exception {
  final String message;
  TodoValidationException(this.message);
}

// ✅ User feature exceptions
class UserNotFoundException implements Exception {
  final String message;
  UserNotFoundException(this.message);
}

class UserUnauthorizedException implements Exception {
  final String message;
  UserUnauthorizedException(this.message);
}

// ✅ Order feature exceptions
class OrderNetworkException implements Exception {
  final String message;
  OrderNetworkException(this.message);
}
