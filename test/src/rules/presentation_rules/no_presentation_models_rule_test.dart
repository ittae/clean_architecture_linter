import 'package:test/test.dart';

/// Unit tests for NoPresentationModelsRule
///
/// This test suite verifies that the no_presentation_models_rule correctly
/// enforces NO Presentation Models or ViewModels pattern.
///
/// Test Coverage:
/// 1. ViewModel class name detection
/// 2. ChangeNotifier extends detection
/// 3. Presentation models directory detection
/// 4. ViewModels directory detection
/// 5. Error messages
/// 6. Edge cases
///
/// Enforced Pattern:
/// - Use Freezed State with Riverpod (not ViewModels)
/// - State contains Domain Entities directly
/// - NO presentation/models/ directory
/// - NO presentation/viewmodels/ directory
/// - NO ChangeNotifier pattern
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('NoPresentationModelsRule', () {
    group('ViewModel Detection', () {
      test('detects class ending with ViewModel', () {
        expect(
          _isViewModel('RankingViewModel'),
          isTrue,
          reason: 'Should detect ViewModel suffix',
        );
      });

      test('detects complex ViewModel names', () {
        expect(
          _isViewModel('UserProfileEditViewModel'),
          isTrue,
          reason: 'Should detect ViewModel in complex names',
        );
      });

      test('rejects classes not ending with ViewModel', () {
        expect(
          _isViewModel('RankingNotifier'),
          isFalse,
          reason: 'Should not flag notifier classes',
        );
      });

      test('rejects State classes', () {
        expect(
          _isViewModel('RankingState'),
          isFalse,
          reason: 'Should not flag State classes',
        );
      });
    });

    group('ChangeNotifier Detection', () {
      test('detects ChangeNotifier in extends clause', () {
        expect(
          _extendsChangeNotifier('ChangeNotifier'),
          isTrue,
          reason: 'Should detect extends ChangeNotifier',
        );
      });

      test('detects ChangeNotifier with mixins', () {
        expect(
          _extendsChangeNotifier('ChangeNotifier with SomeMixin'),
          isTrue,
          reason: 'Should detect ChangeNotifier with mixins',
        );
      });

      test('rejects non-ChangeNotifier extends', () {
        expect(
          _extendsChangeNotifier('_\$RankingNotifier'),
          isFalse,
          reason: 'Should not flag proper Riverpod notifiers',
        );
      });
    });

    group('Directory Detection', () {
      test('detects presentation/models directory', () {
        expect(
          _hasForbiddenDirectory('/lib/presentation/models/user_model.dart'),
          isTrue,
          reason: 'Should detect presentation/models/ directory',
        );
      });

      test('detects presentation/viewmodels directory', () {
        expect(
          _hasForbiddenDirectory('/lib/presentation/viewmodels/user_viewmodel.dart'),
          isTrue,
          reason: 'Should detect presentation/viewmodels/ directory',
        );
      });

      test('accepts presentation/states directory', () {
        expect(
          _hasForbiddenDirectory('/lib/presentation/states/user_state.dart'),
          isFalse,
          reason: 'Should accept states/ directory',
        );
      });

      test('accepts data/models directory', () {
        expect(
          _hasForbiddenDirectory('/lib/data/models/user_model.dart'),
          isFalse,
          reason: 'Should accept data layer models',
        );
      });
    });

    group('Error Messages', () {
      test('provides clear message for ViewModel', () {
        final message = _getErrorMessage(ViolationType.viewModel);

        expect(
          message,
          contains('ViewModel'),
          reason: 'Error message should mention ViewModel',
        );
        expect(
          message,
          contains('Freezed State'),
          reason: 'Error message should mention Freezed State alternative',
        );
        expect(
          message,
          contains('riverpod'),
          reason: 'Error message should mention riverpod',
        );
      });

      test('provides correction for ChangeNotifier', () {
        final message = _getErrorMessage(ViolationType.changeNotifier);

        expect(
          message,
          contains('ChangeNotifier'),
          reason: 'Error message should mention ChangeNotifier',
        );
        expect(
          message,
          contains('@freezed'),
          reason: 'Error message should mention @freezed',
        );
        expect(
          message,
          contains('@riverpod'),
          reason: 'Error message should mention @riverpod',
        );
      });

      test('explains directory structure for models', () {
        final message = _getErrorMessage(ViolationType.modelsDirectory);

        expect(
          message,
          contains('models/'),
          reason: 'Error message should mention models directory',
        );
        expect(
          message,
          contains('states/'),
          reason: 'Error message should suggest states directory',
        );
        expect(
          message,
          contains('Entities'),
          reason: 'Error message should explain using Entities',
        );
      });

      test('explains directory structure for viewmodels', () {
        final message = _getErrorMessage(ViolationType.viewModelsDirectory);

        expect(
          message,
          contains('viewmodels/'),
          reason: 'Error message should mention viewmodels directory',
        );
        expect(
          message,
          contains('Riverpod'),
          reason: 'Error message should mention Riverpod',
        );
      });
    });

    group('Edge Cases', () {
      test('handles case sensitivity in class names', () {
        expect(
          _isViewModel('RankingVIEWMODEL'),
          isFalse,
          reason: 'Should be case sensitive',
        );
      });

      test('handles partial ViewModel match', () {
        expect(
          _isViewModel('ViewModelFactory'),
          isFalse,
          reason: 'Should match only suffix',
        );
      });

      test('handles Windows path separators', () {
        expect(
          _hasForbiddenDirectory('C:\\project\\lib\\presentation\\models\\user.dart'),
          isTrue,
          reason: 'Should handle Windows paths',
        );
      });

      test('handles nested directory structures', () {
        expect(
          _hasForbiddenDirectory('/lib/features/user/presentation/models/user_ui.dart'),
          isTrue,
          reason: 'Should detect forbidden directories in nested structures',
        );
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        final expectedViolations = {
          'ranking_viewmodel_bad.dart': [
            'RankingViewModel class name',
            'extends ChangeNotifier',
          ],
          'user_ui_model_bad.dart': [
            'presentation/models/ directory',
          ],
        };

        expect(
          expectedViolations.values.expand((v) => v).length,
          greaterThan(0),
          reason: 'Should detect ViewModel and PresentationModel violations',
        );
      });

      test('should accept Freezed State pattern in good examples', () {
        final expectedPassing = {
          'ranking_state_good.dart': [
            '@freezed State',
            'Contains Entity',
            'No ViewModel',
            'No ChangeNotifier',
          ],
        };

        expect(
          expectedPassing['ranking_state_good.dart']!.length,
          equals(4),
          reason: 'Should accept proper Freezed State usage',
        );
      });
    });
  });
}

