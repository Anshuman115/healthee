/// The header legacy's Today opens with: date, battery, controls, greeting.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:433` —
/// `_GreetingHeader`. Geometry unchanged: 8 px of air above and 22 below, the
/// eyebrow date at 10 px / 0.16 em on the left with the strap battery 12 px after
/// it, the controls on the right, 16 px, then a two-line 42 px display greeting
/// whose second line is the accent.
///
/// ```text
///   TUE · AUG 4   🔋 71%                          ⊕     ((H))
///
///   Good morning,
///   there.
/// ```
///
/// ## The ring is the app's ONLY connection chrome now
///
/// Legacy draws a 46 px indeterminate ring behind the avatar while a sync runs.
/// This app additionally grew a full-width connection strip above the scroll and
/// a 7 px dot beside the date; the owner asked for both to go (2026-08-05,
/// *"remove that top device connection and sync now that we have the sync
/// visible as a progress ring around profile"*), which moves the header **back
/// toward** legacy rather than away from it.
///
/// The dot went with the strip and it is not mourned: it said `live` or `idle` in
/// a colour, and [SyncRing] says the same two things plus two more in the same
/// colours, eight pixels to the right. Two marks for one fact was the argument
/// for the dot in the first place and it cuts both ways.
///
/// Nothing else in this row moved. The date, the battery bands, the two controls
/// and the 42 px greeting are legacy's, unchanged.
///
/// ## Three notes on fidelity, all reported rather than repaired
///
/// **`there.`** Legacy takes a profile name and falls back to `'there'` with an
/// avatar initial of `'H'` when it has none (`today_screen.dart:443`). This app
/// stores no owner name anywhere, so the fallback is what always renders. It is
/// legacy's own string, not an invention — but it is legacy's *degraded* string,
/// and the port shows it permanently.
///
/// **The italic renders upright.** Legacy sets the name in Newsreader italic;
/// `instrument_type.dart` records that no italic face is vendored, so the
/// parameter is passed and has no effect. Kept so that vendoring the face later
/// restores the design without touching this file.
///
/// **The `+` is conditional.** Legacy's left control opens a manual-entry log
/// sheet (`log_sheet.dart`, `POST /api/log`). This app has no log feature, so
/// [onAddLog] defaults to null and the button is not drawn — a control that
/// looks tappable and does nothing is worse than a missing one. One argument
/// restores it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/connection/sync_ring.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:solar_icons/solar_icons.dart';

/// Today's date and battery, the two controls, and the greeting.
class GreetingHeader extends StatelessWidget {
  /// [date] is the payload's own `YYYY-MM-DD`; [now] picks the greeting.
  const GreetingHeader({
    required this.date,
    required this.now,
    this.name,
    this.batteryPercent,
    this.health,
    this.onOpenProfile,
    this.onAddLog,
    super.key,
  });

  /// The day this screen describes, as the server dated it.
  final String date;

  /// The instant the greeting is chosen from.
  final DateTime now;

  /// The owner's first name, when anything knows one.
  final String? name;

  /// Strap battery at the last sync, or null when it was never read.
  final int? batteryPercent;

  /// The classified connection state, or null when nothing has classified one —
  /// a widget test pumping this row alone. Null draws no ring rather than a
  /// reassuring one.
  ///
  /// It carries `busy` and the fetch's progress too, so there is no separate
  /// `syncing` flag: one classification, one ring, and no second copy of a fact
  /// that could disagree with the first.
  final ConnectionHealth? health;

  /// Opens the owner's own screen. Null draws the avatar without a gesture,
  /// which is what [HTap] does with a null callback.
  final VoidCallback? onOpenProfile;

  /// Opens the manual-entry sheet. See the library docstring.
  final VoidCallback? onAddLog;

  /// Legacy's `EdgeInsets.only(top: 8, bottom: 22)`.
  static const EdgeInsets _padding = EdgeInsets.only(top: 8, bottom: 22);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final who = (name == null || name!.isEmpty) ? 'there' : name!;
    final initial = who == 'there' ? 'H' : who[0].toUpperCase();
    return Padding(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ModuleLabel(prettyDate(date), size: 10, tracking: 0.16),
                  if (batteryPercent case final int percent)
                    _Battery(percent: percent),
                ],
              ),
              Row(
                children: [
                  if (onAddLog case final VoidCallback add) ...[
                    HTap(
                      onTap: add,
                      semanticLabel: 'Log something',
                      child: Icon(
                        SolarIconsOutline.addCircle,
                        size: 26,
                        color: colors.ink2,
                      ),
                    ),
                    const SizedBox(width: 13),
                  ],
                  // The ring is OUTSIDE the tap, deliberately. It is a status
                  // indicator and contributes no gesture; the avatar inside it
                  // still opens Settings, and `HTap`'s `container: true`
                  // semantics would otherwise swallow the ring's own label.
                  SyncRing(
                    health: health,
                    child: HTap(
                      onTap: onOpenProfile,
                      semanticLabel: 'Settings',
                      child: HAvatar(initial),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: HType.serif(colors.ink, size: 42, height: 1.02),
              children: [
                TextSpan(text: '${greetingFor(now)},\n'),
                TextSpan(
                  text: '$who.',
                  style: HType.serif(
                    colors.accent,
                    size: 42,
                    height: 1.02,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy's "Good morning" by the clock (`today_screen.dart:442`).
///
/// Two boundaries, 12:00 and 18:00 — legacy has no small-hours case, so 03:00
/// is "Good morning". Ported unchanged.
String greetingFor(DateTime at) {
  if (at.hour < 12) {
    return 'Good morning';
  }
  if (at.hour < 18) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

/// The strap's charge, in the three bands legacy's `_battColor` sets.
class _Battery extends StatelessWidget {
  const _Battery({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Legacy: <=15 heart-red · <=35 the warn amber · else the accent. That amber
    // is `#E0A33E`, which is this palette's `unf` — one colour in both themes,
    // exactly as legacy wrote it.
    final tint = percent <= 15
        ? colors.alert
        : percent <= 35
        ? colors.unf
        : colors.accent;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            SolarIconsBold.batteryChargeMinimalistic,
            size: 15,
            color: tint,
          ),
          const SizedBox(width: 3),
          Text(
            '$percent%',
            style: HType.number(colors.ink3, size: 11, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
