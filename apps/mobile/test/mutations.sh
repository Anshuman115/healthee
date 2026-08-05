#!/usr/bin/env bash
#
# Break each guard on purpose, and require a test to notice.
#
# A test that passes against broken code is not a test, and three of the guards
# in this app cannot be reached by using it:
#
#   * the 60-day horizon fires two months after a row is written;
#   * the `pushed_at_ms` retention guard fires a year after that;
#   * the daily-counter write is invisible until the day it was needed is over.
#
# `strap_store_test.dart` and `prune_safety_test.dart` name this file as their
# proof. It applies each mutation with an EXACT-STRING replacement that asserts
# it actually changed something — a patch that silently matched nothing runs the
# unmutated suite and reports a pass, which reads exactly like a working guard.
#
# Usage:  bash test/mutations.sh          (from apps/mobile)
# Exit 0  every mutation was caught.  Exit 1  at least one survived.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0
FAIL=0

# patch <file> <old> <new> — replaces exactly once, or aborts.
patch() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
count = src.count(old)
assert count > 0, f'MUTATION DID NOT APPLY: no match in {path}'
open(path, 'w').write(src.replace(old, new))
print(f'  mutated {path} ({count} site(s))')
PY
}

# mutate <name> <test-target> <file> <old> <new> [<old2> <new2>]
# <test-target> may be more than one path, space-separated.
mutate() {
  local name="$1" target="$2" file="$3"
  shift 3
  echo "── $name"
  cp "$file" "$file.orig"
  while [ "$#" -ge 2 ]; do
    if ! patch "$file" "$1" "$2"; then
      mv "$file.orig" "$file"
      echo "  ✗ PATCH FAILED — the mutation script is stale, not the code"
      FAIL=$((FAIL + 1))
      return
    fi
    shift 2
  done
  # shellcheck disable=SC2086 — $target is a space-separated list of paths.
  if flutter test $target >/dev/null 2>&1; then
    echo "  ✗ SURVIVED — $target passes against broken code"
    FAIL=$((FAIL + 1))
  else
    echo "  ✓ caught by $target"
    PASS=$((PASS + 1))
  fi
  mv "$file.orig" "$file"
}

PRUNE=lib/data/store/horizon_prune.dart
WRITER=lib/data/store/strap_writer.dart
SAFETY=test/store/prune_safety_test.dart
STORE=test/store/strap_store_test.dart

# ── the guard this whole file exists for ────────────────────────────────────
# Drop `pushed_at_ms IS NOT NULL` from the samples delete: an unsent
# measurement dies at 60 days again, silently. This IS the original defect.
mutate 'unsent samples are pruned at the horizon' "$SAFETY" "$PRUNE" \
  '    removed += await (delete(strapSamples)..where(
      (r) => r.day.isSmallerThanValue(horizon) & r.pushedAtMs.isNotNull(),
    )).go();' \
  '    removed += await (delete(strapSamples)..where(
      (r) => r.day.isSmallerThanValue(horizon),
    )).go();'

# The same guard on #121'"'"'s table — the since-midnight counter, which has no
# other home anywhere and cannot be re-read tomorrow.
mutate 'the unsent daily counter is pruned at the horizon' "$SAFETY" "$PRUNE" \
  '    removed += await (delete(deviceTotals)..where(
      (r) => r.day.isSmallerThanValue(horizon) & r.pushedAtMs.isNotNull(),
    )).go();' \
  '    removed += await (delete(deviceTotals)..where(
      (r) => r.day.isSmallerThanValue(horizon),
    )).go();'

# The other direction: the one-year bound stops distinguishing sent from unsent,
# so a row the server already has is destroyed AND reported as a loss.
mutate 'the one-year bound ignores pushed_at_ms' "$SAFETY" "$PRUNE" \
  '      ..where(
        strapSamples.day.isSmallerThanValue(floor) &
            strapSamples.pushedAtMs.isNull(),
      );' \
  '      ..where(strapSamples.day.isSmallerThanValue(floor));' \
  '    final rows = await (delete(strapSamples)..where(
      (r) => r.day.isSmallerThanValue(floor) & r.pushedAtMs.isNull(),
    )).go();' \
  '    final rows = await (delete(strapSamples)..where(
      (r) => r.day.isSmallerThanValue(floor),
    )).go();'

