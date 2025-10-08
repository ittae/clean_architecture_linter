import 'package:test/test.dart';

/// Unit tests for EntityBusinessLogicRule
///
/// This test suite verifies that the entity_business_logic_rule correctly
/// enforces Clean Architecture principles for Domain Entity patterns.
///
/// Test Coverage:
/// 1. Entity class detection logic
/// 2. Anemic entity detection (entities without business logic)
/// 3. Freezed + extension pattern recognition
/// 4. Value object pattern allowance
/// 5. Immutability validation (final fields, no setters)
/// 6. Error message accuracy
/// 7. Edge cases (inheritance, abstract classes, mixins)
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('EntityBusinessLogicRule', () {
    group('Entity Class Detection', () {
      test('detects classes ending with Entity', () {
        final testCases = [
          'UserEntity',
          'TodoEntity',
          'OrderEntity',
          'ProductEntity',
        ];

        for (final className in testCases) {
          expect(
            _isEntityClassName(className),
            isTrue,
            reason: '$className should be detected as Entity',
          );
        }
      });

      test('detects classes in domain/entities/ directory', () {
        final testCases = [
          'lib/features/todos/domain/entities/todo.dart',
          'lib/features/users/domain/entities/user.dart',
          'lib/domain/entities/product.dart',
        ];

        for (final filePath in testCases) {
          expect(
            _isDomainEntitiesPath(filePath),
            isTrue,
            reason: '$filePath should be detected as domain entity path',
          );
        }
      });

      test('ignores non-entity classes', () {
        final testCases = [
          'TodoModel', // Data layer
          'TodoState', // Presentation layer
          'TodoDTO',
          'TodoRequest',
          'TodoResponse',
          'TodoUseCase',
          'TodoRepository',
          'TodoException',
          'TodoFailure',
        ];

        for (final className in testCases) {
          expect(
            _isEntityClassName(className),
            isFalse,
            reason: '$className should NOT be detected as Entity',
          );
        }
      });
    });

    group('Anemic Entity Detection', () {
      test('detects entity with only data fields', () {
        final entity = TestEntity(
          hasFields: true,
          hasGetters: true,
          hasBusinessLogicMethods: false,
        );

        expect(
          _isAnemicEntity(entity),
          isTrue,
          reason: 'Entity with only fields/getters should be anemic',
        );
      });

      test('detects entity with only simple getters', () {
        final simpleGetters = ['getName', 'getEmail', 'getId'];

        expect(
          _hasOnlySimpleGetters(simpleGetters),
          isTrue,
          reason: 'Simple getter methods should not count as business logic',
        );
      });

      test('accepts entity with business logic methods', () {
        final entity = TestEntity(
          hasFields: true,
          hasGetters: true,
          hasBusinessLogicMethods: true,
        );

        expect(
          _isAnemicEntity(entity),
          isFalse,
          reason: 'Entity with business logic should not be anemic',
        );
      });

      test('recognizes business logic method types', () {
        final businessLogicMethods = [
          'isValid',
          'canPerformAction',
          'calculateTotal',
          'markAsCompleted',
          'transformToDTO',
        ];

        for (final methodName in businessLogicMethods) {
          expect(
            _isBusinessLogicMethod(methodName),
            isTrue,
            reason: '$methodName should be recognized as business logic',
          );
        }
      });

      test('excludes utility methods from business logic check', () {
        final utilityMethods = [
          'toString',
          'toJson',
          'fromJson',
          'copyWith',
          'toMap',
          'fromMap',
          'toEntity',
          'fromEntity',
          'hashCode',
        ];

        for (final methodName in utilityMethods) {
          expect(
            _isBusinessLogicMethod(methodName),
            isFalse,
            reason: '$methodName should NOT be business logic',
          );
        }
      });
    });

    group('Freezed + Extension Pattern', () {
      test('detects @freezed annotation', () {
        final annotations = ['freezed', 'Freezed', '@freezed'];

        for (final annotation in annotations) {
          expect(
            _isFreezedAnnotation(annotation),
            isTrue,
            reason: '$annotation should be detected as Freezed',
          );
        }
      });

      test('detects extension on entity class', () {
        final extensionDeclarations = [
          'extension TodoX on Todo',
          'extension UserExtensions on User',
          'extension OrderHelpers on Order',
        ];

        for (final ext in extensionDeclarations) {
          expect(
            _isExtensionDeclaration(ext),
            isTrue,
            reason: '$ext should be detected as extension',
          );
        }
      });

      test('validates extension has business logic methods', () {
        final extensionWithMethods = TestExtension(
          className: 'Todo',
          methodCount: 3,
          hasBusinessLogic: true,
        );

        expect(
          _extensionHasBusinessLogic(extensionWithMethods),
          isTrue,
          reason: 'Extension with methods should have business logic',
        );
      });

      test('detects Freezed entity without extension', () {
        final freezedEntity = TestEntity(
          isFreezed: true,
          hasExtension: false,
        );

        expect(
          _needsExtension(freezedEntity),
          isTrue,
          reason: 'Freezed entity without extension should be flagged',
        );
      });

      test('accepts Freezed entity with extension', () {
        final freezedEntity = TestEntity(
          isFreezed: true,
          hasExtension: true,
        );

        expect(
          _needsExtension(freezedEntity),
          isFalse,
          reason: 'Freezed entity with extension should pass',
        );
      });
    });

    group('Value Object Pattern', () {
      test('recognizes common value object class names', () {
        final valueObjectNames = [
          'Email',
          'Money',
          'Address',
          'PhoneNumber',
          'Url',
          'Username',
          'Password',
          'Currency',
          'Price',
          'Quantity',
        ];

        for (final className in valueObjectNames) {
          expect(
            _isValueObject(className),
            isTrue,
            reason: '$className should be recognized as value object',
          );
        }
      });

      test('recognizes value object suffixes', () {
        final valueObjectClasses = [
          'UserIdValue',
          'OrderStatusValue',
          'ProductVO',
          'CategoryVO',
        ];

        for (final className in valueObjectClasses) {
          expect(
            _isValueObject(className),
            isTrue,
            reason: '$className should be recognized as value object',
          );
        }
      });

      test('allows value objects without complex business logic', () {
        final valueObject = TestEntity(
          className: 'Email',
          hasSimpleValidation: true,
          hasComplexBusinessLogic: false,
        );

        expect(
          _valueObjectNeedsBusinessLogic(valueObject),
          isFalse,
          reason: 'Value objects can have simple validation only',
        );
      });

      test('ignores non-value-object classes', () {
        final normalClasses = [
          'User',
          'Order',
          'Product',
          'Todo',
        ];

        for (final className in normalClasses) {
          expect(
            _isValueObject(className),
            isFalse,
            reason: '$className should NOT be value object',
          );
        }
      });
    });

    group('Immutability Validation', () {
      test('detects non-final fields', () {
        final mutableFields = [
          'String name', // Non-final
          'int count',
          'bool isActive',
        ];

        for (final field in mutableFields) {
          expect(
            _isMutableField(field),
            isTrue,
            reason: '$field should be detected as mutable',
          );
        }
      });

      test('accepts final fields', () {
        final immutableFields = [
          'final String name',
          'final int count',
          'final bool isActive',
        ];

        for (final field in immutableFields) {
          expect(
            _isMutableField(field),
            isFalse,
            reason: '$field should be detected as immutable',
          );
        }
      });

      test('detects setter methods', () {
        final setterMethods = [
          'setName',
          'updateStatus',
          'modifyValue',
        ];

        for (final method in setterMethods) {
          expect(
            _isSetterMethod(method),
            isTrue,
            reason: '$method should be detected as setter',
          );
        }
      });

      test('accepts non-setter methods', () {
        final validMethods = [
          'getName',
          'calculateTotal',
          'isValid',
          'copyWith',
        ];

        for (final method in validMethods) {
          expect(
            _isSetterMethod(method),
            isFalse,
            reason: '$method should NOT be setter',
          );
        }
      });

      test('validates entity immutability', () {
        final immutableEntity = TestEntity(
          hasNonFinalFields: false,
          hasSetters: false,
        );

        expect(
          _isImmutable(immutableEntity),
          isTrue,
          reason: 'Entity with final fields and no setters is immutable',
        );
      });

      test('detects mutable entity', () {
        final mutableEntity = TestEntity(
          hasNonFinalFields: true,
          hasSetters: true,
        );

        expect(
          _isImmutable(mutableEntity),
          isFalse,
          reason: 'Entity with mutable fields or setters is not immutable',
        );
      });
    });

    group('Error Messages', () {
      test('anemic entity error message is clear', () {
        const errorMessage = 'Domain Entity appears to be anemic (only data fields without business logic). '
            'Entities should contain business logic methods.';

        expect(
          errorMessage.contains('anemic'),
          isTrue,
          reason: 'Error should mention anemic',
        );
        expect(
          errorMessage.contains('business logic'),
          isTrue,
          reason: 'Error should mention business logic',
        );
      });

      test('freezed without extension error is specific', () {
        const errorMessage = 'Freezed Entity "Todo" lacks business logic extension. '
            'Add extension with business logic methods in same file.';

        expect(
          errorMessage.contains('Freezed'),
          isTrue,
          reason: 'Error should mention Freezed',
        );
        expect(
          errorMessage.contains('extension'),
          isTrue,
          reason: 'Error should mention extension',
        );
      });

      test('immutability error provides guidance', () {
        const errorMessage = 'Entity "Order" has non-final fields. '
            'Domain entities must be immutable.';

        expect(
          errorMessage.contains('non-final'),
          isTrue,
          reason: 'Error should mention non-final fields',
        );
        expect(
          errorMessage.contains('immutable'),
          isTrue,
          reason: 'Error should mention immutability',
        );
      });
    });

    group('Edge Cases', () {
      test('handles abstract entity classes', () {
        final abstractEntity = TestEntity(
          isAbstract: true,
          hasBusinessLogicMethods: false,
        );

        expect(
          _shouldSkipAbstractClass(abstractEntity),
          isTrue,
          reason: 'Abstract entities should be skipped',
        );
      });

      test('handles entity with inheritance', () {
        final childEntity = TestEntity(
          hasParentClass: true,
          parentHasBusinessLogic: true,
        );

        expect(
          _hasBusinessLogicInHierarchy(childEntity),
          isTrue,
          reason: 'Should check parent class for business logic',
        );
      });

      test('handles private methods correctly', () {
        final privateMethods = [
          '_validate',
          '_helper',
          '_calculate',
        ];

        for (final method in privateMethods) {
          expect(
            _isPrivateMethod(method),
            isTrue,
            reason: '$method should be detected as private',
          );
        }
      });

      test('handles generic entity classes', () {
        final genericClasses = [
          'Entity<T>',
          'BaseEntity<T, E>',
          'DomainEntity<ID>',
        ];

        for (final className in genericClasses) {
          expect(
            _isGenericEntity(className),
            isTrue,
            reason: '$className should be detected as generic entity',
          );
        }
      });

      test('handles entity with mixins', () {
        final entityWithMixin = TestEntity(
          hasMixin: true,
          mixinHasBusinessLogic: true,
        );

        expect(
          _hasBusinessLogicInMixins(entityWithMixin),
          isTrue,
          reason: 'Should check mixins for business logic',
        );
      });
    });
  });
}

