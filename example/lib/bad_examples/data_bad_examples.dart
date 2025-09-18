// Bad examples for Data Layer that will be flagged

// ❌ DataSource Naming Violation
class BadUserService { // Should end with DataSource - will be flagged
  Future<Map<String, dynamic>> getUser(String id) async {
    return {};
  }
}

class UserApi { // Should end with DataSource - will be flagged
  Future<Map<String, dynamic>> fetchUser(String id) async {
    return {};
  }
}

// ❌ Model Structure Violation - missing serialization methods
class BadUserModel {
  final String id;
  final String name;
  final String email;

  BadUserModel({
    required this.id,
    required this.name,
    required this.email,
  });

  // ❌ Missing fromJson constructor - will be flagged
  // ❌ Missing toJson method - will be flagged
}

// ❌ Another bad model example
class UserDto {
  final String name;
  final String email;

  UserDto({required this.name, required this.email});

  // ❌ Has toJson but missing fromJson - will be flagged
  Map<String, dynamic> toJson() {
    return {'name': name, 'email': email};
  }
}

// ❌ Repository Implementation Violation
class BadUserRepositoryImpl { // Should implement domain interface - will be flagged
  // ❌ No DataSource dependency - will be flagged
  BadUserRepositoryImpl();

  Future<BadUserModel?> getUser(String id) async {
    // Direct implementation without data sources
    return null;
  }
}

// ❌ Another bad repository
class UserRepositoryImpl {
  // ❌ No interface implementation - will be flagged
  // ❌ No DataSource dependencies - will be flagged

  Future<String> getUserName(String id) async {
    // Implementation
    return '';
  }
}