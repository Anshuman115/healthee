/// Sleep debt — a 14-night accumulation against a need line.
///
/// The number the brief asks the app to *explain* rather than assert: "Why debt
/// is 120 minutes, not 1,400". The payload carries everything that answer needs
/// — [nights], [nightsBelow], [avgTstMin], [avgDeficitMin] and [needMin] — and
/// the reasoning belongs beside the number as an expandable, never as a modal
/// (brief §3).
///
/// [lastTstWithheld] is the one field worth naming here. The block can carry a
/// debt figure while the MOST RECENT night is withheld, and those are different
/// claims: "your fortnight owes you two hours" is still true when last night's
/// own total could not be established. Flattening them would either hide a real
/// debt or assert a night we do not have.
library;

import 'package:healthee/data/models/trend_point.dart';
import 'package:meta/meta.dart';

/// The debt, its window, and what it was measured against.
@immutable
class SleepDebt {
  /// Built by [SleepDebt.maybe].
  const SleepDebt({
    required this.debtMin,
    required this.needMin,
    required this.nights,
    required this.nightsBelow,
    required this.avgTstMin,
    required this.avgDeficitMin,
    required this.performancePct,
    required this.lastTstMin,
    required this.lastTstAsOfDate,
    required this.lastTstWithheld,
    required this.researchNotes,
  });

  /// Parses `sleep_debt`, or null when no debt could be established.
  static SleepDebt? maybe(Map<String, Object?> json) {
    final debt = (json['debt_min'] as num?)?.toInt();
    if (debt == null) {
      return null;
    }
    return SleepDebt(
      debtMin: debt,
      needMin: (json['need_min'] as num?)?.toInt() ?? 480,
      nights: (json['nights'] as num?)?.toInt() ?? 0,
      nightsBelow: (json['nights_below'] as num?)?.toInt() ?? 0,
      avgTstMin: (json['avg_tst_min'] as num?)?.toInt(),
      avgDeficitMin: (json['avg_deficit_min'] as num?)?.toInt(),
      performancePct: (json['performance_pct'] as num?)?.toInt(),
      lastTstMin: (json['last_tst_min'] as num?)?.toInt(),
      lastTstAsOfDate: json['last_tst_as_of_date'] as String?,
      lastTstWithheld: json['last_tst_withheld'] != null,
      researchNotes: [
        for (final entry in (json['research_notes'] as List? ?? const []))
          if (entry is String) entry,
      ],
    );
  }

  /// The accumulated shortfall, minutes.
  final int debtMin;

  /// The nightly need this is measured against — 480 = 8 h.
  final int needMin;

  /// How many nights the window covers.
  final int nights;

  /// How many of them fell short of [needMin].
  final int nightsBelow;

  /// Mean total sleep time over the window.
  final int? avgTstMin;

  /// Mean nightly shortfall over the window.
  final int? avgDeficitMin;

  /// Sleep performance, percent of need met.
  final int? performancePct;

  /// Last night's total sleep time, when it could be established.
  final int? lastTstMin;

  /// Which night [lastTstMin] is about.
  final String? lastTstAsOfDate;

  /// True when the most recent night's own total was withheld, even though a
  /// debt figure exists for the window.
  final bool lastTstWithheld;

  /// The notes licensing the model.
  final List<String> researchNotes;

  /// The nightly totals a debt chart plots, when the payload carried them.
  ///
  /// `/api/today` does not send the per-night series — `/api/sleep` does — so
  /// this is normally empty and the chart draws from `sleep_history_7d`
  /// instead. Kept here so the field has one home if the aggregate ever grows it.
  static List<TrendPoint> nightlyFrom(Map<String, Object?> json) =>
      TrendPoint.listFrom(json['nightly']);
}