# A loss that is counted but not recorded: returned to one sync and gone by
# morning, which is how a data loss becomes a rumour.
mutate 'the loss is never written down' "$SAFETY" "$PRUNE" \
  '    await _recordLoss(rows, throughDay, at);' \
  ''

# ── the horizon itself ──────────────────────────────────────────────────────
# Off by one in the safe direction for storage and the wrong one for data: the
# boundary day goes too.
mutate 'the horizon eats its own boundary day' "$STORE" "$PRUNE" \
  'r.day.isSmallerThanValue(horizon) & r.pushedAtMs.isNotNull()' \
  'r.day.isSmallerOrEqualValue(horizon) & r.pushedAtMs.isNotNull()'

# ── #121, one layer up ──────────────────────────────────────────────────────
# The strap'"'"'s daily counter never reaches the store. On the server this cost
# 142 of 143 production days, permanently.
mutate 'the daily counter is never stored' "$STORE" "$WRITER" \
  '      if (result.dailyTotals case final totals?) {' \
  '      if (result.dailyTotals case final totals? when false) {'

# ── colour: the legacy hue set, and the mapping every sleep chart shares ────
HUES=lib/core/theme/instrument_hues.dart
PALETTE=lib/core/theme/palette.dart
HUES_TEST=test/theme/legacy_hues_test.dart
STAGE_TEST=test/theme/sleep_stage_test.dart

# The block this replaced mutated the five identity tags, whose whole invariant
# was that a tag could never be a verdict colour. Legacy makes two of its hues
# verdicts on purpose (cHrv IS the green, cHeart IS the alert), so that invariant
# is gone and mutating toward it would now be mutating toward CORRECT code.
#
# What is mutable now is the transcription itself, and the one mapping four
# charts share.

# A hue transcribed one digit wrong. Renders perfectly; is not legacy's app.
mutate 'a legacy hue is transcribed wrong' "$HUES_TEST" "$PALETTE" \
  '  static const Color steps = Color(0xFFB27F2C);' \
  '  static const Color steps = Color(0xFFB27F2D);'

# The dark theme quietly wearing the light theme's value. Invisible by day.
mutate 'the dark hue set copies the light one' "$HUES_TEST" "$PALETTE" \
  '  static const Color sleep = Color(0xFF968EC9);' \
  '  static const Color sleep = LegacyLightHues.sleep;'

# The collision legacy makes ON PURPOSE, undone by a well-meaning reader who
# thinks a metric hue should never be a verdict. It was true of the old system.
mutate 'someone separates cHrv from the green accent' "$HUES_TEST" "$PALETTE" \
  '  static const Color hrv = Color(0xFF1F6F54);' \
  '  static const Color hrv = Color(0xFF2E8B6A);'

# Two sleep stages collapsing onto one colour: a hypnogram that cannot be read.
mutate 'deep and light sleep share a colour' "$STAGE_TEST" "$HUES" \
  "    'deep' => steps," \
  "    'deep' => spo2,"

# The pair swapped. Every night on every sleep screen is drawn inside out, and
# nothing about it looks broken.
mutate 'REM and awake are swapped' "$STAGE_TEST" "$HUES" \
  "    'rem' => sleep,
    'awake' => heart," \
  "    'rem' => heart,
    'awake' => sleep,"

# `core` and `light` are one stage under two vocabularies. Giving them different
# colours draws a distinction that does not exist.
mutate 'core and light stop being the same stage' "$STAGE_TEST" "$HUES" \
  "    'core' || 'light' => spo2," \
  "    'core' => rem,
    'light' => spo2,"

# ── the insight rewrite ─────────────────────────────────────────────────────
FINDINGS=lib/features/insights/widgets/findings_section.dart
WORDING=test/features/findings_wording_test.dart

