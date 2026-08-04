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
  if flutter test "$target" >/dev/null 2>&1; then
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

echo
echo "caught $PASS, survived $FAIL"
[ "$FAIL" -eq 0 ]
