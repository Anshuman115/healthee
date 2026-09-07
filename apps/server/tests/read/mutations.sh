#!/usr/bin/env bash
#
# Break each read-layer honesty guard on purpose, and require a test to notice.
#
# The server had no mutation harness; `apps/mobile/test/mutations.sh` did, and its
# argument applies here word for word: a test that passes against broken code is
# not a test. It applies with more force to this layer, because every guard below
# is a guard against a payload that LOOKS right — a value with no date, an empty
# list where nothing was computed, an alias that greps like an id. None of them
# fail loudly, and several of them shipped for months.
#
# Each mutation is an EXACT-STRING replacement that aborts when it matches
# nothing: a patch that silently matched nothing runs the unmutated suite and
# reports a pass, which reads exactly like a working guard. The file is restored
# whether the mutation was caught or not.
#
# Needs a throwaway TimescaleDB, like the suite itself (CONTRIBUTING.md). Point
# POSTGRES_* at it:
#
#   POSTGRES_HOST=localhost POSTGRES_PORT=5599 POSTGRES_DB=healthee \
#   POSTGRES_USER=healthee POSTGRES_PASSWORD=testpw \
#   REALTIME_INGEST_TOKEN=local-test-token bash tests/read/mutations.sh
#
# Exit 0  every mutation was caught.  Exit 1  at least one survived.

set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

PASS=0
FAIL=0

: "${POSTGRES_HOST:?set POSTGRES_* for a throwaway database — see the header}"

# ⛔ NOT optional, and it cost a confusing hour to find out why.
#
# Restoring the source is not enough: CPython caches the compiled module beside
# it and decides whether the cache is stale from the source's mtime and size.
# `cp` + `mv` restores the file with the mtime it had when the copy was taken,
# which can land in the same second as the mutation's write — so the .pyc from
# the MUTATED source is accepted as current, and every later run in that
# checkout imports bytecode that matches no source anyone can read. The symptom
# is a test failing against a file that is provably correct, with `git status`
# clean and `inspect.getsource` showing the right code; only `dis` disagrees.
#
# That is the "fictional mutation" failure inverted, and worse: a fictional
# mutation reports a pass it did not earn, while this one poisons the checkout
# for everything that runs afterwards. Writing no bytecode at all is the cheap,
# total fix.
export PYTHONDONTWRITEBYTECODE=1

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

# mutate <name> <test-target> <file> <old> <new>
mutate() {
  local name="$1" target="$2" file="$3" old="$4" new="$5"
  echo "── $name"
  cp "$file" "$file.orig"
  if ! patch "$file" "$old" "$new"; then
    mv "$file.orig" "$file"
    echo "  ✗ PATCH FAILED — the mutation is stale, not the code"
    FAIL=$((FAIL + 1))
    return
  fi
  # shellcheck disable=SC2086
  if uv run pytest -q --no-cov $target >/dev/null 2>&1; then
    echo "  ✗ SURVIVED — $target passes against broken code"
    FAIL=$((FAIL + 1))
  else
    echo "  ✓ caught by $target"
    PASS=$((PASS + 1))
  fi
  mv "$file.orig" "$file"
  # Belt and braces beside PYTHONDONTWRITEBYTECODE: a cache written by some
  # earlier run in this checkout would be accepted for the restored file just as
  # readily. Cheap, and the alternative is a poisoned checkout.
  find src -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null
}

READ_HONESTY=tests/read/test_wire_honesty.py
READ_THIN=tests/read/test_wire_thinness.py
WORKOUT_TEST=tests/read/test_workout_absence.py

# ── A1 ───────────────────────────────────────────────────────────────────────
# The nap ships the raw hypnogram under the totals' key again — the defect
# itself, and it looks like a field that is merely populated.
mutate 'a nap ships the hypnogram where the totals belong' \
  "$READ_HONESTY" src/healthee/read/sleep_page.py \
  '            "stages": stage_totals(light, deep, rem, wake),
            "stage_timeline": stage_timeline(stages, start_ts),' \
  '            "stages": stages or [],
            "stage_timeline": [],'

# ── A2 ───────────────────────────────────────────────────────────────────────
# The date is dropped again. THE point of this one: the value still ships, the
# card still renders, and only the date is gone — which is what the defect was.
mutate 'the RHR card drops the date of the row it is serving' \
  "$READ_HONESTY" src/healthee/read/today_series.py \
  '        "as_of_date": row_day.isoformat(),' \
  '        "as_of_date": as_of.isoformat(),'

# The gate is defeated while the date stays. This is the failure the paired
# contract exists for: a date in a field the UI may not render does not undo a
# confident current-looking number.
mutate 'a stale value is served under an honest date' \
  "$READ_HONESTY" src/healthee/read/today_series.py \
  '    reason = unavailable_reason(as_of, row_day)' \
  '    reason = None'

