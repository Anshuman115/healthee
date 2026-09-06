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
STAGES=lib/core/theme/sleep_stage_palette.dart
HUES_TEST=test/theme/v02_tokens_test.dart
STAGE_TEST=test/theme/sleep_stage_test.dart
CONTRAST_TEST=test/theme/stage_contrast_test.dart
TOKEN_TEST=test/core/theme_test.dart

# The block this replaced mutated the five identity tags, whose whole invariant
# was that a tag could never be a verdict colour. Legacy makes two of its hues
# verdicts on purpose (cHrv IS the green, cHeart IS the alert), so that invariant
# is gone and mutating toward it would now be mutating toward CORRECT code.
#
# What is mutable now is the transcription itself, and the one mapping four
# charts share.

# A hue transcribed one digit wrong. Renders perfectly; is not legacy's app.
mutate 'a v02 family hue is transcribed wrong' "$HUES_TEST" "$PALETTE" \
  '  static const Color movement = Color(0xFF774000);' \
  '  static const Color movement = Color(0xFF774001);'

# The dark theme quietly wearing the light theme's value. Invisible by day.
mutate 'the dark hue set copies the light one' "$HUES_TEST" "$PALETTE" \
  '  static const Color sleep = Color(0xFFC5A8FF);' \
  '  static const Color sleep = LightFamilies.sleep;'

# The reverse of legacy's rule. Legacy FUSED identity and verdict (cHrv WAS the
# green); v02 separates them, so the regression is someone re-merging the two
# because "the fitness colour and the good colour should surely match".
mutate 'the fitness family is re-merged with the favourable verdict' "$HUES_TEST" "$PALETTE" \
  '  static const Color fav = Color(0xFF065F3D);' \
  '  static const Color fav = LightFamilies.fitness;'

# Two sleep stages collapsing onto one colour: a hypnogram that cannot be read.
mutate 'deep and light sleep share a colour' "$STAGE_TEST $CONTRAST_TEST" "$HUES" \
  "    'deep' => stageDeep," \
  "    'deep' => stageLight,"

# The pair swapped. Every night on every sleep screen is drawn inside out, and
# nothing about it looks broken.
mutate 'REM and awake are swapped' "$STAGE_TEST $CONTRAST_TEST" "$HUES" \
  "    'rem' => stageRem,
    'awake' => stageAwake," \
  "    'rem' => stageAwake,
    'awake' => stageRem,"

# `core` and `light` are one stage under two vocabularies. Giving them different
# colours draws a distinction that does not exist.
mutate 'core and light stop being the same stage' "$STAGE_TEST" "$HUES" \
  "    'core' || 'light' => stageLight," \
  "    'core' => stageRem,
    'light' => stageLight,"

# ── the shipped stage set is the prototype's ────────────────────────────────
# `design/mobile-preview/richer.css` ships four stage hues and those are what the
# app draws. They were once substituted for a derived luminance ramp on
# accessibility grounds; the owner restated the rule — the prototype IS the
# specification — so the substitution is reverted and the measurements are kept
# as recordings. Every mutation below is a way for a stage to drift off
# `richer.css` while still rendering perfectly.

# The whole dark set reverted to legacy's borrowed metric hues — the edit made by
# someone who reads the ramp's docstring and not the file header above it.
mutate "legacy's four dark stage values replace the prototype's" \
  "$CONTRAST_TEST $TOKEN_TEST" "$STAGES" \
  '  static const Color darkDeep = Color(0xFF7859E3);' \
  '  static const Color darkDeep = Color(0xFFD9A84E);' \
  '  static const Color darkLight = Color(0xFF9EBDFF);' \
  '  static const Color darkLight = Color(0xFF7DA3C4);' \
  '  static const Color darkRem = Color(0xFFDA7BDD);' \
  '  static const Color darkRem = Color(0xFF968EC9);' \
  '  static const Color darkAwake = Color(0xFFFFBD76);' \
  '  static const Color darkAwake = Color(0xFFE07A5F);'

# ONE value moved. A wholesale-revert test would not catch a single-line edit,
# and one wrong stage is a whole hypnogram lane painted in another stage's hue.
mutate "the dark REM value alone drifts off richer.css" \
  "$CONTRAST_TEST $TOKEN_TEST" "$STAGES" \
  '  static const Color darkRem = Color(0xFFDA7BDD);' \
  '  static const Color darkRem = Color(0xFF968EC9);'

# The same, in the theme the owner reads by day.
mutate "the light AWAKE value alone drifts off richer.css" \
  "$CONTRAST_TEST $TOKEN_TEST" "$STAGES" \
  '  static const Color lightAwake = Color(0xFFEDA253);' \
  '  static const Color lightAwake = Color(0xFFBF472E);'

# The superseded ramp put back where the prototype's set belongs — the exact
# revert this branch exists to undo, and it renders beautifully.
mutate 'the superseded ramp is restored over the prototype' \
  "$CONTRAST_TEST $TOKEN_TEST" "$HUES" \
  '      stageDeep = V02StagePrototype.darkDeep,' \
  '      stageDeep = DarkStagePalette.deep,'

# The split undone at the source: a stage pointed back at its metric hue. This is
# the edit that looks like a tidy-up — "these are the same colour, why two names".
mutate 'a stage colour is re-merged with its metric hue' \
  "$CONTRAST_TEST $TOKEN_TEST $STAGE_TEST" "$HUES" \
  '      stageDeep = V02StagePrototype.darkDeep,' \
  '      stageDeep = DarkFamilies.movement,'

# The kept record decaying into a story. The superseded ramp is retained so the
# trade stays legible, and its docstring claims it darkens monotonically by
# depth; scramble it and the claim is fiction nobody checks.
mutate 'the superseded ramp stops measuring what it claims' \
  "$CONTRAST_TEST" "$STAGES" \
  '  static const Color deep = Color(0xFFFECC73);
' \
  '  static const Color deep = Color(0xFF8A82BC);
' \
  '  static const Color rem = Color(0xFF8A82BC);
' \
  '  static const Color rem = Color(0xFFFECC73);
'

# The grey joining the ramp. "Unrecognised" is the absence of a stage identity;
# giving it chroma makes it a fifth stage nobody named.
mutate 'the unrecognised grey gains chroma' "$CONTRAST_TEST" "$STAGES" \
  '  static const Color unstaged = Color(0xFF797979);' \
  '  static const Color unstaged = Color(0xFF79885F);'

# Colour left as the ONLY carrier on the one surface with no legend — Today's
# 10 px sleep bar, where a row of keys does not fit.
mutate 'the stage bar stops naming its segments' \
  test/features/grid_sleep_cell_test.dart lib/shared/charts/h_stage_bar.dart \
  '                      child: Semantics(
                        label: sleepStageLabel(stage),
                        child: ColoredBox(
                          color: sleepStageColor(hues, stage),
                        ),
                      ),' \
  '                      child: ColoredBox(
                        color: sleepStageColor(hues, stage),
                      ),'

# ── the fifth row: an unrecognised stage ────────────────────────────────────
# The two halves of one defect, in two files, and each is enough on its own to
# put a byte nobody decoded on screen as a named stage. Fixing one and not the
# other looks fixed and is not: `normaliseStage` launders the code into `core`
# BEFORE the colour mapping ever sees it.
FORMAT=lib/features/sleep/sleep_format.dart

mutate 'an unrecognised code is painted as light sleep again' "$STAGE_TEST" "$HUES" \
  "    _ => unstaged," \
  "    _ => stageLight,"

mutate 'an unrecognised code is renamed to light sleep again' "$STAGE_TEST" "$FORMAT" \
  "  return kUnrecognisedStage;
}" \
  "  return 'core';
}"

# ── the two tiles that were withheld forever ────────────────────────────────
FACTS=lib/features/today/today_facts.dart
VITALS_TEST=test/features/today_overnight_vitals_test.dart

# Reverting the fallback restores the bug exactly: both surfaces go back to
# saying "the server did not say why" about numbers in the same payload.
mutate 'Resp and SpO2 go back to claiming no data' "$VITALS_TEST" "$FACTS" \
  "    return firstRefusal ?? (overnight?.hasValue ?? false ? overnight! : _absent);" \
  "    return firstRefusal ?? _absent;"

