/// Where Today's personal baselines come from, and where they may not come from.
///
/// Split out of `today_facts.dart` at the 400-line gate, and the seam is a real
/// one: that file answers "what figures is this render built from", and this
/// answers "what is the owner's own normal, and which block of the payload said
/// so". The second question grew a second half — the SPREAD — when
/// `docs/BACKEND_GAPS_FROM_UI.md` B4 put `sd_30d` and `baseline_sd` on the wire,
/// and the two halves have to be resolved together or not at all.
///
/// ## Two carriers, ONE definition
///
/// `metrics[].median_30d` and `recovery.signals[].baseline` are both
/// `analytics.baselines.compute_baseline(metric, window_days=30).median`
/// (`read/today_series.py::_derived_card`, `read/recovery.py::_hrv_signal`):
/// same function, same window, same metric id. `sd_30d` and `baseline_sd` are
/// likewise both `Baseline.robust_sd` over that window. CLAUDE.md forbids a
/// second definition, not a second carrier — which is the only reason the
/// fallback chain below is allowed at all.
///
/// The chain exists because `hrv_sleep_avg` is baselined by the server
/// (`read/today.py::_BASELINE_METRICS`) but has **no metric card**
/// (`read/meta.py::TODAY_SECONDARY_METRICS` lists seven ids and that is not one),
/// so the recovery ladder is the only place its median appears.
///
/// ## The centre and the spread come from the SAME carrier
///
/// [Baseline.of] resolves both together rather than each independently. Taking
/// the median from the card and the σ from the ladder would pair two numbers
/// that were never measured together — and it would do so invisibly, because
/// both are correct in isolation.
///
/// ## What this deliberately does NOT do
///
/// There is no fallback to a median or a standard deviation of the fourteen
/// points on the chart. That is a baseline over a different window from the one
/// every other surface quotes — the second definition, arriving as a
/// helpful-looking last resort. A metric the server has not baselined draws no
/// baseline and shows no ±.
library;

import 'package:healthee/data/models/recovery_signals.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:meta/meta.dart';

/// The owner's own normal for one metric: a centre, and how wide it is.
@immutable
class Baseline {
  /// Builds a baseline. Both halves may be null, and independently: a server
  /// that sent a median and no σ is an older one, not a broken one.
  const Baseline({this.median, this.sd});

  /// The centre and spread for [metric], from whichever block carries them.
  ///
  /// [signalContains] is how the same metric is named on the recovery ladder —
  /// the ladder labels its rows for a person ("Overnight HRV"), so the match is
  /// on a substring rather than on an id.
  factory Baseline.of(
    TodaySnapshot snapshot,
    RecoverySignals? signals,
    String metric,
    String signalContains,
  ) {
    final card = snapshot.metric(metric);
    if (card?.median30d case final double median) {
      // Both from the card, including a null σ: an older server sending a
      // median and no `sd_30d` must not have the ladder's σ borrowed for it.
      return Baseline(median: median, sd: card?.sd30d);
    }
    if (signals == null) {
      return const Baseline();
    }
    final marker = signalIn(signals, signalContains);
    return Baseline(median: marker?.baseline, sd: marker?.baselineSd);
  }

  /// The owner's own centre, or null when the server baselined nothing.
  final double? median;

  /// One robust standard deviation of that same window, or null.
  final double? sd;
}

/// The recovery-ladder row whose name contains [contains], or null.
RecoverySignal? signalIn(RecoverySignals signals, String contains) {
  for (final signal in signals.signals) {
    if (signal.name.contains(contains)) {
      return signal;
    }
  }
  return null;
}
