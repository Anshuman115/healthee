/// `.page-header.detail` — the head every sub-screen opens with.
///
/// ```css
/// .page-header        { display:flex; align-items:center;
///                       justify-content:space-between; gap:8px;
///                       margin-bottom:16px; }
/// .page-header.detail { justify-content:start; margin-left:-8px; }
/// .page-header.detail h1 { font-size:23px; letter-spacing:-.8px; }
/// .page-header .date  { font-size:11px; color:var(--muted);
///                       margin-bottom:5px; }
/// .icon-button        { display:grid; place-items:center; width:44px;
///                       height:44px; border-radius:50%; }
/// ```
///
/// The prototype's detail header is `H.header(title, subtitle, true)`: a back
/// button, then a column of the subtitle over the title, and **no avatar** — the
/// trailing avatar is the non-detail branch only. Both lines come from the
/// screen; nothing here is dated, so the `.date` slot carries the screen's
/// eyebrow instead of a day.
///
/// `margin-left: -8px` pulls the 44 px round hit area back so the **glyph**
/// lines up with the page's text column rather than the button's box. On a
/// `width: auto` element a negative left margin moves the left edge and leaves
/// the right one where it was, so the box comes out 8 px WIDER.
///
/// Flutter has no negative padding, so the substitution is the rendered result:
/// a row laid out 8 px wider than its constraints and translated 8 px left. A
/// `Padding` on the trailing edge would have been the wrong fix — it shrinks
/// the row instead of widening it, and the title's right edge would come in
/// 16 px short of the page.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:solar_icons/solar_icons.dart';

/// A sub-screen's head: back, eyebrow, title.
class DetailHeader extends StatelessWidget {
  /// Builds the head. [onBack] of null draws no button — a screen with nothing
  /// beneath it must not offer a way back to it.
  const DetailHeader({
    required this.title,
    required this.eyebrow,
    required this.onBack,
    super.key,
  });

  /// `.page-header { margin-bottom: 16px }`.
  static const double bottomGap = 16;

  /// `.page-header .date { margin-bottom: 5px }`.
  static const double eyebrowGap = 5;

  /// `.page-header.detail { margin-left: -8px }`.
  static const double outdent = 8;

  /// `.icon-button { width: 44px; height: 44px }`.
  static const double buttonSize = 44;

  /// `.icon { width: 22px }`.
  static const double iconSize = 22;

  /// The screen's name.
  final String title;

  /// The line above it — what this screen is about.
  final String eyebrow;

  /// Leaves the screen.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Transform.translate(
        offset: const Offset(-outdent, 0),
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            width: constraints.maxWidth + outdent,
            child: Row(
              children: <Widget>[
                if (onBack case final VoidCallback back)
                  Semantics(
                    button: true,
                    label: 'Go back',
                    child: GestureDetector(
                      onTap: back,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: Icon(
                          SolarIconsOutline.arrowLeft,
                          size: iconSize,
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FormType.detailTitle.copyWith(color: colors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