# The honest bug replacing the dishonest one: the right number with its
# instrument unnamed, so a raw session average reads as today's derived figure.
mutate 'the overnight value loses its instrument caveat' "$VITALS_TEST" "$FACTS" \
  "    return Caveated<double>(value, <Disclosure>[" \
  "    return Present<double>(value); // ignore: dead_code
    return Caveated<double>(value, <Disclosure>["

# ── the insight rewrite ─────────────────────────────────────────────────────
FINDINGS=lib/shared/findings_section.dart
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

# ── Today is LEGACY'S screen, in legacy's order ─────────────────────────────
BODY=lib/features/today/today_body.dart
ORDER_TEST=test/features/today_order_test.dart

# A re-ordering. The v02 prototype reads night, then day, then the longer view,
# and the whole point of the rebuild is that the owner's screen matches it. A
# swap like this compiles, renders, and looks like a design decision somebody
# made.
mutate "the prototype's chapter order is swapped" "$ORDER_TEST" "$BODY" \
  '  _nightChapter(sections, facts, reveals, extras);
  todayDaySections(sections, facts, data, extras);' \
  '  todayDaySections(sections, facts, data, extras);
  _nightChapter(sections, facts, reveals, extras);'

# The bridge under the hero moves above it. It still reads as a sentence about
# the estimate, the chapters are untouched, and nothing looks wrong — the
# connective line has simply stopped connecting the two things it names.
mutate 'the context bridge is drawn before the hero' "$ORDER_TEST" "$BODY" \
  '  sections.add(TodaySummaryTiles(facts: facts));
  sections.gap(PageSpacing.block);
  sections.add(ContextBridge.text(kAgeBridge));' \
  '  sections.add(ContextBridge.text(kAgeBridge));
  sections.add(TodaySummaryTiles(facts: facts));
  sections.gap(PageSpacing.block);'

# A section quietly dropped. Legacy draws the week whenever it has two nights;
# a card that stops appearing is the failure mode a rendered-scroll test cannot
# see, because most of Today is never built at 800x600.
mutate 'a legacy section is dropped' "$ORDER_TEST" "$BODY" \
  '  if (snapshot.sleepHistory7d.length >= 2) {' \
  '  if (snapshot.sleepHistory7d.length >= 2 \&\& false) {'

# ── the connection surface may only be quiet when nothing is wrong ──────────
HEALTH=lib/data/sync/connection_health.dart
LINES=lib/data/sync/health_lines.dart
STRIP_TEST="test/features/today_connection_surface_test.dart test/features/connection_quiet_test.dart"

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

# ── the ring, and the card that carries what a ring cannot say ──────────────
CARD=lib/features/today/widgets/data_health_section.dart
RING=lib/shared/connection/sync_ring.dart
SURFACE_TEST="test/features/today_connection_surface_test.dart test/features/connection_quiet_test.dart"
RING_TEST=test/features/sync_ring_test.dart

# THE mutation the strip's deletion is exposed to. The two RADIO faults have no
# `HealthLine` behind them, so the card is the only place their words exist —
# dropping the loop leaves them classified, loud, and drawn nowhere at all.
mutate 'the radio faults stop reaching the card' "$SURFACE_TEST" "$CARD" \
  '          for (final alert in link) ...[' \
  '          for (final alert in const <ConnectionAlert>[]) ...['

# The remedy dropped while the headline stays. "Bluetooth is off" with no
# "turn Bluetooth on" is a fault with no answer, and it looks fixed.
mutate 'a radio fault loses its remedy' "$SURFACE_TEST" "$CARD" \
  '            if (alert.detail case final String remedy) ...[' \
  '            if (alert.detail case final String remedy when false) ...['

# The ring deciding quietness for itself. It reads `quiet` — the ONE place the
# answer is computed — and a ring that consulted only the link would draw the
# resting state over a phone that cannot reach its server.
mutate 'the ring re-derives quiet from the link alone' "$RING_TEST" "$RING" \
  '  if (!health.quiet) {' \
  '  if (health.linkAlerts.isNotEmpty) {'

# An invented fraction. `strap_progress.dart` is explicit: a determinate bar that
# is really a guess is the interface version of a number nobody measured, and it
# makes a stalled sync indistinguishable from a working one in the other
# direction — the bar simply sits at whatever was invented.
mutate 'a phase with no progress fakes a fraction' "$RING_TEST" "$RING" \
  '        SyncRingState.syncing => health.progress?.fraction,' \
  '        SyncRingState.syncing => health.progress?.fraction ?? 0.5,'

# The fault ring wearing a verdict colour. `README.md`: there is one red and it
# is illness; `unf` is not a warning colour. A radio is not a fact about a body.
mutate 'the fault ring spends a verdict colour' "$RING_TEST" "$RING" \
  '    SyncRingState.needsAttention => colors.ink,' \
  '    SyncRingState.needsAttention => colors.unf,'

# The label collapsing to one sentence for every state: four colours and one
# word is what a screen reader gets from a ring nobody labelled.
mutate 'every ring state announces the same thing' "$RING_TEST" "$RING" \
  '    case SyncRingState.connected:
    case SyncRingState.idle:
      return health.report.headline;' \
  '    case SyncRingState.connected:
    case SyncRingState.idle:
      return '"'"'Syncing'"'"';'

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
SCREEN=lib/features/today/today_screen.dart
DIAG_ROW=lib/features/settings/widgets/diagnostics_setting.dart
STRAP_ROW=lib/features/settings/widgets/strap_setting.dart
SERVER_ROW=lib/features/settings/widgets/server_setting.dart
ROUTER=lib/core/router.dart
BACK_TEST="test/features/back_navigation_test.dart test/features/out_of_shell_navigation_test.dart"

# The defect exactly as it shipped, found on the device and not here. `go`
# REPLACES the location, so Settings has nothing beneath it: the shell's back
# rule finds an empty branch stack, correctly concludes "not on Today", and
# leaves the app — from a screen the owner tapped into two seconds earlier.
mutate 'the avatar reaches settings with go' "$BACK_TEST" "$SCREEN" \
  '          onOpenProfile: () => unawaited(context.push(Routes.settings)),' \
  '          onOpenProfile: () => context.go(Routes.settings),'

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

# ── Today: a refusal must never come back as a number ───────────────────────
TILE=lib/features/today/widgets/metric_tile.dart
RECOVERY=lib/features/today/widgets/recovery_card.dart
TILE_TEST=test/features/today_tiles_test.dart
WITHHELD_TEST=test/features/today_withheld_test.dart

# THE defect this whole architecture exists to make impossible, at the last hop:
# a grid cell that draws a figure where the server sent a refusal. Zero is the
# most dangerous version, because it is a plausible reading.
mutate 'a withheld tile renders a number anyway' "$TILE_TEST" "$TILE" \
  '          Withheld<double>(:final disclosure) => _Hole(
            message: disclosure.message,
            foot: foot,
          ),' \
  '          Withheld<double>() => _body(context, 0),'

# The softer version: the hole is drawn and the REMEDY is dropped. Legacy has no
# detail screen for these six metrics, so a cell that says only "withheld" is a
# refusal with no explanation anywhere on the device.
mutate 'a withheld tile drops the remedy' "$TILE_TEST" "$TILE" \
  '          Text(message, style: HType.sans(colors.ink2, size: 11, height: 1.35)),' \
  '          const SizedBox.shrink(),'

# A withheld BLOCK silently vanishing is legacy's own behaviour and the one this
# port deliberately does not keep: an absent card and a broken screen look the
# same.
mutate 'a withheld block is dropped instead of explained' "$WITHHELD_TEST" \
  lib/shared/states/reading_view.dart \
  '      Withheld<T>(:final disclosure) =>
        withheldBuilder?.call(context, disclosure) ??
            WithheldCard(
              disclosure: disclosure,
              label: label,
              onExplain: onExplainWithheld,
            ),' \
  '      Withheld<T>() => const SizedBox.shrink(),'

# The v02 carrier drops the REASON and keeps the hole. A dash with nothing
# beside it is the state this whole layer exists to make impossible: it reads as
# "nothing happened" rather than as "the server would not say".
mutate 'the withheld panel drops its reason' "$WITHHELD_TEST" \
  lib/shared/v02/withheld_panel.dart \
  '                  child: Text(
                    disclosure.message,' \
  '                  child: Text(
                    '"'"''"'"',' 

# ── a compacted caveat must not become an invisible one ─────────────────────
# The disclosures moved off the card and into a sheet on 2026-08-06, because the
# server's are essays and four of them under one card is what the owner reported.
# Every mutation below is the SAME failure the compaction could have introduced:
# the prose is gone from the screen and nothing took its place. None of them look
# broken — that is the entire risk, and it is worse than the essay was.
VIEW=lib/shared/states/reading_view.dart
CAVEAT=lib/shared/states/caveat_disclosure.dart
MODULE=lib/shared/instrument_module.dart
CAVEAT_TEST="test/features/today_caveat_surface_test.dart test/shared/reading_view_test.dart test/shared/caveat_carriers_test.dart test/features/caveat_attribution_test.dart"

# THE mutation: a Caveated renders exactly like a Present. This is what "just
# stop printing the bullet points" would have been if nobody replaced them, and
# it is a one-line diff that makes the screen look better.
mutate 'a caveated value renders as if it were Present' "$CAVEAT_TEST" "$VIEW" \
  '      Caveated<T>(:final value, :final caveats) =>
        caveatCarrier == CaveatCarrier.insideCard
        ? CaveatScope(
            caveats: caveats,
            label: label,
            child: builder(context, value),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              builder(context, value),
              caveatBuilder?.call(context, caveats) ??
                  CaveatNote(caveats: caveats, label: label),
            ],
          ),' \
  '      Caveated<T>(:final value) => builder(context, value),'

# The same failure on the tile side, where the carrier is a header mark rather
# than a row. The tile keeps its number, its chart and its height, and stops
# saying the number came from a different instrument on a different night.
mutate 'a caveated tile stops marking itself' "$TILE_TEST" \
  lib/features/today/widgets/metric_tile.dart \
  '    final caveats = reading.caveatsOrEmpty;' \
  '    final caveats = const <Disclosure>[];'

# The module ignoring what it was handed — same outcome, one layer down, and it
# takes out the blood-oxygen module, the HRV module and every card a ReadingView
# hands its disclosures down to.
mutate 'the module drops the caveat note' "$CAVEAT_TEST" "$MODULE" \
  '                if (disclosed.isNotEmpty)
                  CaveatNote(caveats: disclosed, label: named),' \
  ''

# The module stops CLAIMING the scope. This is the 2026-08-06 orphan defect
# reintroduced: the disclosure is still drawn, by `ReadingView`, as a sibling
# beneath the whole card — in the gutter, naming neither card. Nothing looks
# missing, which is exactly why it needs a mutation.
mutate 'the card stops claiming its own caveats' "$CAVEAT_TEST" "$MODULE" \
  '    final scope = CaveatScope.of(context);
    final disclosed = <Disclosure>[...caveats, ...?scope?.caveats];' \
  '    final scope = CaveatScope.of(context);
    final disclosed = <Disclosure>[...caveats];'

# The sheet keeping only the first disclosure. The card still says "4 things
# tilt this number", so the count and the contents disagree and only the sheet
# knows. Biological age loses three paragraphs including the SRI exclusion.
mutate 'the sheet shows only the first disclosure' "$CAVEAT_TEST" "$CAVEAT" \
  '            for (final caveat in caveats) _CaveatBlock(caveat: caveat),' \
  '            _CaveatBlock(caveat: caveats.first),'

# The headline stops counting. It is the ONLY part of a compacted caveat a
# reader sees without tapping, so this is where a dropped disclosure has to
# become visible — a fixed sentence would hide it completely.
mutate 'the headline stops counting the disclosures' "$CAVEAT_TEST" "$CAVEAT" \
  "String caveatHeadline(int count) => count == 1
    ? 'Caveated — one thing tilts this number'
    : 'Caveated — \$count things tilt this number';" \
  "String caveatHeadline(int count) => 'Caveated';"

# The geometric half of the bargain. The disclosure line costs a caveated tile no
# height ONLY because EVERY tile reserves the slot; reserve it just-in-time and
# the caveated cell stands proud of the one beside it — which is the owner'"'"'s
# "the card too big" report arriving by a different route.
mutate 'only a caveated tile reserves the disclosure line' "$TILE_TEST" \
  lib/features/today/widgets/metric_tile.dart \
  '        SizedBox(
          height: disclosureHeight,
          child: caveats.isEmpty
              ? null
              : CaveatFoot(caveats: caveats, label: label, gap: 2),
        ),' \
  '        if (caveats.isNotEmpty)
          SizedBox(
            height: disclosureHeight,
            child: CaveatFoot(caveats: caveats, label: label, gap: 2),
          ),'

