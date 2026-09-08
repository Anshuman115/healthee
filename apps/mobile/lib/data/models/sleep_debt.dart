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

/// The reason id filed when the server has no sleep need for this owner.
///
/// ONE definition of the absence, beside the model that reports it, because two
/// screens render it: the Today page's need-and-debt panel and the Sleep tab's.
/// A sentence copied into both is how they start disagreeing about what the
/// owner should do — the same rule that put the need itself on the server.
const String kNoSleepNeedReason = 'no_sleep_need';

/// The sentence that goes with it. It names the one thing that brings the
/// figures back, because the reason is specific: the need band is selected from
/// AGE (NSF 2015), so a profile with no date of birth has no need — and a
/// shortfall, a performance percentage and a nightly gap are all ratios
/// against one.
const String kNoSleepNeed =
    'No sleep need yet — add your date of birth in your profile and the '
    'age-based need, and the figures measured against it, come back.';

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
      needMin: (json['need_min'] as num?)?.toInt(),
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

  /// The nightly need this is measured against, minutes — or null when the
  /// server has none for this owner.
  ///
  /// **Nullable, and NOT defaulted to 480.** The parser coalesced a missing
  /// `need_min` to a flat eight hours, which is a personal target invented for
  /// somebody we have never been able to compute one for. The server's need is
  /// age-selected (NSF 2015: 480 under 65, 450 at 65 and over), so for an older
  /// owner the default was half an hour wrong and presented as theirs. Every
  /// reader below withholds the figures that depend on it rather than assuming
  /// one — "not enough data" beats an optimistic guess.
  final int? needMin;

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
