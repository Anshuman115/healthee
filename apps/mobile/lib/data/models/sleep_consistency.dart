/// `GET /api/sleep/consistency` — bedtime/wake regularity, the odd nights, and
/// the one lever the server picked for tonight.
///
/// ## The one field that already arrives withheld
///
/// `read/sleep_extras.py::_sri_block` is explicit: `sri` is **null** whenever it
/// is not current, and the value survives only inside `sri_withheld` "where it
/// carries its own date and age". So [sri] is folded through the same
/// `readingFrom` every `/api/today` metric uses, and the withheld block reaches
/// the screen with its own message. Legacy read `data['sri']` and drew nothing
/// when it was null, which is the shape of the bug that block exists to prevent.
///
/// ## `tonight` is omitted, not withheld
///
/// `api/gate.py` strips `tonight` for a non-premium owner, exactly as it strips
/// `/api/today`'s `action`. An omitted premium field is an entitlement fact and
/// not a data one — there is no measurement missing — so it is a plain nullable
/// and the card simply is not drawn, which is what legacy does.
library;

import 'package:healthee/data/honesty/envelope.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:meta/meta.dart';

/// One night whose bedtime sat more than two hours off the owner's median.
@immutable
class IrregularNight {
  /// Builds an off-pattern night.
  const IrregularNight({required this.date, required this.bedtime, required this.deltaH});

  /// Parses one entry of `irregular_nights[]`.
  factory IrregularNight.fromJson(Map<String, Object?> json) => IrregularNight(
    date: json['date'] as String?,
    bedtime: json['bedtime'] as String?,
    deltaH: (json['delta_h'] as num?)?.toDouble(),
  );

  /// The night's owner-local date.
  final String? date;

  /// Its bedtime, `HH:MM`.
  final String? bedtime;

  /// How far that sat from the median, in hours. Signed.
  final double? deltaH;
}

/// The server's single highest-leverage lever for tonight, and its coaching.
@immutable
class TonightLever {
  /// Builds a lever.
  const TonightLever({
    required this.title,
    required this.lever,
    required this.targetClock,
    required this.prose,
    required this.hit,
    required this.of,
    required this.napNote,
  });

  /// Parses `tonight`, or null when the payload omits it.
  static TonightLever? maybe(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final adherence = raw['adherence'];
    final nap = raw['nap'];
    // The LLM line when there is one, the deterministic action when there is not
    // — legacy's own precedence (`sleep_screen.dart:725`), kept.
    final coach = (raw['coach'] as String?)?.trim();
    return TonightLever(
      title: raw['title'] as String? ?? 'Tonight',
      lever: raw['lever'] as String? ?? '',
      targetClock: raw['target_clock'] as String?,
      prose: coach != null && coach.isNotEmpty ? coach : (raw['action'] as String? ?? ''),
      hit: adherence is Map<String, Object?> ? (adherence['hit'] as num?)?.toInt() : null,
      of: adherence is Map<String, Object?> ? (adherence['of'] as num?)?.toInt() : null,
      napNote: nap is Map<String, Object?> ? nap['text'] as String? : null,
    );
  }

  /// The server's own headline for the lever.
  final String title;

  /// `bedtime` · `duration` · `wake` — which end of the night it moves.
  final String lever;

  /// The concrete clock time to aim at, when the server named one.
  final String? targetClock;

  /// The coaching sentence, **raw**: it carries `[[note_id]]` markers and is
  /// rendered through the grounded-prose widget, never printed directly.
  final String prose;

  /// Nights the owner hit the target, out of [of].
  final int? hit;

  /// The window the adherence was measured over, in nights.
  final int? of;

  /// The nap line, when the server attached one.
  final String? napNote;

  /// Whether the adherence pair can be drawn at all.
  bool get hasAdherence => hit != null && of != null && of! > 0;
}

/// The whole `/api/sleep/consistency` payload, typed.
@immutable
class SleepConsistency {
  /// Builds the payload.
  const SleepConsistency({
    required this.nights,
    required this.onsetBandH,
    required this.onsetBand,
    required this.medianBedtime,
    required this.meanWake,
    required this.late,
    required this.sri,
    required this.irregularNights,
    required this.action,
    required this.tonight,
  });

  /// Parses the payload.
  ///
  /// The server answers `{days, nights, note}` and nothing else when there are
  /// fewer than three nights. Every field below is nullable for that reason, and
  /// the card that draws them checks [hasBand] rather than assuming.
  factory SleepConsistency.fromJson(Map<String, Object?> json) => SleepConsistency(
    nights: (json['nights'] as num?)?.toInt() ?? 0,
    onsetBandH: (json['onset_band_h'] as num?)?.toDouble(),
    onsetBand: json['onset_band'] as String?,
    medianBedtime: json['median_bedtime'] as String?,
    meanWake: json['mean_wake'] as String?,
    late: json['late'] == true,
    // `sri` sits beside `sri_withheld`, which `_disclosure` reads under the
    // `withheld` key — so the block is lifted to that name first. One line, and
    // it is what lets the ONE envelope decide this field's honesty like every
    // other metric in the app.
    sri: numericReadingFrom(<String, Object?>{
      'sri': json['sri'],
      'withheld': json['sri_withheld'],
    }, 'sri'),
    irregularNights: <IrregularNight>[
      for (final night in (json['irregular_nights'] as List<Object?>? ?? const <Object?>[]))
        if (night is Map<String, Object?>) IrregularNight.fromJson(night),
    ],
    action: json['action'] as String?,
    tonight: TonightLever.maybe(json['tonight']),
  );

  /// How many nights the window found.
  final int nights;

  /// The 10th-to-90th-percentile bedtime spread, hours.
  final double? onsetBandH;

  /// The server's own sentence about that spread.
  final String? onsetBand;

  /// Median bedtime, `HH:MM`.
  final String? medianBedtime;

  /// Mean wake time, `HH:MM`.
  final String? meanWake;

  /// Whether the median bedtime falls after midnight.
  final bool late;

  /// Sleep Regularity Index — withheld with its own reason when not current.
  final Reading<double> sri;

  /// The off-pattern nights, worst first.
  final List<IrregularNight> irregularNights;

  /// The LLM's action line, **raw** — rendered through grounded prose.
  final String? action;

  /// Tonight's lever, or null when the plan does not include it.
  final TonightLever? tonight;

  /// Whether the regularity numbers exist at all.
  bool get hasBand => onsetBandH != null;
}