# The Activity tab answers the same row differently from the Today card.
mutate 'the activity tab keeps serving what the today card refuses' \
  "$READ_HONESTY" src/healthee/read/fitness.py \
  '            reason = unavailable_reason(as_of, row_day)' \
  '            reason = None'

# ── A3 ───────────────────────────────────────────────────────────────────────
# The empty list comes back — the one thing this key may not be, because it
# cannot distinguish "nothing was anomalous" from "nothing looked".
mutate 'anomalies goes back to an empty list' \
  "$READ_HONESTY" src/healthee/read/today.py \
  '        "anomalies": None,' \
  '        "anomalies": [],'

# The list is right and the sentence stops denying the all-clear.
mutate 'the anomalies block stops saying it is not an all-clear' \
  "$READ_HONESTY" src/healthee/read/today.py \
  '    "The Today page does not scan for notable shifts, so this is not an all-clear — "' \
  '    "Notable shifts. "'

# ── A4 ───────────────────────────────────────────────────────────────────────
# One alias back on the wire. It resolves to nothing in every consumer of a
# cited id, and looks perfectly healthy in a grep.
mutate 'one surface goes back to citing an alias' \
  "$READ_HONESTY" src/healthee/read/fitness.py \
  '        "research_notes": ["training_stress_score"],' \
  '        "research_notes": ["cardio_load_trimp"],'

# ── B1 ───────────────────────────────────────────────────────────────────────
# The points are recorded for every candidate rather than the significant ones,
# and the as-of bound is dropped at read time.
mutate 'a finding plots days after the one it answers for' \
  "$READ_THIN" src/healthee/read/findings.py \
  '    kept = [p for p in stored if as_of is None or p.get("date", "") <= as_of.isoformat()]' \
  '    kept = list(stored)'

# The truncation flag is dropped: a partial scatter passes for the whole set.
mutate 'a partial scatter stops saying it is partial' \
  "$READ_THIN" src/healthee/read/findings.py \
  '    truncated = bool((details or {}).get("points_truncated")) or len(kept) < len(stored)' \
  '    truncated = False'

# ── B2 ───────────────────────────────────────────────────────────────────────
# Every point reports the headline's instrument, so a mixed window reads as one.
mutate 'every trend point is labelled with the newest instrument' \
  "$READ_THIN" src/healthee/read/vo2max.py \
  '            "method": resolve((f or {}).get("method")),' \
  '            "method": resolve(flags.get("method")),'

# ── B3 ───────────────────────────────────────────────────────────────────────
# The two surfaces stop agreeing: the week becomes the whole 8-day window.
mutate 'the vo2max week is not the week the activity tab reports' \
  "$READ_THIN" src/healthee/read/mvpa_week.py \
  '        if d >= monday:' \
  '        if True:'

# A week with nothing to sum reads as a measured week of stillness.
mutate 'no mvpa rows becomes a measured zero' \
  "$READ_THIN" src/healthee/read/vo2max.py \
  '    return week.mvpa_min if week else None' \
  '    return week.mvpa_min if week else 0'

# ── B4 ───────────────────────────────────────────────────────────────────────
# The sleep signal ships the UNFLOORED spread, which no longer reproduces its z.
mutate 'a signal ships a sigma that does not reproduce its own z' \
  "$READ_THIN" src/healthee/read/recovery.py \
  '        "baseline": b.median,
        "baseline_sd": b.robust_sd,' \
  '        "baseline": b.median,
        "baseline_sd": b.mad,'

# ── B6 ───────────────────────────────────────────────────────────────────────
# The envelope explains a figure that IS present, so the screen would refuse a
# number it was also being handed.
mutate 'the envelope explains away a figure the payload contains' \
  "$WORKOUT_TEST" src/healthee/read/workout_absence.py \
  '        if name in produced:
            continue' \
  '        if False:
            continue'

# The TRIMP gate reports its inputs in the wrong order, so a session missing a
# resting HR is told its samples are missing.
mutate 'the trimp gate names an input that was not the missing one' \
  "$WORKOUT_TEST" src/healthee/read/workout_absence.py \
  '    if not i.rhr:
        return NO_RESTING_HR' \
  '    if not i.rhr:
        return NO_HR_SAMPLES'

# An all-zero zone list with no HRmax reads as a measured easy session.
mutate 'zeroed zones with no hrmax read as an easy session' \
  "$WORKOUT_TEST" src/healthee/read/workout.py \
  '    return {"zones"} if hrmax and hrs else set()' \
  '    return {"zones"}'

echo
echo "caught $PASS, survived $FAIL"
[ "$FAIL" -eq 0 ]
