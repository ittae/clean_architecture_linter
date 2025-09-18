import 'package:clean_architecture_linter/clean_architecture_linter.dart';

void main() {
  // Example of using Clean Architecture Linter
  final plugin = createPlugin();
  print('Clean Architecture Linter plugin created successfully!');

  // This would normally be used by the Dart analysis server
  // when you run 'dart pub custom_lint' or use it in your IDE

  print('Plugin type: ${plugin.runtimeType}');
  print('Clean Architecture Linter is ready to enforce architectural boundaries!');
}
