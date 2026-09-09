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

/// The date and the screen's name.
///
/// ## ⛔ No avatar here
///
/// It carried an `H` avatar opening settings, on Sleep, Activity and Insights.
/// **Today already has one**, in its own one-row head, and settings is reachable
/// from there and from the tab bar's own destination — so on three screens it
/// was a fourth door to a room the reader was already standing next to, taking
/// the top-right corner of every one of them. The single door is Today's.
class V02PageHeader extends StatelessWidget {
  /// [date] is the payload's own `YYYY-MM-DD`; null prints no date line.
  const V02PageHeader({
    required this.title,
    this.date,
    this.status,
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

  /// `Latest sample` or `Selected day`, appended after a middot.
  ///
  /// Null prints the bare date, which is what a host with no selection to
  /// report gets. It is separate from [date] because the two say different
  /// things: the date is which day, this is **what kind of day** — and a header
  /// that promised the newest readings on a day that cannot have them is the
  /// whole failure `shared/v02/view_day.dart` is about.
  final String? status;

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
                    status == null
                        ? prettyDate(iso)
                        : '${prettyDate(iso)} · $status',
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
        ],
      ),
    );
  }
}
