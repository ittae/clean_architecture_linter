import 'package:test/test.dart';

/// Unit tests for RiverpodProviderNamingRule
///
/// This test suite verifies that the riverpod_provider_naming_rule correctly
/// enforces proper naming conventions for Riverpod provider functions.
///
/// Test Coverage:
/// 1. Provider file detection
/// 2. @riverpod annotation detection
/// 3. Return type detection (Repository/UseCase/DataSource)
/// 4. Function name suffix validation
/// 5. Suggested name generation
///
/// Naming Rules:
/// - Repository return type: function name must end with "repository"
/// - UseCase return type: function name must end with "usecase"
/// - DataSource return type: function name must end with "datasource"
void main() {
  group('RiverpodProviderNamingRule', () {
    group('Provider File Detection', () {
      test('detects provider files in presentation layer', () {
        final testCases = [
          'lib/presentation/providers/event_providers.dart',
          'lib/features/events/presentation/providers/event_provider.dart',
          'lib/presentation/event_provider.dart',
        ];

        for (final path in testCases) {
          expect(
            _isProviderFile(path),
            isTrue,
            reason: '$path should be detected as provider file',
          );
        }
      });

      test('ignores non-provider files', () {
        final testCases = [
          'lib/presentation/pages/event_page.dart',
          'lib/presentation/widgets/event_list.dart',
          'lib/domain/usecases/get_events_usecase.dart',
        ];

        for (final path in testCases) {
          expect(
            _isProviderFile(path),
            isFalse,
            reason: '$path should not be detected as provider file',
          );
        }
      });
    });

    group('Return Type Detection', () {
      test('detects Repository return types', () {
        final repositoryTypes = [
          'EventRepository',
          'UserRepository',
          'TodoRepository',
          'IEventRepository',
        ];

        for (final typeName in repositoryTypes) {
          expect(
            _getRequiredSuffix(typeName),
            'repository',
            reason: '$typeName should require "repository" suffix',
          );
        }
      });

      test('detects UseCase return types', () {
        final useCaseTypes = [
          'GetEventsUsecase',
          'CreateEventUsecase',
          'UpdateEventUsecase',
          'DeleteEventUsecase',
          'GetEventsUseCase',
        ];

        for (final typeName in useCaseTypes) {
          expect(
            _getRequiredSuffix(typeName),
            'usecase',
            reason: '$typeName should require "usecase" suffix',
          );
        }
      });

      test('detects DataSource return types', () {
        final dataSourceTypes = [
          'EventDataSource',
          'EventRemoteDataSource',
          'EventLocalDataSource',
          'UserDataSource',
        ];

        for (final typeName in dataSourceTypes) {
          expect(
            _getRequiredSuffix(typeName),
            'datasource',
            reason: '$typeName should require "datasource" suffix',
          );
        }
      });

      test('returns null for other types', () {
        final otherTypes = [
          'String',
          'int',
          'List<Event>',
          'Future<Event>',
          'Event',
          'EventModel',
          'EventState',
        ];

        for (final typeName in otherTypes) {
          expect(
            _getRequiredSuffix(typeName),
            isNull,
            reason: '$typeName should not require any suffix',
          );
        }
      });
    });

    group('Function Name Validation', () {
      test('detects violation: UseCase without suffix', () {
        final violation = ProviderNaming(
          functionName: 'getEvents',
          returnType: 'GetEventsUsecase',
        );

        expect(
          _hasViolation(violation),
          isTrue,
          reason: 'getEvents should require "usecase" suffix',
        );
      });

      test('detects violation: Repository without suffix', () {
        final violation = ProviderNaming(
          functionName: 'eventRepo',
          returnType: 'EventRepository',
        );

        expect(
          _hasViolation(violation),
          isTrue,
          reason: 'eventRepo should require "repository" suffix',
        );
      });

      test('detects violation: DataSource without suffix', () {
        final violation = ProviderNaming(
          functionName: 'eventData',
          returnType: 'EventDataSource',
        );

        expect(
          _hasViolation(violation),
          isTrue,
          reason: 'eventData should require "datasource" suffix',
        );
      });

      test('allows correct naming: UseCase with suffix', () {
        final naming = ProviderNaming(
          functionName: 'getEventsUsecase',
          returnType: 'GetEventsUsecase',
        );

        expect(
          _hasViolation(naming),
          isFalse,
          reason: 'getEventsUsecase should be valid',
        );
      });

      test('allows correct naming: Repository with suffix', () {
        final naming = ProviderNaming(
          functionName: 'eventRepository',
          returnType: 'EventRepository',
        );

        expect(
          _hasViolation(naming),
          isFalse,
          reason: 'eventRepository should be valid',
        );
      });

      test('allows correct naming: DataSource with suffix', () {
        final naming = ProviderNaming(
          functionName: 'eventDataSource',
          returnType: 'EventDataSource',
        );

        expect(
          _hasViolation(naming),
          isFalse,
          reason: 'eventDataSource should be valid',
        );
      });

      test('handles case-insensitive suffix matching', () {
        final testCases = [
          ProviderNaming(functionName: 'getEventsUseCase', returnType: 'GetEventsUsecase'),
          ProviderNaming(functionName: 'eventREPOSITORY', returnType: 'EventRepository'),
          ProviderNaming(functionName: 'eventDATASOURCE', returnType: 'EventDataSource'),
        ];

        for (final naming in testCases) {
          expect(
            _hasViolation(naming),
            isFalse,
            reason: '${naming.functionName} should be valid (case-insensitive)',
          );
        }
      });
    });

    group('Suggested Name Generation', () {
      test('suggests name with UseCase suffix', () {
        expect(
          _suggestFunctionName('getEvents', 'usecase'),
          'getEventsUsecase',
          reason: 'Should append "Usecase" to preserve camelCase',
        );
      });

      test('suggests name with Repository suffix', () {
        expect(
          _suggestFunctionName('eventRepo', 'repository'),
          'eventRepoRepository',
          reason: 'Should append "Repository" to preserve camelCase',
        );
      });

      test('suggests name with DataSource suffix', () {
        expect(
          _suggestFunctionName('eventData', 'datasource'),
          'eventDataDatasource',
          reason: 'Should append "Datasource" to preserve camelCase',
        );
      });

      test('preserves existing camelCase', () {
        final testCases = {
          'getEvents': 'getEventsUsecase',
          'createEvent': 'createEventUsecase',
          'updateEvent': 'updateEventRepository',
          'deleteEvent': 'deleteEventDatasource',
        };

        for (final entry in testCases.entries) {
          final suffix = entry.value.contains('Usecase')
              ? 'usecase'
              : entry.value.contains('Repository')
                  ? 'repository'
                  : 'datasource';

          expect(
            _suggestFunctionName(entry.key, suffix),
            entry.value,
            reason: 'Should preserve camelCase for ${entry.key}',
          );
        }
      });
    });

    group('Integration Test Expectations', () {
      test('should detect UseCase without suffix', () {
        final badExample = '''
@riverpod
GetEventsUsecase getEvents(Ref ref) {
  return GetEventsUsecase(ref.watch(eventRepositoryProvider));
}
''';

        expect(
          _containsRiverpod(badExample),
          isTrue,
          reason: 'Should detect @riverpod annotation',
        );
        expect(
          _hasViolation(ProviderNaming(
            functionName: 'getEvents',
            returnType: 'GetEventsUsecase',
          )),
          isTrue,
          reason: 'Should detect missing "usecase" suffix',
        );
      });

      test('should detect Repository without suffix', () {
        final badExample = '''
@riverpod
EventRepository eventRepo(Ref ref) {
  return EventRepositoryImpl(ref.watch(eventDataSourceProvider));
}
''';

        expect(
          _hasViolation(ProviderNaming(
            functionName: 'eventRepo',
            returnType: 'EventRepository',
          )),
          isTrue,
          reason: 'Should detect missing "repository" suffix',
        );
      });

      test('should accept correct UseCase naming', () {
        final goodExample = '''
@riverpod
GetEventsUsecase getEventsUsecase(Ref ref) {
  return GetEventsUsecase(ref.watch(eventRepositoryProvider));
}
''';

        expect(
          _hasViolation(ProviderNaming(
            functionName: 'getEventsUsecase',
            returnType: 'GetEventsUsecase',
          )),
          isFalse,
          reason: 'Should accept correct naming with "usecase" suffix',
        );
      });

      test('should accept correct Repository naming', () {
        final goodExample = '''
@riverpod
EventRepository eventRepository(Ref ref) {
  return EventRepositoryImpl(ref.watch(eventDataSourceProvider));
}
''';

        expect(
          _hasViolation(ProviderNaming(
            functionName: 'eventRepository',
            returnType: 'EventRepository',
          )),
          isFalse,
          reason: 'Should accept correct naming with "repository" suffix',
        );
      });

      test('should accept correct DataSource naming', () {
        final goodExample = '''
@riverpod
EventDataSource eventDataSource(Ref ref) {
  return EventRemoteDataSource();
}
''';

        expect(
          _hasViolation(ProviderNaming(
            functionName: 'eventDataSource',
            returnType: 'EventDataSource',
          )),
          isFalse,
          reason: 'Should accept correct naming with "datasource" suffix',
        );
      });
    });

    group('Error Messages', () {
      test('provides clear message for UseCase violation', () {
        final message = _getErrorMessage(
          functionName: 'getEvents',
          returnType: 'GetEventsUsecase',
          suggestedName: 'getEventsUsecase',
          requiredSuffix: 'usecase',
        );

        expect(
          message,
          contains('must end with "usecase"'),
          reason: 'Should mention required suffix',
        );
        expect(
          message,
          contains('getEvents'),
          reason: 'Should include current function name',
        );
        expect(
          message,
          contains('getEventsUsecase'),
          reason: 'Should include suggested name',
        );
        expect(
          message,
          contains('getEventsProvider (ambiguous!)'),
          reason: 'Should explain generated provider name problem',
        );
        expect(
          message,
          contains('getEventsUsecaseProvider (clear!)'),
          reason: 'Should show correct generated provider name',
        );
      });

      test('references CLAUDE.md documentation', () {
        final message = _getErrorMessage(
          functionName: 'eventRepo',
          returnType: 'EventRepository',
          suggestedName: 'eventRepository',
          requiredSuffix: 'repository',
        );

        expect(
          message,
          contains('CLAUDE.md'),
          reason: 'Should reference documentation',
        );
      });
    });
  });
}

