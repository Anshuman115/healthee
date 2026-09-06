/// `.icon-tile` — a rounded square holding one icon, in the resolved family.
///
/// ```css
/// .icon-tile             { display: grid; place-items: center;
///                          width: 40px; height: 40px; border-radius: 13px;
///                          background: var(--surface-soft);
///                          color: var(--accent); }
/// [data-tone] .icon-tile { color: var(--family);
///                          background: var(--family-soft); }
/// ```
///
/// The second rule is the cascade: inside any toned container the tile takes the
/// family. Outside one the tone resolves to `Tone.fitness`, whose family **is**
/// `--accent` — so the untoned case in the prototype and the toned case here
/// paint the same colour, and there is no second code path for it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone_scope.dart';

/// A 40 × 40 tile carrying one icon in the family colour.
class IconTile extends StatelessWidget {
  /// Builds a tile around [icon].
  const IconTile(this.icon, {this.iconSize = defaultIconSize, super.key});

  /// `width: 40px; height: 40px`.
  static const double size = 40;

  /// `border-radius: 13px`.
  static const double radius = 13;

  /// `.icon { width: 22px }` — the prototype's default glyph size.
  static const double defaultIconSize = 22;

  /// The glyph.
  final IconData icon;

  /// Its size. `.icon.small` is 16.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.familySoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: context.family),
    );
  }
}
