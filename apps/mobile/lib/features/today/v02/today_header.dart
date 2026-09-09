/// Today's head: the day, the strap, and the avatar — on ONE row.
///
/// ```css
/// .page-header       { display:flex; align-items:center;
///                      justify-content:space-between; gap:8px;
///                      margin-bottom:16px; }
/// .page-header .date { font-size:11px; color:var(--muted); margin-bottom:5px; }
/// .page-header h1    { font-size:27px; letter-spacing:-1px; line-height:1.2;
///                      font-weight:600; }
/// .device-strip      { display:flex; align-items:center; gap:7px;
///                      color:var(--subtle); font-size:10px;
///                      margin-bottom:20px; }
/// .device-strip .icon{ width:15px; height:15px; }
/// .status-dot        { width:5px; height:5px; background:var(--positive);
///                      border-radius:50%; }
/// ```
///
/// ## The greeting is gone, and so is the title under it
///
/// The screen this replaces opened with a two-line 42 px *"Good morning, there."*
/// — legacy's `_GreetingHeader`, including legacy's degraded fallback for an
/// owner whose name nothing stores. The v02 prototype replaced it with the word
/// **Today** over the date, and the README records why: *"replaces generic
/// main-screen slogans with direct labels such as Today, Sleep, Activity"*. A
/// salutation to nobody was the largest type on the screen and said the least.
///
/// **That title is now gone too, and the date has taken its place.** Three rows
/// stood between the top of the screen and the first number — a date, a 27px
/// `Today`, and a full-width device strip — and two of them were labels. The
/// tab bar already names this screen, in the accent, with a filled glyph; a
/// second `Today` in 27px type said the same thing twice and was only true
/// until midnight. `dayTitle` folds the two into one line that says **Today**
/// on the newest day and names the day on any other, which is the case where a
/// header has something to tell you.
///
/// The device strip folds the same way. It spent a full row on the word
/// *Helio Strap* — there is one strap — and on *Data & sync ›* beside it. Both
/// are now [StrapChip]: the glyph, the health dot, the charge and a chevron,
/// as one tap target with the words in its semantics.
///
/// ## The ring stays, because it is the only connection chrome there is
///
/// `sync_ring.dart` is unchanged and still wraps the avatar: one classification,
/// one ring. The strap's charge moves off the eyebrow and into the device strip,
/// which is where the prototype puts anything about the device.
///
/// The status dot is `positive` only when the link is actually healthy —
/// `ConnectionHealth.quiet` — and `ink3` otherwise. A green dot beside a strap
/// that has not been heard from in two days is the flattery this product exists
/// not to do.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/features/today/v02/date_control.dart';
import 'package:healthee/shared/connection/sync_ring.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:solar_icons/solar_icons.dart';

/// `DataFooter` moved to `shared/v02/` when Activity and Insights grew the same
/// footer (Standards §1, second use). Re-exported so Today's call sites and its
/// order test are unchanged and there is still one definition.
export 'package:healthee/shared/v02/data_footer.dart' show DataFooter;

/// The day, the strap and the avatar, on one row.
class TodayHeader extends StatelessWidget {
  /// [date] is the payload's own `YYYY-MM-DD`.
  const TodayHeader({
    required this.date,
    required this.now,
    this.health,
    this.navigation,
    this.batteryPercent,
    this.onOpenProfile,
    this.onOpenSync,
    super.key,
  });

  /// `.page-header { margin-bottom: 16px }`, plus the strip's own 20 that this
  /// row absorbed — the head is one block now, and it ends once.
  static const double bottomGap = 20;

  /// Between the day and the strap, and between the strap and the avatar.
  static const double gap = 12;

  /// The day this screen describes, as the server dated it.
  final String date;

  /// The instant the screen is being read at. Kept because the header is where
  /// a "this is not today" line will land; nothing draws it yet.
  final DateTime now;

  /// The classified connection, or null when nothing has classified one. Null
  /// draws no ring rather than a reassuring one.
  final ConnectionHealth? health;