# ── the asterisk must not come back ─────────────────────────────────────────
# Owner, on the installed build: *"what are those * symbol in card"*. A bare
# footnote mark is not words, and the file it lived in says in its own docstring
# that a caveated value discloses IN WORDS. This is the regression test for the
# GLYPH: any carrier that reaches for a lone mark again fails here.
mutate 'the caveat goes back to a bare footnote mark' "$TILE_TEST" "$CAVEAT" \
  "String caveatFootnote(int count) =>
    count == 1 ? '1 caveat · tap to read' : '\$count caveats · tap to read';" \
  "String caveatFootnote(int count) => '*';"

# ── the two quiet chart inks ────────────────────────────────────────────────
# The gridline defect exactly as it shipped: `withValues` REPLACES the alpha, so
# a 10% hairline is drawn at 70%. On dark that is the "almost white" the owner
# reported, and it looks like a deliberate emphasis in a diff.
CHART_INK=test/theme/chart_ink_test.dart

mutate 'a gridline derives itself from the hairline again' "$CHART_INK" \
  lib/shared/charts/h_stacked_sleep.dart \
  '      ..color = colors.grid' \
  '      ..color = colors.line.withValues(alpha: 0.7)'

# The reference line back at full ink3 — the same weight as the caption naming
# it, which is what the owner asked us to quieten.
mutate 'the reference line goes back to full-strength ink' "$CHART_INK" \
  lib/shared/charts/h_area.dart \
  '                referenceInk: colors.reference,' \
  '                referenceInk: colors.ink3,'

# The Sleep cell'"'"'s chart. `hypnogramSpans` was mutated here until 2026-08-06 —
# it guarded legacy'"'"'s fabricated one-minute light-sleep band for an unstaged
# night. The cell draws `HStageBar` now (owner-delegated departure, recorded in
# `today_tiles.dart`) and the guard moved into the chart: no minutes, no bar.
# Feeding it an empty map is the same claim the deleted fallback made in reverse
# — a chart slot that says nothing about a night we DO have staged.
TILES=lib/features/today/widgets/today_tiles.dart
SLEEP_CELL_TEST="test/features/grid_sleep_cell_test.dart test/features/today_charts_test.dart"

mutate 'the seven-night stack is drawn from no nights' "$SLEEP_CELL_TEST" \
  lib/features/today/v02/night_panels.dart \
  '            builder: (context, t) =>
                HStackedSleep(nights, progress: t, height: chartHeight),' \
  '            builder: (context, t) => HStackedSleep(
                  const <SleepNightSummary>[],
                  progress: t,
                  height: chartHeight,
                ),'

