/// The little `value over LABEL` column that ends four of legacy's Today cards.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart` — `_vstat`
/// (1271), `_mstat` (1320), `_sstat` (1458) and `_zoneStat` (1394). The first
/// three are **character-for-character identical** in legacy, copied into three
/// classes; Standards §1 says the second occurrence is an extract, so there is
/// one here. The zone variant genuinely differs (a smaller figure and a coloured
/// dot beside the label) and keeps its own widget.
///
/// Both are `Expanded`, because every legacy call site puts them straight into a
/// `Row` and relies on that.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';

/// One figure over its label. Legacy's `_vstat` / `_mstat` / `_sstat`.
class StatColumn extends StatelessWidget {
  /// [value] is already formatted; this widget does not round.
  const StatColumn({required this.label, required this.value, super.key});

  /// The uppercase caption — `MODERATE`, `2-WK DEBT`.
  final String label;

  /// The figure above it, or an em dash when there is none.
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: HType.number(colors.ink, size: 18)),
          const SizedBox(height: 3),
          Text(
            label,
            style: HType.label(colors.ink3, size: 8, tracking: 0.08),
          ),
        ],
      ),
    );
  }
}

/// One heart-rate zone's minutes. Legacy's `_zoneStat`.
class ZoneStatColumn extends StatelessWidget {
  /// [minutes] is the zone's own total; [color] is its band colour.
  const ZoneStatColumn({
    required this.label,
    required this.minutes,
    required this.color,
    super.key,
  });

  /// `Z1` … `Z5`.
  final String label;

  /// Minutes spent in the zone.
  final int minutes;

  /// The colour the strip above draws this zone in.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text('$minutes', style: HType.number(colors.ink, size: 16)),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: HType.label(colors.ink3, size: 8, tracking: 0.06),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
