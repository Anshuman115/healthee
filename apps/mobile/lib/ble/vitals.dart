/// One definition per vital, applied to **just-fetched device data**.
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// vitals.dart`. Its rule is the reason it exists: a metric has exactly one
/// definition, written once, and no widget re-derives it.
///
/// ## Read this before using it on a screen
///
/// The legacy file called itself "a stopgap over raw device data … once the
/// backend read is wired, the app must render the backend's derived values
/// instead and this file goes away". **In this app the backend read is already
/// wired** (`data/today_repository.dart` and the typed models beside it), and
/// the server owns the canonical derivation of every one of these numbers.
///
/// So this class is scoped to what it can honestly claim: it is the definition
/// applied to the samples ONE sync just pulled off the strap, before anything
/// has been sent anywhere — useful for a "what did we just get" surface and for
/// checking a sync did what it said. It is **not** a second definition of the
/// server's metrics and nothing user-facing may treat it as one. CLAUDE.md's
/// one-canonical-definition rule is what that sentence is protecting.
///
/// ## Why these are overnight means
///
/// Raw daytime HRV, SpO₂ and skin temperature are noisy and unrepresentative,
/// so the only meaningful form of each is the mean over the last sleep window —
/// which is also the number the sleep card shows. `latest()` is deliberately not
/// used for them.
library;

import 'package:healthee/ble/models/sleep_session.dart';
import 'package:healthee/ble/models/strap_data.dart';

/// The canonical read of each vital over one sync's worth of device samples.
class Vitals {
  /// Reads from [data]; holds no state of its own.
  Vitals(this.data);

  /// The sync result being read.
  final StrapData data;

  SleepSession? get _night => data.lastNight;

  // ── Instantaneous / daily values ──────────────────────────────────────────

  /// Heart rate: the latest instantaneous reading.
  double? get heartRate => data.latest('hr');

  /// Resting HR: the latest daily resting-HR value (fetch type `0x3A`).
  double? get restingHr => data.latest('resting_hr');

  /// Max HR: the latest daily max-HR value (fetch type `0x3D`).
  double? get maxHr => data.latest('max_hr');

  /// Stress: the latest all-day automatic stress reading (0–100).
  double? get stress => data.latest('stress');

  // ── Overnight / resting values (the ONLY meaningful form of these) ─────────

  /// HRV: mean over last night's sleep window (resting HRV).
  double? get hrv => _sleepMean('hrv');

  /// Blood O₂ / SpO₂: mean overnight (prefers the device's sleep-SpO₂ stream).
  double? get spo2 => _sleepMean('spo2_sleep') ?? _sleepMean('spo2');

  /// Lowest overnight SpO₂.
  double? get spo2Low {
    final v = _sleepWindow('spo2_sleep');
    final w = v.isNotEmpty ? v : _sleepWindow('spo2');
    return w.isEmpty ? null : w.reduce((a, b) => a < b ? a : b);
  }

  /// Skin temperature: mean over last night's sleep window.
  double? get skinTemp => _sleepMean('temperature_c');

  /// Respiratory rate: mean over last night's sleep window.
  double? get respiratoryRate => _sleepMean('respiratory_rate');

  /// Average heart rate during last night's sleep.
  double? get sleepAvgHr => _sleepMean('hr');

  // ── helpers ────────────────────────────────────────────────────────────────

  List<double> _sleepWindow(String metric) {
    final n = _night;
    if (n == null || n.stages.isEmpty) return const [];
    final start = n.stages.first.start;
    final end = n.stages.last.end;
    return data
        .seriesOf(metric)
        .where((s) => !s.date.isBefore(start) && !s.date.isAfter(end))
        .map((s) => s.value)
        .toList();
  }

  double? _sleepMean(String metric) {
    final v = _sleepWindow(metric);
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }
}
