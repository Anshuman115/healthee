/// The recovery signal ladder — brief §5.1's signature chart, and the ring's
/// replacement.
///
/// One row per signal. Each plots **today against that signal's own baseline**,
/// positioned by `z`, with the centre line as the owner's normal. Why it beats a
/// score, in the brief's own words: *"A 72 tells you nothing; 'HRV is 1.4σ below
/// your normal, everything else is at baseline' tells you what to do."*
///
/// Three rules the drawing holds:
///
///   * **The favourable side is the server's, not the sign of `z`.** A low
///     resting heart rate is good and a low HRV is not, and which side is which
///     is a research question. `direction` decides the colour; nothing here
///     re-derives it.
///   * **A signal with no `z` gets no marker.** Drawing it at the centre would
///     assert it is exactly normal, which is a claim about a baseline we do not
///     have. The row stays, with its value and an honest blank.
///   * **The scale is clamped at ±3σ and says so.** Past that the marker would
///     leave the row; clamping without a note would draw 5σ and 3σ identically.
///
/// ## No identity tag, deliberately
///
/// Every other card on Sleep wears the tag of the one metric it is about. This
/// one is about four or five at once — HRV, resting heart rate, sleep duration,
/// breathing — and `instrument_hues.dart` reserves the tag for a card about a single
/// metric. Painting the whole ladder in any one family's colour would claim a
/// family for rows that belong to three of them; painting each row in its own
/// would put four hues beside markers whose only job is to be read as `fav` or
/// `unf`. The section heading above it carries the family instead.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recovery_signals.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// How many standard deviations the ladder can draw before it clamps.
const double kLadderRange = 3;

/// One row per signal, each against its own baseline.
class RecoveryLadder extends StatelessWidget {
  /// [signals] is the parsed `recovery` block; [progress] is 0–1 from
  /// `RevealOnce` and slides the markers out from the centre line.
  const RecoveryLadder({
    required this.signals,
    required this.progress,
    super.key,
  });

  /// The ladder's rows and the server's one-line reading of them.
  final RecoverySignals signals;

  /// How far the markers have travelled from the centre, 0–1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Against your own normal', style: text.labelSmall),
          if (signals.summary case final String summary) ...[
            const SizedBox(height: Insets.xs),
            // The server's calibrated sentence, rendered as sent.
            Text(summary, style: text.bodyLarge),
          ],
          for (final signal in signals.signals) ...[
            const SizedBox(height: Insets.lg),
            _LadderRow(signal: signal, progress: progress),
          ],
          const SizedBox(height: Insets.md),
          Text(
            'The centre line is your own baseline, not a population average. '
            'Markers are capped at ±${kLadderRange.toStringAsFixed(0)}σ.',
            style: text.labelSmall?.copyWith(color: colors.ink3),
          ),
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({required this.signal, required this.progress});

  final RecoverySignal signal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(signal.name, style: text.titleSmall)),
            Text(_reading(signal), style: text.labelLarge),
          ],
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 18,
          width: double.infinity,
          child: CustomPaint(
            painter: _LadderPainter(
              z: signal.z,
              direction: signal.direction,
              colors: colors,
              progress: progress,
            ),
          ),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          _comparison(signal),
          style: text.bodySmall?.copyWith(color: colors.ink2),
        ),
      ],
    );
  }

  static String _reading(RecoverySignal signal) {
    final value = signal.value;
    if (value == null) {
      return '—';
    }
    final unit = signal.unit;
    return '${_number(value)}${unit == null ? '' : ' $unit'}';
  }

  /// The sentence brief §3 asks for: your number against **your** normal.
  static String _comparison(RecoverySignal signal) {
    final baseline = signal.baseline;
    if (baseline == null) {
      return 'No baseline for this yet — a few more days of wearing it builds one.';
    }
    final z = signal.z;
    if (z == null) {
      return 'Your usual is ${_number(baseline)}. Today has no comparable reading.';
    }
    if (z.abs() < 0.25) {
      return 'At your usual ${_number(baseline)}.';
    }
    final side = z > 0 ? 'above' : 'below';
    return '${z.abs().toStringAsFixed(1)}σ $side your usual '
        '${_number(baseline)}.';
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
}

class _LadderPainter extends CustomPainter {
  const _LadderPainter({
    required this.z,
    required this.direction,
    required this.colors,
    required this.progress,
  });

  final double? z;
  final String? direction;
  final HealtheeColors colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final centre = size.width / 2;

    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = colors.line
        ..strokeWidth = 1,
    );
    // The centre tick: the owner's own normal, marked so the row has an origin
    // even when there is no marker to place against it.
    canvas.drawLine(
      Offset(centre, midY - 6),
      Offset(centre, midY + 6),
      Paint()
        ..color = colors.ink3
        ..strokeWidth = 1,
    );

    final score = z;
    if (score == null) {
      return;
    }
    final clamped = score.clamp(-kLadderRange, kLadderRange) / kLadderRange;
    final x = centre + clamped * centre * progress;
    final colour = switch (direction) {
      'favorable' => colors.fav,
      'unfavorable' => colors.unf,
      // Neutral spends no colour: brief §2 rations it to judgement, and "at
      // baseline" is the absence of one.
      _ => colors.ink3,
    };
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (x - 3).clamp(0, size.width - 6),
          midY - 7,
          6,
          14,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = colour,
    );
  }

  @override
  bool shouldRepaint(_LadderPainter old) =>
      old.z != z || old.progress != progress || old.direction != direction;
}
