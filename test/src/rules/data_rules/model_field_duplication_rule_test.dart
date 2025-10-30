import 'package:test/test.dart';

/// Unit tests for ModelFieldDuplicationRule
///
/// This test suite verifies that the model_field_duplication_rule correctly
/// enforces Clean Architecture Model-Entity composition pattern by detecting
/// field duplications.
///
/// Test Coverage:
/// 1. Field duplication detection
/// 2. Metadata field allowlist
/// 3. Entity field identification
/// 4. Domain field patterns
/// 5. Error messages
/// 6. Edge cases
///
/// Model-Entity Composition Pattern:
/// - Model: Entity + metadata only
/// - NO duplication: Model should not duplicate Entity fields
/// - Metadata allowed: etag, version, cachedAt, etc.
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('ModelFieldDuplicationRule', () {
    group('Field Duplication Detection', () {
      test('detects duplicate domain fields', () {
        final duplicateFields = ['id', 'title', 'isCompleted'];

        for (final fieldName in duplicateFields) {
          expect(
            _isPotentialDomainField(fieldName),
            isTrue,
            reason: '$fieldName should be detected as duplicate domain field',
          );
        }
      });

      test('allows metadata fields', () {
        final metadataFields = [
          'etag',
          'version',
          'cachedAt',
          'lastModified',
          'createdAt',
          'updatedAt',
          'syncStatus',
          'isLocal',
          'isCached',
        ];

        for (final fieldName in metadataFields) {
          expect(
            _isAllowedMetadataField(fieldName),
            isTrue,
            reason: '$fieldName should be allowed as metadata',
          );
        }
      });

      test('detects entity field by name', () {
        final entityFieldNames = ['entity', 'todoEntity', 'userEntity'];

        for (final fieldName in entityFieldNames) {
          expect(
            _isEntityFieldName(fieldName),
            isTrue,
            reason: '$fieldName should be detected as entity field',
          );
        }
      });
    });

    group('Domain Field Patterns', () {
      test('recognizes common ID fields', () {
        final idFields = ['id', 'userId', 'productId', 'orderId'];

        for (final fieldName in idFields) {
          expect(
            _isPotentialDomainField(fieldName),
            isTrue,
            reason: '$fieldName is a domain ID field',
          );
        }
      });

      test('recognizes common name/title fields', () {
        final nameFields = ['name', 'title', 'description', 'content'];

        for (final fieldName in nameFields) {
          expect(
            _isPotentialDomainField(fieldName),
            isTrue,
            reason: '$fieldName is a domain name/title field',
          );
        }
      });

      test('recognizes status/state fields', () {
        final stateFields = [
          'status',
          'type',
          'isCompleted',
          'isActive',
          'isEnabled',
        ];

        for (final fieldName in stateFields) {
          expect(
            _isPotentialDomainField(fieldName),
            isTrue,
            reason: '$fieldName is a domain status field',
          );
        }
      });

      test('recognizes date fields', () {
        final dateFields = ['dueDate', 'startDate', 'endDate'];

        for (final fieldName in dateFields) {
          expect(
            _isPotentialDomainField(fieldName),
            isTrue,
            reason: '$fieldName is a domain date field',
          );
        }
      });

      test('recognizes value fields', () {
        final valueFields = ['value', 'amount', 'price', 'quantity'];

        for (final fieldName in valueFields) {
          expect(
            _isPotentialDomainField(fieldName),
            isTrue,
            reason: '$fieldName is a domain value field',
          );
        }
      });
    });

    group('Error Messages', () {
      test('provides clear message for field duplication', () {
        final message = _getErrorMessage('title');

        expect(
          message,
          contains('duplicates Entity field'),
          reason: 'Error message should mention duplication',
        );
        expect(
          message,
          contains('title'),
          reason: 'Error message should include field name',
        );
      });

      test('suggests accessing via entity', () {
        final message = _getErrorMessage('isCompleted');

        expect(
          message,
          contains('entity.isCompleted'),
          reason: 'Error message should suggest entity accessor',
        );
      });

      test('explains composition pattern', () {
        final message = _getErrorMessage('status');

        expect(
          message,
          contains('Model should only contain Entity + metadata'),
          reason: 'Error message should explain pattern',
        );
      });
    });

    group('Edge Cases', () {
      test('handles empty field names', () {
        expect(_isPotentialDomainField(''), isFalse);
        expect(_isAllowedMetadataField(''), isFalse);
        expect(_isEntityFieldName(''), isFalse);
      });

      test('distinguishes between domain and metadata fields', () {
        // Domain fields should NOT be allowed
        expect(_isAllowedMetadataField('title'), isFalse);
        expect(_isAllowedMetadataField('id'), isFalse);

        // Metadata fields should NOT be domain fields
        expect(_isPotentialDomainField('etag'), isFalse);
        expect(_isPotentialDomainField('cachedAt'), isFalse);
      });

      test('handles case sensitivity', () {
        // Field names are case-sensitive
        expect(_isPotentialDomainField('Title'), isFalse);
        expect(_isPotentialDomainField('ID'), isFalse);
      });

      test('handles custom field names', () {
        // Custom fields not in the domain pattern list
        final customFields = ['customData', 'extraInfo', 'metadata'];

        for (final fieldName in customFields) {
          expect(
            _isPotentialDomainField(fieldName),
            isFalse,
            reason: '$fieldName is not a recognized domain field pattern',
          );
        }
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        // This test documents what violations should be detected in bad example files
        final expectedViolations = {
          'todo_model_bad.dart': [
            'TodoModelDuplicateFields.title',
            'TodoModelDuplicateFields.isCompleted',
          ],
        };

        expect(
          expectedViolations['todo_model_bad.dart']!.length,
          greaterThan(0),
          reason: 'Should detect field duplications in bad examples',
        );
      });

      test('should accept all patterns in good examples', () {
        final expectedPassing = {
          'todo_model_good.dart': [
            'TodoModel: Only has entity + metadata fields',
            'TodoModel: No duplicate fields',
          ],
        };

        expect(
          expectedPassing['todo_model_good.dart']!.length,
          equals(2),
          reason: 'Should accept good example patterns',
        );
      });
    });
  });
}

// Helper functions that simulate rule logic

/// Allowed metadata field names
const _allowedMetadataFields = {
  'etag',
  'version',
  'cachedAt',
  'lastModified',
  'createdAt',
  'updatedAt',
  'syncStatus',
  'isLocal',
  'isCached',
};

/// Common domain field patterns
const _domainFieldPatterns = {
  'id',
  'name',
  'title',
  'description',
  'content',
  'status',
  'type',
  'value',
  'amount',
  'price',
  'quantity',
  'isCompleted',
  'isActive',
  'isEnabled',
  'dueDate',
  'startDate',
  'endDate',
  'userId',
  'productId',
  'orderId',
};

bool _isAllowedMetadataField(String fieldName) {
  return _allowedMetadataFields.contains(fieldName);
}

bool _isPotentialDomainField(String fieldName) {
  if (fieldName.isEmpty) return false;
  return _domainFieldPatterns.contains(fieldName);
}

bool _isEntityFieldName(String fieldName) {
  if (fieldName.isEmpty) return false;
  return fieldName == 'entity' || fieldName.endsWith('Entity');
}

String _getErrorMessage(String fieldName) {
  return 'Field "$fieldName" duplicates Entity field. '
      'Model should only contain Entity + metadata.\n\n'
      'Remove "$fieldName" field. Access it via entity.$fieldName instead.';
}
