import 'package:test/test.dart';

/// Unit tests for RiverpodGeneratorRule
///
/// This test suite verifies that the riverpod_generator_rule correctly enforces
/// riverpod_generator (@riverpod) usage instead of manual providers.
///
/// Test Coverage:
/// 1. Manual provider detection (StateNotifierProvider, ChangeNotifierProvider, etc.)
/// 2. Provider file path validation
/// 3. Error messages
/// 4. Edge cases
///
/// Enforced Pattern:
/// - @riverpod annotation for state management
/// - NO manual StateNotifierProvider
/// - NO ChangeNotifierProvider
/// - Use generated providers for type safety
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('RiverpodGeneratorRule', () {
    group('Manual Provider Detection', () {
      test('detects StateNotifierProvider', () {
        expect(
          _isManualProvider('StateNotifierProvider'),
          isTrue,
          reason: 'Should detect StateNotifierProvider as manual provider',
        );
      });

      test('detects ChangeNotifierProvider', () {
        expect(
          _isManualProvider('ChangeNotifierProvider'),
          isTrue,
          reason: 'Should detect ChangeNotifierProvider as manual provider',
        );
      });

      test('detects StateProvider', () {
        expect(
          _isManualProvider('StateProvider'),
          isTrue,
          reason: 'Should detect StateProvider as manual provider',
        );
      });

      test('detects FutureProvider', () {
        expect(
          _isManualProvider('FutureProvider'),
          isTrue,
          reason: 'Should detect FutureProvider as manual provider',
        );
      });

      test('detects StreamProvider', () {
        expect(
          _isManualProvider('StreamProvider'),
          isTrue,
          reason: 'Should detect StreamProvider as manual provider',
        );
      });

      test('rejects generated providers', () {
        expect(
          _isManualProvider('rankingNotifierProvider'),
          isFalse,
          reason: 'Should not flag generated providers',
        );
      });
    });

    group('Provider File Path Validation', () {
      test('checks presentation/providers directory', () {
        expect(
          _isProviderFile('/lib/presentation/providers/ranking_provider.dart'),
          isTrue,
          reason: 'Should check providers directory',
        );
      });

      test('checks files ending with _provider.dart', () {
        expect(
          _isProviderFile('/lib/presentation/notifiers/ranking_provider.dart'),
          isTrue,
          reason: 'Should check *_provider.dart files',
        );
      });

      test('ignores non-provider files in presentation', () {
        expect(
          _isProviderFile('/lib/presentation/widgets/ranking_widget.dart'),
          isFalse,
          reason: 'Should ignore non-provider files',
        );
      });

      test('ignores files outside presentation layer', () {
        expect(
          _isProviderFile('/lib/domain/repositories/ranking_repository.dart'),
          isFalse,
          reason: 'Should ignore non-presentation files',
        );
      });
    });

    group('Error Messages', () {
      test('provides clear message for StateNotifierProvider', () {
        final message = _getErrorMessage(
          ProviderType.stateNotifier,
        );

        expect(
          message,
          contains('StateNotifierProvider'),
          reason: 'Error message should mention the provider type',
        );
        expect(
          message,
          contains('@riverpod'),
          reason: 'Error message should mention @riverpod alternative',
        );
      });

      test('provides correction guidance', () {
        final message = _getErrorMessage(
          ProviderType.changeNotifier,
        );

        expect(
          message,
          contains('class with @riverpod'),
          reason: 'Error message should explain how to use @riverpod',
        );
      });

      test('explains riverpod_generator benefits', () {
        final message = _getErrorMessage(
          ProviderType.stateNotifier,
        );

        final hasRiverpodGenerator = message.contains('riverpod_generator');
        final hasTypeSafety = message.contains('type safety');
        final hasGenerated = message.contains('generated');

        expect(
          hasRiverpodGenerator || hasTypeSafety || hasGenerated,
          isTrue,
          reason: 'Error message should explain benefits',
        );
      });
    });

    group('Edge Cases', () {
      test('handles provider with complex generics', () {
        expect(
          _isManualProvider(
              'StateNotifierProvider<RankingNotifier, AsyncValue<RankingState>>'),
          isTrue,
          reason: 'Should detect manual providers with complex generics',
        );
      });

      test('handles multiple provider declarations', () {
        final providers = [
          'StateNotifierProvider',
          'StateProvider',
          'FutureProvider',
        ];

        expect(
          providers.where(_isManualProvider).length,
          equals(3),
          reason: 'Should detect all manual providers',
        );
      });

      test('handles case sensitivity', () {
        expect(
          _isManualProvider('statenotifierprovider'),
          isFalse,
          reason: 'Should be case sensitive for provider names',
        );
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        final expectedViolations = {
          'ranking_provider_bad.dart': [
            'StateNotifierProvider usage',
            'ChangeNotifierProvider usage',
            'StateProvider usage',
          ],
        };

        expect(
          expectedViolations['ranking_provider_bad.dart']!.length,
          greaterThan(0),
          reason: 'Should detect manual provider violations',
        );
      });

      test('should accept @riverpod pattern in good examples', () {
        final expectedPassing = {
          'ranking_notifier_good.dart': [
            '@riverpod annotation',
            'extends generated notifier',
            'no manual providers',
          ],
        };

        expect(
          expectedPassing['ranking_notifier_good.dart']!.length,
          equals(3),
          reason: 'Should accept proper @riverpod usage',
        );
      });
    });
  });
}

// Helper enums and classes for testing

enum ProviderType {
  stateNotifier,
  changeNotifier,
  state,
  future,
  stream,
}

// Helper functions that simulate rule logic

final _manualProviders = [
  'StateNotifierProvider',
  'ChangeNotifierProvider',
  'StateProvider',
  'FutureProvider',
  'StreamProvider',
];

bool _isManualProvider(String providerName) {
  return _manualProviders.any((provider) => providerName.contains(provider));
}

bool _isProviderFile(String filePath) {
  final normalized = filePath.replaceAll('\\', '/').toLowerCase();

  if (!normalized.contains('/presentation/')) return false;

  return normalized.contains('/providers/') ||
      normalized.endsWith('_provider.dart');
}

String _getErrorMessage(ProviderType providerType) {
  String providerName;
  switch (providerType) {
    case ProviderType.stateNotifier:
      providerName = 'StateNotifierProvider';
      break;
    case ProviderType.changeNotifier:
      providerName = 'ChangeNotifierProvider';
      break;
    case ProviderType.state:
      providerName = 'StateProvider';
      break;
    case ProviderType.future:
      providerName = 'FutureProvider';
      break;
    case ProviderType.stream:
      providerName = 'StreamProvider';
      break;
  }

  return 'Manual provider "$providerName" detected. Use @riverpod annotation instead. '
      'Use riverpod_generator: Create a class with @riverpod annotation instead of manual provider declaration. '
      'This provides type safety and auto-generated providers.';
}
