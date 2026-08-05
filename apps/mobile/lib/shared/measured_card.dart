/// The frame every measured card shares: a title, the value, and its provenance.
///
/// The provenance line is not decoration. Everything on this screen came off the
/// wrist rather than out of a model, and the brief's §3 rule — *"provenance is
/// part of the number"* — applies to a measurement exactly as it applies to a
/// VO₂max that names its instrument. So each card says **which device produced
/// it and when**, in [HealtheeColors.ink3], every time.
///
/// "When" matters more here than it looks. The strap samples on its own
/// schedule: a SpO₂ reading can be eight hours old while the card sits next to a
/// heart rate from four minutes ago. A screen that showed both as "today"
/// without the clock would be flattening two very different claims.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// A card of measured data, titled and stamped.
class MeasuredCard extends StatelessWidget {
  /// [measuredAt] stamps the value; null omits the clock but keeps the source.
  const MeasuredCard({
    required this.title,
    required this.child,
    this.measuredAt,
    this.now,
    this.footnote,
    super.key,
  });

  /// The metric's name, in the same position a withheld card puts it.
  final String title;

  /// The value, however this metric draws one.
  final Widget child;

  /// When the strap recorded it.
  final DateTime? measuredAt;

  /// The current instant, injected so a test does not read the wall clock.
  final DateTime? now;

  /// An extra line under the value — units, counts, an attribution.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          child,
          if (footnote case final String note) ...[
            const SizedBox(height: Insets.sm),
            Text(note, style: text.bodySmall?.copyWith(color: colors.ink2)),
          ],
          const SizedBox(height: Insets.md),
          Text(
            _provenance(measuredAt, now ?? DateTime.now()),
            style: text.labelSmall?.copyWith(color: colors.ink3),
          ),
        ],
      ),
    );
  }

  /// Names the instrument and dates the reading. Never "updated just now" on its
  /// own — the source is half the claim.
  static String _provenance(DateTime? at, DateTime now) {
    if (at == null) {
      return 'Measured by your strap';
    }
    return 'Measured by your strap · ${clockLabel(at)} · '
        '${ageLabel(at, now: now)}';
  }
}

/// A hero figure with its unit, in tabular numerals.
///
/// Tabular is mandatory on every number (brief §7.2) and is set on the display
/// styles in `typography.dart`; the unit is a separate, quieter run so a column
/// of values still aligns on the digits.
class HeroValue extends StatelessWidget {
  /// [value] is already formatted; this widget does not round.
  const HeroValue({required this.value, this.unit, super.key});

  /// The formatted number.
  final String value;

  /// Its unit, or null when there is none.
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: text.displayLarge),
        if (unit case final String symbol) ...[
          const SizedBox(width: Insets.xs),
          Text(symbol, style: text.labelMedium?.copyWith(color: colors.ink3)),
        ],
      ],
    );
  }
}
