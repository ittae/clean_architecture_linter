// ignore_for_file: unused_element

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'state_with_async_value_good.g.dart';

class Todo {
  final String id;
  final String title;
  Todo({required this.id, required this.title});
}

abstract class TodoRepository {
  Future<List<Todo>> getTodos();
}

// ✅ GOOD: Pure State without error fields
@freezed
class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,
    @Default(false) bool isLoading, // This is acceptable for UI state
  }) = _TodoState;
}

// ✅ GOOD: Using AsyncValue pattern with Riverpod
@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  Future<List<Todo>> build() async {
    // ✅ Return Future - Riverpod wraps in AsyncValue<List<Todo>>
    final repository = ref.read(todoRepositoryProvider);
    return repository.getTodos();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(todoRepositoryProvider);
      return repository.getTodos();
    });
  }
}

@riverpod
TodoRepository todoRepository(TodoRepositoryRef ref) {
  throw UnimplementedError();
}

// ✅ GOOD: Widget using AsyncValue.when()
class TodoListWidget {
  void build(TodoNotifierProvider ref) {
    final todosAsync = ref; // AsyncValue<List<Todo>>

    // ✅ Handle loading, error, data with AsyncValue.when()
    todosAsync.when(
      data: (todos) {
        // Display todos
      },
      loading: () {
        // Show loading indicator
      },
      error: (error, stack) {
        // Handle error from AsyncValue
      },
    );
  }
}

// ✅ GOOD: Multiple AsyncValue notifiers
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  Future<String> build() async {
    // ✅ Each notifier has its own AsyncValue
    return 'User Name';
  }
}

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<Map<String, dynamic>> build() async {
    // ✅ AsyncValue handles errors automatically
    return {};
  }
}
