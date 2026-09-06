/// `.page-header`, in its two shapes — the tab's and the pushed screen's.
///
/// ```css
/// .page-header        { display:flex; align-items:center;
///                       justify-content:space-between; gap:8px;
///                       margin-bottom:16px }
/// .page-header .date  { font-size:11px; color:var(--muted); margin-bottom:5px }
/// .page-header h1     { font-size:27px; letter-spacing:-1px }
/// .page-header.detail { justify-content:start; margin-left:-8px }
/// .page-header.detail h1 { font-size:23px; letter-spacing:-.8px }
/// ```
///
/// `components.js::H.header(title, subtitle, detail)` builds both: the detail
/// form puts a back control first and drops the avatar, and the non-detail form
/// keeps the avatar and no back control. Which one a screen uses is decided by
/// whether it is a tab, not by taste.
///
/// **The eyebrow is a `String?` and null draws nothing.** A header that reserved
/// its 5 px gap for a line nothing wrote would move the title down by a space
/// with no content in it, which is the empty-section rule applied to type.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// `.page-header` — a tab's head: eyebrow, title, and whatever sits at the end.
class ScreenHead extends StatelessWidget {
  /// [trailing] is the avatar on the screens that have one.
  const ScreenHead({
    required this.title,
    this.eyebrow,
    this.trailing,
    super.key,
  });

  /// `margin-bottom: var(--space-xl)` — `styles.css` 20, `richer.css` 16.
  static const double bottomGap = 16;

  /// `.page-header .date { margin-bottom: 5px }`.
  static const double eyebrowGap = 5;

  /// `gap: var(--space-sm)`.
  static const double gap = 8;

  /// The screen's name. May be two lines; the prototype's Actions h1 is.
  final String title;

  /// The line above it.
  final String? eyebrow;

  /// The control at the end of the row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (eyebrow case final String line) ...<Widget>[
                  Text(
                    line,
                    style: TypeScale.pageDate.copyWith(color: colors.ink2),
                  ),
                  const SizedBox(height: eyebrowGap),
                ],
                Text(
                  title,
                  style: TypeScale.pageTitle.copyWith(color: colors.ink),
                ),
              ],
            ),
          ),
          if (trailing case final Widget end) ...<Widget>[
            const SizedBox(width: gap),
            end,
          ],
        ],
      ),
    );
  }
}

/// `.page-header.detail` — a back control, the eyebrow, and a 23 px title.
class DetailHead extends StatelessWidget {
  /// [onBack] of null draws no control; every pushed screen supplies one.
  const DetailHead({
    required this.title,
    this.eyebrow,
    this.onBack,
    super.key,
  });

  /// `.page-header { margin-bottom: 16px }`.
  static const double bottomGap = ScreenHead.bottomGap;

  /// `.page-header.detail { margin-left: -8px }` — the icon button's own
  /// padding, pulled back so the glyph lines up with the title's left edge.
  static const double backSize = 44;

  /// `.page-header .date { margin-bottom: 5px }`.
  static const double eyebrowGap = ScreenHead.eyebrowGap;

  /// The screen's name.
  final String title;

  /// The line above it — a date, or what kind of thing this is.
  final String? eyebrow;

  /// Goes back.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (onBack case final VoidCallback back)
            // `margin-left: -8px` is the row's, so it is spent here rather than
            // on the whole header: a negative inset on the Column would move the
            // title too, and the prototype's title does not move.
            Transform.translate(
              offset: const Offset(-8, 0),
              child: SizedBox(
                width: backSize,
                height: backSize,
                child: IconButton(
                  onPressed: back,
                  icon: const Icon(Icons.arrow_back),
                  color: colors.ink,
                  tooltip: 'Go back',
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (eyebrow case final String line) ...<Widget>[
                  Text(
                    line,
                    style: TypeScale.pageDate.copyWith(color: colors.ink2),
                  ),
                  const SizedBox(height: eyebrowGap),
                ],
                Text(
                  title,
                  style: TypeScale.detailTitle.copyWith(color: colors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
