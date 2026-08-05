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

# ── colour: a tag is an identity, never a verdict ───────────────────────────
HUES=lib/core/theme/metric_hues.dart
PALETTE=lib/core/theme/palette.dart
HUES_TEST=test/theme/metric_hues_test.dart

# The failure the whole tag argument exists to prevent: a family wearing a
# colour that already means "worse than your normal". It renders perfectly.
mutate 'a tag is set to a judgement colour' "$HUES_TEST" "$PALETTE" \
  '  static const Color heart = Color(0xFFAB3F84);' \
  '  static const Color heart = LightPalette.unf;'

# Subtler, and the one a reviewer would not catch: a hue nudged to within a few
# degrees of the illness red. At the 6 px a dot occupies it reads as the verdict.
mutate 'a tag drifts to the edge of the alert red' "$HUES_TEST" "$PALETTE" \
  '  static const Color heart = Color(0xFFAB3F84);' \
  '  static const Color heart = Color(0xFFB03A5A);'

# Lightness is the axis the eye reads as rank. One tag brighter than the rest
# says "this metric family matters more", which nobody computed.
mutate 'one tag is lighter than the others' "$HUES_TEST" "$PALETTE" \
  '  static const Color move = Color(0xFF5462CA);' \
  '  static const Color move = Color(0xFF9AA3E4);'

# Two families collapsing onto one colour is the split silently undone.
mutate 'two families share a colour' "$HUES_TEST" "$PALETTE" \
  '  static const Color energy = Color(0xFF8B4EB3);' \
  '  static const Color energy = LightTagPalette.move;'

# The invariant `tagFor` exists for: the movement metrics rejoining the family
# they were split out of, which makes the tag mean "not sleep and not heart".
mutate 'the movement metrics fall back to the default tag' "$HUES_TEST" "$HUES" \
  "    'steps_total' ||
    'steps' ||
    'steps_per_minute' ||" \
  "    'steps_per_minute' ||"

# ── the insight rewrite ─────────────────────────────────────────────────────
FINDINGS=lib/features/coach/widgets/findings_section.dart
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

echo
echo "caught $PASS, survived $FAIL"
[ "$FAIL" -eq 0 ]