# The bar drawn from the wrong night'"'"'s shape: every stage equal. It renders as a
# perfectly plausible four-colour bar and is a picture of no measurement.
mutate 'every sleep stage is drawn the same width' "$SLEEP_CELL_TEST" \
  lib/shared/charts/h_stage_bar.dart \
  '                    Expanded(
                      flex: minutes,' \
  '                    Expanded(
                      flex: 1,'

# A factor the model did not score, drawn as a factor scored zero. An empty
# track and a full-length zero-width fill are the same picture; the em dash in
# the reading column is the only thing that says which of the two this is.
mutate 'an unscored recovery factor reads as zero' \
  test/features/today_screen_test.dart \
  lib/shared/v02/meters.dart \
  '                    child: factor.fraction == null
                        ? const SizedBox.shrink()
                        : FractionallySizedBox(' \
  '                    child: factor.fraction == 999
                        ? const SizedBox.shrink()
                        : FractionallySizedBox('

# The factor rows print the payload's own keys. `rr` under a bar on a health
# screen is a log line where a name belongs.
mutate 'a recovery factor is labelled by its wire key' \
  test/features/today_screen_test.dart \
  lib/features/today/v02/recovery_panel.dart \
  '                  factorLabel(factor.name),' \
  '                  factor.name,'

# ── a modal sheet is over the APP, not over one tab ─────────────────────────
# The owner's report: "the info sheet comes beyond the navbar". Both halves are
# mutated here because each is enough on its own to put the tail of a sheet
# under an opaque bar, and each looks completely fine in review.
SHEET=lib/shared/sheets/app_sheet.dart
INFO=lib/shared/metric_info/metric_info_sheet.dart
LAYER_TEST=test/features/sheet_layering_test.dart

# The defect exactly as it shipped: the DEFAULT. `useRootNavigator: false`
# resolves the current tab's branch navigator, which lives inside
# `Scaffold.body`, so the sheet is laid out in one tab's content box and stops
# at the bar's top edge.
mutate 'the sheet goes back to the tab branch navigator' "$LAYER_TEST" "$SHEET" \
  '    useRootNavigator: true,' \
  '    useRootNavigator: false,'

# The other half: covering the bar means owning the inset the bar was absorbing.
# Dropping it puts the sources inside the gesture bar, which reads as fixed.
mutate 'the sheet foot stops leaving the gesture inset' "$LAYER_TEST" "$INFO" \
  '      padding: EdgeInsets.fromLTRB(22, 12, 22, 32 + sheetBottomInset(context)),' \
  '      padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),'

# ── the four vitals charts, and the corpus rules on them ───────────────────
# Owner report 2026-08-06: "can we change the heartrate, stress, hrv, blood
# oxygen graphs to be more meaningful ones, this graphs all look similar." The
# fix gave each chart a reference — and the SECOND report, on that build, was
# "stress is named as AROUSAL, heart rate is also looks wried, same as blood
# oxygen you just made it bad": three of the four captions had been painted on
# top of the data, the metric had been renamed out from under him, and two
# y-scales spent the plot on air. Every mutation below is a way for one of those
# to come back, or for a reference to become a claim the corpus forbids, or for
# two of the four to collapse onto one picture. Every one renders perfectly, and
# three look like MORE care rather than less: a mood label reads as insight, a
# flag on one low night reads as vigilance, and a baseline computed from the
# visible window reads as data.
STRESSCARD=lib/features/today/widgets/stress_card.dart
OXYGEN=lib/features/today/widgets/blood_oxygen_card.dart
HRVCARD=lib/features/today/widgets/hrv_trend_card.dart
NOTE=lib/features/today/widgets/metric_note.dart
DEVIATION=lib/shared/charts/h_deviation.dart
NIGHTLINE=lib/shared/charts/h_night_line.dart
REFERENCE=lib/shared/charts/chart_reference.dart
AREA=lib/shared/charts/h_area.dart
STRESS_TEST=test/features/vitals_stress_test.dart
LABEL_TEST=test/features/vitals_labels_test.dart
SCALE_TEST=test/features/vitals_scales_test.dart
THRESHOLD_TEST=test/features/vitals_thresholds_test.dart
MARKS_TEST=test/features/vitals_marks_test.dart

# wearable_stress_validity D1/D2, SAFETY-CRITICAL. The number banded into a
# feeling — the single thing this note exists to forbid, and the most natural
# "improvement" anyone could make to a bare number in a header.
mutate 'the stress figure is banded into a mood' "$STRESS_TEST" "$STRESSCARD" \
  "              '\$average avg'," \
  '              "$average avg · ${average > 40 ? \"tense\" : \"calm\"}",'

# The rename itself, which is what the owner actually reported. The directives
# are about CLAIMS the card makes, never about the name of the metric, and the
# verbatim-legacy rule says keep legacy's word — so this edit reads like corpus
# compliance and is a design change nobody asked for.
mutate 'the card is renamed Arousal again' "$STRESS_TEST" "$STRESSCARD" \
  "      label: useIntraday ? 'Stress · today' : 'Stress · 14 days'," \
  "      label: useIntraday ? 'Arousal · today' : 'Arousal · 14 days',"

# D3: a high or low value is non-specific and must never be singled out.
# `HBars` emphasises its last bar by default, so this mutation is a DELETION —
# exactly what a reviewer removing a "redundant" argument would do.
mutate 'the latest hour of stress is picked out' "$STRESS_TEST" "$STRESSCARD" \
  '              allHighlighted: true,' \
  '              allHighlighted: false,'

# wearable_spo2_validity D1/D3: "never a single-reading alarm", "never call out
# individual low-reading minutes". A run of one IS a single-reading alarm.
mutate 'one low night counts as a sustained run' "$THRESHOLD_TEST" "$NOTE" \
  'const int sustainedLowNights = 3;' \
  'const int sustainedLowNights = 1;'

# The same directive from the other side: the run counter stops resetting, so
# four scattered artefact nights across a fortnight add up to a "run".
mutate 'scattered low nights accumulate into a run' "$THRESHOLD_TEST" "$NOTE" \
  '    run = minimum < spo2ConventionPercent ? run + 1 : 0;' \
  '    run = minimum < spo2ConventionPercent ? run + 1 : run;'

# D2: the ~92% figure is a clinical convention, NOT a wearable-validated cutoff
# (#98 sourced none). Drawn without that word it becomes a pass/fail line about
# this owner's oxygen, measured by a sensor whose error is unquantified.
mutate 'the 92% line stops saying it is a convention' "$THRESHOLD_TEST" "$OXYGEN" \
  "      label:
          '\${spo2ConventionPercent.round()}% is a clinical convention '
          '— not a cutoff for this strap'," \
  "      label: 'MIN \${spo2ConventionPercent.round()}%',"

# CLAUDE.md, ONE canonical definition per metric. The baseline the server did
# not send, computed from the fourteen points on screen instead. It renders
# identically to a real one and is a different number over a different window
# from the median every other surface in the app quotes.
mutate 'the HRV baseline is invented from the visible window' \
  "$THRESHOLD_TEST" "$HRVCARD" \
  '    final median = baseline;' \
  '    final median = baseline ?? series.reduce((a, b) => a + b) / series.length;'

# The honesty rule all four share: too short to be a trend draws NOTHING. One
# night is a reading; a chart of it invites it to be read as a fortnight.
mutate 'a single night is drawn as a fortnight' "$MARKS_TEST" "$NIGHTLINE" \
  '    if (data.length < HNightLine.minimumNights) {' \
  '    if (data.isEmpty) {'

# The owner's actual complaint, mechanised: HRV fills to the floor of its box
# again instead of to its baseline, which makes it the same picture as the
# heart-rate chart — one mark, two questions.
mutate 'HRV goes back to filling to the floor' "$MARKS_TEST" "$DEVIATION" \
  '      ..lineTo(size.width - _padX, baselineY)
      ..lineTo(_padX, baselineY)' \
  '      ..lineTo(size.width - _padX, size.height)
      ..lineTo(_padX, size.height)'

# ── THE DEFECT THE OWNER PHOTOGRAPHED: a label lying on the data ────────────
# `YOUR 30-DAY NORMAL 53 MS` across the HRV trace, `RESTING 56` in the same
# pixels as the hour captions, a 55-character SpO2 sentence through the nights.
# It renders, and the label is drawn CORRECTLY — in the wrong place. Nothing
# short of geometry catches that, which is why it shipped.
mutate 'a reference caption is painted back into the plot' "$LABEL_TEST" "$REFERENCE" \
  '  } else {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}' \
  '  } else {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  final label = chartLabel(
    reference.label,
    TextStyle(fontSize: 8, color: color),
  );
  label.paint(canvas, Offset(0, (y - label.height - 1).clamp(0.0, size.height)));
}'

# The other half of "looks wried", and it is invisible to every assertion about
# WHAT was drawn: the reference painted first, so a grey hairline sits under a
# 32% clay wash and comes out as brown sludge. This is the code as it shipped.
mutate 'the reference goes back behind the fill' "$LABEL_TEST" "$AREA" \
  '    for (final reference in references) {
      paintChartReference(
        canvas,
        size,
        reference,
        scale: scale,
        color: referenceInk,
        progress: progress,
      );
    }
