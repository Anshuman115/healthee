/// What Today draws from this phone's own store when the server has not answered.
///
/// Split out of `today_sections.dart` at the 400-line gate (Standards section
/// 1), and what is left here is the MEASURED half — stored per calendar day and
/// readable with no network at all.
///
/// It used to hold a second function, `pastDaySections`, for the other situation
/// in which nothing derived could be drawn: a past day, because `/api/today` took
/// no day and answered only for the current one. That endpoint now answers for
/// the day it is asked about (`docs/AS_OF_DAY.md`), so a past day draws the same
/// screen as any other and the function is gone rather than kept "just in case"
/// (Standards section 1). The two sentences it existed to keep apart were "the
/// server CANNOT answer for this day" and "the server has not answered YET"; only
/// the second is still a state this app can be in.
library;

import 'package:flutter/material.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/device_health_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// What this phone measured, when the server cannot be reached.
///
/// **Not a prototype section, and it appears in one state only.** This app holds
/// the strap's own readings on disk, and `docs/APP_DESIGN_BRIEF.md` §7.4 requires
/// that half to render with no network at all: an app that shows zero
/// measurements while sitting on a database of them is broken, not careful.
///
/// It draws only behind the failure card, in v02's own twin-panel row, and
/// nothing on the healthy path moves by a pixel.
void measuredOnlySections(SectionList sections, ScreenData data) {
  final day = data.day;
  sections.add(
    Panel(
      head: const PanelHead(
        title: 'From the strap',
        icon: SolarIconsOutline.watchRound,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatRow(<Stat>[
            if (day.steps.valueOrNull case final int steps)
              Stat('Steps', commaGrouped(steps)),
            if (day.heartRate.valueOrNull case final double bpm)
              Stat('Heart rate', bpm.round().toString(), unit: 'bpm'),
          ]),
          const PanelNote(
            'Measured on this phone, since midnight. The server has not been '
            'reached, so nothing here has been derived.',
          ),
        ],
      ),
    ),
  );
  sections.gap(PageSpacing.panel);
  sections.add(DeviceHealthCard(day: day, now: data.now));
}
