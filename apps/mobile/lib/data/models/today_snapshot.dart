/// `GET /api/today`, typed — the app's proof that the whole boundary works.
///
/// One model, parsed from the committed contract snapshot, exercising every part
/// of the pipeline: nested objects, lists, nullable fields, and all four honesty
/// states. `test/data/today_snapshot_golden_test.dart` parses
/// `packages/contracts/snapshots/today.json` **directly from the repo** — not a
/// copy — so a reviewed server-side shape change fails the mobile suite in the
/// same commit that makes it. That is the point of the file living where it does.
///
/// ## What this model does NOT do
///
/// It does not cover every key `/api/today` sends; the payload is ~20 KB of
/// deeply nested, largely optional structure and the server's own standards
/// document names it as the documented exception to typed responses. Fields land
/// here as the screens that need them land. What is settled is the *shape* of the
/// work: every honesty-bearing field is a [Reading], and nothing above the data
/// layer sees a `Map<String, Object?>` again.
library;

import 'package:healthee/data/honesty/envelope.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/data_health.dart';
import 'package:healthee/data/models/metric_card.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:meta/meta.dart';

/// The Today page's whole payload.
@immutable
class TodaySnapshot {
  /// Builds a snapshot. Prefer [TodaySnapshot.fromJson].
  const TodaySnapshot({
    required this.date,
    required this.action,
    required this.recovery,
    required this.metrics,
    required this.vo2max,
    required this.biologicalAge,
    required this.dataHealth,
  });

  /// Parses `GET /api/today`.
  ///
  /// Every honesty-bearing block goes through [readingFrom]; none of them decide
  /// their own state. A block the server omitted entirely becomes a `Withheld`
  /// with the honest "we don't know why" sentence rather than being dropped — an
  /// absence the UI never hears about is the silence this whole design is against.
  factory TodaySnapshot.fromJson(Map<String, Object?> json) {
    return TodaySnapshot(
      date: json['date']! as String,
      action: json['action'] as String?,
      recovery: readingFrom(_block(json['recovery_score']), RecoveryScore.maybe),
      metrics: [
        for (final entry in (json['metrics'] as List? ?? const []))
          if (entry is Map<String, Object?>) MetricCard.fromJson(entry),
      ],
      vo2max: readingFrom(_block(json['vo2max']), Vo2max.maybe),
      biologicalAge: readingFrom(_block(json['biological_age']), BiologicalAge.maybe),
      dataHealth: switch (json['data_health']) {
        final Map<String, Object?> health => DataHealth.fromJson(health),
        _ => null,
      },
    );
  }

  /// The owner-local calendar date this snapshot describes, `YYYY-MM-DD`.
  final String date;

  /// The AI daily-action one-liner, or null until the nightly job has warmed it.
  ///
  /// `docs/APP_DESIGN.md` §3.1: null means "show nothing, never a spinner". It is
  /// deliberately NOT a [Reading] — an un-warmed action is not a withheld number,
  /// it is a premium surface that has nothing to say yet, and dressing it in a
  /// refusal card would tell the owner something is wrong when nothing is.
  final String? action;

  /// Recovery 0–100 with its per-factor breakdown.
  final Reading<RecoveryScore> recovery;

  /// The metric cards, in server order.
  final List<MetricCard> metrics;

  /// The fitness headline. The payload most likely to be [Withheld] in real use.
  final Reading<Vo2max> vo2max;

  /// The motivational estimate. Usually [Caveated] — it carries its own tilts.
  final Reading<BiologicalAge> biologicalAge;

  /// Per-feed freshness, or null when the payload omitted it.
  final DataHealth? dataHealth;

  /// A metric card by its canonical id, or null when today has no such card.
  MetricCard? metric(String id) {
    for (final card in metrics) {
      if (card.metric == id) {
        return card;
      }
    }
    return null;
  }

  /// A missing block parses as an empty object, which [readingFrom] resolves to a
  /// `Withheld` carrying [unexplainedAbsenceMessage]. Returning `const {}` rather
  /// than throwing is the choice that keeps a partial payload renderable: one
  /// absent block should cost the owner that block, not the whole page.
  static Map<String, Object?> _block(Object? raw) =>
      raw is Map<String, Object?> ? raw : const <String, Object?>{};
}