' \
  '' \
  '    if (fill) {' \
  '    for (final reference in references) {
      paintChartReference(
        canvas,
        size,
        reference,
        scale: scale,
        color: referenceInk,
        progress: progress,
      );
    }

    if (fill) {'

# `include:` is what makes a reference honest rather than decorative. Dropped,
# the resting line still draws — on the floor of the box, where it reads as
# "you never went below your resting rate". A false claim made by layout alone.
mutate 'the heart-rate reference is left out of its own scale' "$SCALE_TEST" "$AREA" \
  '      include: <double>[for (final line in references) line.value],' \
  '      include: const <double>[],'

# The padding made symmetric again — "why would a reference pad differently from
# the data?" It is a tidy-up, it renders, and it is the owner's flat trace: his
# day drops from 59% of its plot to 51%, and a reading in an empty box is what
# he was looking at when he said the chart looked wrong.
mutate 'the reference pad reverts to the data pad' "$SCALE_TEST" "$REFERENCE" \
  '  static const double referencePadFraction = 0.06;' \
  '  static const double referencePadFraction = padFraction;'

# Blood oxygen back to unconnected dots — my own instruction of that morning,
# and the shape that hides the multi-night trend D1 makes the only readable
# thing about SpO2. It also collapses this chart back toward the other three.
mutate 'blood oxygen goes back to unconnected dots' "$MARKS_TEST" "$NIGHTLINE" \
  '    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
' \
  ''

# The fixed window dropped for an auto-scale. It looks like less code and more
# data, and it makes the axis move every night: the same 95% night lands on a
# different pixel depending on which OTHER nights are in the fortnight, on a
# sensor whose error is unquantified and at least ±3.5%.
mutate 'the blood-oxygen window is dropped for an auto-scale' "$SCALE_TEST" "$OXYGEN" \
  '            window: (low: scaleFloorPercent, high: scaleCeilingPercent),
' \
  ''

# The plot back to legacy's 52 px, which is the verbatim-port rule applied to the
# one card legacy itself gave extra room. At 52 a percentage point is 3.8 px —
# narrower than a night mark — so consecutive nights smear into one another.
mutate 'the blood-oxygen plot goes back to 52 px' "$SCALE_TEST" "$OXYGEN" \
  '  static const double chartHeight = 76;' \
  '  static const double chartHeight = 52;'

# A fixed scale that silently stops being fixed. The low night is still plotted,
# so nothing looks wrong — the reader is simply reading a different axis from the
# one every other night was drawn on, and is never told.
mutate 'the widened scale stops saying so' "$SCALE_TEST" "$OXYGEN" \
  '        if (lowest != null && lowest < scaleFloorPercent)
          ModuleFoot(
            '"'"'Scale widened below ${scaleFloorPercent.round()}% '"'"'
            '"'"'to keep every night on it'"'"',
          ),
' \
  ''

# ── v02 charts: the foundation and the series charts (phase 2a) ─────────────
V02_FOUNDATION="test/shared/v02_chart_foundation_test.dart"
V02_SERIES="test/shared/v02_charts_series_test.dart"
V02_COLUMNS="test/shared/v02_charts_columns_test.dart"
V02_TICKS="lib/shared/charts/v02/chart_ticks.dart"
V02_CURVE="lib/shared/charts/v02/chart_curve.dart"
V02_SCRUB="lib/shared/charts/v02/chart_scrub.dart"
V02_FRAME="lib/shared/charts/v02/chart_frame.dart"
V02_INK="lib/shared/charts/v02/chart_ink.dart"
V02_VOID="lib/shared/charts/v02/chart_void.dart"
V02_COLUMN_PAINTER="lib/shared/charts/v02/column_painter.dart"
V02_BARS="lib/shared/charts/v02/v02_bar_chart.dart"
V02_LINKED="lib/shared/charts/v02/v02_linked_chart.dart"
V02_LINKED_PAINTER="lib/shared/charts/v02/linked_painter.dart"

# The axis goes back to the prototype's [min, mid, max]: three rules at whatever
# the data reached, so every chart carries a different arbitrary scale.
mutate 'the tick step stops being a round number' "$V02_FOUNDATION" "$V02_TICKS" \
  '  return multiple * magnitude;' \
  '  return rough;'

# The Fritsch-Carlson limiter removed. The curve is still smooth and still
# passes through every sample -- and now draws values between them that the
# sensor never produced.
mutate 'the monotone limiter is dropped' "$V02_FOUNDATION" "$V02_CURVE" \
  '    if (radius > 9) {' \
  '    if (radius > 1e9) {'

# The turning-point rule removed, which is the half that stops a curve
# continuing downward past a local minimum.
mutate 'a local extremum stops flattening the tangent' "$V02_FOUNDATION" "$V02_CURVE" \
  '    tangent[i] = slope[i - 1] * slope[i] <= 0
        ? 0
        : (slope[i - 1] + slope[i]) / 2;' \
  '    tangent[i] = (slope[i - 1] + slope[i]) / 2;'

# One reading becomes a line. This is the shipped bug: HArea([0, 0]).
mutate 'one sample is enough to draw a trend' "$V02_SERIES" "$V02_VOID" \
  '      if (measured >= 2) {' \
  '      if (measured >= 1) {'

# The tick labels move back inside the plot -- the exact 2026-08-06 failure,
# where three charts shipped with words lying across the trace.
mutate 'the value labels move into the plot' "$V02_SERIES" "$V02_FRAME" \
  '  final left = math.max(
    box.values.left,
    box.values.right - _gutterPad - painter.width,
  );' \
  '  final left = box.plot.left;'

# A withheld chart collapses its slot, so every card below it jumps when the
# sync lands and an absence stops looking like an absence.
mutate 'the empty slot stops holding its height' "$V02_SERIES" "$V02_VOID" \
  '      SizedBox(height: height, width: double.infinity);' \
  '      const SizedBox.shrink();'

# withValues REPLACES alpha. This is the gridline-at-five-times bug, exactly.
mutate 'the gridline alpha is replaced instead of scaled' "$V02_SERIES" "$V02_INK" \
  '    ..color = revealed(grid, progress)' \
  '    ..color = grid.withValues(alpha: progress)'

# The finger is mapped across the whole widget instead of the plot inside it, so
# the scrubber reports a sample next to the one under the cursor -- and looks
# exactly right doing it.
mutate 'the scrubber maps the finger against the widget, not the plot' "$V02_SERIES" "$V02_SCRUB" \
  '    final box = widget.metrics.box(Size(_width, widget.height));
    final index = box.indexAt(dx, widget.sampleCount);' \
  '    final index = ((dx / _width).clamp(0.0, 1.0) * (widget.sampleCount - 1))
        .round();'

# A bar axis cut above zero: a 9,000-step day then draws twice the bar of an
# 8,000-step day, and nobody can see the arithmetic that did it.
mutate 'the bar axis stops standing on zero' "$V02_COLUMNS" "$V02_BARS" \
  '                zeroBased: true,' \
  '                zeroBased: false,'

# A measured zero and an unmeasured day become the same picture.
mutate 'a measured zero stops marking its baseline' "$V02_COLUMNS" "$V02_COLUMN_PAINTER" \
  '    final height = math.max(full.abs() * progress.clamp(0.0, 1.0), _floorMark);' \
  '    final height = full.abs() * progress.clamp(0.0, 1.0);'

# Both panes forced onto one axis: heart rate flattens into the bottom third and
# the crossing point of the two traces starts looking like it means something.
mutate 'the linked panes share one scale' "$V02_COLUMNS" "$V02_LINKED" \
  '          ticks: ChartTicks.nice(pane.values.whereType<double>()),' \
  '          ticks: ChartTicks.nice(panes.first.values.whereType<double>()),'

# The lanes abut, and the second pane title sits on the first pane fill.
mutate 'the linked lanes stop leaving air between them' "$V02_COLUMNS" "$V02_LINKED_PAINTER" \
  'const double _laneGap = 5;' \
  'const double _laneGap = 0;'

# ── the v02 hero instruments ────────────────────────────────────────────────
HALO=lib/shared/v02/instruments/bio_halo.dart
FIELD=lib/shared/v02/instruments/halo_field.dart
WATERFALL=lib/shared/v02/instruments/age_waterfall.dart
RULER=lib/shared/v02/instruments/age_scale.dart
RAIL=lib/shared/v02/instruments/vo2max_rail.dart
ROUTE=lib/shared/v02/instruments/route_plot.dart
HALO_TEST=test/shared/instruments/halo_motion_test.dart
AGE_TEST=test/shared/instruments/age_instruments_test.dart
FITNESS_TEST=test/shared/instruments/fitness_instruments_test.dart

# THE failure the waterfall exists to prevent. A term that could not be computed
# is drawn as a minimum-height bar, which is pixel-identical to the sleep term
# that WAS computed and came out at zero. One says "we could not price this",
# the other says "we priced it and it was nothing".
mutate 'an excluded age term is drawn as a stub bar' "$AGE_TEST" "$WATERFALL" \
  '            from: running,
            to: null,' \
  '            from: running,
            to: running,'

# The ladder snapped onto the estimate. It looks tidier, and it draws a
# reconciliation that did not happen.
mutate 'the waterfall snaps its ladder onto the estimate' "$AGE_TEST" "$WATERFALL" \
  '    final anchor = column.from == null ? bottom : y(column.from!);' \
  '    final anchor = column.from == null ? bottom : y(column.to ?? running);'

# A value off the 28-44 ruler clamped to the end instead of drawing nothing.
mutate 'the age ruler clamps an off-scale estimate' "$AGE_TEST" "$RULER" \
  '    if (onScale(estimate, low: kAgeScaleLow, high: kAgeScaleHigh)) {' \
  '    if (estimate.isFinite) {'

# The three ways the halo must stop, broken one at a time: a halo that pauses
# two ways out of three still burns the battery the third way.
mutate 'the halo keeps animating in the background' "$HALO_TEST" "$HALO" \
  '    _foreground = state == AppLifecycleState.resumed;' \
  '    _foreground = true;'

mutate 'the halo ignores the system reduced-motion setting' "$HALO_TEST" "$HALO" \
  '    _reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;' \
  '    _reducedMotion = false;'

mutate 'the halo keeps animating offscreen' "$HALO_TEST" "$HALO" \
  '    if (!_onScreen()) {
      _ticker.stop();
      return;
    }
