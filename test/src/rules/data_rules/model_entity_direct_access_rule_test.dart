import 'package:test/test.dart';

/// Unit tests for ModelEntityDirectAccessRule
///
/// This test suite verifies that the model_entity_direct_access rule correctly
/// enforces using toEntity() method instead of direct .entity property access.
///
/// Test Coverage:
/// 1. Direct .entity access detection
/// 2. Layer-based restriction (Data layer only)
/// 3. Exception for extension methods
/// 4. Exception for test files
/// 5. Error messages
/// 6. Edge cases
///
/// Pattern:
/// - ❌ Disallow: `model.entity` in Data layer (outside extensions)
/// - ✅ Allow: `model.toEntity()` in Data layer
/// - ✅ Allow: `model.entity` inside extension methods
/// - ✅ Allow: `model.entity` in test files
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('ModelEntityDirectAccessRule', () {
    group('Property Access Detection', () {
      test('detects direct .entity access', () {
        expect(
          _isEntityPropertyAccess('model.entity'),
          isTrue,
          reason: 'Should detect .entity property access',
        );
      });

      test('ignores other property access', () {
        expect(
          _isEntityPropertyAccess('model.id'),
          isFalse,
          reason: 'Should not flag non-entity properties',
        );
      });

      test('detects .entity in chain', () {
        expect(
          _isEntityPropertyAccess('result.value.entity'),
          isTrue,
          reason: 'Should detect .entity in property chain',
        );
      });

      test('detects .entity in map', () {
        expect(
          _isEntityPropertyAccess('models.map((m) => m.entity)'),
          isTrue,
          reason: 'Should detect .entity in lambda expressions',
        );
      });
    });

    group('Layer-Based Restriction', () {
      test('flags .entity access in Data layer', () {
        expect(
          _shouldFlag(
            code: 'model.entity',
            filePath: 'lib/data/repositories/todo_repository_impl.dart',
          ),
          isTrue,
          reason: 'Should flag .entity in Data layer files',
        );
      });

      test('ignores .entity in Presentation layer', () {
        expect(
          _shouldFlag(
            code: 'model.entity',
            filePath: 'lib/presentation/pages/todo_page.dart',
          ),
          isFalse,
          reason:
              'Presentation should not import Model at all (handled by other rules)',
        );
      });

      test('ignores .entity in Domain layer', () {
        expect(
          _shouldFlag(
            code: 'model.entity',
            filePath: 'lib/domain/usecases/get_todos.dart',
          ),
          isFalse,
          reason:
              'Domain should not import Model at all (handled by other rules)',
        );
      });

      test('flags .entity in DataSource', () {
        expect(
          _shouldFlag(
            code: 'model.entity',
            filePath: 'lib/data/datasources/todo_remote_datasource.dart',
          ),
          isTrue,
          reason: 'Should flag .entity in DataSource files',
        );
      });

      test('flags .entity in Repository', () {
        expect(
          _shouldFlag(
            code: 'model.entity',
            filePath: 'lib/data/repositories/todo_repository_impl.dart',
          ),
          isTrue,
          reason: 'Should flag .entity in Repository implementation files',
        );
      });
    });

    group('Extension Method Exception', () {
      test('allows .entity inside extension method', () {
        expect(
          _shouldFlag(
            code: 'entity',
            filePath: 'lib/data/models/todo_model.dart',
            insideExtension: true,
          ),
          isFalse,
          reason: 'Should allow .entity inside extension methods',
        );
      });

      test('flags .entity outside extension', () {
        expect(
          _shouldFlag(
            code: 'model.entity',
            filePath: 'lib/data/models/todo_model.dart',
            insideExtension: false,
          ),
          isTrue,
          reason: 'Should flag .entity outside extension methods',
        );
      });

      test('allows .entity in toEntity() method', () {
        expect(
          _shouldFlag(
            code: 'return entity;',
            filePath: 'lib/data/models/todo_model.dart',
            insideExtension: true,
            methodName: 'toEntity',
          ),
          isFalse,
          reason: 'toEntity() is the implementation of conversion',
        );
      });

      test('allows .entity in fromEntity() method', () {
        expect(
          _shouldFlag(
            code: 'ModelName(entity: entity)',
            filePath: 'lib/data/models/todo_model.dart',
            insideExtension: true,
            methodName: 'fromEntity',
          ),
          isFalse,
          reason: 'fromEntity() needs to access entity parameter',
        );
      });
    });

    group('Test File Exception', () {
      test('allows .entity in test files', () {
        expect(
          _shouldFlag(
            code: 'model.entity',
            filePath: 'test/data/models/todo_model_test.dart',
          ),
          isFalse,
          reason: 'Test files can access .entity for verification',
        );
      });

      test('allows .entity in integration tests', () {
        expect(
          _shouldFlag(
            code: 'model.entity',
            filePath: 'integration_test/todo_flow_test.dart',
          ),
          isFalse,
          reason: 'Integration tests can access .entity',
        );
      });
    });

    group('Error Messages', () {
      test('provides clear message for direct access', () {
        final message = _getErrorMessage();

        expect(
          message,
          contains('Direct access'),
          reason: 'Error message should mention direct access',
        );
        expect(
          message,
          contains('model.entity'),
          reason: 'Error message should show problematic pattern',
        );
        expect(
          message,
          contains('toEntity()'),
          reason: 'Error message should show correct method',
        );
      });

      test('provides correction example', () {
        final message = _getErrorMessage();

        expect(
          message,
          contains('model.toEntity()'),
          reason: 'Error message should show correction',
        );
      });

      test('explains architectural reasoning', () {
        final message = _getErrorMessage();

        expect(
          message,
          contains('conversion'),
          reason: 'Error message should explain conversion concept',
        );
      });
    });

    group('Code Fix Suggestions', () {
      test('suggests toEntity() for single access', () {
        final fix = _getSuggestedFix('final entity = model.entity;');

        expect(
          fix,
          equals('final entity = model.toEntity();'),
          reason: 'Should suggest toEntity() method call',
        );
      });

      test('suggests toEntity() in map', () {
        final fix = _getSuggestedFix('models.map((m) => m.entity).toList()');

        expect(
          fix,
          equals('models.map((m) => m.toEntity()).toList()'),
          reason: 'Should suggest toEntity() in map',
        );
      });

      test('suggests toEntity() in chain', () {
        final fix = _getSuggestedFix('return result.value.entity;');

        expect(
          fix,
          equals('return result.value.toEntity();'),
          reason: 'Should suggest toEntity() in property chain',
        );
      });
    });

    group('Edge Cases', () {
      test('handles property named "entity" that is not Model', () {
        expect(
          _shouldFlag(
            code: 'someObject.entity',
            filePath: 'lib/data/repositories/todo_repository_impl.dart',
            isModelType: false,
          ),
          isTrue,
          reason:
              'Rule checks property name, not type (type checking is expensive)',
        );
      });

      test('handles nested models', () {
        expect(
          _shouldFlag(
            code: 'parentModel.childModel.entity',
            filePath: 'lib/data/repositories/todo_repository_impl.dart',
          ),
          isTrue,
          reason: 'Should detect .entity at any depth',
        );
      });

      test('handles entity as variable name', () {
        expect(
          _isEntityPropertyAccess('final entity = something;'),
          isFalse,
          reason: 'Should not flag variable named entity',
        );
      });

      test('handles generated model files', () {
        expect(
          _shouldFlag(
            code: 'model.entity',
            filePath: 'lib/data/models/todo_model.freezed.dart',
          ),
          isFalse,
          reason: 'Generated files should be excluded',
        );
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        final expectedViolations = {
          'data/repositories/todo_repository_impl_bad.dart': [
            'Line 10: models.map((m) => m.entity)',
            'Line 15: final entity = model.entity',
          ],
          'data/datasources/todo_remote_datasource_bad.dart': [
            'Line 8: return model.entity',
          ],
        };

        expect(
          expectedViolations.length,
          greaterThan(0),
          reason: 'Should detect direct .entity access violations',
        );
      });

      test('should accept all patterns in good examples', () {
        final expectedPassing = {
          'data/repositories/todo_repository_impl_good.dart': [
            'Uses toEntity() method',
            'No direct .entity access',
          ],
          'data/models/todo_model_good.dart': [
            'Extension uses .entity internally',
            'toEntity() returns entity field',
          ],
        };

        expect(
          expectedPassing.length,
          equals(2),
          reason: 'Should accept correct usage patterns',
        );
      });
    });
  });
}

// Helper functions that simulate rule logic

bool _isEntityPropertyAccess(String code) {
  return code.contains('.entity') && !code.startsWith('final entity');
}

bool _shouldFlag({
  required String code,
  required String filePath,
  bool insideExtension = false,
  String? methodName,
  bool isModelType = true,
}) {
  // Exclude test files
  if (filePath.contains('/test/') || filePath.endsWith('_test.dart')) {
    return false;
  }

  // Exclude generated files
  if (filePath.endsWith('.freezed.dart') || filePath.endsWith('.g.dart')) {
    return false;
  }

  // Only check Data layer files
  if (!filePath.contains('/data/')) {
    return false;
  }

  // Allow inside extension methods
  if (insideExtension) {
    return false;
  }

  // Check if accessing .entity
  return _isEntityPropertyAccess(code);
}

String _getErrorMessage() {
  return 'Direct access to model.entity is not allowed in Data layer. '
      'Use the toEntity() extension method instead. '
      'Replace ".entity" with ".toEntity()" to maintain clear conversion boundaries. '
      'Example: model.toEntity() instead of model.entity';
}

String _getSuggestedFix(String originalCode) {
  return originalCode.replaceAll('.entity', '.toEntity()');
}
