Feature: presentation_no_throw
  Presentation state does not throw; AsyncValue.guard owns the error channel.

  Scenario: a notifier that throws from build is reported
    Given the file "lib/features/todo/presentation/providers/bad_notifier.dart" contains:
      """
      class TodoException implements Exception {}

      class BadNotifier {
        Future<void> build() async {
          throw TodoException();
        }
      }
      """
    When the rule "presentation_no_throw" analyzes "lib/features/todo/presentation/providers/bad_notifier.dart"
    Then the only diagnostic is "presentation_no_throw" at line 5 of "lib/features/todo/presentation/providers/bad_notifier.dart"

  Scenario: a business exception thrown inside AsyncValue.guard stays clean
    Given the file "lib/features/todo/presentation/providers/good_notifier.dart" contains:
      """
      class TodoException implements Exception {}

      class AsyncValue<T> {
        const AsyncValue.data(this.value);

        final T value;

        static Future<AsyncValue<T>> guard<T>(Future<T> Function() body) async {
          return AsyncValue.data(await body());
        }
      }

      class GoodNotifier {
        Future<AsyncValue<String>> build() {
          return AsyncValue.guard(() async {
            throw TodoException();
          });
        }
      }
      """
    When the rule "presentation_no_throw" analyzes "lib/features/todo/presentation/providers/good_notifier.dart"
    Then no diagnostic is reported
