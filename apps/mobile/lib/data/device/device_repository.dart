/// Today's measurements, read from the local tier. The screen's one source.
///
/// Deliberately offline-only: this provider never touches the network, so the
/// app is fully readable with no connection at all (brief §7.4) and a Today that
/// renders is a Today backed by data the strap actually produced.
///
/// It is an `AsyncValue` because reading SQLite is asynchronous, not because it
/// might fail to find anything. Those are different: a day the strap never
/// recorded is a perfectly good [DeviceDay] full of withholds, while a database
/// that will not open is an `AsyncError` and renders with a retry. Folding the
/// first into the second would show "something went wrong" to somebody whose
/// only mistake was leaving their strap on the charger.
library;

import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_repository.g.dart';

/// Everything the strap measured on the day the app is showing.
///
/// Invalidated by `SyncController` after every sync attempt, so a pull that
/// stored anything is on screen without the owner pulling to refresh.
@riverpod
Future<DeviceDay> deviceDay(Ref ref) {
  final store = ref.watch(localStoreProvider);
  return store.strapReader.day(ref.watch(todayProvider));
}
