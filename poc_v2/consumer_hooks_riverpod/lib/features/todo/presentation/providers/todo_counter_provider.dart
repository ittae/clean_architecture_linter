import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final counterProvider = Provider<int>((ref) => 0);

class TodoCounterPage extends HookConsumerWidget {
  const TodoCounterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tick = useState(0);
    final count = ref.watch(counterProvider);
    return HookConsumer(
      builder: (context, ref, child) {
        final nested = ref.watch(counterProvider);
        return child ?? Text('${tick.value}:$count:$nested');
      },
    );
  }
}

class TodoCounterBox extends StatefulHookConsumerWidget {
  const TodoCounterBox({super.key});

  @override
  ConsumerState<TodoCounterBox> createState() => _TodoCounterBoxState();
}

class _TodoCounterBoxState extends ConsumerState<TodoCounterBox> {
  @override
  Widget build(BuildContext context) {
    final tick = useState(0);
    final count = ref.watch(counterProvider);
    return Text('${tick.value}:$count');
  }
}

class TodoCounterNotifier {
  TodoCounterNotifier(this.ref);

  final Ref ref;

  int build() {
    return ref.read(counterProvider);
  }
}
