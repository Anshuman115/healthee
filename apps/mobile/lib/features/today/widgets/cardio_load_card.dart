/// `Strain · cardio load` — Banister TRIMP, its trend, and the zone strip.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:1330` —
/// `_CardioLoadModule`. Anatomy unchanged: strain as a 40 px figure over its
/// maximum, a 6 px bar, a line of load / delta-vs-usual / average, a 46 px
/// filled area of the 30-day trend, then the proportional zone strip and five
/// zone columns.
///
/// ```text
///   STRAIN · CARDIO LOAD                              TRIMP
///   21.0  / 21 strain
///   ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬
///   55 load   +0 vs usual   · avg 55
///   ╱‾‾╲___╱‾╲
///   ▮▮▮▮ ▮▮▮ ▮▮ ▮ ▮
///   20   12   8   4   3
///   Z1   Z2   Z3  Z4  Z5
/// ```
///
/// The five zone colours are legacy's exact list — `[cSpo2, green, cSteps,
/// cCal, cHeart]` — which is a deliberate cool-to-hot ramp and the one place on
/// Today where a hue sequence carries meaning rather than identity.
///
/// The strip draws only the zones with minutes in them, each `Expanded` by its
/// own minutes, so its widths are the real proportions. A zone with no minutes
/// is absent from the strip and still keeps its column below, at zero.
///
/// Legacy draws this module in `cHeart` on Today and in `cReady` on its Activity
/// screen. `metric_hue.dart` records that disagreement and resolves it to Today's.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/features/today/widgets/stat_columns.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/instrument/h_progress_bar.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// Today's training load against the owner's own 30-day baseline.
class CardioLoadCard extends StatelessWidget {
  /// [load] is the whole `cardio_load` block.
  const CardioLoadCard({required this.load, required this.reveals, super.key});

  /// Today's load, strain, zones and trend.
  final CardioLoad load;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  /// How many zones the strip and the columns always account for.
  static const int zoneCount = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final tint = hues.heart;
    // Legacy's Z1..Z5 ramp (`today_screen.dart:1345`).
    final zoneColors = <Color>[
      hues.oxygen,
      colors.accent,
      hues.movement,
      hues.movement,
      hues.heart,
    ];
    final zones = <int>[
      for (var i = 0; i < zoneCount; i++)
        i < load.zoneMinutes.length ? load.zoneMinutes[i] : 0,
    ];
    final zoneTotal = zones.fold<int>(0, (sum, minutes) => sum + minutes);
    final strain = load.strain;
    final strainMax = load.strainMax?.round() ?? 21;
    final baseline = load.baseline30d;
    final delta = baseline != null && baseline > 0 ? load.load - baseline : null;
    final trend = <double>[for (final point in load.trend30d) point.value];
    return InstrumentModule(
      label: 'Strain · cardio load',
      infoKey: 'cardio_load',
      tag: tint,
      minHeight: 0,
      trailing: Text(
        'TRIMP',
        style: HType.label(colors.ink3, size: 9, tracking: 0.06),
      ),
      children: [
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              strain?.toStringAsFixed(1) ?? load.load.round().toString(),
              style: HType.number(
                colors.ink,
                size: 40,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            if (strain != null)
              Text(
                '/ $strainMax strain',
                style: HType.number(
                  colors.ink3,
                  size: 13,
                  weight: FontWeight.w400,
                ),
              ),
          ],
        ),
        if (strain != null) ...[
          const SizedBox(height: 10),
          RevealOnce(
            id: 'today.cardio-strain',
            registry: reveals,
            builder: (context, t) => HProgressBar(
              value: strain,
              max: strainMax.toDouble(),
              progress: t,
              height: 6,
              color: tint,
              semanticLabel: 'Strain $strain of $strainMax',
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${load.load.round()} load',
              style: HType.number(
                colors.ink3,
                size: 11,
                weight: FontWeight.w400,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: 8),
              Text(
                '${delta >= 0 ? '+' : ''}${delta.round()} vs usual',
                style: HType.number(
                  tint,
                  size: 11,
                  weight: FontWeight.w700,
                ),
              ),
            ],
            if (baseline != null) ...[
              const SizedBox(width: 8),
              Text(
                '· avg ${baseline.round()}',
                style: HType.number(
                  colors.ink3,
                  size: 11,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        RevealOnce(
          id: 'today.cardio-trend',
          registry: reveals,
          builder: (context, t) => HArea(
            trend,
            color: tint,
            progress: t,
            height: 46,
            unit: 'load',
          ),
        ),
        if (zoneTotal > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < zoneCount; i++)
                if (zones[i] > 0)
                  Expanded(
                    flex: zones[i],
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.only(right: i < zoneCount - 1 ? 2 : 0),
                      decoration: BoxDecoration(
                        color: zoneColors[i],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < zoneCount; i++)
                ZoneStatColumn(
                  label: 'Z${i + 1}',
                  minutes: zones[i],
                  color: zoneColors[i],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
