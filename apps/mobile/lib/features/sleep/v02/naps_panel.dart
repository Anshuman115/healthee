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
/// ## `naps[].stages` USED TO BE STRUCTURALLY EMPTY. IT NO LONGER IS.
///
/// `/api/sleep` shipped the raw hypnogram under the key a *night* uses for
/// per-stage minute totals, so the shape that reached the phone was empty on
/// every nap, on every day, for every owner. The pre-v02 card drew a stage bar
/// from it and rendered a strip with nothing in it; this panel drew no bar and
/// said in a sentence that the server did not send the breakdown.
///
/// The server sends it now (`docs/BACKEND_GAPS_FROM_UI.md` A1), so **that
/// sentence is gone — it had become false, which is worse than the gap it was
/// describing.**
///
/// **No bar came back with it, and that is not an oversight.** The prototype
/// (`design/mobile-preview/sleep-history-view.js`, quoted above) draws nap rows
/// as text and has no stage element on this panel at all. The old comment's
/// "when the server starts filling that field the bar can come back" was reading
/// the pre-v02 card as the specification; it is not. Adding one now would be a
/// design decision, and the design is the owner's.
///
/// What replaces the sentence is the honest half of it: [kNapsUnstagedNote] says
/// the *strap* recorded no stages, and only when that is true of every nap shown.
/// That is a fact about the recording rather than a complaint about the wire.
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

/// Shown only when the strap staged NONE of the naps listed. See the docstring.
///
/// It replaces a sentence that blamed the server for a breakdown it now sends.
/// The distinction matters to the reader: "we were not told" and "there was
/// nothing to tell" are different states, and only one of them is about them.
const String kNapsUnstagedNote =
    'The strap recorded no stage breakdown for these naps — only when they '
    'started, when they ended and how long they ran.';

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

  /// Whether the strap staged none of the naps shown.
  ///
  /// Every one, not any one: a note that fired because a single short nap went
  /// unstaged would be describing the panel wrongly whenever another nap on it
  /// carries a full breakdown.
  bool get noneStaged => naps.take(shown).every((nap) => nap.stages.isEmpty);

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
            if (noneStaged) const PanelNote(kNapsUnstagedNote),
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
