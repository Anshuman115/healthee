/// Today is legacy's screen, in legacy's order — and this is where that is held.
///
/// `healthee-legacy/app/lib/ui/today_screen.dart:217–378` is one list literal.
/// The port is `todaySections`, and the only way a re-ordering, a dropped card or
/// a card that crept back in gets caught is by reading that list and comparing it
/// to the original section by section. A rendered scroll cannot do it: half the
/// screen is off the viewport and a `ListView.builder` has not built it.
///
/// The order below was transcribed from legacy with the file open. Every entry
/// cites the legacy line it came from.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/data/models/recovery_signals.dart';
import 'package:healthee/data/models/sleep_debt.dart';
import 'package:healthee/data/models/sleep_health.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/features/today/widgets/actions_section.dart';
import 'package:healthee/features/today/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/today/widgets/data_health_section.dart';
import 'package:healthee/features/today/widgets/greeting_header.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/hrv_trend_card.dart';
import 'package:healthee/features/today/widgets/insights_section.dart';
import 'package:healthee/features/today/widgets/readiness_block.dart';
import 'package:healthee/features/today/widgets/recovery_summary_line.dart';
import 'package:healthee/features/today/widgets/seven_night_card.dart';
import 'package:healthee/features/today/widgets/stale_sleep_banner.dart';
import 'package:healthee/features/today/widgets/stress_card.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_heading.dart';
import 'package:healthee/shared/states/reading_view.dart';

import '../_today_stubs.dart';
import '_screen_data.dart';

/// The section list, built the way the screen builds it.
List<PageSection> sections({
  Map<String, Object?> Function(Map<String, Object?> json)? mutate,
}) => todaySections(
  screenData(server: todayView(mutate: mutate)),
  const TodayExtras(),
);

int _indexOf<T>(List<PageSection> list) =>
    list.indexWhere((section) => section.child is T);

/// The heading whose title is [title], by index.
int _headingIndex(List<PageSection> list, String title) => list.indexWhere(
  (section) => section.child is SectionHeading &&
      (section.child as SectionHeading).title == title,
);

