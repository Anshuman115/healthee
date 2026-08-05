/// The header legacy's Today opens with: date, battery, controls, greeting.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:433` —
/// `_GreetingHeader`. Geometry unchanged: 8 px of air above and 22 below, the
/// eyebrow date at 10 px / 0.16 em on the left with the strap battery 12 px after
/// it, the controls on the right, 16 px, then a two-line 42 px display greeting
/// whose second line is the accent.
///
/// ```text
///   TUE · AUG 4   🔋 71%                          ⊕      (H)
///
///   Good morning,
///   there.
/// ```
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
import 'package:healthee/shared/connection/connection_dot.dart';
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
    this.syncing = false,
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
  /// a widget test pumping this row alone. Null draws no dot rather than a
  /// reassuring one.
  final ConnectionHealth? health;

  /// Whether a sync is in flight — draws the ring around the avatar.
  final bool syncing;

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
                  // The quiet half of the connection surface — 7 px, and drawn
                  // only when `ConnectionHealth.quiet`. Legacy has no such mark;
                  // it is kept because `connection_health.dart`'s whole argument
                  // is that a quiet healthy state is honest only if it is
                  // visible at all. When the answer is NOT quiet the full strip
                  // is already above this row and no dot is drawn, so the two
                  // never say the same thing twice.
                  if (health case final ConnectionHealth state when state.quiet) ...[
                    const SizedBox(width: 8),
                    ConnectionDot(
                      live: state.live,
                      semanticLabel: state.report.headline,
                    ),
                  ],
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
                  HTap(
                    onTap: onOpenProfile,
                    semanticLabel: 'Settings',
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (syncing)
                          SizedBox(
                            width: 46,
                            height: 46,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.accent,
                            ),
                          ),
                        HAvatar(initial),
                      ],
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
                    italic: true,
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
