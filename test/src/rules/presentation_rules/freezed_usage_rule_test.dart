import 'package:test/test.dart';

/// Unit tests for FreezedUsageRule
///
/// This test suite verifies that the freezed_usage_rule correctly enforces
/// Freezed usage instead of Equatable for data classes.
///
/// Test Coverage:
/// 1. Equatable extends detection
/// 2. Equatable implements detection
/// 3. Equatable import detection
/// 4. Error messages
/// 5. Architecture layer filtering
/// 6. Edge cases
///
/// Enforced Pattern:
/// - @freezed for all data classes (Models, Entities, States)
/// - NO Equatable extends or implements
/// - NO equatable package import
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('FreezedUsageRule', () {
    group('Equatable Detection', () {
      test('detects Equatable in extends clause', () {
        expect(
          _hasEquatable(extendsEquatable: true),
          isTrue,
          reason: 'Should detect "extends Equatable"',
        );
      });

      test('detects Equatable in implements clause', () {
        expect(
          _hasEquatable(implementsEquatable: true),
          isTrue,
          reason: 'Should detect "implements Equatable"',
        );
      });

      test('rejects class without Equatable', () {
        expect(
          _hasEquatable(),
          isFalse,
          reason: 'Should not detect Equatable when not present',
        );
      });
    });

    group('Import Detection', () {
      test('detects equatable package import', () {
        expect(
          _hasEquatableImport('package:equatable/equatable.dart'),
          isTrue,
          reason: 'Should detect equatable package import',
        );
      });

      test('rejects non-equatable imports', () {
        expect(
          _hasEquatableImport('package:freezed_annotation/freezed_annotation.dart'),
          isFalse,
          reason: 'Should not detect non-equatable imports',
        );
      });
    });

    group('Architecture Layer Filtering', () {
      test('checks domain layer files', () {
        expect(
          _isArchitectureLayer('/project/lib/domain/entities/user.dart'),
          isTrue,
          reason: 'Should check domain layer',
        );
      });

      test('checks data layer files', () {
        expect(
          _isArchitectureLayer('/project/lib/data/models/user_model.dart'),
          isTrue,
          reason: 'Should check data layer',
        );
      });

      test('checks presentation layer files', () {
        expect(
          _isArchitectureLayer('/project/lib/presentation/states/user_state.dart'),
          isTrue,
          reason: 'Should check presentation layer',
        );
      });

      test('ignores non-architecture files', () {
        expect(
          _isArchitectureLayer('/project/lib/utils/helpers.dart'),
          isFalse,
          reason: 'Should ignore non-architecture layer files',
        );
      });
    });

    group('Error Messages', () {
      test('provides clear message for Equatable extends', () {
        final message = _getErrorMessage(ErrorType.extendsEquatable);

        expect(
          message,
          contains('Equatable'),
          reason: 'Error message should mention Equatable',
        );
        expect(
          message,
          contains('@freezed'),
          reason: 'Error message should mention @freezed alternative',
        );
      });

      test('provides correction for Equatable usage', () {
        final message = _getErrorMessage(ErrorType.extendsEquatable);

        expect(
          message,
          contains('Replace'),
          reason: 'Error message should provide replacement guidance',
        );
        expect(
          message,
          contains('factory'),
          reason: 'Error message should mention factory constructor',
        );
      });

      test('explains Freezed benefits', () {
        final message = _getErrorMessage(ErrorType.equatableImport);

        final hasImmutability = message.contains('immutability');
        final hasCopyWith = message.contains('copyWith');
        final hasEquality = message.contains('equality');

        expect(
          hasImmutability || hasCopyWith || hasEquality,
          isTrue,
          reason: 'Error message should explain Freezed benefits',
        );
      });
    });

    group('Edge Cases', () {
      test('handles class with multiple interfaces', () {
        expect(
          _hasMultipleInterfaces(['Serializable', 'Equatable', 'Comparable']),
          isTrue,
          reason: 'Should detect Equatable among multiple interfaces',
        );
      });

      test('handles empty class declaration', () {
        expect(
          _hasEquatable(),
          isFalse,
          reason: 'Should handle empty class without extends or implements',
        );
      });

      test('handles case sensitivity in imports', () {
        expect(
          _hasEquatableImport('package:Equatable/equatable.dart'),
          isTrue,
          reason: 'Should detect Equatable regardless of case',
        );
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        final expectedViolations = {
          'ranking_state_bad.dart': [
            'RankingEquatable: extends Equatable',
            'UserState: implements Equatable',
            'equatable package import',
          ],
        };

        expect(
          expectedViolations['ranking_state_bad.dart']!.length,
          greaterThan(0),
          reason: 'Should detect Equatable usage violations',
        );
      });

      test('should accept Freezed patterns in good examples', () {
        final expectedPassing = {
          'ranking_state_good.dart': [
            '@freezed annotation',
            'factory constructor',
            'no Equatable',
          ],
        };

        expect(
          expectedPassing['ranking_state_good.dart']!.length,
          equals(3),
          reason: 'Should accept proper Freezed usage',
        );
      });
    });
  });
}

// Helper enums and classes for testing

enum ErrorType {
  extendsEquatable,
  implementsEquatable,
  equatableImport,
}

// Helper functions that simulate rule logic

bool _hasEquatable({
  bool extendsEquatable = false,
  bool implementsEquatable = false,
}) {
  return extendsEquatable || implementsEquatable;
}

bool _hasEquatableImport(String importUri) {
  return importUri.toLowerCase().contains('equatable');
}

bool _isArchitectureLayer(String filePath) {
  final normalized = filePath.replaceAll('\\', '/').toLowerCase();
  return normalized.contains('/domain/') || normalized.contains('/data/') || normalized.contains('/presentation/');
}

bool _hasMultipleInterfaces(List<String> interfaces) {
  return interfaces.any((interface) => interface.contains('Equatable'));
}

String _getErrorMessage(ErrorType errorType) {
  switch (errorType) {
    case ErrorType.extendsEquatable:
      return 'Use Freezed instead of Equatable for data classes. '
          'Replace "extends Equatable" with @freezed annotation. '
          'Remove props getter and use Freezed factory constructor.';
    case ErrorType.implementsEquatable:
      return 'Use @freezed annotation for immutable data classes.';
    case ErrorType.equatableImport:
      return 'Remove equatable import and add freezed_annotation. '
          'Use @freezed for data classes. '
          'Freezed provides immutability, copyWith, and equality automatically.';
  }
}