  /// Where the date may move to, and who to tell. **Null draws the date as a
  /// plain label** — a screen that cannot change the day it is showing should
  /// not offer chevrons that do nothing.
  final DateNavigation? navigation;

  /// The strap's charge at the last sync. Null prints no charge.
  final int? batteryPercent;

  /// Opens the owner's own screen.
  final VoidCallback? onOpenProfile;

  /// Opens the sync surface, from the strap chip.
  final VoidCallback? onOpenSync;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Row(
        children: <Widget>[
          // `Expanded` around an `Align`, not a bare `Flexible` beside a
          // `Spacer`: flex children split the free space by their factors, so a
          // spacer of flex 1 took half the row and ellipsised `Today` to `T…`.
          // The control takes the whole leftover and sizes itself inside it, so
          // the forward chevron sits beside the date instead of at the far end.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: navigation == null
                  ? Text(
                      prettyDate(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.pageDateStrong.copyWith(
                        color: colors.ink,
                      ),
                    )
                  : DateControl(
                      date: date,
                      navigation: navigation!,
                      prominent: true,
                    ),
            ),
          ),
          const SizedBox(width: gap),
          StrapChip(
            health: health,
            batteryPercent: batteryPercent,
            onOpenSync: onOpenSync,
          ),
          const SizedBox(width: gap),
          SyncRing(
            health: health,
            child: HTap(
              onTap: onOpenProfile,
              semanticLabel: 'Settings',
              child: const HAvatar('H'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The strap, compressed to a chip: its glyph, its health, its charge.
///
/// What it dropped and why is in the library docstring. What it kept is every
/// fact the strip carried a number for — and the dot, which is `positive` ONLY
/// when the classification found nothing to say. A green dot beside a strap that
/// has not been heard from in two days is the flattery this product exists not
/// to do; the full sentence is on the data-health card either way.
class StrapChip extends StatelessWidget {
  /// [batteryPercent] of null prints no charge; nothing has read one.
  const StrapChip({
    this.health,
    this.batteryPercent,
    this.onOpenSync,
    super.key,
  });

  /// `.device-strip .icon { width: 15px }`.
  static const double iconSize = 15;

  /// The chevron that says the chip opens something.
  static const double chevronSize = 12;

  /// `.status-dot { width: 5px; height: 5px }`.
  static const double dotSize = 5;

  /// `.device-strip { gap: 7px }`, tightened for a chip.
  static const double gap = 5;

  /// The strap this app talks to. One device, named — in the semantics.
  static const String deviceName = 'Helio Strap';

  /// Where the chip leads.
  static const String action = 'Data & sync';

  /// The classified connection. Null draws a neutral dot, never a green one.
  final ConnectionHealth? health;

  /// The strap's charge at the last sync.
  final int? batteryPercent;

  /// Opens the sync surface.
  final VoidCallback? onOpenSync;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Green only when the classification found nothing to say. `alerts` is the
    // union of the link's own faults and the data's, so an empty one is the
    // whole surface agreeing that the strap is being heard from.
    final state = health;
    final healthy = state != null && state.alerts.isEmpty;
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(SolarIconsOutline.watchRound, size: iconSize, color: colors.ink3),
        const SizedBox(width: gap),
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: healthy ? colors.fav : colors.ink3,
            shape: BoxShape.circle,
          ),
        ),
        if (batteryPercent case final int percent) ...<Widget>[
          const SizedBox(width: gap),
          Text(
            '$percent%',
            style: TypeScale.deviceStrip.copyWith(color: colors.ink3),
          ),
        ],
        Icon(
          SolarIconsOutline.altArrowRight,
          size: chevronSize,
          color: colors.ink3,
        ),
      ],
    );
    return onOpenSync == null
        ? chip
        : Semantics(
            button: true,
            label: '$deviceName · $action',
            child: GestureDetector(
              onTap: onOpenSync,
              behavior: HitTestBehavior.opaque,
              child: chip,
            ),
          );
  }
}
