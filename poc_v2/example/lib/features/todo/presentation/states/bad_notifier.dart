class TodoBusinessException implements Exception {}

class BadNotifier {
  Future<void> build() async {
    throw TodoBusinessException();
  }
}
