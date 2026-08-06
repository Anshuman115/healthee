/// How many coach questions are left — shown BEFORE one can be spent.
///
/// `PRICING.md` §0 sells "20 coach questions per rolling 30 days" and argues that
/// *"a stated number beats 'unlimited (fair-use)'"*, because *"'unlimited' with a
/// silent throttle is the dishonest version of the same thing"*. The server built
/// `/api/entitlement.included` (#116) on exactly that argument: **a stated limit
/// nobody can observe until it stops them is most of the way back to the thing
/// that argument rejected.** This widget is the observing half.
///
/// ## The four states, and why none of them is "0 of 20"
///
/// `api/allowance_report.py` documents three shapes on the wire and this reads all
/// three plus the locked case:
///
/// ```text
///   capped, slots free      "17 of 20 questions left, in the last 30 days"
///   capped, window full     "All 20 used. The window reopens …"
///   premium, no entry       uncapped — say so, never a meter reading zero
///   free / locked           not included; `locked` is their story, not a meter
/// ```
///
/// A free owner deliberately does **not** see `0/20`. They were not sold twenty of
/// anything, and a meter reading empty for somebody who has no access at all is an
/// upsell wearing a meter's clothes.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/entitlement.dart';
import 'package:healthee/shared/format/time_labels.dart';

/// The questions-left line.
class CoachMeter extends StatelessWidget {
  /// [entitlement] is the freshly-read `/api/entitlement`.
  const CoachMeter({required this.entitlement, this.now, super.key});

  /// What the server says this owner holds.
  final Entitlement entitlement;

  /// The instant "reopens in …" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Text(
      meterLine(entitlement, now: now ?? DateTime.now()),
      style: text.bodySmall?.copyWith(color: colors.ink2),
    );
  }
}

/// The sentence for [entitlement]. Public so a test can pin it without pixels.
String meterLine(Entitlement entitlement, {required DateTime now}) {
  final allowance = entitlement.allowanceFor(kCoachFeature);
  if (allowance == null) {
    if (entitlement.premium) {
      // Absent from PREMIUM_ALLOWANCE means unlimited, not zero — the asymmetry
      // `api/gate.py` documents and the one an entry with `limit: 0` would invert.
      return 'Your subscription includes the coach with no question limit.';
    }
    return 'The coach is part of the subscription. Nothing you ask here is '
        'counted, because nothing can be asked here yet.';
  }
  if (allowance.hasRemaining) {
    return '${allowance.remaining} of ${allowance.limit} questions left, '
        'over the last ${allowance.windowDays} days.';
  }
  final reopens = allowance.resetsAt;
  return 'All ${allowance.limit} of your questions in the last '
      '${allowance.windowDays} days have been used.'
      '${reopens == null ? '' : ' The window reopens ${untilLabel(reopens, now: now)}.'}';
}
