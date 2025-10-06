// Bad examples that will be flagged by Clean Architecture Linter
import 'package:freezed_annotation/freezed_annotation.dart';

part 'domain_bad_examples.freezed.dart';

// ❌ Domain Purity Violation - importing external frameworks
// import 'package:http/http.dart' as http; // This will be flagged
// import 'package:flutter/material.dart'; // This will be flagged

// These imports are commented out for example purposes, but would be flagged:

// ❌ Anemic Entity (no business logic methods)
class AnemicProduct {
  final String id;
  final String name;
  final double price;

  const AnemicProduct({
    required this.id,
    required this.name,
    required this.price,
  });
  // ❌ No business logic methods - just data fields
}

// ❌ Entity Immutability Violation
class BadUserEntity {
  String name; // Non-final field - will be flagged
  final String email;

  BadUserEntity({required this.name, required this.email});

  // ❌ Setter in entity - will be flagged
  void setName(String newName) {
    name = newName;
  }
}

// ❌ Mock implementation for example purposes
class BadUserRepositoryImpl {
  Future<BadUserEntity?> getUser(String id) async => null;
}

class BadUserService {
  // ❌ Depending on concrete data layer class - will be flagged
  final BadUserRepositoryImpl repository;

  BadUserService(this.repository);
}

// ❌ UseCase Single Responsibility Violation
class BadUserUseCase {
  final UserRepository repository;

  BadUserUseCase(this.repository);

  Future<BadUserEntity?> call(String userId) {
    return getUserById(userId);
  }

  // ❌ Extra public methods violate single responsibility - will be flagged
  Future<BadUserEntity?> getUserById(String userId) async {
    // Implementation
    return null;
  }

  // ❌ Another extra method - will be flagged
  Future<List<BadUserEntity>> getAllUsers() async {
    return [];
  }

  // ❌ Yet another method - will be flagged
  void validateUser(BadUserEntity user) {
    // Validation logic
  }
}

// ❌ Dependency Inversion Violation
class BadUserBusinessLogic {
  // ❌ Depending on concrete implementation - will be flagged
  final BadUserRepositoryImpl repository;
  // ❌ Depending on external framework type - will be flagged
  // final http.Client httpClient; // Would be flagged if uncommented

  BadUserBusinessLogic(this.repository);
}

abstract class UserRepository {
  Future<BadUserEntity?> getUserById(String id);
}

// ❌ Freezed Entity without Extension (no business logic)
@freezed
class FreezedTodo with _$FreezedTodo {
  const factory FreezedTodo({
    required String id,
    required String title,
    required bool isCompleted,
  }) = _FreezedTodo;
  // ❌ Missing extension with business logic
}

// ❌ Anemic Entity with only getters
class CustomerEntity {
  final String id;
  final String name;
  final String email;

  const CustomerEntity({
    required this.id,
    required this.name,
    required this.email,
  });

  // ❌ Only simple getters, no business logic
  String get displayName => name;
  String get contactEmail => email;
}

// ❌ Entity with mutable fields and setters
class MutableOrder {
  String status; // ❌ Non-final field
  final String id;
  final List<String> items;

  MutableOrder({
    required this.status,
    required this.id,
    required this.items,
  });

  // ❌ Setter method violates immutability
  void updateStatus(String newStatus) {
    status = newStatus;
  }

  // ❌ Mutating method
  void addItem(String item) {
    items.add(item);
  }
}
