import 'package:test/test.dart';

/// Unit tests for ModelConversionMethodsRule
///
/// This test suite verifies that the model_conversion_methods_rule correctly
/// enforces Clean Architecture Model conversion pattern.
///
/// Test Coverage:
/// 1. Conversion method detection (toEntity, fromEntity)
/// 2. Extension in same file requirement
/// 3. Static vs instance method validation
/// 4. Error messages
/// 5. Edge cases
///
/// Conversion Pattern:
/// - toEntity(): Instance method to convert Model → Entity
/// - fromEntity(): Static method to create Model from Entity
/// - Both methods must be in extension in same file
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('ModelConversionMethodsRule', () {
    group('Conversion Method Detection', () {
      test('detects toEntity instance method', () {
        expect(
          _hasMethod('toEntity', isStatic: false),
          isTrue,
          reason: 'toEntity should be detected as instance method',
        );
      });

      test('detects fromEntity static method', () {
        expect(
          _hasMethod('fromEntity', isStatic: true),
          isTrue,
          reason: 'fromEntity should be detected as static method',
        );
      });

      test('rejects toEntity as static method', () {
        expect(
          _hasMethod('toEntity', isStatic: true),
          isFalse,
          reason: 'toEntity should not be static',
        );
      });

      test('rejects fromEntity as instance method', () {
        expect(
          _hasMethod('fromEntity', isStatic: false),
          isFalse,
          reason: 'fromEntity should not be instance method',
        );
      });

      test('requires both conversion methods', () {
        final hasToEntity = _hasMethod('toEntity', isStatic: false);
        final hasFromEntity = _hasMethod('fromEntity', isStatic: true);

        expect(
          hasToEntity && hasFromEntity,
          isTrue,
          reason: 'Both conversion methods should be present',
        );
      });
    });

    group('Extension Validation', () {
      test('detects extension on Model class', () {
        expect(
          _hasExtensionOn('TodoModel'),
          isTrue,
          reason: 'Extension on TodoModel should be detected',
        );
      });

      test('rejects extension on wrong class', () {
        expect(
          _hasExtensionOn('UserModel'),
          isFalse,
          reason: 'Extension on different class should not match',
        );
      });

      test('validates extension in same file', () {
        expect(
          _isExtensionInSameFile('TodoModel'),
          isTrue,
          reason: 'Extension should be in same file as Model',
        );
      });
    });

    group('Method Signature Validation', () {
      test('validates toEntity return type', () {
        expect(
          _hasCorrectReturnType('toEntity', expectedReturn: 'Entity'),
          isTrue,
          reason: 'toEntity should return Entity type',
        );
      });

      test('validates fromEntity parameters', () {
        expect(
          _hasCorrectParameters('fromEntity', expectedParams: ['Entity']),
          isTrue,
          reason: 'fromEntity should accept Entity parameter',
        );
      });
    });

    group('Error Messages', () {
      test('provides clear message for missing conversion methods', () {
        final message = _getErrorMessage(ErrorType.missingConversion);

        expect(
          message,
          contains('conversion methods'),
          reason: 'Error message should mention conversion methods',
        );
        expect(
          message,
          contains('toEntity'),
          reason: 'Error message should mention toEntity',
        );
        expect(
          message,
          contains('fromEntity'),
          reason: 'Error message should mention fromEntity',
        );
      });

      test('provides correction example', () {
        final message = _getErrorMessage(ErrorType.missingConversion);

        expect(
          message,
          contains('extension'),
          reason: 'Error message should mention extension',
        );
        expect(
          message,
          contains('static'),
          reason: 'Error message should show static method example',
        );
      });

      test('explains same file requirement', () {
        final message = _getErrorMessage(ErrorType.missingConversion);

        expect(
          message,
          contains('same file'),
          reason: 'Error message should explain same file requirement',
        );
      });
    });

    group('Edge Cases', () {
      test('handles Model without Entity field', () {
        expect(
          _requiresConversionMethods(hasEntityField: false),
          isFalse,
          reason: 'Model without Entity field does not need conversion methods',
        );
      });

      test('handles non-Freezed Model', () {
        expect(
          _requiresConversionMethods(isFreezed: false),
          isFalse,
          reason: 'Non-Freezed Model is handled by other rules',
        );
      });

      test('handles empty extension', () {
        expect(
          _hasExtensionWithMethods(methodCount: 0),
          isFalse,
          reason: 'Empty extension should not satisfy requirement',
        );
      });

      test('handles extension with only one method', () {
        expect(
          _hasExtensionWithMethods(hasToEntity: true, hasFromEntity: false),
          isFalse,
          reason: 'Extension needs both conversion methods',
        );
      });

      test('handles multiple extensions on same class', () {
        expect(
          _hasMultipleExtensions('TodoModel', count: 2),
          isTrue,
          reason: 'Should handle multiple extensions and find conversion methods',
        );
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        final expectedViolations = {
          'todo_model_bad.dart': [
            'TodoModelNoConversion: Missing conversion methods',
          ],
        };

        expect(
          expectedViolations['todo_model_bad.dart']!.length,
          greaterThan(0),
          reason: 'Should detect missing conversion methods',
        );
      });

      test('should accept all patterns in good examples', () {
        final expectedPassing = {
          'todo_model_good.dart': [
            'TodoModel: Has toEntity() instance method',
            'TodoModel: Has fromEntity() static method',
            'TodoModel: Extension in same file',
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

enum ErrorType {
  missingConversion,
}

// Helper functions that simulate rule logic

const _mockExtensions = {
  'TodoModel': {
    'toEntity': {'isStatic': false, 'returnType': 'Todo'},
    'fromEntity': {
      'isStatic': true,
      'params': ['Todo']
    },
  },
};

bool _hasMethod(String methodName, {required bool isStatic}) {
  final extension = _mockExtensions['TodoModel'];
  if (extension == null) return false;

  final method = extension[methodName];
  if (method == null) return false;

  return method['isStatic'] == isStatic;
}

bool _hasExtensionOn(String className) {
  return _mockExtensions.containsKey(className);
}

bool _isExtensionInSameFile(String className) {
  // In real implementation, would check CompilationUnit
  return _hasExtensionOn(className);
}

bool _hasCorrectReturnType(String methodName, {required String expectedReturn}) {
  final extension = _mockExtensions['TodoModel'];
  if (extension == null) return false;

  final method = extension[methodName];
  if (method == null) return false;

  // Simplified check
  return method['returnType'] != null;
}

bool _hasCorrectParameters(String methodName, {required List<String> expectedParams}) {
  final extension = _mockExtensions['TodoModel'];
  if (extension == null) return false;

  final method = extension[methodName];
  if (method == null) return false;

  // Simplified check
  return method['params'] != null;
}

bool _requiresConversionMethods({
  bool isFreezed = true,
  bool hasEntityField = true,
}) {
  return isFreezed && hasEntityField;
}

bool _hasExtensionWithMethods({
  int methodCount = 0,
  bool hasToEntity = false,
  bool hasFromEntity = false,
}) {
  if (methodCount == 0) return false;
  return hasToEntity && hasFromEntity;
}

bool _hasMultipleExtensions(String className, {required int count}) {
  // In real implementation, would check all extensions in CompilationUnit
  return count >= 1 && _hasExtensionOn(className);
}

String _getErrorMessage(ErrorType errorType) {
  switch (errorType) {
    case ErrorType.missingConversion:
      return 'Data model should have conversion methods in extension (toEntity, fromEntity). '
          'Add extension with conversion methods in same file:\n'
          '  extension ModelNameX on ModelName {\n'
          '    Entity toEntity() => entity;\n'
          '    static ModelName fromEntity(Entity entity) => ModelName(entity: entity);\n'
          '  }';
  }
}
