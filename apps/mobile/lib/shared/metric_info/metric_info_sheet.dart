/// The ⓘ in a card header, and the sheet behind it — **legacy's `HInfoDot` and
/// `showMetricInfo`, ported**.
///
/// `healthee-legacy/app/lib/ui/metric_info.dart:129`. Geometry unchanged: a 16 px
/// outline icon with 4 px of left padding in the header, and a bottom sheet with
/// a 36×5 grab handle, a 24 px display title, three labelled blocks, and the
/// grounding line at the foot.
///
/// The dot **draws nothing for a key the map does not hold**, which is legacy's
/// behaviour and is the right one: an ⓘ that opens an empty sheet is worse than
/// no ⓘ.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/metric_info/metric_info.dart';
import 'package:solar_icons/solar_icons.dart';

/// The small ⓘ button placed in a card header.
class MetricInfoDot extends StatelessWidget {
  /// [infoKey] indexes [kMetricInfo]. An unknown key draws nothing.
  const MetricInfoDot(this.infoKey, {super.key});

  /// Which explainer this opens.
  final String infoKey;

  /// Legacy's `Icon(..., size: 16)`.
  static const double _size = 16;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final info = kMetricInfo[infoKey];
    if (info == null) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => showMetricInfo(context, infoKey),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: Insets.xs),
        child: Semantics(
          button: true,
          label: 'What ${info.title} means',
          child: ExcludeSemantics(
            child: Icon(SolarIconsOutline.infoCircle, size: _size, color: colors.ink3),
          ),
        ),
      ),
    );
  }
}

/// Opens the plain-language explainer for [key]. No-op for an unknown key.
void showMetricInfo(BuildContext context, String key) {
  final info = kMetricInfo[key];
  if (info == null) {
    return;
  }
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MetricInfoSheet(info: info),
    ),
  );
}

class _MetricInfoSheet extends StatelessWidget {
  const _MetricInfoSheet({required this.info});

  final MetricInfo info;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        border: Border.all(color: colors.line),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(info.title, style: HType.serif(colors.ink, size: 24)),
            const SizedBox(height: 18),
            _InfoBlock(
              icon: SolarIconsOutline.documentText,
              label: 'WHAT IT IS',
              body: info.what,
              accent: colors.ink3,
            ),
            const SizedBox(height: 16),
            _InfoBlock(
              icon: SolarIconsOutline.target,
              label: 'WHAT TO AIM FOR',
              body: info.target,
              accent: colors.accent,
            ),
            const SizedBox(height: 16),
            _InfoBlock(
              icon: SolarIconsOutline.heartPulse,
              label: 'WHY IT MATTERS',
              body: info.why,
              accent: hues.heart,
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(Radii.badge),
              ),
              child: Row(
                children: [
                  Icon(SolarIconsOutline.shieldCheck, size: 14, color: colors.ink3),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      'Grounded in peer-reviewed research, not marketing scores.',
                      style: HType.sans(colors.ink3, size: 11.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: Insets.sm),
            Text(label, style: HType.label(accent, tracking: 0.1)),
          ],
        ),
        const SizedBox(height: 7),
        Text(body, style: HType.sans(colors.ink, size: 14.5, height: 1.55)),
      ],
    );
  }
}
