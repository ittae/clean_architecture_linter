/// ✅ Passes `riverpod_keep_alive`.
///
/// `keepAlive: true` is accepted here because the provider name carries an
/// app-lifetime keyword (`listener`). The rule also accepts startup,
/// bootstrap, manager, storage, timezone, the app-wide state keywords
/// (auth, settings, cache, ...) and infrastructure suffixes.
///
/// A purchase stream must be subscribed exactly once for the whole app
/// session. If it were autoDispose, the subscription would be cancelled with
/// the first screen that stops watching it and purchase events would be lost.
///
/// Counter-example (reported): see doc/EXAMPLES.md "riverpod_keep_alive".
class Riverpod {
  const Riverpod({required bool keepAlive});
}

@Riverpod(keepAlive: true)
void purchaseStreamListener(Object ref) {}
