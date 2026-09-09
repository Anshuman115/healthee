/// `.button`, `.button.secondary`, `.button.soft` and `.text-button`.
///
/// ```css
/// .button           { display:inline-flex; justify-content:center;
///                     align-items:center; gap:8px; padding:12px 20px;
///                     min-height:48px; border-radius:16px;
///                     background:var(--accent); color:var(--on-accent);
///                     font-weight:700; font-size:13px; }
/// .button.secondary { background:var(--surface); color:var(--ink);
///                     border:1px solid var(--rule); }
/// .button.soft      { background:var(--accent-soft); color:var(--accent); }
/// .button.full      { width:100%; }
/// .text-button      { display:inline-flex; align-items:center; gap:8px;
///                     color:var(--accent); font-size:12px; font-weight:700;
///                     min-height:44px; }
/// button:disabled   { cursor:not-allowed; opacity:.45; }
/// ```
///
/// ## These read `--accent`, and `--accent` is not `--family`
///
/// The prototype paints a button with `var(--accent)`, which `richer.css` aliases
/// to `--fitness` at `:root` and **never** re-points inside a `[data-tone]`
/// block. So a primary button on a sleep-toned screen is still green in the
/// prototype, and it is still green here: the ground comes from
/// `context.colors.accent`, a theme token, not from `context.family`.
///
/// That is not a `Color` parameter and does not weaken the tone rule. The rule
/// bans a caller **handing a widget a hue**; reading a role off the active theme
/// is what every primitive here does for ink, line and surface. `tone_scope.dart`
/// makes the distinction: the hazard is a colour that can disagree with the card
/// it sits in, and a token cannot.
///
/// A disabled button is `opacity: .45` on the whole control, which is what the
/// CSS does — dimming the label alone would leave a full-strength accent slab
/// advertising an action that is not available.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:solar_icons/solar_icons.dart';

/// Which of the three button grounds a [HButton] wears.
enum HButtonKind {
  /// `.button` — accent ground, the primary path.
  primary,

  /// `.button.secondary` — surface ground with a `--rule` edge.
  secondary,

  /// `.button.soft` — accent-soft ground, accent label.
  soft,
}

/// `.button` — the one button shape in the product.
class HButton extends StatelessWidget {
  /// Builds a button. [onPressed] of null draws it disabled, never absent.
  const HButton({
    required this.label,
    required this.onPressed,
    this.kind = HButtonKind.primary,
    this.icon,
    this.full = true,
    super.key,
  });

  /// `min-height: 48px`.
  static const double minHeight = 48;

  /// `border-radius: 16px`.
  static const double radius = 16;

  /// `padding: 12px 20px`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 12,
  );

  /// `.button { gap: 8px }`.
  static const double gap = 8;

  /// `.icon.small { width: 16px }` — a button's leading glyph.
  static const double iconSize = 16;

  /// `button:disabled { opacity: .45 }`.
  static const double disabledOpacity = 0.45;

  /// The words on it.
  final String label;

  /// What it does. Null disables it.
  final VoidCallback? onPressed;

  /// Which ground it wears.
  final HButtonKind kind;

  /// A leading glyph. Null draws none.
  final IconData? icon;

  /// `.full` — whether it spans the row. The settings screens always do.
  final bool full;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (Color ground, Color mark, Color? edge) = switch (kind) {
      HButtonKind.primary => (colors.accent, colors.onAccent, null),
      HButtonKind.secondary => (colors.surface, colors.ink, colors.rule),
      HButtonKind.soft => (colors.accentSoft, colors.accent, null),
    };
    final enabled = onPressed != null;
    final Widget button = Opacity(
      opacity: enabled ? 1 : disabledOpacity,
      child: Container(
        constraints: const BoxConstraints(minHeight: minHeight),
        padding: padding,
        decoration: ShapeDecoration(
          color: ground,
          shape: hSquircle(
            radius,
            side: edge == null
                ? BorderSide.none
                : BorderSide(color: edge, width: hairline),
          ),
        ),
        child: Row(
          mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon case final IconData glyph) ...<Widget>[
              Icon(glyph, size: iconSize, color: mark),
              const SizedBox(width: gap),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FormType.button.copyWith(color: mark),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(onTap: onPressed, child: button),
    );
  }
}

/// `.text-button` — a link with a trailing arrow, in the accent.
class HLinkButton extends StatelessWidget {
  /// Builds the link. [onPressed] of null draws it disabled.
  const HLinkButton({required this.label, required this.onPressed, super.key});

  /// `.text-button { min-height: 44px }`.
  static const double minHeight = 44;

  /// `.text-button { gap: 8px }`.
  static const double gap = 8;

  /// `.icon.small { width: 16px }`.
  static const double iconSize = 16;

  /// The words.
  final String label;

  /// What it does.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: enabled ? 1 : HButton.disabledOpacity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FormType.linkButton.copyWith(color: accent),
                  ),
                ),
                const SizedBox(width: gap),
                Icon(
                  SolarIconsOutline.arrowRight,
                  size: iconSize,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
