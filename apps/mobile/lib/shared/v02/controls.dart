/// The v02 controls that ACT: `.button`, `.text-button`, `.icon-button.filled`.
///
/// The three that record or select — `.check-action`, `.prompt-button` and
/// `.segment` — live in `choices.dart`; this file was split at the 400-line gate
/// (Standards §1) along that seam.
///
/// ```css
/// .button            { display:inline-flex; justify-content:center; gap:8px;
///                      padding:12px 20px; min-height:48px; border-radius:16px;
///                      background:var(--accent); color:var(--on-accent);
///                      font:700 13px }
/// .button.secondary  { background:var(--surface); color:var(--ink);
///                      border:1px solid var(--rule) }
/// .button.full       { width:100% }
/// .text-button       { display:inline-flex; gap:8px; color:var(--accent);
///                      font:700 12px; min-height:44px }
/// .icon-button.filled{ width:44px; height:44px; border-radius:50%;
///                      background:var(--surface); border:1px solid var(--line) }
/// ```
///
/// **Nothing here takes a `Color`.** `richer.css` gives
/// `.focus-card[data-tone] .text-button { color: var(--family) }`, so a link
/// inside a toned card is the card's family and follows it when the card's tone
/// changes. A parameter would let the two disagree.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// `.button` — filled by default, `.secondary` outlined, `.full` stretched.
class ActionButton extends StatelessWidget {
  /// [onPressed] of null is `button:disabled`.
  const ActionButton({
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.full = false,
    this.trailingIcon,
    super.key,
  });

  /// `min-height: 48px`.
  static const double minHeight = 48;

  /// `border-radius: 16px`.
  static const double radius = 16;

  /// `padding: var(--space-md) var(--space-xl)`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 12,
  );

  /// `gap: var(--space-sm)`.
  static const double gap = 8;

  /// What it says.
  final String label;

  /// What it does. Null disables it.
  final VoidCallback? onPressed;

  /// `.button.secondary`.
  final bool secondary;

  /// `.button.full`.
  final bool full;

  /// The glyph after the label, at `.icon.small`.
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = Row(
      mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypeScale.buttonLabel,
          ),
        ),
        if (trailingIcon case final IconData icon) ...<Widget>[
          const SizedBox(width: gap),
          Icon(icon, size: 16),
        ],
      ],
    );
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(full ? double.infinity : 0, minHeight),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsets>(padding),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(TypeScale.buttonLabel),
    );
    return secondary
        ? OutlinedButton(
            onPressed: onPressed,
            style: style.copyWith(
              foregroundColor: WidgetStatePropertyAll<Color>(colors.ink),
              backgroundColor: WidgetStatePropertyAll<Color>(colors.surface),
              side: WidgetStatePropertyAll<BorderSide>(
                BorderSide(color: colors.rule, width: hairline),
              ),
            ),
            child: child,
          )
        : FilledButton(
            onPressed: onPressed,
            style: style.copyWith(
              foregroundColor: WidgetStatePropertyAll<Color>(colors.onAccent),
              backgroundColor: WidgetStatePropertyAll<Color>(colors.accent),
            ),
            child: child,
          );
  }
}

/// `.text-button` — a label, an arrow, and the family colour.
class TextLink extends StatelessWidget {
  /// [icon] defaults to the prototype's forward arrow.
  const TextLink({
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
    this.iconLeading = false,
    super.key,
  });

  /// `min-height: 44px`.
  static const double minHeight = 44;

  /// `.icon.small`.
  static const double iconSize = 16;

  /// `gap: var(--space-sm)`.
  static const double gap = 8;

  /// The words.
  final String label;

  /// Where it goes.
  final VoidCallback? onPressed;

  /// The glyph after the label.
  final IconData icon;

  /// Whether the glyph comes BEFORE the words instead.
  ///
  /// Two `.text-button` call sites, two orders: `H.link` writes
  /// `${label}${arrow}` and `H.evidence` writes `${info}${label}`. Both are the
  /// same CSS rule with the same gap, so this is which side the icon is
  /// transcribed on rather than a second opinion about the control.
  final bool iconLeading;

  @override
  Widget build(BuildContext context) {
    final family = context.family;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, minHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (iconLeading) ...<Widget>[
            Icon(icon, size: iconSize, color: family),
            const SizedBox(width: gap),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.textLink.copyWith(color: family),
            ),
          ),
          if (!iconLeading) ...<Widget>[
            const SizedBox(width: gap),
            Icon(icon, size: iconSize, color: family),
          ],
        ],
      ),
    );
  }
}

/// `.icon-button.filled` — a 44 px round control on the surface.
class FilledIconButton extends StatelessWidget {
  /// [semanticLabel] is required: a glyph with no words needs them elsewhere.
  const FilledIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  /// `width: 44px; height: 44px`.
  static const double size = 44;

  /// The glyph.
  final IconData icon;

  /// What it does, for a reader who cannot see the glyph.
  final String semanticLabel;

  /// What it does.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surface,
          shape: CircleBorder(
            side: BorderSide(color: colors.line, width: hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: 22, color: colors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
