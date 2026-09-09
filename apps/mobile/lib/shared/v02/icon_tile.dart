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
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';

/// A 40 × 40 tile carrying one icon in the family colour.
class IconTile extends StatelessWidget {
  /// Builds a tile around [icon], in the enclosing family.
  const IconTile(
    this.icon, {
    this.iconSize = defaultIconSize,
    this.boxSize = size,
    super.key,
  }) : chrome = false;

  /// A tile for APP CHROME, in the owner's chosen accent.
  ///
  /// **A settings row is not a reading.** The family tile resolves the enclosing
  /// `ToneScope`, and a settings row declares none — so every row on every
  /// settings screen fell through to `fitness`, the `:root` default, and wore
  /// the colour of recovery and VO₂max. `tone.dart` still calls `fitness` "the
  /// app's accent" and `palette.dart` did define it that way, but
  /// `AppearanceColors` has overridden `accent` from the owner's own choice
  /// since the appearance variants landed. So a phone set to Amber showed an
  /// amber tab bar, an amber coach button, and twelve green settings rows.
  ///
  /// This asks for the accent by name. It is still not a colour handed in from
  /// a call site — the tile resolves the token itself, which is the contract
  /// `list_row.dart` describes.
  const IconTile.chrome(
    this.icon, {
    this.iconSize = defaultIconSize,
    this.boxSize = size,
    super.key,
  }) : chrome = true;

  /// `width: 40px; height: 40px`.
  static const double size = 40;

  /// `border-radius: 13px`.
  static const double radius = 13;

  /// The tile on a compact row — see `list_row.dart`'s `minHeight`.
  static const double compactSize = 34;

  /// Its corner, scaled with it. Above `hSquircle`'s floor of 12, so it is
  /// still a superellipse and not an arc.
  static const double compactRadius = 12;

  /// `.icon { width: 22px }` — the prototype's default glyph size.
  static const double defaultIconSize = 22;

  /// The glyph.
  final IconData icon;

  /// Its size. `.icon.small` is 16.
  final double iconSize;

  /// Whether this tile is chrome, and so wears the owner's accent.
  final bool chrome;

  /// The box. [compactSize] on a compact row; [size] everywhere else.
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxSize,
      height: boxSize,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: chrome ? context.colors.accentSoft : context.familySoft,
        shape: hSquircle(boxSize == size ? radius : compactRadius),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: chrome ? context.colors.accent : context.family,
      ),
    );
  }
}
