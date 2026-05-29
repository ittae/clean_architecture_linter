import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/cross_layer/boundary_crossing_rule.dart';
import 'src/rules/presentation_rules/presentation_no_throw_rule.dart';

final plugin = CleanArchitectureLinterPlugin();

class CleanArchitectureLinterPlugin extends Plugin {
  @override
  String get name => 'Clean Architecture Linter';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(BoundaryCrossingRule());
    registry.registerWarningRule(PresentationNoThrowRule());
  }
}
