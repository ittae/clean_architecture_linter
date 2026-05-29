class BadNotifier {
  Future<void> build() async {
    throw StateError('Do not throw directly from presentation code.');
  }
}
