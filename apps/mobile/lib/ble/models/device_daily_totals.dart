/// The strap's own since-midnight counters — **the authoritative daily total**.
///
/// This one is worth reading before touching anything that handles it.
///
/// The strap keeps a live running daily total on chunked endpoint `0x0016`
/// (the number the Zepp app shows). It also keeps a per-minute activity buffer
/// on the fetch channel — and the June-2026 firmware freezes that buffer
/// mid-day, returning `0xFF` for minutes it allocated and never wrote. So the
/// per-minute sum is, in the legacy code's own words, "possibly frozen /
/// incomplete", while this counter is the real measurement.
///
/// The server learned the same thing the expensive way (#121): 142 of 143 days
/// in production carry the per-minute sum because a re-derive pass overwrote
/// the counter, which had no durable table to live in. It has one now
/// (`device_daily_total`). **Dropping this value on the phone would recreate
/// that loss one layer up**, so the sync carries it out as a first-class
/// result rather than as a log line.
///
/// ## Offset table — the reply on endpoint 0x0016
///
/// | offset | size | field |
/// |---|---|---|
/// | 0 | 1 | `0x04` — reply marker |
/// | 1 | 1 | `0x01` |
/// | 2 | 1 | `0x0c` — payload length |
/// | 3 | 4 | steps, uint32 LE |
/// | 7 | 4 | distance in metres, uint32 LE |
/// | 11 | 4 | calories, uint32 LE |
///
/// The request that provokes it is a single `0x03` byte on the same endpoint.
library;

import 'package:meta/meta.dart';

/// The strap's live since-midnight counters, read once per connection.
@immutable
class DeviceDailyTotals {
  /// [readAt] is when the reply landed — the counters are "since midnight" in
  /// the strap's own local day, so the instant is what anchors them to a date.
  const DeviceDailyTotals({
    required this.steps,
    required this.distanceM,
    required this.calories,
    required this.readAt,
  });

  /// Steps since the strap's local midnight. The authoritative step total.
  final int steps;

  /// Distance in metres since midnight, as the strap computed it.
  final int distanceM;

  /// Calories since midnight, as the strap computed them. The server owns the
  /// canonical energy model; this is the device's figure, carried unaltered.
  final int calories;

  /// When this reply arrived.
  final DateTime readAt;

  @override
  String toString() =>
      'daily totals @${readAt.toIso8601String()}: $steps steps · '
      '$distanceM m · $calories kcal';
}