# The regression this change exists to undo: the server's debug string back on
# the surface as the headline.
mutate 'the raw Spearman string is the headline again' "$WORDING" "$FINDINGS" \
  '  if (a == null) {
    return '"'"'A pattern in your own data'"'"';
  }' \
  '  if (a == null || true) {
    return finding.description ?? '"'"'A pattern in your own data'"'"';
  }'

# The failure that would make the rewrite WORSE than what it replaced: readable,
# and causal about an observational n-of-1.
mutate 'the headline acquires a causal verb' "$WORDING" "$FINDINGS" \
  "    _ => 'moved with'," \
  "    _ => 'improves',"

# The caveat dropped from the disclosure, so opening the arithmetic means
# leaving the framing behind.
mutate 'the caveat is dropped from the disclosure' "$WORDING" "$FINDINGS" \
  "    'One person, one stretch of time, nothing controlled. It says the two moved '
        'together — not that either one caused the other.'," \
  "    ''," \

# ── the two resting heart rates ─────────────────────────────────────────────
STRAP_STRIP=lib/features/diagnostics/widgets/metric_strip.dart
SERVER_STRIP=lib/features/diagnostics/widgets/server_metric_strip.dart
TABS=test/features/tab_screens_test.dart

# The owner'"'"'s own bug report: two differently-defined numbers under one label,
# with nothing anywhere saying they are different instruments. The stream still
# CARRIES its instrument sentence here; the row just stops drawing it, which is
# exactly how an attribution is lost — nothing is deleted and nothing is shown.
mutate 'the strap row stops naming its instrument' "$TABS" "$STRAP_STRIP" \
  '        if (metric.stream.instrument case final String note)' \
  '        if (metric.stream.instrument case final String note when false)'

# The same failure from the other side: the canonical row stops saying it is the
# canonical one, so the two numbers are back to disagreeing in silence.
mutate 'the canonical row stops naming its method' "$TABS" "$SERVER_STRIP" \
  '        if (_instrumentNote(card.metric) case final String note)' \
  '        if (_instrumentNote(card.metric) case final String note when false)'

# ── Today is an index ───────────────────────────────────────────────────────
SECTIONS=lib/features/today/today_sections.dart
GRID_TEST=test/features/today_grid_test.dart

# A card creeping back onto the daily read. Every one of them is a good card;
# none of them is a daily read, and the screen this replaced had twenty.
mutate 'a moved card comes back to Today' "$GRID_TEST" "$SECTIONS" \
  "import 'package:healthee/features/today/widgets/stress_card.dart';" \
  "import 'package:healthee/features/sleep/widgets/sleep_week_card.dart';
import 'package:healthee/features/today/widgets/stress_card.dart';" \
  '    PageSection(HeartRateCard(day: data.day, reveals: data.reveals, now: data.now)),' \
  '    PageSection(HeartRateCard(day: data.day, reveals: data.reveals, now: data.now)),
    if (snapshot != null)
      PageSection(
        SleepWeekCard(nights: snapshot.sleepHistory7d, reveals: data.reveals),
      ),'

# ── the connection surface may only be quiet when nothing is wrong ──────────
HEALTH=lib/data/sync/connection_health.dart
LINES=lib/data/sync/health_lines.dart
STRIP_TEST=test/features/today_connection_strip_test.dart

# The whole bargain of collapsing the strip to a dot. A quiet healthy state is
# honest ONLY if every unhealthy state is loud, so the mutation is the one that
# would be easy to write and impossible to see: the data-side faults stop
# reaching the surface and the dot keeps saying nothing is wrong.
mutate 'the data-side faults stop opening the strip' "$STRIP_TEST" "$HEALTH" \
  '      if (line.loud)
        ConnectionAlert(id: line.id, headline: line.headline!),' \
  '      if (false) ConnectionAlert(id: line.id, headline: line.headline!),'

# The link half, the same way round: an unreachable strap classified as fine.
mutate 'a failed link classifies as healthy' "$STRIP_TEST" "$HEALTH" \
  "  ConnectionFailed(:final failure) => <ConnectionAlert>[" \
  "  ConnectionFailed(:final failure) => failure.code.isNotEmpty ? null : <ConnectionAlert>["

