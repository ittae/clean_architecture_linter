import 'package:clean_architecture_linter/clean_architecture_linter.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

void main() {
  group('Clean Architecture Linter Tests', () {
    test('Plugin can be created', () {
      final plugin = createPlugin();
      expect(plugin, isNotNull);
      expect(
        plugin.runtimeType.toString(),
        contains('CleanArchitectureLinterPlugin'),
      );
    });

    test('Plugin is properly configured', () {
      final plugin = createPlugin();
      expect(plugin, isA<PluginBase>());
    });
  });
}
