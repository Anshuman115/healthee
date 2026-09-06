/// `.page-header` on a screen that is not Today: a date, a name, an avatar.
///
/// ```css
/// .page-header        { display:flex; align-items:center;
///                       justify-content:space-between; gap:8px;
///                       margin-bottom:16px; }
/// .page-header .date  { font-size:11px; color:var(--muted);
///                       margin-bottom:5px; }
/// .page-header h1     { font-size:27px; letter-spacing:-1px; line-height:1.2;
///                       font-weight:600; }
/// .icon-button        { width:44px; height:44px; border-radius:50%; }
/// .page-header .avatar{ background:var(--accent-soft); color:var(--accent);
///                       font-weight:700; font-size:15px; }
/// ```
///
/// ## Why this is not `TodayHeader` with a flag
///
/// `H.header(...)` branches in the prototype too: the Today route gets
/// `H.dateControl()` — two chevrons, a calendar and a `Latest` — and every other
/// data screen gets *"a small date label"* (README, **Historical dates**). Today
/// also carries the sync ring round its avatar, which is the connection surface
/// and belongs to the screen that owns the device strip.
///
/// So the two headers are two different controls that happen to share a row
/// shape, and folding them into one widget would mean a `navigation`/`health`
/// pair that is null on every screen but one — the flag-argument shape
/// Standards §3 asks not to grow.
///
/// **The date is `prettyDate`, not the prototype's `31 July`.** Today already
/// prints `FRI · JUL 31` in this slot, and one day worded two ways on two tabs
/// is the drift `shared/format/` exists to stop. The substitution is here
/// rather than at the call sites so there is one of it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/format/date_labels.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';
import 'package:healthee/shared/instrument/h_tap.dart';

/// The date, the screen's name, and the way out to settings.
class V02PageHeader extends StatelessWidget {
  /// [date] is the payload's own `YYYY-MM-DD`; null prints no date line.
  const V02PageHeader({
    required this.title,
    this.date,
    this.onOpenProfile,
    super.key,
  });

  /// `.page-header { margin-bottom: 16px }`.
  static const double bottomGap = 16;

  /// `.page-header .date { margin-bottom: 5px }`.
  static const double dateGap = 5;

  /// The screen's name — the h1.
  final String title;

  /// The day this screen describes. Null draws no line rather than a blank one.
  final String? date;

  /// Opens the owner's own screen. Null draws the avatar without a tap.
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // `Expanded`, and the avatar is intrinsic beside it. Two `Flexible`s
          // would split the row in half and ellipsize a title that fits.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (date case final String iso) ...<Widget>[
                  Text(
                    prettyDate(iso),
                    style: TypeScale.pageDate.copyWith(color: colors.ink2),
                  ),
                  const SizedBox(height: dateGap),
                ],
                Text(
                  title,
                  style: TypeScale.pageTitle.copyWith(color: colors.ink),
                ),
              ],
            ),
          ),
          HTap(
            onTap: onOpenProfile,
            semanticLabel: 'Settings',
            child: const HAvatar('H'),
          ),
        ],
      ),
    );
  }
}
