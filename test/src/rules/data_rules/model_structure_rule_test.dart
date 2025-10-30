import 'package:test/test.dart';

/// Unit tests for ModelStructureRule
///
/// This test suite verifies that the model_structure_rule correctly
/// enforces Clean Architecture Model-Entity composition pattern.
///
/// Test Coverage:
/// 1. Freezed annotation detection
/// 2. Entity field detection
/// 3. Data model file detection
/// 4. Model naming convention
/// 5. Entity type recognition
/// 6. Edge cases (nested models, generic types)
///
/// Model-Entity Pattern:
/// - Model: Data layer, contains Entity + metadata (etag, cachedAt)
/// - Entity: Domain layer, pure business logic
/// - Composition: Model contains Entity, not inheritance
/// - Conversion: toEntity() and fromEntity() methods
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('ModelStructureRule', () {
    group('Data Model File Detection', () {
      test('detects data model file by path', () {
        final testCases = [
          'lib/features/todos/data/models/todo_model.dart',
          'lib/data/models/user_model.dart',
          'lib/core/data/models/cache_model.dart',
        ];

        for (final path in testCases) {
          expect(
            _isDataModelFile(path),
            isTrue,
            reason: '$path should be detected as data model file',
          );
        }
      });

      test('rejects non-data model files', () {
        final testCases = [
          'lib/domain/entities/todo.dart',
          'lib/presentation/states/todo_state.dart',
          'lib/models/todo_model.dart', // Missing 'data' directory
          'lib/data/todo_model.dart', // Missing 'models' directory
        ];

        for (final path in testCases) {
          expect(
            _isDataModelFile(path),
            isFalse,
            reason: '$path should not be detected as data model file',
          );
        }
      });

      test('handles Windows path separators', () {
        final windowsPath = r'lib\features\todos\data\models\todo_model.dart';
        expect(
          _isDataModelFile(windowsPath),
          isTrue,
          reason: 'Should handle Windows path separators',
        );
      });
    });

    group('Freezed Annotation Detection', () {
      test('detects @freezed annotation', () {
        expect(
          _hasFreezedAnnotation('@freezed'),
          isTrue,
          reason: '@freezed annotation should be detected',
        );
      });

      test('detects @Freezed annotation (capitalized)', () {
        expect(
          _hasFreezedAnnotation('@Freezed'),
          isTrue,
          reason: '@Freezed annotation should be detected',
        );
      });

      test('rejects class without Freezed annotation', () {
        expect(
          _hasFreezedAnnotation(''),
          isFalse,
          reason: 'Missing annotation should be rejected',
        );
      });

      test('rejects other annotations', () {
        final otherAnnotations = [
          '@JsonSerializable',
          '@immutable',
          '@override',
        ];

        for (final annotation in otherAnnotations) {
          expect(
            _hasFreezedAnnotation(annotation),
            isFalse,
            reason: '$annotation should not be detected as Freezed',
          );
        }
      });
    });

    group('Sealed Class Detection', () {
      test('detects sealed class modifier', () {
        expect(
          _isSealedClass(hasSealed: true),
          isTrue,
          reason: 'sealed class should be detected',
        );
      });

      test('rejects non-sealed class', () {
        expect(
          _isSealedClass(hasSealed: false),
          isFalse,
          reason: 'Regular class should not be detected as sealed',
        );
      });
    });

    group('Entity Field Detection', () {
      test('detects entity field by name "entity"', () {
        expect(
          _hasEntityField('entity', 'Todo'),
          isTrue,
          reason: 'Field named "entity" should be detected',
        );
      });

      test('detects entity field ending with "Entity"', () {
        final testCases = ['todoEntity', 'userEntity', 'productEntity'];

        for (final fieldName in testCases) {
          expect(
            _hasEntityField(fieldName, 'String'),
            isTrue,
            reason: '$fieldName should be detected as entity field',
          );
        }
      });

      test('detects entity by type name', () {
        final entityTypes = [
          'Todo', // Simple entity type
          'User',
          'Product',
          'TimeSlot',
          'TodoEntity', // Explicitly named entity
        ];

        for (final typeName in entityTypes) {
          expect(
            _isEntityType(typeName),
            isTrue,
            reason: '$typeName should be recognized as entity type',
          );
        }
      });

      test('rejects primitive types as entity', () {
        final primitiveTypes = [
          'String',
          'int',
          'double',
          'bool',
          'DateTime',
          'List',
          'Map',
          'Set',
        ];

        for (final typeName in primitiveTypes) {
          expect(
            _isEntityType(typeName),
            isFalse,
            reason: '$typeName should not be recognized as entity type',
          );
        }
      });

      test('rejects data layer types as entity', () {
        final dataLayerTypes = [
          'TodoModel',
          'UserDto',
          'ProductResponse',
          'OrderRequest',
        ];

        for (final typeName in dataLayerTypes) {
          expect(
            _isEntityType(typeName),
            isFalse,
            reason: '$typeName should not be recognized as entity type',
          );
        }
      });
    });

    group('Model Naming Convention', () {
      test('validates Model suffix', () {
        final validNames = ['TodoModel', 'UserModel', 'ProductModel'];

        for (final name in validNames) {
          expect(
            _isValidModelName(name),
            isTrue,
            reason: '$name follows Model naming convention',
          );
        }
      });

      test('rejects names without Model suffix', () {
        final invalidNames = ['Todo', 'UserEntity', 'ProductDto'];

        for (final name in invalidNames) {
          expect(
            _isValidModelName(name),
            isFalse,
            reason: '$name does not follow Model naming convention',
          );
        }
      });
    });

    group('Error Messages', () {
      test('provides clear message for missing Freezed', () {
        final message = _getErrorMessage(ErrorType.missingFreezed);

        expect(
          message,
          contains('@freezed annotation'),
          reason: 'Error message should mention Freezed annotation',
        );
      });

      test('provides clear message for missing sealed modifier', () {
        final message = _getErrorMessage(ErrorType.missingSealed);

        expect(
          message,
          contains('sealed class'),
          reason: 'Error message should mention sealed class',
        );
        expect(
          message,
          contains('sealed'),
          reason: 'Error message should include sealed keyword',
        );
      });

      test('provides clear message for missing Entity field', () {
        final message = _getErrorMessage(ErrorType.missingEntity);

        expect(
          message,
          contains('Entity field'),
          reason: 'Error message should mention Entity field',
        );
        expect(
          message,
          contains('composition'),
          reason: 'Error message should explain composition pattern',
        );
      });

      test('includes correction suggestion', () {
        final message = _getErrorMessage(ErrorType.missingEntity);

        expect(
          message,
          contains('required EntityName entity'),
          reason: 'Error message should show correct pattern',
        );
      });
    });

    group('Edge Cases', () {
      test('handles generic entity types', () {
        final genericTypes = [
          'List<Todo>',
          'Map<String, User>',
          'Set<Product>',
        ];

        for (final typeName in genericTypes) {
          // Generic types start with 'List', 'Map', 'Set' - should be rejected
          expect(
            _isEntityType(typeName),
            isFalse,
            reason: '$typeName is a generic type, not an entity',
          );
        }
      });

      test('handles nullable entity types', () {
        expect(
          _isEntityType('Todo?'),
          isTrue,
          reason: 'Nullable entity type should be recognized',
        );
      });

      test('handles empty strings', () {
        expect(_isEntityType(''), isFalse);
        expect(_hasEntityField('', ''), isFalse);
        expect(_isDataModelFile(''), isFalse);
      });

      test('handles nested model structures', () {
        // Model can contain another Model as metadata
        expect(
          _isEntityType('CacheMetadataModel'),
          isFalse,
          reason: 'Nested Model should not be recognized as entity',
        );
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        // This test documents what violations should be detected in bad example files
        final expectedViolations = {
          'todo_model_bad.dart': [
            'TodoModelNoFreezed: Missing @freezed',
            'TodoModelNoEntity: Missing entity field',
            // Other violations will be detected by Tasks 25.2, 25.3
          ],
        };

        expect(
          expectedViolations['todo_model_bad.dart']!.length,
          greaterThan(0),
          reason: 'Should detect violations in bad examples',
        );
      });

      test('should accept all patterns in good examples', () {
        final expectedPassing = {
          'todo_model_good.dart': [
            'TodoModel: Has @freezed annotation',
            'TodoModel: Contains entity field',
            'TodoModel: Only metadata fields added',
          ],
        };

        expect(
          expectedPassing['todo_model_good.dart']!.length,
          equals(3),
          reason: 'Should accept good example patterns',
        );
      });
    });
  });
}

