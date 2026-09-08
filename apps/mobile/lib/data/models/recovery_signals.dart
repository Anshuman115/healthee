/// The recovery **signal ladder** — the payload behind the signature chart.
///
/// `recovery.signals[]`, each `{name, value, baseline, z, direction, unit,
/// research_note_id}`. Brief §5.1 makes the case for why this replaces the ring
/// everyone else draws: a 72 tells you nothing, and "HRV is 1.4σ below your
/// normal, everything else is at baseline" tells you what to do.
///
/// Two things the model keeps structural.
///
/// **[z] may be null and that is not zero.** A signal with no baseline yet has
/// no position on the ladder, and drawing it at the centre line would assert it
/// is exactly normal. It renders as a row with no marker instead.
///
/// **[direction] comes from the server, always.** Which side of the baseline is
/// favourable is a research question — a low resting heart rate is good, a low
/// HRV is not — and re-deriving it from the sign of `z` in the UI would put that
/// judgement in the one place with no access to the evidence.
///
/// ## Three honesty fields that were on the wire and nowhere else
///
/// [n], [directionBasis] and [populationFloorMin] were sent by the server, added
/// deliberately, each with its reason written beside it in `read/recovery_signals.py`
/// — and none of them was parsed here. `grep direction_basis population_floor_min`
/// over `apps/mobile/lib` returned nothing.
///
/// That is the shape this product is built to prevent, three times over: the server
/// did the honest work and the client filed it under a key nothing reads. Each field's
/// own doc below says what it exists to disclose.
library;

import 'package:meta/meta.dart';

/// One signal, positioned against its own baseline.
@immutable
class RecoverySignal {
  /// A named signal with its personal comparison.
  const RecoverySignal({
    required this.name,
    required this.value,
    required this.baseline,
    required this.baselineSd,
    required this.n,
    required this.z,
    required this.direction,
    required this.directionBasis,
    required this.populationFloorMin,
    required this.unit,
    required this.researchNoteId,
  });

