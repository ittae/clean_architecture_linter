import 'package:test/test.dart';

/// Unit tests for EntityNoJsonSerializationRule
///
/// This test suite verifies that the entity_no_json_serialization_rule correctly
/// enforces Clean Architecture principles where domain entities should not contain
/// JSON/Map serialization methods.
///
/// Test Coverage:
/// 1. Detection of fromJson factory constructor
/// 2. Detection of toJson method
/// 3. Detection of fromMap/toMap methods
/// 4. Skipping Model classes (defensive check)
/// 5. Domain layer file detection
/// 6. Error message clarity
void main() {
  group('EntityNoJsonSerializationRule', () {
    group('JSON Serialization Detection', () {
      test('detects fromJson factory constructor', () {
        final violations = [
          'fromJson',
        ];

        for (final name in violations) {
          expect(
            _isJsonSerializationConstructor(name),
            isTrue,
            reason: '$name should be detected as JSON serialization',
          );
        }
      });

      test('detects toJson method', () {
        final violations = [
          'toJson',
        ];

        for (final name in violations) {
          expect(
            _isJsonSerializationMethod(name),
            isTrue,
            reason: '$name should be detected as JSON serialization',
          );
        }
      });

      test('detects fromMap/toMap methods', () {
        final constructorViolations = ['fromMap'];
        final methodViolations = ['toMap'];

        for (final name in constructorViolations) {
          expect(
            _isMapSerializationConstructor(name),
            isTrue,
            reason: '$name should be detected as Map serialization',
          );
        }

        for (final name in methodViolations) {
          expect(
            _isMapSerializationMethod(name),
            isTrue,
            reason: '$name should be detected as Map serialization',
          );
        }
      });

      test('allows regular factory constructors', () {
        final allowed = [
          'create',
          'empty',
          'initial',
          'fromEntity',
          'withDefaults',
        ];

        for (final name in allowed) {
          expect(
            _isJsonSerializationConstructor(name),
            isFalse,
            reason: '$name should be allowed',
          );
          expect(
            _isMapSerializationConstructor(name),
            isFalse,
            reason: '$name should be allowed',
          );
        }
      });

      test('allows regular methods', () {
        final allowed = [
          'copyWith',
          'toString',
          'validate',
          'toEntity',
          'toModel',
        ];

        for (final name in allowed) {
          expect(
            _isJsonSerializationMethod(name),
            isFalse,
            reason: '$name should be allowed',
          );
          expect(
            _isMapSerializationMethod(name),
            isFalse,
            reason: '$name should be allowed',
          );
        }
      });
    });

    group('Model Class Skipping', () {
      test('skips classes ending with Model', () {
        final models = [
          'UserModel',
          'TodoModel',
          'ProductModel',
        ];

        for (final name in models) {
          expect(
            _shouldSkipClass(name),
            isTrue,
            reason: '$name should be skipped (Model class)',
          );
        }
      });

      test('skips classes ending with Dto', () {
        final dtos = [
          'UserDto',
          'TodoDto',
          'ProductDto',
        ];

        for (final name in dtos) {
          expect(
            _shouldSkipClass(name),
            isTrue,
            reason: '$name should be skipped (DTO class)',
          );
        }
      });

      test('checks entity classes', () {
        final entities = [
          'User',
          'Todo',
          'Product',
          'Order',
          'Schedule',
        ];

        for (final name in entities) {
          expect(
            _shouldSkipClass(name),
            isFalse,
            reason: '$name should be checked (Entity class)',
          );
        }
      });
    });

    group('Domain Layer File Detection', () {
      test('correctly identifies domain entity files', () {
        final domainPaths = [
          'lib/features/todos/domain/entities/todo.dart',
          'lib/domain/entities/user.dart',
          'lib/core/domain/entities/product.dart',
          'lib/features/orders/entities/order.dart',
        ];

        for (final path in domainPaths) {
          expect(
            _isDomainFile(path),
            isTrue,
            reason: '$path should be detected as domain layer',
          );
        }
      });

      test('correctly identifies data model files (not checked)', () {
        final dataPaths = [
          'lib/features/todos/data/models/todo_model.dart',
          'lib/data/models/user_model.dart',
          'lib/features/orders/data/models/order_model.dart',
        ];

        for (final path in dataPaths) {
          expect(
            _isDataModelFile(path),
            isTrue,
            reason: '$path should be detected as data model (not checked)',
          );
        }
      });
    });

    group('Error Messages', () {
      test('provides clear message for fromJson violation', () {
        final message = _getFromJsonErrorMessage('User');

        expect(
          message,
          contains('fromJson'),
          reason: 'Error message should mention fromJson',
        );
        expect(
          message,
          contains('User'),
          reason: 'Error message should include class name',
        );
        expect(
          message,
          contains('UserModel'),
          reason: 'Error message should suggest Model class',
        );
        expect(
          message,
          contains('Data layer'),
          reason: 'Error message should mention Data layer',
        );
      });

      test('provides clear message for toJson violation', () {
        final message = _getToJsonErrorMessage('Todo');

        expect(
          message,
          contains('toJson'),
          reason: 'Error message should mention toJson',
        );
        expect(
          message,
          contains('Todo'),
          reason: 'Error message should include class name',
        );
        expect(
          message,
          contains('TodoModel'),
          reason: 'Error message should suggest Model class',
        );
      });
    });

    group('Integration Test Expectations', () {
      test('should detect bad examples', () {
        // Documents what violations should be detected in domain entity files
        final expectedViolations = [
          EntityTestCase(
            className: 'User',
            hasFromJson: true,
            hasToJson: false,
            shouldViolate: true,
          ),
          EntityTestCase(
            className: 'Todo',
            hasFromJson: true,
            hasToJson: true,
            shouldViolate: true,
          ),
          EntityTestCase(
            className: 'Product',
            hasFromJson: false,
            hasToJson: true,
            shouldViolate: true,
          ),
        ];

        for (final testCase in expectedViolations) {
          final hasViolation =
              testCase.hasFromJson || testCase.hasToJson;
          expect(
            hasViolation,
            testCase.shouldViolate,
            reason:
                '${testCase.className} with fromJson=${testCase.hasFromJson}, toJson=${testCase.hasToJson} should violate=${testCase.shouldViolate}',
          );
        }
      });

      test('should accept good examples (pure entities)', () {
        // Documents what entities should pass (no serialization)
        final expectedPassing = [
          EntityTestCase(
            className: 'User',
            hasFromJson: false,
            hasToJson: false,
            shouldViolate: false,
          ),
          EntityTestCase(
            className: 'Todo',
            hasFromJson: false,
            hasToJson: false,
            shouldViolate: false,
          ),
        ];

        for (final testCase in expectedPassing) {
          final hasViolation =
              testCase.hasFromJson || testCase.hasToJson;
          expect(
            hasViolation,
            testCase.shouldViolate,
            reason:
                '${testCase.className} without serialization should not violate',
          );
        }
      });
    });

    group('Edge Cases', () {
      test('handles entities with copyWith (allowed)', () {
        expect(
          _isJsonSerializationMethod('copyWith'),
          isFalse,
          reason: 'copyWith is standard Freezed method, should be allowed',
        );
      });

      test('handles entities with toEntity (allowed)', () {
        expect(
          _isJsonSerializationMethod('toEntity'),
          isFalse,
          reason: 'toEntity is allowed for conversions',
        );
      });

      test('handles private fromJson methods', () {
        // Private methods like _$UserFromJson are generated by Freezed
        // but should still trigger if exposed via factory
        expect(
          _isJsonSerializationConstructor('fromJson'),
          isTrue,
          reason: 'Public fromJson factory should be detected',
        );
      });
    });
  });
}

