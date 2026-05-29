class TodoException implements Exception {}

class BadNotifier {
  Future<void> build() async {
    throw TodoException();
  }
}
