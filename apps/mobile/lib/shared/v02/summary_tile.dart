/// `.summary-tile` — one number in a row of three, on its family's soft ground.
///
/// ```css
/// .summary-tile            { background: var(--family-soft); color: var(--ink);
///                            border-radius: 18px; padding: 14px 10px 10px;
///                            min-width: 0; }
/// .summary-tile .tile-title{ display: flex; align-items: center; gap: 5px;
///                            font-size: 10px; color: var(--family); }
/// .summary-tile .icon      { width: 13px; height: 13px; }
/// .summary-tile strong     { display: block; font-size: 24px;
///                            letter-spacing: -1px; margin-top: 10px;
///                            white-space: nowrap; }
/// .summary-tile .tile-meta { display: block; font-size: 8.5px;
///                            color: var(--muted); margin-top: 4px;
///                            white-space: nowrap; }
/// .summary-tile .micro-track       { display: flex; gap: 3px; height: 5px;
///                                    margin-top: 14px; }
/// .summary-tile .micro-track i     { flex: 1; background: var(--family);
///                                    border-radius: 3px; opacity: .45; }
/// .summary-tile .micro-track i:nth-child(-n+4) { opacity: 1; }
/// ```
///
/// `white-space: nowrap` on the value and the meta is honesty rather than
/// typography: a wrapped number changes the tile's height, and three tiles of
/// different heights in one row read as three different kinds of thing.
/// `TextOverflow.clip` on a single line is what the CSS does — it lets the glyph
/// run out of the box, and the box clips it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// One summary tile: label, value, qualifier, and an optional micro-track.
class SummaryTile extends StatelessWidget {
  /// Builds a tile. [segments] of zero draws no track.
  const SummaryTile({
    required this.title,
    required this.value,
    this.icon,
    this.meta,
    this.tone,
    this.segments = 0,
    this.filled = defaultFilled,
    super.key,
  });

  /// `border-radius: 18px`.
  static const double radius = 18;

  /// `padding: 14px 10px 10px`.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(10, 14, 10, 10);

  /// `.tile-title { gap: 5px }`.
  static const double titleGap = 5;

  /// `.summary-tile .icon { width: 13px }`.
  static const double iconSize = 13;

  /// `strong { margin-top: 10px }`.
  static const double valueGap = 10;

  /// `.tile-meta { margin-top: 4px }`.
  static const double metaGap = 4;

  /// `.micro-track { margin-top: 14px }`.
  static const double trackGap = 14;

  /// `.micro-track { height: 5px }`.
  static const double trackHeight = 5;

  /// `.micro-track { gap: 3px }`.
  static const double trackSpacing = 3;

  /// `.micro-track i { border-radius: 3px }`.
  static const double trackRadius = 3;

  /// `.micro-track i { opacity: .45 }` — the unfilled segments.
  static const double trackFaintOpacity = 0.45;

  /// `i:nth-child(-n+4)` — the prototype fills the first four.
  static const int defaultFilled = 4;

  /// The tile's label, drawn in the family colour.
  final String title;

  /// The number.
  final String value;

  /// Drawn before [title], at [iconSize].
  final IconData? icon;

  /// The qualifier under the number.
  final String? meta;

  /// Declares the family for this tile. Null inherits the enclosing scope.
  final Tone? tone;

  /// How many segments the micro-track has. Zero draws no track.
  final int segments;

  /// How many of them are at full opacity.
  final int filled;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;
    return tone == null
        ? _body(context)
        : ToneScope(tone: tone, child: Builder(builder: _body));
  }

  Widget _body(BuildContext context) {
    final colors = context.colors;
    final family = context.family;
    final meta = this.meta;
    return Container(
      clipBehavior: Clip.hardEdge,
      padding: padding,
      decoration: BoxDecoration(
        color: context.familySoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: iconSize, color: family),
                const SizedBox(width: titleGap),
              ],
              Flexible(
                child: Text(
                  title,
                  style: TypeScale.tileTitle.copyWith(color: family),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: valueGap),
          Text(
            value,
            style: TypeScale.tileValue.copyWith(color: colors.ink),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
          if (meta != null) ...<Widget>[
            const SizedBox(height: metaGap),
            Text(
              meta,
              style: TypeScale.tileMeta.copyWith(color: colors.ink2),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ],
          if (segments > 0) ...<Widget>[
            const SizedBox(height: trackGap),
            MicroTrack(segments: segments, filled: filled),
          ],
        ],
      ),
    );
  }
}

/// `.micro-track` — equal segments, the first [filled] at full strength.
///
/// Public because a tile is not the only place a discrete progress reading
/// belongs, and because the geometry is asserted directly in the primitive
/// tests rather than through the tile that happens to host it.
class MicroTrack extends StatelessWidget {
  /// Builds a track of [segments], with the first [filled] opaque.
  const MicroTrack({
    required this.segments,
    this.filled = SummaryTile.defaultFilled,
    super.key,
  });

  /// How many segments.
  final int segments;

  /// How many of them are at full opacity.
  final int filled;

  @override
  Widget build(BuildContext context) {
    final family = context.family;
    return SizedBox(
      height: SummaryTile.trackHeight,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < segments; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: SummaryTile.trackSpacing),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < filled
                      ? family
                      : family.withValues(
                          alpha:
                              family.a * SummaryTile.trackFaintOpacity,
                        ),
                  borderRadius: BorderRadius.circular(
                    SummaryTile.trackRadius,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
