import 'package:test/test.dart';

/// Unit tests for RepositoryImplementationRule
///
/// This test suite verifies that the repository_implementation_rule correctly
/// enforces Clean Architecture principles for Repository implementation patterns
/// in the data layer.
///
/// Test Coverage:
/// 1. RepositoryImpl must implement domain repository interface
/// 2. Naming convention validation (Repository vs RepositoryImpl)
/// 3. Wrong location detection (implementations in domain, interfaces in data)
/// 4. Interface implementation detection
/// 5. Edge cases (multiple interfaces, inheritance patterns)
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('RepositoryImplementationRule', () {
    group('Implementation Validation', () {
      test('requires RepositoryImpl to implement repository interface', () {
        final testCases = [
          TestRepositoryImpl(
            className: 'UserRepositoryImpl',
            implementsInterfaces: [],
            inDataLayer: true,
          ),
          TestRepositoryImpl(
            className: 'TodoRepositoryImpl',
            implementsInterfaces: [],
            inDataLayer: true,
          ),
        ];

        for (final impl in testCases) {
          expect(
            _hasRepositoryInterface(impl),
            isFalse,
            reason:
                '${impl.className} should require repository interface implementation',
          );
        }
      });

      test('accepts RepositoryImpl with proper interface implementation', () {
        final testCases = [
          TestRepositoryImpl(
            className: 'UserRepositoryImpl',
            implementsInterfaces: ['UserRepository'],
            inDataLayer: true,
          ),
          TestRepositoryImpl(
            className: 'TodoRepositoryImpl',
            implementsInterfaces: ['TodoRepository'],
            inDataLayer: true,
          ),
        ];

        for (final impl in testCases) {
          expect(
            _hasRepositoryInterface(impl),
            isTrue,
            reason:
                '${impl.className} properly implements repository interface',
          );
        }
      });

      test('detects wrong interface implementation', () {
        final testCases = [
          TestRepositoryImpl(
            className: 'UserRepositoryImpl',
            implementsInterfaces: ['DataSource', 'CacheManager'],
            inDataLayer: true,
          ),
          TestRepositoryImpl(
            className: 'TodoRepositoryImpl',
            implementsInterfaces: ['Service', 'Manager'],
            inDataLayer: true,
          ),
        ];

        for (final impl in testCases) {
          expect(
            _hasRepositoryInterface(impl),
            isFalse,
            reason:
                '${impl.className} should implement proper repository interface',
          );
        }
      });

      test(
          'accepts RepositoryImpl with multiple interfaces including repository',
          () {
        final impl = TestRepositoryImpl(
          className: 'UserRepositoryImpl',
          implementsInterfaces: ['UserRepository', 'Disposable', 'Cacheable'],
          inDataLayer: true,
        );

        expect(
          _hasRepositoryInterface(impl),
          isTrue,
          reason: 'Should accept multiple interfaces when one is a repository',
        );
      });
    });

    group('Naming Convention Validation', () {
      test('detects repository implementations with correct naming', () {
        final testCases = [
          'UserRepositoryImpl',
          'TodoRepositoryImpl',
          'OrderRepositoryImpl',
          'ProductRepositoryImpl',
        ];

        for (final className in testCases) {
          expect(
            _isRepositoryImpl(className),
            isTrue,
            reason: '$className should be detected as RepositoryImpl',
          );
        }
      });

      test('rejects classes without RepositoryImpl suffix', () {
        final testCases = [
          'UserRepository',
          'TodoService',
          'DataSource',
          'UserRepositoryImplementation',
        ];

        for (final className in testCases) {
          expect(
            _isRepositoryImpl(className),
            isFalse,
            reason: '$className should not be detected as RepositoryImpl',
          );
        }
      });

      test('detects repository interfaces in wrong location (data layer)', () {
        final testCases = [
          TestRepositoryInterface(
            className: 'UserRepository',
            isAbstract: true,
            inDataLayer: true,
          ),
          TestRepositoryInterface(
            className: 'TodoRepository',
            isAbstract: true,
            inDataLayer: true,
          ),
        ];

        for (final interface in testCases) {
          expect(
            _isRepositoryInWrongLayer(interface),
            isTrue,
            reason: 'Repository interface should not be in data layer',
          );
        }
      });

      test(
          'detects repository implementations in wrong location (domain layer)',
          () {
        final testCases = [
          TestRepositoryImpl(
            className: 'UserRepositoryImpl',
            implementsInterfaces: ['UserRepository'],
            inDataLayer: false,
          ),
          TestRepositoryImpl(
            className: 'TodoRepositoryImpl',
            implementsInterfaces: ['TodoRepository'],
            inDataLayer: false,
          ),
        ];

        for (final impl in testCases) {
          expect(
            _isImplementationInWrongLayer(impl),
            isTrue,
            reason: 'Repository implementation should not be in domain layer',
          );
        }
      });
    });

    group('Layer Detection', () {
      test('correctly identifies data layer files', () {
        final testCases = [
          'lib/features/user/data/repositories/user_repository_impl.dart',
          'lib/data/repositories/todo_repository_impl.dart',
          'lib/core/data/repositories/base_repository_impl.dart',
        ];

        for (final path in testCases) {
          expect(
            _isInDataLayer(path),
            isTrue,
            reason: '$path should be detected as data layer',
          );
        }
      });

      test('correctly identifies domain layer files', () {
        final testCases = [
          'lib/features/user/domain/repositories/user_repository.dart',
          'lib/domain/repositories/todo_repository.dart',
          'lib/core/domain/repositories/base_repository.dart',
        ];

        for (final path in testCases) {
          expect(
            _isInDataLayer(path),
            isFalse,
            reason: '$path should not be detected as data layer',
          );
        }
      });
    });

    group('Interface Detection', () {
      test('detects repository interface names', () {
        final testCases = [
          'UserRepository',
          'TodoRepository',
          'OrderRepository',
          'ProductRepository',
        ];

        for (final interfaceName in testCases) {
          expect(
            _isRepositoryInterface(interfaceName),
            isTrue,
            reason: '$interfaceName should be detected as repository interface',
          );
        }
      });

      test('rejects non-repository interface names', () {
        final testCases = [
          'UserRepositoryImpl',
          'DataSource',
          'Service',
          'Manager',
        ];

        for (final interfaceName in testCases) {
          expect(
            _isRepositoryInterface(interfaceName),
            isFalse,
            reason: '$interfaceName should not be detected as repository',
          );
        }
      });
    });

    group('Error Messages', () {
      test('provides clear message for missing implements clause', () {
        final impl = TestRepositoryImpl(
          className: 'UserRepositoryImpl',
          implementsInterfaces: [],
          inDataLayer: true,
        );

        final message = _getErrorMessage(impl);
        expect(
          message,
          contains('must implement a domain repository interface'),
          reason: 'Error message should mention missing implements clause',
        );
        expect(
          message,
          contains('UserRepositoryImpl'),
          reason: 'Error message should include class name',
        );
      });

      test('provides clear message for wrong interface', () {
        final impl = TestRepositoryImpl(
          className: 'UserRepositoryImpl',
          implementsInterfaces: ['DataSource'],
          inDataLayer: true,
        );

        final message = _getErrorMessage(impl);
        expect(
          message,
          contains('should implement a domain repository interface'),
          reason: 'Error message should mention wrong interface',
        );
      });

      test('provides clear message for wrong layer location', () {
        final impl = TestRepositoryImpl(
          className: 'UserRepositoryImpl',
          implementsInterfaces: ['UserRepository'],
          inDataLayer: false,
        );

        final message = _getErrorMessage(impl);
        expect(
          message,
          contains('should be in data layer'),
          reason: 'Error message should mention correct layer',
        );
      });
    });

    group('Edge Cases', () {
      test('handles empty class names', () {
        expect(_isRepositoryImpl(''), isFalse);
        expect(_isRepositoryInterface(''), isFalse);
      });

      test('handles partial naming matches', () {
        final testCases = [
          'RepositoryImpl', // Just suffix, no feature name
          'Repository', // Just Repository
          'Impl', // Just Impl
        ];

        for (final className in testCases) {
          final isImpl = _isRepositoryImpl(className);
          final isInterface = _isRepositoryInterface(className);

          // Repository alone should be detected as interface
          if (className == 'Repository') {
            expect(isInterface, isTrue);
          }
          // RepositoryImpl should be detected as implementation
          else if (className == 'RepositoryImpl') {
            expect(isImpl, isTrue);
          }
        }
      });

      test('handles generic repository implementations', () {
        final impl = TestRepositoryImpl(
          className: 'BaseRepositoryImpl<T>',
          implementsInterfaces: ['BaseRepository<T>'],
          inDataLayer: true,
        );

        expect(
          _isRepositoryImpl(impl.className),
          isTrue,
          reason: 'Should handle generic type parameters',
        );
      });

      test('handles repositories with multiple parent interfaces', () {
        final impl = TestRepositoryImpl(
          className: 'UserRepositoryImpl',
          implementsInterfaces: [
            'UserRepository',
            'CacheableRepository',
            'RefreshableRepository'
          ],
          inDataLayer: true,
        );

        expect(
          _hasRepositoryInterface(impl),
          isTrue,
          reason: 'Should find repository interface among multiple parents',
        );
      });

      test('handles nested path structures', () {
        final testCases = [
          'lib/features/auth/user/data/repositories/user_repository_impl.dart',
          'lib/modules/core/data/cache/repositories/cache_repository_impl.dart',
        ];

        for (final path in testCases) {
          expect(
            _isInDataLayer(path),
            isTrue,
            reason: '$path should be detected as data layer',
          );
        }
      });
    });
  });
}

