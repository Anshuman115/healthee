/// `.bio-eyebrow` — the hero's top row, and the one place its ⓘ can live.
///
/// Split out of `bio_hero.dart` at the 400-line gate (Standards section 1), but
/// it earns its own file for a second reason: this row decides where the card's
/// disclosures go. A hero either prints the model line and the caveat under the
/// contributions, or hands both to the ⓘ built here — never both, and never
/// neither.
///
/// ```css
/// .bio-eyebrow       { display:flex; justify-content:space-between;
///                      font-size:12px; font-weight:600; }
/// .bio-eyebrow .icon { width: 17px }
/// .bio-controls      { display:flex; align-items:center; gap:12px; }
/// ```
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/type_scale_bio.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';

/// The hero's eyebrow: its label, at most one action, and an optional arrow.
class BioEyebrow extends StatelessWidget {
  /// Builds the row. [minHeight] pins it in the centred (motion) layout.
  const BioEyebrow({
    required this.label,
    required this.ink,
    required this.minHeight,
    this.action,
    this.infoKey,
    this.modelLabel,
    this.caveats = const <Disclosure>[],
    this.caveatsLabel,
    this.icon,
    this.iconSize = 17,
    this.gap = 12,
    this.onIconTap,
    this.semanticLabel,
    super.key,
  });

  /// The eyebrow's words.
  final String label;

  /// The hero's own ink — see `bio_hero_parts.dart` on why this is a parameter.
  final Color ink;

  /// `.bio-controls .motion-toggle` is 32px and sets the row's height, not the
  /// 12px label. Pinned so the still centre is arithmetic, not a measurement.
  final double minHeight;

  /// A widget the host supplies instead of the built-in ⓘ.
  final Widget? action;

  /// Which explainer the built-in ⓘ opens. Ignored when [action] is given.
  final String? infoKey;

  /// The line naming the model, routed into the ⓘ's sheet.
  final String? modelLabel;

  /// The card's disclosures, routed into the same sheet.
  final List<Disclosure> caveats;

  /// What the disclosures are called there.
  final String? caveatsLabel;

  /// The trailing arrow, if the eyebrow opens something.
  final IconData? icon;

  /// `.bio-eyebrow .icon { width: 17px }`.
  final double iconSize;

  /// `.bio-controls { gap: 12px }`.
  final double gap;

  /// What the arrow opens.
  final VoidCallback? onIconTap;

  /// The arrow's `aria-label`; the eyebrow's own words when absent.
  final String? semanticLabel;

  /// Whether this row carries something to the right of the label.
  bool get _hasAction => action != null || infoKey != null;

  /// The label. **Left, even on a centred card** — the owner asked for it back
  /// there after seeing it centred, and it is the card's name rather than part
  /// of the reading the halo is centred around.
  Widget _label() => Text(
    label,
    style: BioType.bioEyebrow.copyWith(color: ink),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  List<Widget> _actions() => <Widget>[
    if (action case final Widget supplied)
      supplied
    else if (infoKey case final String key)
      MetricInfoDot(
        key,
        ink: ink,
        detail: MetricDetail(
          source: modelLabel,
          disclosures: caveats,
          disclosuresLabel: caveatsLabel,
        ),
      ),
    if (_hasAction && icon != null) SizedBox(width: gap),
    if (icon case final IconData arrow)
      HTap(
        onTap: onIconTap,
        semanticLabel: semanticLabel ?? label,
        child: Icon(arrow, size: iconSize, color: ink),
      ),
  ];

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minHeight),
    child: Row(
      children: <Widget>[
        Expanded(child: _label()),
        ..._actions(),
      ],
    ),
  );
}