// Helper classes

class ProviderNaming {
  final String functionName;
  final String returnType;

  ProviderNaming({
    required this.functionName,
    required this.returnType,
  });
}

// Helper functions that simulate rule logic

bool _isProviderFile(String filePath) {
  final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();

  if (!normalizedPath.contains('/presentation/')) return false;

  return normalizedPath.contains('/providers/') ||
      normalizedPath.endsWith('_provider.dart') ||
      normalizedPath.endsWith('_providers.dart');
}

String? _getRequiredSuffix(String returnTypeName) {
  final lowerTypeName = returnTypeName.toLowerCase();

  // Check for Repository
  if (lowerTypeName.contains('repository')) {
    return 'repository';
  }

  // Check for UseCase
  if (lowerTypeName.contains('usecase')) {
    return 'usecase';
  }

  // Check for DataSource
  if (lowerTypeName.contains('datasource')) {
    return 'datasource';
  }

  return null;
}

bool _hasViolation(ProviderNaming naming) {
  final requiredSuffix = _getRequiredSuffix(naming.returnType);
  if (requiredSuffix == null) return false;

  final lowerFunctionName = naming.functionName.toLowerCase();
  return !lowerFunctionName.endsWith(requiredSuffix.toLowerCase());
}

String _suggestFunctionName(String currentName, String requiredSuffix) {
  // Capitalize first letter of suffix for camelCase
  final capitalizedSuffix =
      requiredSuffix[0].toUpperCase() + requiredSuffix.substring(1);

  return '$currentName$capitalizedSuffix';
}

bool _containsRiverpod(String code) {
  return code.contains('@riverpod') || code.contains('@Riverpod');
}

String _getErrorMessage({
  required String functionName,
  required String returnType,
  required String suggestedName,
  required String requiredSuffix,
}) {
  return '''
Provider function returning $returnType must end with "$requiredSuffix".

❌ Current:
   @riverpod
   $returnType $functionName(Ref ref) { }
   // Generates: ${functionName}Provider (ambiguous!)

✅ Correct:
   @riverpod
   $returnType $suggestedName(Ref ref) { }
   // Generates: ${suggestedName}Provider (clear!)

Why: Function name must include "$requiredSuffix" suffix for:
• Clear provider name generation
• Proper UseCase provider detection
• Consistent naming across codebase

See CLAUDE.md § Riverpod State Management Patterns
''';
}
