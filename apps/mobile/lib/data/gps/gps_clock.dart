import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Only the visible live summary subscribes; closing it releases the timer.
final gpsClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
