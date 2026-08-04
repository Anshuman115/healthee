/// The illness flag — the only place in this product that spends red.
///
/// Brief §2: *"Reserve true red for the illness/safety flag alone."* Brief §4.1:
/// *"if present, it outranks everything. Deterministic, safety-critical, not
/// AI."* Both are honoured here and nowhere else.
///
/// [IllnessFlag.framing] is rendered **verbatim**. It is a calibrated safety
/// sentence — "possible early signal", "consider lighter activity" — and the UI
/// layer has no access to the evidence that calibrated it. Re-wording it here is
/// how a hedge becomes a diagnosis or a warning becomes a shrug.
///
/// The deltas sit under it because the flag is deterministic and the owner is
/// entitled to see what fired it: respiratory rate and skin temperature, each
/// against **their own** baseline, not a population's.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/illness_flag.dart';
import 'package:healthee/shared/states/citation_row.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// A possible early illness signal, with what fired it.
class IllnessBanner extends StatelessWidget {
  /// Renders [flag]. Callers show this only when the payload carried one.
  const IllnessBanner({required this.flag, super.key});

  /// The flag, with its calibrated sentence.
  final IllnessFlag flag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      border: colors.alert,
      fill: colors.alertSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'POSSIBLE EARLY SIGNAL',
                style: text.labelSmall?.copyWith(
                  color: colors.alert,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              if (flag.sustained)
                Text(
                  'sustained',
                  style: text.labelSmall?.copyWith(color: colors.alert),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          // Verbatim. See the library docstring.
          Text(flag.framing, style: text.bodyLarge),
          if (_deltas() case final String line) ...[
            const SizedBox(height: Insets.sm),
            Text(line, style: text.bodySmall?.copyWith(color: colors.ink2)),
          ],
          const SizedBox(height: Insets.md),
          CitationRow(noteIds: flag.researchNoteIds),
        ],
      ),
    );
  }

  /// What moved, against the owner's own normal. Null when neither was sent.
  String? _deltas() {
    final parts = <String>[
      if (flag.respiratoryRateDeltaBpm case final double rr)
        'breathing rate ${_signed(rr, 1)} bpm vs your baseline',
      if (flag.skinTempDeltaC case final double temp)
        'skin temperature ${_signed(temp, 2)} °C vs your baseline',
    ];
    return parts.isEmpty ? null : '${parts.join(' · ')}.';
  }

  static String _signed(double value, int digits) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(digits)}';
}