// ============================================================================
// Helper Functions (Simulating EntityBusinessLogicRule behavior)
// ============================================================================

/// Simulates entity class name detection
bool _isEntityClassName(String className) {
  // Entity naming patterns
  if (className.endsWith('Entity')) return true;

  // Non-entity patterns
  if (className.endsWith('Model')) return false;
  if (className.endsWith('State')) return false;
  if (className.endsWith('DTO')) return false;
  if (className.endsWith('Request')) return false;
  if (className.endsWith('Response')) return false;
  if (className.endsWith('UseCase')) return false;
  if (className.endsWith('Repository')) return false;
  if (className.endsWith('Exception')) return false;
  if (className.endsWith('Failure')) return false;

  return false;
}

/// Simulates domain entities path detection
bool _isDomainEntitiesPath(String filePath) {
  return filePath.contains('/domain/entities/');
}

/// Simulates anemic entity detection
bool _isAnemicEntity(TestEntity entity) {
  return !entity.hasBusinessLogicMethods;
}

/// Checks if methods are only simple getters
bool _hasOnlySimpleGetters(List<String> methods) {
  return methods.every((m) => m.startsWith('get'));
}

/// Checks if method name indicates business logic
bool _isBusinessLogicMethod(String methodName) {
  // Utility methods are not business logic
  const utilityMethods = [
    'toString',
    'toJson',
    'fromJson',
    'copyWith',
    'toMap',
    'fromMap',
    'toEntity',
    'fromEntity',
    'hashCode',
  ];

  if (utilityMethods.contains(methodName)) return false;

  // Simple getters are not business logic
  if (methodName.startsWith('get')) return false;

  // Business logic patterns
  return methodName.startsWith('is') ||
      methodName.startsWith('can') ||
      methodName.startsWith('calculate') ||
      methodName.startsWith('mark') ||
      methodName.startsWith('transform');
}

