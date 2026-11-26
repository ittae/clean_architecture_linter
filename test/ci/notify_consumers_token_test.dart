import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('notify-consumers does not use the release token', () {
    final publish = File('.github/workflows/publish.yml').readAsStringSync();
    final releasePlease = File(
      '.github/workflows/release-please.yml',
    ).readAsStringSync();
    final docs = File('docs/release-please.md').readAsStringSync();

    expect(publish, contains('secrets.CONSUMER_DISPATCH_TOKEN'));
    expect(publish.contains('RELEASE_PLEASE_TOKEN'), isFalse);
    expect(
      publish,
      contains('CONSUMER_DISPATCH_TOKEN cannot read the consumer list'),
    );
    expect(releasePlease, contains('secrets.RELEASE_PLEASE_TOKEN'));
    expect(docs, contains('`CONSUMER_DISPATCH_TOKEN`'));
    expect(docs.contains('notify-consumers` also uses it'), isFalse);
  });
}