# A phone that has never read its strap, reported as resting.
mutate 'never-synced classifies as healthy' "$STRIP_TEST" "$HEALTH" \
  '  Disconnected(:final lastCompleteSync) => lastCompleteSync == null' \
  '  Disconnected(:final lastCompleteSync) => lastCompleteSync != null'

# `quiet` is the ONE place the answer is computed. A widget that could decide it
# for itself could decide it while something is wrong.
mutate 'quiet stops accounting for the alerts' "$STRIP_TEST" "$HEALTH" \
  '  bool get quiet => !busy && alerts.isEmpty;' \
  '  bool get quiet => !busy;'

# A loud line whose short form goes missing renders as nothing on the strip.
# The constructor makes that impossible; this is the check that it stays so.
mutate 'a loud line ships with an empty headline' "$STRIP_TEST" "$LINES" \
  "  headline: 'Not signed in to a server'," \
  "  headline: '',"

# ── colour on Insights is a claim, and only where there is one ──────────────
POLARITY=lib/shared/format/metric_polarity.dart
TRENDS_TEST=test/features/insights_trends_test.dart

# The load-bearing case. Calories turning green or red is how the owner learns
# that every colour on the screen is decoration.
mutate 'a NEUTRAL metric acquires a verdict' "$TRENDS_TEST" "$POLARITY" \
  '    MetricPolarity.neutral || null => TrendVerdict.none,' \
  '    MetricPolarity.neutral ||
    null =>
      delta > 0 ? TrendVerdict.favourable : TrendVerdict.unfavourable,'

# The sign read as the verdict, which gets resting heart rate exactly backwards.
mutate 'polarity is ignored and the sign decides' "$TRENDS_TEST" "$POLARITY" \
  '    MetricPolarity.lowerIsBetter =>
      delta < 0 ? TrendVerdict.favourable : TrendVerdict.unfavourable,' \
  '    MetricPolarity.lowerIsBetter =>
      delta > 0 ? TrendVerdict.favourable : TrendVerdict.unfavourable,'

# ── an out-of-shell route reached with `go` is a one-way door ───────────────
HEADER=lib/features/today/widgets/today_header.dart
DIAG_ROW=lib/features/settings/widgets/diagnostics_setting.dart
STRAP_ROW=lib/features/settings/widgets/strap_setting.dart
SERVER_ROW=lib/features/settings/widgets/server_setting.dart
ROUTER=lib/core/router.dart
BACK_TEST="test/features/back_navigation_test.dart test/features/out_of_shell_navigation_test.dart"

# The defect exactly as it shipped, found on the device and not here. `go`
# REPLACES the location, so Settings has nothing beneath it: the shell's back
# rule finds an empty branch stack, correctly concludes "not on Today", and
# leaves the app — from a screen the owner tapped into two seconds earlier.
mutate 'the avatar reaches settings with go' "$BACK_TEST" "$HEADER" \
  '      onPressed: () => unawaited(context.push(Routes.settings)),' \
  '      onPressed: () => context.go(Routes.settings),'

# Two levels out: back from diagnostics must land on the screen that opened it.
mutate 'diagnostics is reached with go' "$BACK_TEST" "$DIAG_ROW" \
  '              onPressed: () => unawaited(context.push(Routes.diagnostics)),' \
  '              onPressed: () => context.go(Routes.diagnostics),'

mutate 'pairing is reached with go' "$BACK_TEST" "$STRAP_ROW" \
  '              onPressed: () => unawaited(context.push(Routes.pairing)),' \
  '              onPressed: () => context.go(Routes.pairing),'

mutate 'the server screen is reached with go' "$BACK_TEST" "$SERVER_ROW" \
  '              onPressed: () => unawaited(context.push(Routes.serverSignIn)),' \
  '              onPressed: () => context.go(Routes.serverSignIn),'

