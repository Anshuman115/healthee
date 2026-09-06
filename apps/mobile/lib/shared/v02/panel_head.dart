/// `.panel-head` — a panel's title row: icon, title, and one text action.
///
/// ```css
/// .panel-head  { display: flex; justify-content: space-between;
///                align-items: center; gap: 8px; margin-bottom: 12px; }
/// .panel-title { display: flex; align-items: center; gap: 8px;
///                font-size: 13px; font-weight: 700; }
/// .panel-title > .icon    { width: 17px; height: 17px; color: var(--family); }
/// .panel .text-button     { color: var(--family); min-height: 28px;
///                           font-size: 11px; }
/// ```
///
/// The action is built here rather than accepted as a `Widget`, so its colour,
/// size and minimum height cannot be bypassed — the icon and the action are the
/// two places a panel's tone becomes visible, and a caller that passed its own
/// button would be the one thing in the card not following the cascade.
///
/// **28 px is under the 48 px tap target Material asks for**, and it is the
/// prototype's number. It is a secondary affordance inside a card that is itself
/// usually tappable; the size is the spec's and is flagged here rather than
/// quietly widened, because widening it would move every panel's head.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/v02/panel_density.dart';

/// The head of a [Panel]: title (+ optional icon) left, optional action right.
class PanelHead extends StatelessWidget {
  /// Builds a head. [onAction] without [actionLabel] draws nothing.
  const PanelHead({
    required this.title,
    this.icon,
    this.infoKey,
    this.detail = MetricDetail.none,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// `.panel-title > .icon { width: 17px }`.
  static const double iconSize = 17;

  /// The `gap: 8px` shared by `.panel-head` and `.panel-title`.
  static const double gap = 8;

  /// `.panel .text-button { min-height: 28px }`.
  static const double actionMinHeight = 28;

  /// The panel's name.
  final String title;

  /// Drawn in the resolved family colour, before the title.
  final IconData? icon;

  /// Opens the plain-language explainer for this metric, when it has one.
  ///
  /// The prototype's `H.evidence(...)` — *"How we know"* with an info glyph —
  /// on every panel whose number is a model output. An unknown key draws
  /// nothing (`metric_info_sheet.dart`), so a panel naming a metric this build
  /// has no explainer for is silent rather than dead.
  final String? infoKey;

  /// This panel's OWN provenance — its references, its payload citations, and
  /// the prose that used to sit under its chart.
  ///
  /// The head owns the ⓘ, so the head is where a card hands over what the ⓘ has
  /// to carry. A non-empty detail draws the dot even for a panel with no
  /// explainer entry, because the alternative is a card whose sources became
  /// unreachable — see `metric_info_sheet.dart`.
  final MetricDetail detail;

  /// The text button's label. Null draws no action.
  final String? actionLabel;

  /// What the action does.
  final VoidCallback? onAction;

  /// `.twin-panels .panel-head .text-button .icon { width: 13px }`.
  static const double compactActionIcon = 13;

  /// `.twin-panels .panel-title { gap: 5px }`.
  static const double compactGap = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final family = context.family;
    final compact = context.compactPanel;
    final label = actionLabel;
    if (compact) {
      return _compact(context, colors.ink, family, label);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: iconSize, color: family),
                const SizedBox(width: gap),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TypeScale.panelTitle.copyWith(color: colors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        MetricInfoDot(infoKey, detail: detail, fallbackTitle: title),
        if (label != null) ...<Widget>[
          const SizedBox(width: gap),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: family,
              textStyle: TypeScale.textButton,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, actionMinHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(label),
          ),
        ],
      ],
    );
  }

  /// The half-width head: a smaller title, and an action reduced to its arrow.
  ///
  /// `font-size: 0` on the text button is the prototype deleting the words and
  /// keeping the glyph. A `Text('')` would do the same thing and would still be
  /// read aloud as an empty button, so the label travels as the icon's semantic
  /// label instead — the control keeps its name for anyone who cannot see the
  /// arrow.
  Widget _compact(
    BuildContext context,
    Color ink,
    Color family,
    String? label,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      if (icon != null) ...<Widget>[
        Icon(icon, size: iconSize, color: family),
        const SizedBox(width: compactGap),
      ],
      Expanded(
        child: Text(
          title,
          style: TypeScale.panelTitleCompact.copyWith(color: ink),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      MetricInfoDot(infoKey, detail: detail, fallbackTitle: title),
      if (label != null) ...<Widget>[
        const SizedBox(width: compactGap),
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onAction,
            child: Icon(
              Icons.arrow_forward,
              size: compactActionIcon,
              color: family,
            ),
          ),
        ),
      ],
    ],
  );
}