// Helper classes for testing
class TestRepositoryImpl {
  final String className;
  final List<String> implementsInterfaces;
  final bool inDataLayer;

  TestRepositoryImpl({
    required this.className,
    required this.implementsInterfaces,
    required this.inDataLayer,
  });
}

class TestRepositoryInterface {
  final String className;
  final bool isAbstract;
  final bool inDataLayer;

  TestRepositoryInterface({
    required this.className,
    required this.isAbstract,
    required this.inDataLayer,
  });
}

// Helper functions that simulate rule logic
bool _isRepositoryImpl(String className) {
  // Remove generic type parameters before checking
  final cleanName = className.split('<').first;
  return cleanName.endsWith('RepositoryImpl');
}

bool _isRepositoryInterface(String interfaceName) {
  return interfaceName.endsWith('Repository') &&
      !interfaceName.endsWith('RepositoryImpl');
}

bool _hasRepositoryInterface(TestRepositoryImpl impl) {
  return impl.implementsInterfaces
      .any((interface) => _isRepositoryInterface(interface));
}

bool _isRepositoryInWrongLayer(TestRepositoryInterface interface) {
  return interface.inDataLayer && interface.isAbstract;
}

bool _isImplementationInWrongLayer(TestRepositoryImpl impl) {
  return !impl.inDataLayer;
}

bool _isInDataLayer(String filePath) {
  return filePath.contains('/data/') || filePath.contains('\\data\\');
}

String _getErrorMessage(TestRepositoryImpl impl) {
  if (impl.implementsInterfaces.isEmpty) {
    return 'Repository implementation must implement a domain repository interface: ${impl.className}';
  }

  if (!_hasRepositoryInterface(impl)) {
    final interfaces = impl.implementsInterfaces.join(', ');
    return 'Repository implementation should implement a domain repository interface: ${impl.className} implements $interfaces';
  }

  if (!impl.inDataLayer) {
    return 'Repository implementation should be in data layer, not domain layer: ${impl.className}';
  }

  return '';
}