# "Done" on a PUSHED setup flow must return where it came from. Hard-coding the
# redirect'"'"'s answer throws away the screen underneath, which looks correct until
# somebody opens pairing from settings.
mutate 'leaving a setup flow always goes to Today' "$BACK_TEST" "$ROUTER" \
  '  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.today);
  }' \
  '  context.go(Routes.today);'

# ── Sleep: a card that blanks a value without saying so ─────────────────────
# The Sleep port's one deliberate difference from legacy is that a missing field
# renders as WITHHELD rather than as `—`. Half of that is a hole where the number
# was; the other half is the sentence naming what is missing and why. A hole with
# no sentence is a blank with a dashed border, and it is exactly what a "the card
# still renders" test passes for — which is why each `SleepGapNote` is deleted
# here on purpose.
WITHHELD_TEST=test/features/sleep_withheld_test.dart
HERO=lib/features/sleep/widgets/sleep_hero_card.dart
VITALS=lib/features/sleep/widgets/overnight_vitals_card.dart
HEALTH=lib/features/sleep/widgets/sleep_health_card.dart
PERF=lib/features/sleep/widgets/sleep_performance_card.dart

mutate 'the hero blanks its score and says nothing' "$WITHHELD_TEST" "$HERO" \
  '        SleepGapNote(
          fields: <String, Reading<Object>>{
            "The strap'"'"'s sleep score": night.deviceScore,' \
  '        SleepGapNote(
          fields: <String, Reading<Object>>{
            if (false) "The strap'"'"'s sleep score": night.deviceScore,'

mutate 'the vitals card stops iterating its own slots' "$WITHHELD_TEST" "$VITALS" \
  '        SleepGapNote(fields: slots),' \
  '        const SleepGapNote(fields: <String, Reading<Object>>{}),'

# The legacy defect itself: a dimension the server never scored drawn as a FAILED
# check. `point_timing == 1` is false for a null, so the cross appears and the
# owner reads a judgement made out of nothing.
mutate 'an unscored sleep dimension renders as a failure' "$WITHHELD_TEST" "$HEALTH" \
  '    final result = passed.valueOrNull;
    if (result == null) {' \
  '    final result = passed.valueOrNull ?? false;
    if (false) {'

# `0/0` — a ratio out of nothing, which reads as "no nights were short".
mutate 'an empty fortnight reports 0 of 0' "$WITHHELD_TEST" "$PERF" \
  '    final measured = totals;
    if (measured.isEmpty) {
      return Withheld<String>(SleepGap.noSession.disclosure);
    }
    final short = measured.where((minutes) => minutes < kSleepNeedMin).length;' \
  '    final measured = totals;
    final short = measured.where((minutes) => minutes < kSleepNeedMin).length;'

# ── Sleep: the citations ────────────────────────────────────────────────────
# Legacy DELETED its `[[note_id]]` markers and showed the sources nowhere. Going
# back to a plain `Text` is one keystroke and looks fine in review.
HONESTY_TEST=test/features/sleep_honesty_test.dart
TONIGHT=lib/features/sleep/widgets/tonight_card.dart

mutate 'the tonight coaching drops its grounding' "$HONESTY_TEST" "$TONIGHT" \
  '              child: GroundedProse(
                text: lever.prose,
                style: HType.sans(colors.ink2, size: 13, height: 1.45),
              ),' \
  '              child: Text(
                lever.prose,
                style: HType.sans(colors.ink2, size: 13, height: 1.45),
              ),'

# ── Sleep: the trends that legacy drew as a flat line at zero ───────────────
# `HArea(data.length >= 2 ? data : [0, 0])` — two data points the app invented,
# in the metric'"'"'s own colour, on a health screen.
TRENDS=lib/features/sleep/widgets/sleep_trends_card.dart

mutate 'a one-night trend is plotted as a flat zero' "$WITHHELD_TEST" "$TRENDS" \
  '  bool get isPlottable => series.length >= minimumPoints;' \
  '  bool get isPlottable => true;'


echo
echo "caught $PASS, survived $FAIL"
[ "$FAIL" -eq 0 ]
