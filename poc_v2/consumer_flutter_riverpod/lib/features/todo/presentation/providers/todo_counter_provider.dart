import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterProvider = Provider<int>((ref) => 0);

class TodoCounterPage extends ConsumerWidget {
  const TodoCounterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}

class TodoCounterNotifier {
  TodoCounterNotifier(this.ref);

  final Ref ref;

  int build() {
    return ref.read(counterProvider);
  }
}