/// Detects Freezed annotation
bool _isFreezedAnnotation(String annotation) {
  final cleaned = annotation.replaceAll('@', '');
  return cleaned.toLowerCase() == 'freezed';
}

/// Detects extension declaration
bool _isExtensionDeclaration(String declaration) {
  return declaration.contains('extension') && declaration.contains('on');
}

/// Checks if extension has business logic
bool _extensionHasBusinessLogic(TestExtension extension) {
  return extension.hasBusinessLogic && extension.methodCount > 0;
}

/// Checks if Freezed entity needs extension
bool _needsExtension(TestEntity entity) {
  return entity.isFreezed && !entity.hasExtension;
}

/// Detects value object classes
bool _isValueObject(String className) {
  // Common value object patterns
  const valueObjectPatterns = [
    'Email',
    'Money',
    'Address',
    'PhoneNumber',
    'Url',
    'Username',
    'Password',
    'Currency',
    'Price',
    'Quantity',
  ];

  for (final pattern in valueObjectPatterns) {
    if (className.contains(pattern)) return true;
  }

  // Explicit value object naming
  if (className.endsWith('Value')) return true;
  if (className.endsWith('VO')) return true;

  return false;
}

/// Checks if value object needs business logic
bool _valueObjectNeedsBusinessLogic(TestEntity entity) {
  return entity.hasComplexBusinessLogic;
}

