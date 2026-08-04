/// The judgements the server owns, standing on Today as refusals.
///
/// Recovery, sleep health, sleep debt, VO₂max and biological age all belong on
/// this screen — brief §4.1 orders Today by what the owner should act on, and
/// recovery is second. None of them can be honestly produced from strap data on
/// the phone, so each is a [Withheld] reading with the reason
/// `derived_on_server`, rendered through the same `WithheldCard` a production
/// withhold uses.
///
/// ## Why they are shown at all rather than simply left out
///
/// A Today with these cards missing would look finished. The owner would have no
/// way to tell "this app does not do recovery" from "recovery is coming from
/// somewhere that is not connected yet", and the first is false. Brief §1 is
/// explicit that a missing number is a first-class designed state and not an
/// absence — so the honest thing is to keep the slot, in its ordered position,
/// and say what stands between the owner and a number.
///
/// When the push and `/api/today` land, these fields change **source**. Their
/// shape, their position and their rendering do not change at all, which is the
/// point of having built them as readings rather than as placeholder copy.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// One server-owned judgement, withheld with its reason.
class ServerDerivedCard extends StatelessWidget {
  /// [label] is the metric's owner-facing name; [reading] its refusal.
  const ServerDerivedCard({
    required this.label,
    required this.reading,
    super.key,
  });

  /// The metric's name, in the position a reported card would use it.
  final String label;

  /// The reading — a `Withheld` on this build, a real value later.
  final Reading<double> reading;

  @override
  Widget build(BuildContext context) {
    return ReadingView<double>(
      reading: reading,
      label: label,
      builder: (context, value) => Text(
        value.toStringAsFixed(1),
        style: Theme.of(context).textTheme.displayLarge,
      ),
    );
  }
}

/// The whole group, in the brief's order, under one quiet heading.
///
/// A heading rather than five unexplained refusals in a row: five identical
/// cards read as breakage, and one sentence naming what they have in common
/// reads as a boundary the app is keeping on purpose.
class ServerDerivedSection extends StatelessWidget {
  /// Reads the withheld readings off [day].
  const ServerDerivedSection({required this.day, super.key});

  /// The day being shown.
  final DeviceDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Derived on the server', style: text.labelSmall),
        const SizedBox(height: Insets.xs),
        Text(
          'These are judgements, not measurements. They are worked out from '
          'your strap data by the server, against a graded research corpus — '
          'never on the phone, because one number computed two ways is two '
          'numbers.',
          style: text.bodySmall?.copyWith(color: colors.ink2),
        ),
        const SizedBox(height: Insets.md),
        for (final (label, reading) in <(String, Reading<double>)>[
          ('Recovery', day.recovery),
          ('Sleep health', day.sleepHealth),
          ('Sleep debt', day.sleepDebt),
          ('VO₂max', day.vo2max),
          ('Biological age', day.biologicalAge),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: ServerDerivedCard(label: label, reading: reading),
          ),
      ],
    );
  }
}
