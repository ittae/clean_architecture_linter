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
      throw StateError('AsyncValue.guard owns the error channel.');
    });
  }
}
