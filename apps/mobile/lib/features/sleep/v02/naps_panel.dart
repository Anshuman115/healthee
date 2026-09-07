/// `Naps & your day` — the daytime sleep around the night.
///
/// `design/mobile-preview/sleep-history-view.js`:
///
/// ```js
/// H.panel('Naps & your day','sleep',
///   `${naps.length
///       ? naps.map(n => H.note(`${localTime(n.start_iso)}–${localTime(n.end_iso)}`
///                              + ` · ${H.duration(n.duration_min)}`)).join('')
///       : H.note('No nap record included for this day.')}
///    ${H.link('Journal for this day','journal')}`,
///   'journal','moon')
/// ```
///
/// ## ⛔ `naps[].stages` IS ALWAYS EMPTY, AND THAT IS WHY NO BAR IS DRAWN
///
/// `/api/sleep` ships `naps[].stages` as a list of `{stage, duration_min}`
/// objects and **the server never populates it** — the shape that reaches the
/// phone is structurally empty on every nap, on every day, for every owner. The
/// pre-v02 card drew a stage bar from it, which meant every nap on this screen
/// rendered a strip with nothing in it.
///
/// So this panel draws **no stage bar at all**, and says in words that the
/// breakdown is not sent. An empty bar is a picture of a measurement that does
/// not exist; a sentence is the truth. When the server starts filling that field
/// the bar can come back, and the sentence with it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// `H.note('No nap record included for this day.')`.
const String kNoNapsNote = 'No nap record included for this day.';

/// Why no nap here carries a stage breakdown. See the library docstring.
const String kNapStagesNote =
    'Your server sends a nap’s start, end and length, but not its stages, so '
    'there is no breakdown to draw for one.';

/// `Naps & your day`.
class NapsPanel extends StatelessWidget {
  /// [naps] is what `/api/sleep` returned, newest first.
  const NapsPanel({required this.naps, this.onOpenJournal, super.key});

  /// The prototype's title.
  static const String title = 'Naps & your day';

  /// How many rows before the panel stops listing.
  static const int shown = 8;

  /// The gap between two nap rows.
  static const double rowGap = 10;

  /// The gap above the journal link.
  static const double linkGap = 6;

  /// The recorded naps.
  final List<SleepNap> naps;

  /// Opens the journal.
  final VoidCallback? onOpenJournal;

  /// Total minutes napped across [naps].
  double get totalMin =>
      naps.fold<double>(0, (sum, nap) => sum + (nap.durationMin ?? 0));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Panel(
      tone: Tone.sleep,
      label: 'Naps',
      head: PanelHead(
        title: title,
        icon: Icons.bedtime_outlined,
        infoKey: 'sleep',
        actionLabel: onOpenJournal == null ? null : 'Journal',
        onAction: onOpenJournal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (naps.isEmpty)
            const PanelNote(kNoNapsNote)
          else ...<Widget>[
            PanelValue(
              hoursMinutes(totalMin),
              unit: naps.length == 1 ? 'in 1 nap' : 'in ${naps.length} naps',
            ),
            for (final nap in naps.take(shown))
              Padding(
                padding: const EdgeInsets.only(bottom: rowGap),
                child: Text(
                  _line(nap),
                  style: TypeScale.panelContext.copyWith(color: colors.ink),
                ),
              ),
            const PanelNote(kNapStagesNote),
          ],
          if (onOpenJournal != null) ...<Widget>[
            const SizedBox(height: linkGap),
            HLinkButton(
              label: 'Journal for this day',
              onPressed: onOpenJournal,
            ),
          ],
        ],
      ),
    );
  }

  /// `31 Jul · 2:00p–2:35p · 35m`, dropping whatever was not recorded.
  static String _line(SleepNap nap) {
    final start = nap.start;
    final end = nap.end;
    return <String>[
      if (shortDate(nap.date) case final String date when date.isNotEmpty) date,
      if (start != null && end != null) napRange(start, end),
      if (nap.durationMin case final double minutes) napDuration(minutes),
    ].join(' · ');
  }
}
