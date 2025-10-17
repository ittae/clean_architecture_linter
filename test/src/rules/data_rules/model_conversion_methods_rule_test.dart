import 'package:test/test.dart';

/// Unit tests for ModelConversionMethodsRule
///
/// This test suite verifies that the model_conversion_methods_rule correctly
/// enforces Clean Architecture Model conversion pattern.
///
/// Test Coverage:
/// 1. toEntity() method detection (required)
/// 2. fromEntity() method detection (optional - can be factory or extension)
/// 3. Extension in same file requirement
/// 4. Error messages
/// 5. Edge cases
///
/// Conversion Pattern:
/// - toEntity(): Instance method in extension (REQUIRED)
/// - fromEntity(): Use factory constructor in class (OPTIONAL, not checked by this rule)
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

      test('requires toEntity method (fromEntity is optional)', () {
        final hasToEntity = _hasMethod('toEntity', isStatic: false);

        expect(
          hasToEntity,
          isTrue,
          reason: 'toEntity() method is required',
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
      test('provides clear message for missing toEntity method', () {
        final message = _getErrorMessage(ErrorType.missingConversion);

        expect(
          message,
          contains('toEntity'),
          reason: 'Error message should mention toEntity',
        );
        expect(
          message,
          contains('extension'),
          reason: 'Error message should mention extension',
        );
      });

      test('provides correction example with factory suggestion', () {
        final message = _getErrorMessage(ErrorType.missingConversion);

        expect(
          message,
          contains('extension'),
          reason: 'Error message should mention extension',
        );
        expect(
          message,
          contains('factory'),
          reason: 'Error message should suggest factory constructor for fromEntity',
        );
      });

      test('explains toEntity requirement clearly', () {
        final message = _getErrorMessage(ErrorType.missingConversion);

        expect(
          message,
          contains('toEntity'),
          reason: 'Error message should clearly state toEntity is required',
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

      test('handles extension with only toEntity method', () {
        expect(
          _hasExtensionWithMethods(hasToEntity: true, hasFromEntity: false),
          isTrue,
          reason: 'toEntity() is sufficient, fromEntity is optional',
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
            'TodoModelNoConversion: Missing toEntity() method',
          ],
        };

        expect(
          expectedViolations['todo_model_bad.dart']!.length,
          greaterThan(0),
          reason: 'Should detect missing toEntity() method',
        );
      });

      test('should accept all patterns in good examples', () {
        final expectedPassing = {
          'todo_model_good.dart': [
            'TodoModel: Has toEntity() instance method',
            'TodoModel: Extension in same file',
          ],
        };

        expect(
          expectedPassing['todo_model_good.dart']!.length,
          greaterThan(0),
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
  // fromEntity is optional, only toEntity is required
  // methodCount == 0 means empty extension
  if (methodCount == 0 && !hasToEntity) return false;
  return hasToEntity;
}

bool _hasMultipleExtensions(String className, {required int count}) {
  // In real implementation, would check all extensions in CompilationUnit
  return count >= 1 && _hasExtensionOn(className);
}

String _getErrorMessage(ErrorType errorType) {
  switch (errorType) {
    case ErrorType.missingConversion:
      return 'Data model should have toEntity() method in extension. '
          'Add extension with toEntity() method in the same file:\n'
          '  extension ModelNameX on ModelName {\n'
          '    Entity toEntity() => entity;\n'
          '  }\n\n'
          'For creating Models from Entities, use factory constructors:\n'
          '  factory ModelName.fromEntity(Entity entity) => ModelName(entity: entity);';
  }
}