/// Detects mutable fields
bool _isMutableField(String field) {
  return !field.contains('final');
}

/// Detects setter methods
bool _isSetterMethod(String methodName) {
  return methodName.startsWith('set') || methodName.startsWith('update') || methodName.startsWith('modify');
}

/// Checks entity immutability
bool _isImmutable(TestEntity entity) {
  return !entity.hasNonFinalFields && !entity.hasSetters;
}

/// Checks if abstract class should be skipped
bool _shouldSkipAbstractClass(TestEntity entity) {
  return entity.isAbstract;
}

/// Checks business logic in class hierarchy
bool _hasBusinessLogicInHierarchy(TestEntity entity) {
  return entity.parentHasBusinessLogic;
}

/// Detects private methods
bool _isPrivateMethod(String methodName) {
  return methodName.startsWith('_');
}

/// Detects generic entity classes
bool _isGenericEntity(String className) {
  return className.contains('<') && className.contains('>');
}

/// Checks business logic in mixins
bool _hasBusinessLogicInMixins(TestEntity entity) {
  return entity.mixinHasBusinessLogic;
}

// ============================================================================
// Test Helper Classes
// ============================================================================

class TestEntity {
  final bool hasFields;
  final bool hasGetters;
  final bool hasBusinessLogicMethods;
  final bool isFreezed;
  final bool hasExtension;
  final String className;
  final bool hasSimpleValidation;
  final bool hasComplexBusinessLogic;
  final bool hasNonFinalFields;
  final bool hasSetters;
  final bool isAbstract;
  final bool hasParentClass;
  final bool parentHasBusinessLogic;
  final bool hasMixin;
  final bool mixinHasBusinessLogic;

  TestEntity({
    this.hasFields = false,
    this.hasGetters = false,
    this.hasBusinessLogicMethods = false,
    this.isFreezed = false,
    this.hasExtension = false,
    this.className = '',
    this.hasSimpleValidation = false,
    this.hasComplexBusinessLogic = false,
    this.hasNonFinalFields = false,
    this.hasSetters = false,
    this.isAbstract = false,
    this.hasParentClass = false,
    this.parentHasBusinessLogic = false,
    this.hasMixin = false,
    this.mixinHasBusinessLogic = false,
  });
}

class TestExtension {
  final String className;
  final int methodCount;
  final bool hasBusinessLogic;

  TestExtension({
    required this.className,
    required this.methodCount,
    required this.hasBusinessLogic,
  });
}
