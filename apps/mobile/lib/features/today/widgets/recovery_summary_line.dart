/// The editorial line under the greeting: `Recovery — <the server's sentence>.`
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:219` — an
/// 18 px display line at 1.5 height with 20 px under it, the server's own
/// summary in the accent between a fixed prefix and a full stop.
///
/// The sentence is [RecoverySignals.summary] and it is rendered **verbatim**.
/// It is a calibrated statement the server chose from the marker tallies
/// ("Recovery signals lean favorable"), and re-wording or re-punctuating it in
/// the UI is how calibration gets lost. The only thing added is the period,
/// which is legacy's.
///
/// ## Where the fallback went
///
/// Legacy prints `'Your readings are in.'` when the payload has no summary
/// (`today_screen.dart:140`). That sentence is a reassurance about data that may
/// not exist — the same payload that omits a summary is usually the one with no
/// markers to summarise. So a missing summary draws the line without it, and a
/// [Reading] that carries no value at all draws nothing here: the refusal is
/// rendered by the ladder below, which is the card that owns it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';

/// `Recovery — signals lean favorable.`
class RecoverySummaryLine extends StatelessWidget {
  /// [summary] is the server's sentence, or null when it sent none.
  const RecoverySummaryLine({required this.summary, super.key});

  /// The calibrated one-liner. Rendered as it arrived.
  final String? summary;

  /// Legacy's `EdgeInsets.only(bottom: 20)`.
  static const EdgeInsets _padding = EdgeInsets.only(bottom: 20);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = HType.serif(colors.ink, size: 18, height: 1.5);
    return Padding(
      padding: _padding,
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'Recovery'),
            if (summary case final String sentence) ...[
              const TextSpan(text: ' — '),
              TextSpan(
                text: sentence,
                style: HType.serif(colors.accent, size: 18, height: 1.5),
              ),
            ],
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