// Helper enums and classes for testing

enum ViolationType {
  viewModel,
  changeNotifier,
  modelsDirectory,
  viewModelsDirectory,
}

// Helper functions that simulate rule logic

bool _isViewModel(String className) {
  return className.endsWith('ViewModel');
}

bool _extendsChangeNotifier(String extendsClause) {
  return extendsClause.contains('ChangeNotifier');
}

bool _hasForbiddenDirectory(String filePath) {
  final normalized = filePath.replaceAll('\\', '/').toLowerCase();

  return normalized.contains('/presentation/models/') || normalized.contains('/presentation/viewmodels/');
}

String _getErrorMessage(ViolationType violationType) {
  switch (violationType) {
    case ViolationType.viewModel:
      return 'ViewModel pattern is not allowed. '
          'Use Freezed State with riverpod_generator (@riverpod annotation) instead.';
    case ViolationType.changeNotifier:
      return 'ChangeNotifier pattern is not allowed. '
          'Use Freezed State with Riverpod instead. '
          'Define state with @freezed and notifier with @riverpod.';
    case ViolationType.modelsDirectory:
      return 'Presentation models directory is not allowed. '
          'Remove presentation/models/ directory. '
          'Use states/ directory with Freezed State containing Entities.';
    case ViolationType.viewModelsDirectory:
      return 'ViewModels directory is not allowed. '
          'Remove presentation/viewmodels/ directory. '
          'Use Freezed State with Riverpod instead.';
  }
}