' \
  ''

# The still centre stops being enforced, so particles drift across the figure.
mutate 'particles are allowed into the still centre' "$HALO_TEST" "$FIELD" \
  '    if ((at - centre).distance < stillRadius) {
      return null;
    }
' \
  ''

# The extent renamed. A wording mutation on purpose: the sentence is the honesty
# half of the instrument, and it is as breakable as the geometry.
mutate 'the error magnitude is called a confidence interval' "$FITNESS_TEST" "$RAIL" \
  'const String kErrorMagnitudeNote = '"'"'not a confidence interval'"'"';' \
  'const String kErrorMagnitudeNote = '"'"'a 95% confidence interval'"'"';'

# Elevations that do not line up with the fixes are drawn anyway — the profile
# of a different walk, plotted along this one.
mutate 'mismatched elevations are drawn anyway' "$FITNESS_TEST" "$ROUTE" \
  'if (series == null || series.length != points.length || series.length < 2) {' \
  'if (series == null || series.length < 2) {'

# ── the v02 Today: what a panel may not stop saying ─────────────────────────
PANEL=lib/shared/v02/panel.dart
HERO=lib/shared/v02/bio_hero.dart
MINI=lib/features/today/v02/mini_trend_panel.dart
FITNESS=lib/features/today/v02/longer_panels.dart
HERO_TEST=test/features/today_hero_test.dart
V02_CAVEAT_TEST="test/features/today_caveat_surface_test.dart test/features/caveat_attribution_test.dart"

# The v02 carrier stops reading the scope it was handed. `ReadingView` draws
# nothing itself under `CaveatCarrier.insideCard`, so this is the disclosure
# vanishing in silence — the one failure worse than the essay it replaced.
mutate 'the v02 panel drops the caveats it was handed' "$V02_CAVEAT_TEST" "$PANEL" \
  '          if (disclosed.isNotEmpty)
            CaveatNote(caveats: disclosed, label: named),' \
  ''

# The same, in the hero. It is not a `Panel`, so it needs its own block and its
# own mutation: the biological-age block carries FOUR disclosures on the
# committed payload and is the card the owner reported.
mutate 'the hero drops the caveats it was handed' "$V02_CAVEAT_TEST" "$HERO" \
  '    if (disclosed.isNotEmpty) ...<Widget>[
      const SizedBox(height: modelGap),
      _inset(CaveatNote(caveats: disclosed, label: scope?.label)),
    ],' \
  ''

# A half-width panel blanking on a refusal. It keeps its title, its slot and its
# chart void, and stops saying why the number is missing — which reads as a
# metric that simply has nothing today.
mutate 'a twin panel blanks instead of saying why' "$THRESHOLD_TEST" "$MINI" \
  '      withheldBuilder: (context, disclosure) =>
          _panel(value: '"'"'—'"'"', note: disclosure.message),' \
  '      withheldBuilder: (context, disclosure) =>
          _panel(value: '"'"'—'"'"', note: '"'"''"'"'),'

# The tier id printed raw. `gps_graded` under a VO₂max figure is an identifier
# where an instrument's name belongs, and it looks like a deliberate label.
mutate 'the VO2max method is printed as its wire id' \
  test/features/today_screen_test.dart "$FITNESS" \
  "      'Read by \${methodLabel(vo2max.method)}'," \
  '      vo2max.method,'

# The server's 300-character method prose back inline. This is the owner's
# *"raw text below the fitness card"* report, arriving by the shortest route.
mutate "the method essay is printed on the card again" \
  "test/features/today_caveat_surface_test.dart" "$FITNESS" \
  '          PanelNote(_qualifiers(vo2max)),' \
  '          PanelNote(vo2max.methodCaveat),'

# A meter drawn against a target the payload never sent. `/api/today` carries no
# step goal, so any fraction here is this app inventing the owner's target and
# then reporting progress against it.
mutate 'the movement tile invents a step target' "$HERO_TEST" \
  lib/features/today/v02/today_hero.dart \
  '      value: commaGrouped(steps.round()),
      meta: facts.medianFootFor(TodayMetricIds.steps).toLowerCase(),' \
  '      value: commaGrouped(steps.round()),
      fraction: steps / 10000,
      meta: facts.medianFootFor(TodayMetricIds.steps).toLowerCase(),'

# The halo placed outside the scroll it watches. It still animates, it still
# looks right on the first screen, and it never pauses again.
mutate 'the hero art is dropped from the card' "$HERO_TEST" \
  lib/features/today/v02/today_hero.dart \
  '      art: const BioHalo(),' \
  '      art: null,'

# ── the v02 Today fixes (withheld hero · provenance off the cards) ───────────
ENVELOPE=lib/data/honesty/envelope.dart
WITHHELD_HERO=lib/features/today/v02/today_hero_withheld.dart
HERO_PARTS=lib/shared/v02/bio_hero_parts.dart
SHEET=lib/shared/metric_info/metric_info_sheet.dart
NIGHT=lib/features/today/v02/night_panels.dart
RECOVERY=lib/features/today/v02/recovery_panel.dart
CHAPTER=lib/shared/v02/chapter.dart
EXCLUDED=lib/shared/states/withheld_card.dart
BODY=lib/features/today/today_body.dart
WITHHELD_HERO_TEST=test/features/today_withheld_hero_test.dart
PROVENANCE_TEST=test/features/card_provenance_test.dart
CHAPTER_TEST=test/shared/chapter_heading_test.dart
READING_TEST=test/shared/reading_view_test.dart

# THE ORIGINAL DEFECT. The composite `withheld` block carries `consequence` +
# `terms` and no top-level `reason`, so the envelope read it as absent, the null
# value fell through to `Excluded`, and Today drew the 400-word regularity essay
# where the hero belongs. Put the blind spot back.
mutate 'the composite withheld block is unreadable again' \
  "$WITHHELD_HERO_TEST" "$ENVELOPE" \
  '    return _composite(raw);' \
  '    return null;'

# The essay back on the card's face, by the shortest route there is.
mutate 'the withheld hero prints the server prose inline' \
  "$WITHHELD_HERO_TEST" "$WITHHELD_HERO" \
  '      kWithheldPointer,
      if (left.isNotEmpty)' \
  '      withheld.message,
      for (final term in withheld.terms) term.message,
      for (final exclusion in exclusions) exclusion.message,
      kWithheldPointer,
      if (left.isNotEmpty)'

# A marker placed for a value that does not exist — the held figure fed to the
# ruler, which is exactly the stale-as-current step this design forbids.
mutate 'a held value is drawn on the age ruler' \
  "$WITHHELD_HERO_TEST" "$WITHHELD_HERO" \
  "import 'package:healthee/shared/v02/bio_hero.dart';" \
  "import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/instruments/age_scale.dart';" \
  '      figure: BioWithheldFigure(' \
  '      instrument: held == null
          ? null
          : AgeScale(estimate: held.value, chronologicalAge: 36),
      figure: BioWithheldFigure('

# The date blanked. A held figure with no date IS the stale-as-current bug.
mutate 'the last-known date is blanked' \
  "$WITHHELD_HERO_TEST" "$HERO_PARTS" \
  "          '\$asOfPrefix\${plainDay(day)}'," \
  "          ''," 

# The refused hero collapsed back into a panel — the small dashed box the owner
# read as the card being missing.
mutate 'the refused hero collapses into a panel' \
  "$WITHHELD_HERO_TEST" "$BODY" \
  '      withheldBuilder: (context, disclosure) => TodayBioHeroWithheld(
        withheld: disclosure,
        exclusions: switch (snapshot.biologicalAge) {
          Withheld<BiologicalAge>(:final exclusions) => exclusions,
          _ => const <Disclosure>[],
        },
      ),' \
  '      withheldBuilder: (context, disclosure) => WithheldPanel(
        disclosure: disclosure,
        label: '"'"'Biological age · estimate'"'"',
      ),'

# The ⓘ sheet emptied of the sources the cards handed it. Every card would keep
# its ⓘ and lose its grounding — the one way this change can do harm.
mutate "the info sheet drops the card's citations" \
  "$PROVENANCE_TEST" "$SHEET" \
  '              noteIds: _notes,' \
  '              noteIds: const <String>[],'

# A reference pill back on a card's face.
mutate 'the reference label returns to the sleep-health grid' \
  "$PROVENANCE_TEST" "$NIGHT" \
  '                dimension.reading ?? '"'"'—'"'"',
              ),' \
  '                dimension.reading ?? '"'"'—'"'"',
                note: '"'"'Reference \${dimension.cutoff}'"'"',
              ),'

