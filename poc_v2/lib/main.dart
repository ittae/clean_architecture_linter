import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/presentation_no_throw_rule.dart';

final plugin = CleanArchitectureLinterPlugin();

class CleanArchitectureLinterPlugin extends Plugin {
  @override
  String get name => 'Clean Architecture Linter';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(PresentationNoThrowRule());
  }
}