  /// Parses one entry of `recovery.signals`.
  factory RecoverySignal.fromJson(Map<String, Object?> json) {
    return RecoverySignal(
      name: json['name']! as String,
      value: (json['value'] as num?)?.toDouble(),
      baseline: (json['baseline'] as num?)?.toDouble(),
      baselineSd: (json['baseline_sd'] as num?)?.toDouble(),
      n: (json['n'] as num?)?.toInt(),
      z: (json['z'] as num?)?.toDouble(),
      direction: json['direction'] as String?,
      directionBasis: json['direction_basis'] as String?,
      populationFloorMin: (json['population_floor_min'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      researchNoteId: json['research_note_id'] as String?,
    );
  }

  /// Owner-facing name — "Sleep duration", "HRV".
  final String name;

  /// Today's reading.
  final double? value;

  /// The owner's own normal for this signal. **Not a population norm** — brief
  /// §5.2 is explicit that population norms are irrelevant here.
  final double? baseline;

  /// The spread [z] was measured in — one robust standard deviation of the
  /// owner's own window, and the exact divisor the server used.
  ///
  /// It arrived with `docs/BACKEND_GAPS_FROM_UI.md` B4. Before it, a reader had
  /// a centre and a score and no way to turn one into the other, so the only
  /// thing drawable was a reference LINE: a value one unit above a tight
  /// baseline and one unit above a scattered one looked identical.
  ///
  /// **Not recomputed on the phone, ever.** `today_facts.dart` states the rule
  /// for the centre and it holds for the spread: a second, on-device σ over the
  /// fourteen points a card happens to hold would be a different number from the
  /// one that produced [z], and the two would disagree in exactly the cases that
  /// matter.
  final double? baselineSd;

  /// How many days of the owner's own history [baseline] and [z] rest on.
  ///
  /// Before it existed the RHR and HRV signals had **no count gate at all**: their only
  /// admission rule was a non-zero robust SD, and with two days the MAD is the
  /// half-distance — so a finite z shipped with a `direction` of "favorable" or
  /// "unfavorable", a verdict on this owner's autonomic state from two mornings.
  /// `read/recovery_signals.py` added `_SIGNAL_MIN_DAYS = 5` **and** shipped this count
  /// *"beside `baseline` and `baseline_sd` … so a reader can weigh a direction rather
  /// than take it."*
  ///
  /// The reader could not: this was on the wire and absent from the whole of
  /// `apps/mobile/lib`. The server did the honest work and the client filed it under a
  /// key nothing read.
  final int? n;

  /// Standard scores from [baseline]. Null when there is no baseline yet.
  final double? z;

  /// `favorable` · `unfavorable` · `neutral`, as the server judged it.
  final String? direction;

  /// WHICH limb produced [direction] — `population` · `personal` · `both`, or null.
  ///
  /// **The sharpest of the three dropped fields, and sharpest for this owner.** The
  /// sleep signal describes itself as "vs personal usual" and then decides its direction
  /// from an ABSOLUTE floor as well as from the personal z, so
  /// `read/recovery_signals.py` says plainly: *"for a chronic short sleeper the
  /// population floor decides every night and the personal number beside it cannot
  /// change the verdict."*
  ///
  /// The owner of this app is a chronic short sleeper. Without this field the ladder
  /// draws a personal z beside a verdict that z did not produce, and the field built to
  /// disclose exactly that was disclosed to nobody.
  ///
  /// Only the unfavourable branch has two independent limbs, so this is null on every
  /// favourable and neutral direction and on every signal but sleep duration.
  final String? directionBasis;

  /// The absolute cut-point an `unfavorable` verdict was taken against, in [unit].
  ///
  /// Ships with [directionBasis] and is meaningless without it: "the population floor
  /// decided this" is a claim the reader can only weigh if the floor is named. The one
  /// signal that carries it is sleep duration, where it is 5 h — deep in the short arm
  /// of the U-shaped duration/mortality curve `[[sleep_duration_mortality]]` describes.
  final double? populationFloorMin;

  /// Unit of [value] and [baseline].
  final String? unit;

  /// The note licensing this signal. Tappable, per brief §5.1.
  final String? researchNoteId;

  /// Whether this row can be drawn against the centre line at all.
  bool get hasPosition => z != null;
}

/// The whole ladder, plus the server's one-line reading of it.
@immutable
class RecoverySignals {
  /// Built by [RecoverySignals.maybe].
  const RecoverySignals({
    required this.summary,
    required this.signals,
    required this.favorable,
    required this.unfavorable,
    required this.neutral,
    required this.total,
  });

  /// Parses `recovery`, or null when there are no signals to draw.
  ///
  /// Null on an empty list rather than an empty ladder: a chart with no rows is
  /// a frame around nothing, and the honest render for it is a refusal.
  static RecoverySignals? maybe(Map<String, Object?> json) {
    final signals = [
      for (final entry in (json['signals'] as List? ?? const []))
        if (entry is Map<String, Object?>) RecoverySignal.fromJson(entry),
    ];
    if (signals.isEmpty) {
      return null;
    }
    return RecoverySignals(
      summary: json['summary'] as String?,
      signals: signals,
      favorable: (json['favorable'] as num?)?.toInt() ?? 0,
      unfavorable: (json['unfavorable'] as num?)?.toInt() ?? 0,
      neutral: (json['neutral'] as num?)?.toInt() ?? 0,
      // The server's own count, not `signals.length` and not the three tallies
      // summed. `recovery_signals` counts only the markers it could position, so
      // deriving the denominator here would silently disagree with the numerator
      // beside it the moment one marker has no baseline yet.
      total: (json['total'] as num?)?.toInt() ?? signals.length,
    );
  }

  /// "Recovery signals lean favorable" — the server's sentence, rendered
  /// verbatim. It is a calibrated statement and re-wording it in the UI is how
  /// calibration gets lost.
  final String? summary;

  /// One row per signal, in server order.
  final List<RecoverySignal> signals;

  /// How many signals sit on the favourable side.
  final int favorable;

  /// How many sit on the unfavourable side.
  final int unfavorable;

  /// How many are at baseline.
  final int neutral;

  /// How many markers the server judged in all — the denominator of legacy's
  /// `N of M favorable` line (`today_screen.dart:795`).
  final int total;
}