# Clinical routing swept away with the method text. A symptom outranks the score
# above it, and that sentence is not clutter.
mutate 'the illness-priority sentence is tidied off the card' \
  "$PROVENANCE_TEST" "$RECOVERY" \
  '          const PanelNote(kRecoveryPriorityNote),' \
  ''

# The exclusion essay back inline, under every value that has one.
mutate 'the exclusion prints its reasoning on the card again' \
  "$READING_TEST" "$EXCLUDED" \
  '                  child: Text(
                    headline(exclusions),' \
  '                  child: Text(
                    exclusions.first.message,'

# The equal-flex split restored: the title and the rule share the row, so every
# chapter heading is cut and the rule stops half way.
mutate 'the chapter title goes back to sharing the row' \
  "$CHAPTER_TEST" "$CHAPTER" \
  '              SizedBox(
                width: wanted < room ? wanted : (room < 0 ? 0 : room),
                child: Text(' \
  '              Flexible(
                child: Text('

# ── the prototype's own chrome: the pinned nav, the glint, the date control ──
# Four things had drifted from `design/mobile-preview/` on judgement calls that
# were not ours to make. Each mutation below is the drift coming back, and every
# one of them renders perfectly.
SHELL_SRC=lib/shared/instrument_screen.dart
BODY_SRC=lib/features/today/today_body.dart
REVEAL=lib/shared/reveal_once.dart
PINNED_TEST=test/features/chapter_nav_pinned_test.dart
REVEAL_TEST=test/shared/reveal_once_test.dart
HALO=lib/shared/v02/instruments/halo_painter.dart
HALO_TEST=test/shared/instruments/halo_ink_test.dart
PARTS=lib/shared/v02/panel_parts.dart
PARTS_TEST=test/shared/panel_value_width_test.dart
VIEW_DATE=lib/data/store/view_date.dart
DEVICE_REPO=lib/data/device/device_repository.dart
SECTIONS=lib/features/today/today_sections.dart
DATE_TEST=test/features/date_control_test.dart

# The nav un-pinned — the edit that reads as a simplification and silently gives
# back `position: sticky`.
mutate 'the chapter nav scrolls away again' "$PINNED_TEST" "$BODY_SRC" \
  '    sections.addPinned(
      TodayChapterNav(chapters: chapters),
      ChapterNav.extentOf,
    );' \
  '    sections.add(TodayChapterNav(chapters: chapters));'

# The pin kept but the shell told to ignore it. Same rendered result, different
# line, and a test that only watched the call site would miss it.
mutate 'the shell stops honouring a pinned section' "$PINNED_TEST" "$SHELL_SRC" \
  '      if (section.pinnedExtent case final SectionExtent extent) {' \
  '      if (section.pinnedExtent case final SectionExtent extent when false) {'

# `CLAUDE.md`'s hard rule, broken inside the restructured scroll: every chart
# replays its reveal on the way back, which is the known expensive legacy bug.
mutate 'a chart replays its reveal on scroll-back' \
  "$REVEAL_TEST $PINNED_TEST" "$REVEAL" \
  '  bool markSeen(Object id) => _seen.add(id);' \
  '  bool markSeen(Object id) {
    _seen.add(id);
    return true;
  }'

# The glint back to a brightness event: `--halo-warm` resolved and then not used.
mutate 'the halo glint stops being warm' "$HALO_TEST" "$HALO" \
  '      glint: colors.haloWarm,' \
  '      glint: colors.bioInk,'

# `--halo-warm` transcribed one digit wrong. Renders; is not the prototype.
mutate 'the halo warm is transcribed wrong' "$HALO_TEST" "$PALETTE" \
  '  static const Color haloWarm = Color(0xFFFED16B);' \
  '  static const Color haloWarm = Color(0xFFFED16C);'

# `.panel-summary` back to two equal halves, which clips every long figure on
# every phone width and looks fine on the 800 px test surface.
mutate 'the panel figure goes back to sharing the row' "$PARTS_TEST" "$PARTS" \
  '                    width: _figureWidth(
                      context,
                      constraints.maxWidth - gap,
                      context.compactPanel,
                    ),' \
  '                    width: (constraints.maxWidth - gap) / 2,'

# ⛔ STALE-AS-CURRENT. The date control without its refusal: a past day draws
# today'"'"'s recovery, sleep health, debt, VO₂max and biological age under an older
# date, and every one of them looks like a reading about that day.
mutate "a past day renders today's judgements as its own" \
  "$DATE_TEST" "$SECTIONS" \
  '  final past =
      extras.navigation != null && data.day.date != extras.navigation!.latest;' \
  '  const past = false;'

# The window gone: the control can ask for tomorrow, or for a day the horizon
# already pruned, and both answer with a screen of withholds.
mutate 'the date control can leave its window' "$DATE_TEST" "$VIEW_DATE" \
  '  void select(String day) {
    if (isViewableDay(day, ref.read(todayProvider))) {
      state = day;
    }
  }' \
  '  void select(String day) {
    state = day;
  }'

# The selection stops reaching the data: the header moves and the screen does
# not, which is a date control that lies about what is under it.
mutate 'the measured half stops following the selection' \
  "$DATE_TEST" "$DEVICE_REPO" \
  '  return store.strapReader.day(ref.watch(viewDateProvider));' \
  '  return store.strapReader.day(ref.watch(todayProvider));'

HERO=lib/shared/v02/bio_hero.dart
GEOMETRY_TEST=test/features/today_hero_geometry_test.dart
FIELD_TEST=test/features/today_hero_field_test.dart

# ── the hero's geometry ─────────────────────────────────────────────────────
# THE DEFECT ITSELF: the field stops being a background layer and becomes a
# sized child of the stack, so the card is as tall as the FIELD and the
# contributions and the model label go off the bottom of the screen.
mutate 'the field drives the card height' "$GEOMETRY_TEST" "$HERO" \
  '    return Positioned.fill(
      // The constraints here are the card'"'"'s finished size' \
  '    return SizedBox.fromSize(
      size: const Size(300, 900),
      // The constraints here are the card'"'"'s finished size'

# The clip goes soft: `overflow: clip` over a 28px radius becomes a square
# corner, and the field paints into the four corners the card does not have.
mutate 'the card stops clipping to its rounded rect' "$FIELD_TEST" "$HERO" \
  '        borderRadius: BorderRadius.circular(radius),' \
  '        borderRadius: BorderRadius.zero,'

# The hole goes back to the middle of the CARD: the densest part of the field
# crosses the figure, and the still centre lands on the sentence and the ruler.
mutate 'the still centre leaves the figure' "$FIELD_TEST" "$HERO" \
  '          stillCentre: centred
              ? bioStillCentre(constraints.biggest)
              : Alignment.center,' \
  '          stillCentre: Alignment.center,'

# `motion.css` resets `.age-value { margin: 0 }`; richer.css'"'"'s 20 comes back
# and the square no longer starts directly under the eyebrow.
mutate 'the centred display takes the inline layout gap' \
  "$GEOMETRY_TEST" "$HERO" \
  '    if (!centred) const SizedBox(height: valueGap),' \
  '    const SizedBox(height: valueGap),'

# The two margins stop being told apart: the divider'"'"'s own 16 is replaced by
# the collapsed 18, which is only right when the caption abuts the rule.
mutate 'the divider gap is always the collapsed one' "$GEOMETRY_TEST" "$HERO" \
  '        height: caption != null && instrument == null ? ruleGap : dividerGap,' \
  '        height: ruleGap,'

# The eyebrow row stops being the control'"'"'s 32: the still centre'"'"'s arithmetic
# is then wrong by the difference, and the square moves up.
mutate 'the eyebrow row loses its pinned extent' "$GEOMETRY_TEST" "$HERO" \
  '    constraints: BoxConstraints(minHeight: centred ? eyebrowExtent : 0),' \
  '    constraints: const BoxConstraints(),'

