/// Overnight blood oxygen — full width, because the **minimum** is the signal.
///
/// Legacy gave this its own full-width block in the sleep section and that was
/// right: SpO₂ is the one overnight series where the average is nearly useless
/// and the nightly low is the clinical fact. A night that sat at 97% and dipped
/// to 88% is a different night from one that sat at 97% throughout, and only the
/// minimum distinguishes them.
///
/// So the minimum is the hero and the average is the footnote — the opposite of
/// how every other metric on this screen is laid out, deliberately.
///
/// **No threshold is drawn and no verdict is given.** Where a nightly low
/// becomes clinically interesting is a medical judgement with a real cutoff
/// behind it, and this app does not hold that cutoff — `/api/today` sends the
/// numbers and nothing else. Colouring a low reading `unf` would be inventing
/// the threshold in the UI layer, which is the one place with no access to the
/// evidence.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/today/widgets/measured_card.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// Last night's blood oxygen, minimum first.
class BloodOxygenCard extends StatelessWidget {
  /// [nightlyMinimums] is the `spo2_overnight_min` sparkline, oldest first.
  const BloodOxygenCard({
    required this.vitals,
    required this.nightlyMinimums,
    required this.reveals,
    super.key,
  });

  /// The overnight block. Rendered only when it carries a blood-oxygen figure.
  final OvernightVitals vitals;

  /// Fourteen nights of nightly lows.
  final List<TrendPoint> nightlyMinimums;

  /// The screen's reveal registry.
  final RevealRegistry reveals;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final minimum = vitals.spo2Min;
    if (minimum == null && vitals.spo2Avg == null) {
      return const SizedBox.shrink();
    }
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Blood oxygen overnight', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          if (minimum != null)
            HeroValue(value: '${minimum.round()}', unit: '% lowest')
          else
            HeroValue(value: '${vitals.spo2Avg!.round()}', unit: '% average'),
          const SizedBox(height: Insets.xs),
          Text(
            _footnote(vitals),
            style: text.bodySmall?.copyWith(color: colors.ink2),
          ),
          if (nightlyMinimums.length >= 2) ...[
            const SizedBox(height: Insets.lg),
            RevealOnce(
              id: 'spo2-overnight-min',
              registry: reveals,
              builder: (context, t) => HArea(
                TrendPoint.valuesOf(nightlyMinimums),
                color: colors.accent,
                progress: t,
                height: 56,
                unit: '%',
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Nightly lows over the last ${nightlyMinimums.length} nights. '
              'The low is the number worth watching; the average smooths away '
              'the dips that make it interesting.',
              style: text.labelSmall?.copyWith(color: colors.ink3),
            ),
          ],
        ],
      ),
    );
  }

  static String _footnote(OvernightVitals vitals) {
    final parts = <String>[
      if (vitals.spo2Min != null)
        if (vitals.spo2Avg case final double average)
          'averaged ${average.round()}% across the night',
    ];
    parts.add('measured by your strap while you slept');
    return parts.join(' · ');
  }
}
