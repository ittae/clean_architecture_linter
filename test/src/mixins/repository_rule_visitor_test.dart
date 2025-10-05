import 'package:test/test.dart';

import '../../../lib/src/mixins/repository_rule_visitor.dart';

// Test class that uses the mixin
class _TestRule with RepositoryRuleVisitor {
  // Expose mixin methods for testing
}

void main() {
  group('RepositoryRuleVisitor', () {
    late _TestRule testRule;

    setUp(() {
      testRule = _TestRule();
    });

    group('isValidRepositoryName', () {
      test('returns true for valid abstract repository names', () {
        expect(testRule.isValidRepositoryName('TodoRepository'), isTrue);
        expect(testRule.isValidRepositoryName('UserRepository'), isTrue);
      });

      test('returns true for valid implementation names', () {
        expect(testRule.isValidRepositoryName('TodoRepositoryImpl'), isTrue);
        expect(testRule.isValidRepositoryName('UserRepositoryImplementation'), isTrue);
      });

      test('returns false for invalid repository names', () {
        expect(testRule.isValidRepositoryName('TodoRepo'), isFalse);
        expect(testRule.isValidRepositoryName('TodoService'), isFalse);
      });

      test('returns false for names without Repository', () {
        expect(testRule.isValidRepositoryName('TodoManager'), isFalse);
        expect(testRule.isValidRepositoryName('DataSource'), isFalse);
      });
    });

    group('mixin structure', () {
      test('mixin is properly exposed', () {
        expect(testRule, isNotNull);
      });
    });
  });
}
