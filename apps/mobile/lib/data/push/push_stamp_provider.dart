/// The last upload attempt, read once and read by everyone who asks.
///
/// It lived as a private `FutureProvider` inside `today_screen.dart` while Today
/// was the only surface that classified the connection. The data-freshness
/// screen classifies the same connection with the same `connectionHealth(...)`,
/// and a second private provider reading the same row would be a second answer
/// to *"when did this phone last try to upload"* — which is the one-definition
/// rule (CLAUDE.md) applied to a read rather than to a metric.
///
/// Extracted on its second use (Standards §1).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/store/store_provider.dart';

/// This phone's last upload attempt. Re-read whenever it is invalidated.
final pushStampProvider = FutureProvider<PushStamp>((ref) {
  return ref.watch(localStoreProvider).pushReader.lastAttempt();
});
