/// Steps today — from the strap's own `0x0016` counter, and it says so.
///
/// This card is the reason #121 exists in the memory index. The strap keeps two
/// step numbers: a live since-midnight counter on chunked endpoint `0x0016`, and
/// a per-minute activity buffer that the June-2026 firmware freezes mid-day and
/// backfills with `0xFF`. The counter is the real measurement — it is what the
/// Zepp app shows — and the per-minute sum is, in the legacy code's own words,
/// "possibly frozen / incomplete".
///
/// On the server, 142 of 143 production days ended up carrying the worse number,
/// permanently, because the counter had no durable table and a re-derive
/// overwrote it. **This card renders the counter and nothing else.** There is no
/// fallback to a per-minute sum, because a silent fallback to a number known to
/// be low is the same failure with a nicer shape: withheld beats wrong.
///
/// The read time is shown for a reason particular to this metric. "Since
/// midnight" read at 09:12 is a claim about nine hours, and a nine-hour step
/// count presented as a day's is flattery by omission.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/features/today/widgets/measured_card.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// The day's step total, with the distance and calories the strap counted.
class StepsCard extends StatelessWidget {
  /// [now] is injected so tests do not depend on the wall clock.
  const StepsCard({required this.day, this.now, super.key});

  /// The day being shown.
  final DeviceDay day;

  /// The current instant.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    // The withheld case is `ReadingView`'s, so a strap that did not answer gets
    // the same footprint and title as one that did — never a zero, and never a
    // card that quietly vanishes from the list.
    return ReadingView<int>(
      reading: day.steps,
      label: 'Steps',
      builder: (context, steps) => MeasuredCard(
        title: 'Steps',
        measuredAt: day.stepsReadAt,
        now: now,
        footnote: _footnote(day),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroValue(value: _grouped(steps)),
            const SizedBox(height: Insets.sm),
            const _CounterNote(),
          ],
        ),
      ),
    );
  }

  /// Distance and the strap's own calorie figure, attributed to it.
  ///
  /// The attribution is not politeness. CLAUDE.md pins free-living energy to the
  /// server's MET-by-state model, so a calorie number on this screen must be
  /// unmistakably the device's rather than the product's.
  static String? _footnote(DeviceDay day) {
    final parts = <String>[];
    if (day.distanceKm.valueOrNull case final double km) {
      parts.add('${km.toStringAsFixed(2)} km');
    }
    if (day.deviceCalories.valueOrNull case final int kcal) {
      parts.add("$kcal kcal by the strap's own count");
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Thousands separated, so five digits are readable at a glance.
  static String _grouped(int value) {
    final digits = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        out.write(',');
      }
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// Says which of the strap's two step numbers this is.
class _CounterNote extends StatelessWidget {
  const _CounterNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      "The strap's own since-midnight counter, not a sum of per-minute "
      'samples — that stream freezes on this firmware.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.ink3),
    );
  }
}
