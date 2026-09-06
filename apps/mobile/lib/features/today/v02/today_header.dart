/// Today's head: the date, the screen's name, the avatar, and the strap row.
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
/// ## The greeting is gone, and that is the port rather than a preference
///
/// The screen this replaces opened with a two-line 42 px *"Good morning, there."*
/// — legacy's `_GreetingHeader`, including legacy's degraded fallback for an
/// owner whose name nothing stores. The v02 prototype opens with the word
/// **Today** over the date, and the README records why: *"replaces generic
/// main-screen slogans with direct labels such as Today, Sleep, Activity"*. A
/// salutation to nobody was the largest type on the screen and said the least.
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

/// The date, the title, and the avatar with its ring.
class TodayHeader extends StatelessWidget {
  /// [date] is the payload's own `YYYY-MM-DD`.
  const TodayHeader({
    required this.date,
    required this.now,
    this.health,
    this.navigation,
    this.onOpenProfile,
    super.key,
  });

  /// `.page-header { margin-bottom: 16px }`.
  static const double bottomGap = 16;

  /// `.page-header .date { margin-bottom: 5px }`.
  static const double dateGap = 5;

  /// The prototype's own h1 for this screen.
  static const String title = 'Today';

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

  /// Opens the owner's own screen.
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (navigation case final DateNavigation navigation)
                  DateControl(date: date, navigation: navigation)
                else
                  Text(
                    prettyDate(date),
                    style: TypeScale.pageDate.copyWith(color: colors.ink2),
                  ),
                const SizedBox(height: dateGap),
                Text(
                  title,
                  style: TypeScale.pageTitle.copyWith(color: colors.ink),
                ),
              ],
            ),
          ),
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

/// `.device-strip` — which device this screen is about, and how to reach it.
class DeviceStrip extends StatelessWidget {
  /// [batteryPercent] of null prints no charge; nothing has read one.
  const DeviceStrip({
    this.health,
    this.batteryPercent,
    this.onOpenSync,
    super.key,
  });

  /// `.device-strip { margin-bottom: 20px }`.
  static const double bottomGap = 20;

  /// `.device-strip { gap: 7px }`.
  static const double gap = 7;

  /// `.device-strip .icon { width: 15px }`.
  static const double iconSize = 15;

  /// `.status-dot { width: 5px; height: 5px }`.
  static const double dotSize = 5;

  /// The strap this app talks to. One device, named.
  static const String deviceName = 'Helio Strap';

  /// Where the strip leads.
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
    final style = TypeScale.deviceStrip.copyWith(color: colors.ink3);
    // Green only when the classification found nothing to say. `alerts` is the
    // union of the link's own faults and the data's, so an empty one is the
    // whole surface agreeing that the strap is being heard from.
    final state = health;
    final healthy = state != null && state.alerts.isEmpty;
    final strip = Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Row(
        children: <Widget>[
          Icon(Icons.watch_outlined, size: iconSize, color: colors.ink3),
          const SizedBox(width: gap),
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: healthy ? colors.fav : colors.ink3,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: gap),
          Text(deviceName, style: style),
          if (batteryPercent case final int percent) ...<Widget>[
            const SizedBox(width: gap),
            Text('$percent%', style: style),
          ],
          const Spacer(),
          Text(action, style: style),
          Icon(Icons.chevron_right, size: iconSize, color: colors.ink3),
        ],
      ),
    );
    return onOpenSync == null
        ? strip
        : Semantics(
            button: true,
            label: '$deviceName · $action',
            child: GestureDetector(onTap: onOpenSync, child: strip),
          );
  }
}

/// `.data-footer` — the two lines Today closes on.
class DataFooter extends StatelessWidget {
  /// Builds the footer.
  const DataFooter({super.key});

  /// `.data-footer { margin-top: 32px }`.
  static const double topGap = 32;

  /// `.data-footer > .icon { width: 12px }`.
  static const double iconSize = 12;

  /// The prototype's own closing line.
  static const String line = 'Your data. A little better understood.';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: topGap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.shield_outlined, size: iconSize, color: colors.ink3),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: TypeScale.footer.copyWith(color: colors.ink3),
            ),
          ),
        ],
      ),
    );
  }
}