void main() {
  group("legacy's order, section by section", () {
    test('EVERY SECTION LEGACY DRAWS IS DRAWN, AND IN LEGACY\'S ORDER', () {
      final list = sections();
      final order = <int>[
        // 218 · the greeting header
        _indexOf<GreetingHeader>(list),
        // 219 · "Recovery — <summary>."
        _indexOf<RecoverySummaryLine>(list),
        // 228 · the data-health banner
        _indexOf<DataHealthSection>(list),
        // 234 · the recovery card
        _indexOf<ReadingView<RecoveryScore>>(list),
        // 238 · the recovery signal ladder
        _indexOf<ReadingView<RecoverySignals>>(list),
        // 242 · the collapsible suggested actions
        _indexOf<ActionsSection>(list),
        // 248 · HRV · 14 days  (the grid above it is checked separately)
        _indexOf<HrvTrendCard>(list),
        // 263 · Stress
        _indexOf<StressCard>(list),
        // 283 · Heart rate · 24h
        _indexOf<HeartRateDayCard>(list),
        // 300 · the Sleep heading
        _headingIndex(list, 'Sleep'),
        // 304 · the readiness block
        _indexOf<ReadinessBlock>(list),
        // 316 · Blood oxygen · 14 nights
        _indexOf<BloodOxygenCard>(list),
        // 338 · Sleep need · debt
        _indexOf<ReadingView<SleepDebt>>(list),
        // 342 · Sleep health · 4-dim
        _indexOf<ReadingView<SleepHealth>>(list),
        // 346 · Sleep · 7 nights
        _indexOf<SevenNightCard>(list),
        // 351 · the Activity heading
        _headingIndex(list, 'Activity'),
        // 355 · Strain · cardio load
        _indexOf<ReadingView<CardioLoad>>(list),
        // 359 · Active minutes · MVPA
        _indexOf<ReadingView<Mvpa>>(list),
        // 365 · the Fitness heading
        _headingIndex(list, 'Fitness'),
        // 366 · Biological age
        _indexOf<ReadingView<BiologicalAge>>(list),
        // 368 · VO₂max
        _indexOf<ReadingView<Vo2max>>(list),
        // 374 · the Insights heading
        _headingIndex(list, 'Insights'),
        // 375 · the patterns
        _indexOf<InsightsSection>(list),
      ];
      for (final index in order) {
        expect(index, isNonNegative, reason: 'a legacy section is missing');
      }
      // Strictly increasing: every section sits after the one legacy puts before
      // it. This is the assertion a re-order fails.
      for (var i = 1; i < order.length; i++) {
        expect(
          order[i],
          greaterThan(order[i - 1]),
          reason: 'section $i is out of legacy order',
        );
      }
    });

    test('the three grid rows sit where legacy puts them', () {
      // Legacy's `_grid` calls are at 245 (RHR · HRV), 306 (Sleep · Resp) and
      // 352 (Steps · Energy) — one before the HRV trend, one after the readiness
      // block, one after the Activity heading.
      final list = sections();
      final rows = <int>[
        for (var i = 0; i < list.length; i++)
          if (list[i].child.toString().contains('Builder')) i,
      ];
      expect(rows, hasLength(3), reason: 'three two-up rows, exactly');
      expect(rows[0], lessThan(_indexOf<HrvTrendCard>(list)));
      expect(rows[1], greaterThan(_indexOf<ReadinessBlock>(list)));
      expect(rows[1], lessThan(_indexOf<BloodOxygenCard>(list)));
      expect(rows[2], greaterThan(_headingIndex(list, 'Activity')));
      expect(rows[2], lessThan(_indexOf<ReadingView<CardioLoad>>(list)));
    });
  });

  group("the gaps between sections are legacy's SizedBoxes", () {
    test('a section break is 24 and a card break is 10', () {
      final list = sections();
      // Legacy: `_ActionsSection, SizedBox(height: 24)` (242) then the grid.
      expect(list[_indexOf<ActionsSection>(list)].gap, 24);
      // Legacy: `_RecoveryCard, SizedBox(height: 10)` (234).
      expect(list[_indexOf<ReadingView<RecoveryScore>>(list)].gap, 10);
      // Legacy puts 24 before each `HSectionTitle`, on the card above it.
      expect(list[_headingIndex(list, 'Sleep') - 1].gap, 24);
      expect(list[_headingIndex(list, 'Activity') - 1].gap, 24);
      expect(list[_headingIndex(list, 'Fitness') - 1].gap, 24);
      expect(list[_headingIndex(list, 'Insights') - 1].gap, 24);
      // And nothing between a heading and the first card under it — the heading
      // carries its own 12 px (`ui.dart:183`).
      expect(list[_headingIndex(list, 'Sleep')].gap, 0);
    });
  });

  group('the conditional sections are legacy\'s conditions', () {
    test('the stale-sleep banner appears only for a night over 24 h old', () {
      // The fixture's `last_sleep.end_iso` is recent relative to `screenData`'s
      // clock, so legacy draws no banner.
      expect(_indexOf<StaleSleepBanner>(sections()), -1);

      final stale = todaySections(
        screenData(
          server: todayView(
            mutate: (json) => {
              ...json,
              'last_sleep': {
                ...json['last_sleep']! as Map<String, Object?>,
                'end_iso': '2026-07-20T01:00:00+00:00',
              },
            },
          ),
        ),
        const TodayExtras(),
      );
      final banner = _indexOf<StaleSleepBanner>(stale);
      expect(banner, isNonNegative);
      // It dates the whole overnight section, so it comes first inside it.
      expect(banner, greaterThan(_headingIndex(stale, 'Sleep')));
      expect(banner, lessThan(_indexOf<ReadinessBlock>(stale)));
    });

    test('a trend with two points or fewer draws no module', () {
      // Legacy's `_nums(spark[…]).length > 2`. Two nights is not a trend, and a
      // chart of it invites one point to be read as a pattern.
      final thin = sections(
        mutate: (json) => {
          ...json,
          'sparklines': <String, Object?>{
            ...json['sparklines']! as Map<String, Object?>,
            'hrv_sleep_avg': const <Object?>[],
            'spo2_overnight': const <Object?>[],
            // The blood-oxygen module is gated on its DRAWN series, and since
            // 2026-08-06 that is the nightly minimums rather than the averages.
            // See `blood_oxygen_card.dart`.
            'spo2_overnight_min': const <Object?>[],
          },
          'today_hr_series': const <Object?>[],
        },
      );
      expect(_indexOf<HrvTrendCard>(thin), -1);
      expect(_indexOf<BloodOxygenCard>(thin), -1);
      expect(_indexOf<HeartRateDayCard>(thin), -1);
    });

    test('one night is not a week', () {
      final oneNight = sections(
        mutate: (json) => {
          ...json,
          'sleep_history_7d': [(json['sleep_history_7d']! as List).first],
        },
      );
      expect(_indexOf<SevenNightCard>(oneNight), -1);
    });

    test('no recommendations means no suggested-actions block at all', () {
      final none = sections(
        mutate: (json) => {...json, 'recommendations': const <Object?>[]},
      );
      expect(_indexOf<ActionsSection>(none), -1);
    });

    test('no findings means no Insights heading — a heading over nothing is dead',
        () {
      final none = sections(
        mutate: (json) => {...json, 'top_findings': const <Object?>[]},
      );
      expect(_headingIndex(none, 'Insights'), -1);
      expect(_indexOf<InsightsSection>(none), -1);
    });
  });
}