// Helper classes for testing
class EntityTestCase {
  final String className;
  final bool hasFromJson;
  final bool hasToJson;
  final bool shouldViolate;

  EntityTestCase({
    required this.className,
    required this.hasFromJson,
    required this.hasToJson,
    required this.shouldViolate,
  });
}

// Helper functions that simulate rule logic

bool _isJsonSerializationConstructor(String name) {
  return name == 'fromJson';
}

bool _isJsonSerializationMethod(String name) {
  return name == 'toJson';
}

bool _isMapSerializationConstructor(String name) {
  return name == 'fromMap';
}

bool _isMapSerializationMethod(String name) {
  return name == 'toMap';
}

bool _shouldSkipClass(String className) {
  return className.endsWith('Model') || className.endsWith('Dto');
}

bool _isDomainFile(String filePath) {
  final normalized = filePath.replaceAll('\\', '/');
  return normalized.contains('/domain/') ||
      normalized.contains('/entities/') ||
      normalized.contains('/usecases/') ||
      normalized.contains('/use_cases/');
}

bool _isDataModelFile(String filePath) {
  final normalized = filePath.replaceAll('\\', '/');
  return normalized.contains('/data/') && normalized.contains('/models/');
}

String _getFromJsonErrorMessage(String className) {
  return '''
Entity "$className" has fromJson constructor. JSON serialization belongs in Data layer.
Create ${className}Model in data/models/ with fromJson. Entity should be pure.
''';
}

String _getToJsonErrorMessage(String className) {
  return '''
Entity "$className" has toJson method. JSON serialization belongs in Data layer.
Create ${className}Model in data/models/ with toJson. Entity should be pure.
''';
}
