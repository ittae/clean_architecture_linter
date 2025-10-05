// ignore_for_file: unused_element

import 'package:freezed_annotation/freezed_annotation.dart';

part 'state_with_error_bad.freezed.dart';

class Todo {
  final String id;
  final String title;
  Todo({required this.id, required this.title});
}

// ❌ BAD: State with error field
// This will trigger: presentation_use_async_value
@freezed
class TodoStateBad1 with _$TodoStateBad1 {
  const factory TodoStateBad1({
    @Default([]) List<Todo> todos,
    String? errorMessage, // ❌ Should use AsyncValue
    @Default(false) bool isLoading,
  }) = _TodoStateBad1;
}

// ❌ BAD: State with error field (different name)
@freezed
class TodoStateBad2 with _$TodoStateBad2 {
  const factory TodoStateBad2({
    @Default([]) List<Todo> todos,
    String? error, // ❌
  }) = _TodoStateBad2;
}

// ❌ BAD: State with failure field
@freezed
class TodoStateBad3 with _$TodoStateBad3 {
  const factory TodoStateBad3({
    @Default([]) List<Todo> todos,
    Object? failure, // ❌
  }) = _TodoStateBad3;
}

// ❌ BAD: State with exception field
@freezed
class TodoStateBad4 with _$TodoStateBad4 {
  const factory TodoStateBad4({
    @Default([]) List<Todo> todos,
    Exception? exception, // ❌
  }) = _TodoStateBad4;
}

// ❌ BAD: State with errorMsg field
@freezed
class TodoStateBad5 with _$TodoStateBad5 {
  const factory TodoStateBad5({
    @Default([]) List<Todo> todos,
    String? errorMsg, // ❌
  }) = _TodoStateBad5;
}