# The rim's dust handed the stream heads' glow — one line, and 1,120 grains
# become solid balls six times too wide. This IS the defect the owner reported.
SCALE_TEST=test/shared/instruments/halo_scale_test.dart
mutate 'the rim dust wears the stream glow' \
  "$SCALE_TEST" lib/shared/v02/instruments/halo_painter.dart \
  '    dust.forEach(
      (dot) => canvas.drawPoints(
        ui.PointMode.points,
        dot.at,
        _dot(
          glint: dot.glint,
          width: dot.extent,' \
  '    dust.forEach(
      (dot) => canvas.drawPoints(
        ui.PointMode.points,
        dot.at,
        _dot(
          glint: dot.glint,
          width: dot.extent * 6,'

# ── Actions · Journal · Coach, rebuilt to v02 ───────────────────────────────
# The honesty layer on these three screens is almost entirely a set of things
# that must NOT be drawn — a bar with no observation behind it, an input with no
# balance behind it, a prompt that spends a question the owner does not have.
# Every one of those is invisible when it is right, so each is broken here.
SUGGESTION=lib/features/actions/v02/suggestion_card.dart
CHALLENGE_CARD=lib/features/actions/v02/challenge_card.dart
ACTIONS_SCREEN=lib/features/actions/actions_screen.dart
OUTCOME_CARD=lib/shared/challenge_outcome_card.dart
CHOICES=lib/shared/v02/choices.dart
COACH_SHEET=lib/features/coach/coach_sheet.dart
COACH_CTRL=lib/features/coach/coach_controller.dart
COMPOSER=lib/features/coach/v02/coach_composer.dart
JOURNAL_GRID=lib/features/journal/v02/journal_grid.dart
LOG_SHEET=lib/features/journal/v02/log_sheet.dart
ACTIONS_TEST=test/features/actions_v02_test.dart
CARDS_TEST=test/features/actions_cards_test.dart
COACH_TEST=test/features/coach_sheet_test.dart
COMPOSER_TEST=test/features/coach_composer_test.dart
JOURNAL_TEST=test/journal/journal_screen_test.dart

# A snake_case token on a health screen is a log line where a source belongs.
mutate 'a raw signal id reaches the suggestion card' "$ACTIONS_TEST" "$SUGGESTION" \
  "  return hasMetricName(signal)
      ? 'Raised by your \${metricName(signal)}'
      : 'Raised by a reading this build cannot name yet';" \
  "  return 'Raised by \$signal';"

# Adoption records an INTENTION. Nothing in this app observes the doing.
mutate 'the checkbox starts claiming the action was done' "$ACTIONS_TEST" "$SUGGESTION" \
  "const String kAdoptNote = 'One manageable change to start with.';" \
  "const String kAdoptNote = 'Marks it Done for today.';"

# The family is the rec's own category. A card that picked one would be a hue
# that can disagree with what the card is about.
mutate 'the suggestion card ignores its category' "$ACTIONS_TEST" "$SUGGESTION" \
  '      tone: toneForCategory(rec.category),' \
  '      tone: Tone.fitness,'

# The eyebrow is the only thing that says which of the ranked set this is.
mutate 'every suggestion claims to be the top one' "$ACTIONS_TEST" "$ACTIONS_SCREEN" \
  '            SuggestionCard(recommendation: recommendations[i], first: i == 0),' \
  '            SuggestionCard(recommendation: recommendations[i], first: true),'

# The prototype's order, moved by one.
mutate 'the Actions sections come out of order' "$ACTIONS_TEST" "$ACTIONS_SCREEN" \
  '    const PageSection(SectionHead(title: kWorkingOnHeading), gap: 0),
    const PageSection(WorkingOn(), gap: PageSpacing.block),' \
  '    const PageSection(WorkingOn(), gap: PageSpacing.block),
    const PageSection(SectionHead(title: kWorkingOnHeading), gap: 0),'

# "Nothing observed yet" and "you are at zero" are different days.
mutate 'a challenge with no progress draws a bar at zero' "$CARDS_TEST" "$CHALLENGE_CARD" \
  '  static double? fraction(ChallengeProgress? progress) {
    if (progress == null) {
      return null;
    }' \
  '  static double? fraction(ChallengeProgress? progress) {
    if (progress == null) {
      return 0;
    }'

# A 7-day window over something nobody started reads as a commitment.
mutate 'a suggested challenge is labelled as a running one' "$CARDS_TEST" "$CHALLENGE_CARD" \
  "    return challenge.status == 'active'
        ? '\$window challenge'
        : 'Suggested · \$window';" \
  "    return '\$window challenge';"

# `.check-action .checkbox { width: 24px; height: 24px }`.
mutate 'the adopt checkbox loses its box' "$ACTIONS_TEST" "$CHOICES" \
  '  static const double boxSize = 24;' \
  '  static const double boxSize = 20;'

# Half a comparison drawn as a whole one is the claim the card refuses.
mutate 'an outcome invents the half of the comparison it was not sent' \
  "$CARDS_TEST" "$OUTCOME_CARD" \
  '    if (before == null || during == null) {
      return null;
    }' \
  '    if (during == null) {
      return null;
    }
    final start = before ?? during;'

# The sentence that keeps an outcome an observation.
mutate 'the outcome drops its "not a proven effect" sentence' \
  "$CARDS_TEST" "$OUTCOME_CARD" \
  "const String kObservationNote =
    'These are the readings inside the window, beside the readings before it. '
    'That is an observation, not a proven effect of the challenge.';" \
  "const String kObservationNote =
    'The challenge raised your average over the window.';"

# ── the coach's meter, which is the only spend in the product ───────────────
# An input beside an unknown or empty balance is the silent spend the feature is
# not allowed to have.
mutate 'the coach composer appears with no balance behind it' \
  "$COACH_TEST" "$COACH_SHEET" \
  '    final canAsk = uncapped || (allowance?.hasRemaining ?? false);' \
  '    final canAsk = true;'

# A prompt button asks a question, so it costs one — same gate as the input.
mutate 'the opening prompts stop being gated by the balance' \
  "$COMPOSER_TEST" "$COACH_SHEET" \
  '                  canAsk: canAsk,' \
  '                  canAsk: true,'

# `routers/coach.py` refunds three of five outcomes, so a local subtraction is
# wrong — and wrong the flattering way round. THE METER IS RE-READ.
mutate 'the meter stops being re-read after an attempt' "$COACH_TEST" "$COACH_CTRL" \
  '      if (_isCurrent(generation)) {
        ref.invalidate(coachEntitlementProvider);
        state = state.copyWith(asking: false);
      }' \
  '      if (_isCurrent(generation)) {
        state = state.copyWith(asking: false);
      }'

# The cost is on the button, before the tap, in the number.
mutate 'the cost comes off the ask button' "$COACH_TEST" "$COMPOSER" \
  "    remaining == null ? 'Ask' : 'Ask — uses 1 of your \$remaining';" \
  "    remaining == null ? 'Ask' : 'Ask';"

# A cost label that squeezes the input off the page satisfies "the label is
# present" and makes the surface unusable.
mutate 'the composer stops making room for its input' "$COMPOSER_TEST" "$COMPOSER" \
  '          if (room >= CoachComposer.minFieldWidth) {' \
  '          if (room >= 0) {'

# ── the journal ────────────────────────────────────────────────────────────
# Current fasting state is FETCHED, never inferred.
mutate 'the fast tile guesses instead of reading the state' \
  "$JOURNAL_TEST" "$JOURNAL_GRID" \
  "    final label = tile.kind == null && fastOpen ? 'End fast' : tile.label;" \
  '    final label = tile.label;'

# `grid-template-columns: repeat(3, minmax(0, 1fr))`.
mutate 'the journal grid loses a column' "$JOURNAL_TEST" "$JOURNAL_GRID" \
  '  static const int columns = 3;' \
  '  static const int columns = 2;'

# `screens-actions.js::H.journalKinds`, in its order.
mutate 'the journal kinds are reordered' "$JOURNAL_TEST" "$JOURNAL_GRID" \
  "  JournalKindTile(Icons.water_drop_outlined, 'Water', LogKind.water),
  JournalKindTile(Icons.sentiment_satisfied_outlined, 'Mood', LogKind.mood)," \
  "  JournalKindTile(Icons.sentiment_satisfied_outlined, 'Mood', LogKind.mood),
  JournalKindTile(Icons.water_drop_outlined, 'Water', LogKind.water),"

# An entry nobody acknowledged must not clear the form — the owner types a
# weight once.
mutate 'a failed journal write clears the draft anyway' "$JOURNAL_TEST" "$LOG_SHEET" \
  "      AppLog.failure('journal', 'saving an observation', error, stack);
      if (mounted) {" \
  "      AppLog.failure('journal', 'saving an observation', error, stack);
      _value.clear();
      if (mounted) {"

# The phone and the endpoint agree about what a valid entry is.
mutate 'an invalid amount reaches the wire' "$JOURNAL_TEST" "$LOG_SHEET" \
  '    if (problem != null) {
      setState(() => _message = problem);
      return;
    }' \
  '    if (problem != null) {
      setState(() => _message = problem);
    }'

echo
echo "caught $PASS, survived $FAIL"
[ "$FAIL" -eq 0 ]