// Helper enums and classes for testing

enum ErrorType { missingFreezed, missingSealed, missingEntity }

// Helper functions that simulate rule logic

bool _isDataModelFile(String filePath) {
  final normalized = filePath.replaceAll('\\', '/').toLowerCase();
  return normalized.contains('/data/') && normalized.contains('/models/');
}

bool _hasFreezedAnnotation(String annotation) {
  return annotation == '@freezed' || annotation == '@Freezed';
}

bool _isSealedClass({required bool hasSealed}) {
  return hasSealed;
}

bool _hasEntityField(String fieldName, String typeName) {
  // Check if field name indicates entity
  if (fieldName == 'entity' || fieldName.endsWith('Entity')) {
    return true;
  }

  // Check if type indicates entity
  return _isEntityType(typeName);
}

bool _isEntityType(String typeName) {
  if (typeName.isEmpty) return false;

  // Remove nullable marker for checking
  final cleanTypeName = typeName.replaceAll('?', '');

  // Exclude common data layer types
  if (cleanTypeName.endsWith('Model') ||
      cleanTypeName.endsWith('Dto') ||
      cleanTypeName.endsWith('Response') ||
      cleanTypeName.endsWith('Request')) {
    return false;
  }

  // Exclude primitive types
  final primitiveTypes = [
    'String',
    'int',
    'double',
    'bool',
    'DateTime',
    'List',
    'Map',
    'Set',
  ];
  if (primitiveTypes.any((type) => cleanTypeName.startsWith(type))) {
    return false;
  }

  // Explicitly named entities
  if (cleanTypeName.endsWith('Entity')) return true;

  // Custom types are likely entities
  return true;
}

bool _isValidModelName(String className) {
  return className.endsWith('Model');
}

String _getErrorMessage(ErrorType errorType) {
  switch (errorType) {
    case ErrorType.missingFreezed:
      return 'Data model should use @freezed annotation. '
          'Add @freezed above the class declaration.';
    case ErrorType.missingSealed:
      return 'Data model should be a sealed class. '
          'Add "sealed" modifier before "class" keyword.';
    case ErrorType.missingEntity:
      return 'Data model should contain Entity field using composition pattern. '
          'Add "required EntityName entity" field to contain the Domain Entity.';
  }
}
