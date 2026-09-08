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
SEVERITY_A=tests/read/test_honesty_severity_a.py
SEVERITY_A_SLEEP=tests/read/test_honesty_severity_a_sleep.py
FORMULAS=tests/read/test_formulas.py
B_AND_C=tests/read/test_honesty_b_c.py
UNWORN=tests/derive/test_unworn_day.py
SLEEP_NEED=tests/derive/test_sleep_need_inputs.py
CALORIES=tests/derive/test_calorie_weight_staleness.py
OUT_OF_RANGE=tests/derive/test_vo2max_out_of_range.py

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
  "$READ_THIN" src/healthee/read/recovery_signals.py \
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

# ── the basemap proxy ────────────────────────────────────────────────────────
# Not a read-layer guard, and it lives here because this is the server's only
# mutation harness. The argument is the header's own: this guard is invisible
# when it breaks. A forwarded out-of-range tile draws the same plain ground in
# the app as a refused one — the difference shows up on somebody else's quota
# and, eventually, on their ban list.
mutate 'the tile route forwards an out-of-range zoom' \
  tests/test_map_tiles.py src/healthee/api/routers/map_tiles.py \
  '    if not tile_in_range(z, x, y):' \
  '    if False:'

# ── BACKEND_AUDIT.md section A ───────────────────────────────────────────────
#
# One mutation per finding, each putting the SHIPPED defect back rather than a
# plausible-looking near miss. These are the thirteen that reached the owner's
# screen past a green suite, so a mutation that goes red for any reason other
# than the behaviour would be exactly the "fictional mutation" the header warns
# about — every one below was checked to fail on an assertion, not an import.

# ── A1 ───────────────────────────────────────────────────────────────────────
# The unsourced 5.6 comes back as a default. Note the shape: the payload still
# carries a number and still looks complete — that is why it survived.
mutate 'a row with no recorded error gets the deleted 5.6 back' \
  "$SEVERITY_A" src/healthee/read/vo2max.py \
  '        "see_ml_kg_min": float(see) if see is not None else None,' \
  '        "see_ml_kg_min": float(see) if see is not None else 5.6,'

# ── A2 ───────────────────────────────────────────────────────────────────────
# An unrecorded sex is assumed male again. The tell is not the shipped letter,
# it is that `median_for_age` is then SPENT against the wrong distribution.
mutate 'an unrecorded sex is assumed male and spent on the median' \
  "$SEVERITY_A" src/healthee/read/vo2max.py \
  '    sex = flags.get("sex") if flags.get("sex") in ("male", "female") else None' \
  '    sex = flags.get("sex") if flags.get("sex") in ("male", "female") else "male"'

# ── A3 ───────────────────────────────────────────────────────────────────────
# Filed back under a key the app's honesty envelope does not read. The server
# still computes the flag perfectly; it just lands where nothing looks.
mutate 'the out-of-range flags go back to a key the envelope cannot see' \
  "$OUT_OF_RANGE" src/healthee/read/vo2max.py \
  '        "caveats": out_of_range_inputs(age or None, flags.get("bmi")),' \
  '        "out_of_range_inputs": out_of_range_inputs(age or None, flags.get("bmi")),'

# The reason id is dropped. The block still ships and still reads correctly to a
# human — and `envelope.dart` silently drops any disclosure missing `reason`.
mutate 'an out-of-range caveat loses the reason the envelope requires' \
  "$OUT_OF_RANGE" src/healthee/derive/vo2max.py \
  '        "reason": f"vo2max_{name}_out_of_validated_range",' \
  '        "input_name": f"vo2max_{name}_out_of_validated_range",'

# ── A5 ───────────────────────────────────────────────────────────────────────
# A night with no breakdown is answered with four zeros again — the value that
# painted a zero-height stacked bar, indistinguishable from no sleep at all.
mutate 'an unstaged night is answered with four zeroed stages' \
  "$SEVERITY_A_SLEEP" src/healthee/read/sleep_common.py \
  '    if light is None and deep is None and rem is None and wake is None:
        return None' \
  '    if False:
        return None'

# TST is summed across absent stages, so an unstaged night reports 0 minutes of
# sleep — the number the client then substituted for a correct withhold.
mutate 'an unstaged night reports zero minutes of sleep' \
  "$SEVERITY_A_SLEEP" src/healthee/read/sleep_common.py \
  '    if light is None and deep is None and rem is None:
        return None' \
  '    if False:
        return None'

# ── A6 ───────────────────────────────────────────────────────────────────────
# The clobbering upsert returns: a partial re-push overwrites a measured night.
mutate 'a partial re-push clobbers the stage breakdown on file' \
  "$SEVERITY_A_SLEEP" src/healthee/ingest/upsert.py \
  '            "rem_min = COALESCE(EXCLUDED.rem_min, sleep_session.rem_min), "' \
  '            "rem_min = EXCLUDED.rem_min, "'

# ── A7 ───────────────────────────────────────────────────────────────────────
# The floor goes away, so a two-row window publishes one day as a "30-day
# baseline" and the app draws today's load as a multiple of it.
mutate 'the 30-day load baseline loses its minimum' \
  "$SEVERITY_A" src/healthee/read/fitness.py \
  '    baseline = round(sum(prior) / len(prior), 1) if len(prior) >= _BASELINE_MIN_DAYS else None' \
  '    baseline = round(sum(prior) / len(prior), 1) if prior else None'

# The window goes back to 36 days behind two keys that say thirty.
mutate 'the 30-day window is 36 days again' \
  "$SEVERITY_A" src/healthee/read/fitness.py \
  '_LOAD_WINDOW_DAYS = 30' \
  '_LOAD_WINDOW_DAYS = 36'

# ── A8 ───────────────────────────────────────────────────────────────────────
# Two mornings publish an autonomic verdict again. MAD over two points is the
# half-distance, so the z is finite and everything downstream looks healthy.
mutate 'two days of resting heart rate publish a direction' \
  "$SEVERITY_A" src/healthee/read/recovery_signals.py \
  '    if b.median is None or b.n < _SIGNAL_MIN_DAYS:
        return Unplaced(name, SHORT_HISTORY)
    if not b.robust_sd:
        return Unplaced(name, FLAT_HISTORY)
    z = (value - b.median) / b.robust_sd
    direction = (
        "favorable"
        if z < -_AUTONOMIC_FAVORABLE_Z' \
  '    if b.median is None:
        return Unplaced(name, SHORT_HISTORY)
    if not b.robust_sd:
        return Unplaced(name, FLAT_HISTORY)
    z = (value - b.median) / b.robust_sd
    direction = (
        "favorable"
        if z < -_AUTONOMIC_FAVORABLE_Z'

# ── A9 ───────────────────────────────────────────────────────────────────────
# The reference day is dropped, so the session borrows TODAY's resting heart
# rate — an answer for a past day containing something measured after it.
mutate 'a past workout is scored against today reserve' \
  "$SEVERITY_A" src/healthee/read/workout.py \
  '    load = cardio_load_payload(cur, user_id, tz, session_day) or {}' \
  '    load = cardio_load_payload(cur, user_id, tz) or {}'

# ── A10 ──────────────────────────────────────────────────────────────────────
# The HR profile goes back to one element per raw sample, so TRIMP and every
# "zone minute" are multiplied by the strap's in-workout sample rate.
#
# The bucket is widened to a SECOND rather than removed. Deleting the aggregate
# leaves invalid SQL, and a mutation that dies on a GroupingError proves the
# query is malformed, not that anything checks the unit — the header's
# "fictional mutation", and this one was written that way first.
mutate 'the session hr profile counts samples and calls them minutes' \
  "$SEVERITY_A" src/healthee/read/workout.py \
  '        "SELECT date_trunc('"'"'minute'"'"', ts) AS m, AVG(value) FROM sample "' \
  '        "SELECT date_trunc('"'"'second'"'"', ts) AS m, AVG(value) FROM sample "'

# ── A11 ──────────────────────────────────────────────────────────────────────
# The closing edge goes away and a future-dated row reaches every dated panel.
mutate 'the history series loses its closing edge' \
  "$SEVERITY_A" src/healthee/read/history.py \
  '        f"AND day > ({USER_TODAY_SQL} - %s::int) AND day <= ({USER_TODAY_SQL}) "
        "ORDER BY metric, day",
        (user_id, metrics, tz, days, tz),' \
  '        f"AND day > ({USER_TODAY_SQL} - %s::int) "
        "ORDER BY metric, day",
        (user_id, metrics, tz, days),'

# ── A12 ──────────────────────────────────────────────────────────────────────
# Three nights publish a regularity verdict again, beside an SRI the same
# payload has just refused for having fewer than seven.
mutate 'three nights publish a bedtime-band verdict' \
  "$SEVERITY_A_SLEEP" src/healthee/read/sleep_extras.py \
  '    banded = len(rows) >= REGULARITY_MIN_NIGHTS' \
  '    banded = True'

# The population claim comes back. It is a statement about where this owner sits
# in a distribution nothing here reads, with no note and no n.
mutate 'the band verdict claims a population quintile again' \
  "$SEVERITY_A_SLEEP" src/healthee/read/sleep_extras.py \
  '        return "tight — inside the ~1 h band, near enough"' \
  '        return "tight — top-quintile territory (~1 h band)"'

# ── A13 ──────────────────────────────────────────────────────────────────────
# The intensity flags are coalesced to zero again, so a day nobody split reads
# as a day of no moderate and no vigorous minutes.
mutate 'a missing intensity breakdown becomes zero measured minutes' \
  "$SEVERITY_A" src/healthee/read/mvpa_week.py \
  '        "SELECT day, (flags->>'"'"'moderate'"'"')::float, "
        "(flags->>'"'"'vigorous'"'"')::float, value FROM derived_daily "' \
  '        "SELECT day, COALESCE((flags->>'"'"'moderate'"'"')::float,0), "
        "COALESCE((flags->>'"'"'vigorous'"'"')::float,0), value FROM derived_daily "'

# A workout the strap logged with no calorie figure goes back to contributing
# nothing, silently, after its minutes were removed from the MET walk.
mutate 'an uncounted workout stops being disclosed' \
  "$CALORIES" src/healthee/derive/energy.py \
  '    if sessions_n <= 0:
        return []' \
  '    if True:
        return []'

# ── the ACWR verdict ─────────────────────────────────────────────────────────
# The suppression [[training_load_acwr]] D6 requires — and which the note already
# claimed this product had — is lowered back to seven rows. With exactly seven,
# acute and chronic are the SAME values, so the ratio is 1.0 by construction.
mutate 'acwr publishes from seven rows of chronic history' \
  "$FORMULAS" src/healthee/read/acwr.py \
  '_ACWR_MIN_CHRONIC_DAYS = 28' \
  '_ACWR_MIN_CHRONIC_DAYS = 7'

# The discredited numeric verdict comes back on the wire.
mutate 'acwr ships a categorical verdict again' \
  "$FORMULAS" src/healthee/read/acwr.py \
  '        "n_acute": len(acute_vals),' \
  '        "state": "optimal" if 0.8 <= acute / chronic <= 1.3 else "caution",
        "n_acute": len(acute_vals),'

# ── B2 ───────────────────────────────────────────────────────────────────────
# The considered null comes back as a constant, under the same key name. `41`
# cites nothing, and one response then says null in one block and 41.0 in
# another.
mutate 'the plan invents an age median again' \
  "$B_AND_C" src/healthee/read/fitness_plan.py \
  '    median_ref = None if raw_median is None else float(raw_median)' \
  '    median_ref = float(raw_median or 41)'

# ── B3 ───────────────────────────────────────────────────────────────────────
# D5's conditional is dropped, so the projection ships bare again — a specific
# gain, promised, from a note whose Established directive forbids exactly that.
mutate 'the projection stops saying it is not a promise' \
  "$B_AND_C" src/healthee/read/fitness_plan.py \
  '        "caveats": [] if gain is None else [_PROJECTION_CAVEAT],' \
  '        "caveats": [],'

# The bound stops travelling with the number, so a reader cannot tell a bounded
# typical response from a forecast.
mutate 'the projection stops shipping the bound it was produced inside' \
  "$B_AND_C" src/healthee/read/fitness_plan.py \
  '        "gain_floor": _GAIN_FLOOR_ML_KG_MIN,' \
  '        "gain_floor": None,'

# ── B4 ───────────────────────────────────────────────────────────────────────
# The population stride comes back into the SQL, under a key that has no
# personal denominator behind it and can therefore never refuse.
mutate 'a step bucket reports a population-stride distance again' \
  "$B_AND_C" src/healthee/read/today_series.py \
  '            "steps": steps,
        }
        for local_t, steps, bucket in cur.fetchall()' \
  '            "steps": steps,
            "distance_m": int(steps * 0.78),
        }
        for local_t, steps, bucket in cur.fetchall()'

# ── C2 ───────────────────────────────────────────────────────────────────────
# A nap goes back to reporting its wall-clock span under the key a NIGHT uses
# for total sleep time — one name, two quantities, one payload.
mutate 'a nap ships time in bed under the night is total-sleep-time name' \
  "$B_AND_C" src/healthee/read/sleep_page.py \
  '            "tib_min": int(dur),' \
  '            "duration_min": int(dur),
            "tib_min": int(dur),'

# ── C3 ───────────────────────────────────────────────────────────────────────
# /api/sleep stops carrying the need and the debt, so the Sleep tab is back to
# having nothing to measure against but a constant of its own.
mutate 'the sleep page stops sending the need it has' \
  "$B_AND_C" src/healthee/read/sleep_page.py \
  '        "sleep_debt": sleep_debt_payload(cur, user_id, tz, None, as_of),' \
  '        "sleep_debt": None,'

# ── C4 ───────────────────────────────────────────────────────────────────────
# The flat 480 comes back as the recovery composite's fallback need, and is
# published in flags.factors.sleep.need_min as this owner is own.
mutate 'the recovery sleep factor invents a need again' \
  "$SLEEP_NEED" src/healthee/derive/recovery.py \
  '    if not (nr and nr[0]):
        return
    need = float(nr[0])' \
  '    need = float(nr[0]) if nr and nr[0] else 480.0'

# ── C5 ───────────────────────────────────────────────────────────────────────
# The instrument stops reaching the wire: the derive layer still decides which
# of two counted the day, and the read layer discards the answer again (#121).
mutate 'the step card stops naming its instrument' \
  "$B_AND_C" src/healthee/read/common.py \
  '    return {key: flags[key] for key in _PROVENANCE_FLAGS if key in flags}' \
  '    return {}'

# The partial-day disclosure goes back to being a comment nobody emitted.
mutate 'a counter read mid-day stops saying so' \
  "$B_AND_C" src/healthee/derive/device_totals.py \
  '    if device is None or device.steps is None:
        return []' \
  '    if True:
        return []'

# ── C6 ───────────────────────────────────────────────────────────────────────
# The calorie card loses its note id again, so the note is own +-15-20% estimate
# label has nowhere to render.
mutate 'the calorie card stops citing its note' \
  "$B_AND_C" src/healthee/read/meta.py \
  '    "total_calories": "energy_expenditure_derivation",' \
  '    "total_calories_UNCITED": "energy_expenditure_derivation",'

# ── C7 ───────────────────────────────────────────────────────────────────────
# The unconditional upsert comes back, so a day no instrument counted is stored
# and baselined as a measured zero.
mutate 'an unworn day is written as zero steps again' \
  "$UNWORN" src/healthee/derive/activity.py \
  '    counted = (device is not None and device.steps is not None) or per_minute_n > 0' \
  '    counted = True'

# ── C8 ───────────────────────────────────────────────────────────────────────
# Sleep need goes back to being gated on a logged weight it never reads.
mutate 'sleep need is blocked by a weight again' \
  "$SLEEP_NEED" src/healthee/derive/sleep_score.py \
  '    dob = _date_of_birth(cur, user_id)
    if dob is None:
        return None' \
  '    prof = _load_profile(cur, user_id, "UTC", day)
    dob = None if not prof else prof["dob"]
    if dob is None:
        return None'

# ── D-c ──────────────────────────────────────────────────────────────────────
# The sleep signal stops saying which of its two limbs produced its verdict, so
# a population threshold reads as a personal one again.
mutate 'the sleep signal stops naming the limb that decided it' \
  "$B_AND_C" src/healthee/read/recovery_signals.py \
  '        "direction_basis": _direction_basis(direction, population, personal),' \
  '        "direction_basis": None,'

# ── D-d ──────────────────────────────────────────────────────────────────────
# The pace stops naming its denominator, so a paused session reads as a slower
# one with nothing on the wire to say why.
mutate 'the workout pace stops naming its denominator' \
  "$B_AND_C" src/healthee/read/workout.py \
  '        m["pace_basis"] = "elapsed"' \
  '        m["pace_basis"] = "moving"'

# ── the LLM audit ────────────────────────────────────────────────────────────
#
# Every guard below protects a SENTENCE rather than a number, which is why they
# belong in this harness with more force than the read layer's: none of them
# fails loudly, and a defect here is an unfounded claim in prose.

LLM_GATES=tests/insights/test_grounded_surface_gates.py
LLM_THREAD=tests/insights/test_thread_and_topic.py
LLM_OWNER_TEXT=tests/insights/test_owner_text_in_prompts.py
LLM_RECS_DAY=tests/read/test_as_of_day_recommendations.py

# ── LLM A2 ───────────────────────────────────────────────────────────────────────
# `grounded_ask` stops computing `without_data`, so `personal_claims.issues`
# returns on its first line again and the gate is inert on every surface but the
# coach. THE defect: the daily action, the briefing, every insight card and recs
# go back to having nothing check a claim about the owner's own data.
mutate 'the personal-claims gate goes back to being coach-only' \
  "$LLM_GATES" src/healthee/insights/grounded.py \
  '        candidate.without_data = personal_claims.subjects_without_data(
            user_id, tz, (), response.text or ""
        )' \
  '        candidate.without_data = frozenset()'

# The gate is computed but not carried, which is the same hole one line later and
# looks even more like working code.
mutate 'the computed subjects never reach the gate' \
  "$LLM_GATES" src/healthee/insights/grounded.py \
  '            context=lambda: pipeline.AnswerContext(
                json_mode=json_mode, without_data=candidate.without_data
            ),' \
  '            context=lambda: pipeline.AnswerContext(json_mode=json_mode),'

# ── LLM A4 ───────────────────────────────────────────────────────────────────────
# The owner's journal goes back into the prompt with nothing marking it as data.
mutate 'the manual-entry block loses its data fence' \
  "$LLM_OWNER_TEXT" src/healthee/insights/context_sessions.py \
  '    lines = [f"## Manual entries (last {days} days, {tz})", _DATA_FENCE]' \
  '    lines = [f"## Manual entries (last {days} days, {tz})"]'

# The owner's newline ends the bullet again and lifts the rest of their sentence
# to the top level of the prompt — the fence with a hole cut in it.
mutate 'owner text can break out of its own line again' \
  "$LLM_OWNER_TEXT" src/healthee/insights/context_sessions.py \
  '    return " ".join(value.split())' \
  '    return value'

# The character cap goes back to being a row cap, i.e. no bound at all.
mutate 'the entry block is bounded by rows rather than characters' \
  "$LLM_OWNER_TEXT" src/healthee/insights/context_sessions.py \
  '        if used + len(line) > _MAX_ENTRY_CHARS and lines:' \
  '        if False:'

# `notes` loses its boundary bound, so 200 rows is the prompt budget again.
mutate 'the journal note is unbounded at the API boundary' \
  "$LLM_OWNER_TEXT" src/healthee/read/logs.py \
  '    notes: str | None = Field(default=None, max_length=_NOTES_MAX)' \
  '    notes: str | None = None'

# ── LLM A5 ───────────────────────────────────────────────────────────────────────
# The refusal gate reads the last message again while the whole thread is sent,
# so a refused emergency re-enters the model's context on the next turn.
mutate 'the refusal gate screens only the last message again' \
  "$LLM_THREAD" src/healthee/insights/coach_thread.py \
  '    for message in history:
        if message["role"] != "user":
            continue
        hit = pipeline.check_question(message["content"])
        if hit is not None:
            return hit
    return pipeline.check_question(topic) if topic else None' \
  '    hit = pipeline.check_question(last_user(history))
    return hit if hit is not None else None'

# Only the topic stops being screened — the half a "screen what is sent" fix is
# most likely to forget.
mutate 'the topic skips the refusal gate' \
  "$LLM_THREAD" src/healthee/insights/coach_thread.py \
  '    return pipeline.check_question(topic) if topic else None' \
  '    return None'

# ── LLM B1 ───────────────────────────────────────────────────────────────────────
# The greeting claims to be an answered turn again, so the router's fourth refund
# branch never fires and a question with no question in it charges one of twenty.
mutate 'a canned greeting counts as an answer delivered' \
  "$LLM_THREAD" src/healthee/insights/coach.py \
  '        return CoachResult(reply=_GREETING, answered=False)' \
  '        return CoachResult(reply=_GREETING)'

# ── LLM B2 ───────────────────────────────────────────────────────────────────────
# A past `day` is honoured again: today's judgement, from today's data, filed
# under an older date and then served as that day's answer.
mutate 'recs are dated a day their own inputs never answered for' \
  tests/jobs/test_recs_day.py src/healthee/jobs/recs.py \
  '    today = user_today(tz)
    if day is not None and day != today:' \
  '    today = user_today(tz)
    if False:'

# ── LLM B3 ───────────────────────────────────────────────────────────────────────
# The metric label comes from the caller again — unvalidated text in the task
# sentence, and absent from the cache key.
mutate 'the metric prompt takes its label from the caller again' \
  "$LLM_GATES" src/healthee/insights/surfaces.py \
  '        f"In 1–2 short sentences, interpret my {metric_label(metric)} for me right now. "' \
  '        f"In 1–2 short sentences, interpret my {metric} for me right now. "'

# ── LLM C3 ───────────────────────────────────────────────────────────────────────
# The workout review is read through the per-DAY cache again, so a fixed past
# session is re-reviewed daily against a different week each time.
mutate 'a fixed past workout is re-reviewed every day' \
  "$LLM_GATES" src/healthee/insights/surfaces.py \
  '        stored = get_stored(user_id, key)
        if stored is not None:
            return stored' \
  '        stored = get_cached(user_id, tz, key)
        if stored is not None:
            return stored'

# The prompt stops saying what its window covers, so it is named for a period it
# does not cover — the class the last audit raised twice.
mutate 'the workout prompt stops naming its real window' \
  "$LLM_GATES" src/healthee/insights/surfaces.py \
  '        "The WORKOUT below is the session under review, with its own numbers. The "
        "CONTEXT block is my LAST 7 DAYS UP TO TODAY, which may be long after this "
        "session — do not describe it as the week around this workout, and do not read "
        "a trend in it as something this session caused or was caused by."' \
  '        ""'

# ── LLM C5 ───────────────────────────────────────────────────────────────────────
# The validator's grade lookup fails OPEN again: an unrecognised grade ranks
# Established, the least strict wording rule, inside the strictest module.
mutate 'an unknown grade ranks Established in the validator again' \
  "$LLM_GATES" src/healthee/insights/validator.py \
  '    ranks = [manifest.GRADE_RANK.get(g or "", 0) for g in grades if g]' \
  '    ranks = [manifest.GRADE_RANK.get(g or "", 3) for g in grades if g]'

mutate 'an unknown grade is ranked as the FIRMEST thing in the answer' \
  "$LLM_GATES" src/healthee/insights/validator.py \
  '        (manifest.GRADE_RANK.get(manifest.grade_of(i) or "", 0), manifest.grade_of(i))' \
  '        (manifest.GRADE_RANK.get(manifest.grade_of(i) or "", 3), manifest.grade_of(i))'

# ── LLM A3, the server half ──────────────────────────────────────────────────────
# The rec row stops carrying its own date, so a two-day-old action reaches the
# app with nothing able to say which day it was written for.
mutate 'a recommendation ships without the day it was written for' \
  "$LLM_RECS_DAY" src/healthee/read/recommendations.py \
  '            (row[0], row[1].isoformat(), *row[2:8], list(row[8] or []), row[9], row[10]),' \
  '            (row[0], None, *row[2:8], list(row[8] or []), row[9], row[10]),'

# The two-day reach becomes unbounded, so a set of any age is served as the day's.
mutate 'the recommendation reach becomes unbounded' \
  "$LLM_RECS_DAY" src/healthee/read/today.py \
  '        (user_id, as_of - timedelta(days=2), as_of),' \
  '        (user_id, as_of - timedelta(days=3650), as_of),'

# ── the coach topic ──────────────────────────────────────────────────────────
# The topic stops reaching retrieval, so the field is accepted and does nothing —
# the gap it was added to close, wearing a fix's clothes.
mutate 'the topic never reaches retrieval' \
  "$LLM_THREAD" src/healthee/insights/coach_thread.py \
  '    return f"{subject}\n{question}" if subject else question' \
  '    return question'

# The topic arrives as a bare subject with nothing saying it is not a finding —
# context becoming a claim the model is invited to justify.
mutate 'the topic arrives unfenced, as if it were evidence' \
  "$LLM_THREAD" src/healthee/insights/coach_thread.py \
  '    return f'"'"'\n\n# WHAT THIS CONVERSATION IS ABOUT\n\n{_TOPIC_FENCE}\n\n  "{subject}"'"'"'' \
  '    return f'"'"'\n\n# WHAT THIS CONVERSATION IS ABOUT\n\n  "{subject}"'"'"''

# ══ the auth, tenancy and ingest hardening (AUTH_AUDIT.md) ═══════════════════
#
# Every mutation below restores exactly the defect the audit found, in the file
# it found it in. Each is one sentence about one thing that must not come back.

AUTH_CONFIG=tests/test_config_isolation_guards.py
AUTH_SUSPEND=tests/integration/test_suspension.py
AUTH_CALLERS=tests/db/test_admin_connection_callers.py
AUTH_SCOPING=tests/db/test_tenant_read_scoping.py
INGEST_BOUNDS=tests/test_ingest_bounds.py
LOG_BOUNDS=tests/read/test_log_bounds.py
REFRESH_BUDGET=tests/premium/test_refresh_budget.py
COACH_BOUNDS=tests/test_coach_request_bounds.py
AI_GATE=tests/premium/test_ai_gate.py
CONTRACT_MODELS=tests/contracts/test_challenge_response_models.py

# ── B1 ───────────────────────────────────────────────────────────────────────
# The boot refusal becomes a warning again: blank POSTGRES_APP_* is accepted and
# the pool connects as the admin, which bypasses every RLS policy 0008 creates.
# This is the finding exactly — it is what "announced with only a log line" was.
mutate 'a blank app role boots again, with RLS isolating nothing' \
  "$AUTH_CONFIG" src/healthee/core/config_guards.py \
  '    if app_role_configured or allow_fallback:
        return' \
  '    if app_role_configured or allow_fallback or True:
        return'

# The opt-out defaults to ON, so the refusal exists and never fires — a guard
# that is present, passes review, and protects nothing.
mutate 'the transitional opt-out becomes the default' \
  "$AUTH_CONFIG" src/healthee/core/config.py \
  '    allow_admin_db_fallback: bool = False' \
  '    allow_admin_db_fallback: bool = True'

# ── C3 ───────────────────────────────────────────────────────────────────────
# One never-expiring shared secret that authenticates as a real tenant is allowed
# to coexist with open signups again — the one combination the design says must
# never happen, back to being prevented by a paragraph.
mutate 'the shared token may live beside open signups again' \
  "$AUTH_CONFIG" src/healthee/core/config_guards.py \
  '    if signups_open and token:' \
  '    if signups_open and token and False:'

# ── B2 ───────────────────────────────────────────────────────────────────────
# Suspension goes back to being a no-op on every request path: the column is read
# and the answer is discarded, which is the shape the finding describes.
mutate 'a suspended owner keeps full access' \
  "$AUTH_SUSPEND" src/healthee/core/supabase_auth.py \
  '    if status_value == ACTIVE_STATUS:
        return' \
  '    if status_value == ACTIVE_STATUS or True:
        return'

# The API path forgets to ask, so the JWT branch alone is unguarded — the half of
# the finding a single-path test would miss.
mutate 'the api path stops consulting status' \
  "$AUTH_SUSPEND" src/healthee/core/request_auth.py \
  '    refuse_unless_active(user_id, row[1])
    return row[0]' \
  '    return row[0]'

# Any non-active word is interpreted as fine, so only the literal 'suspended'
# refuses — a guard that a future 'deleted' walks straight past.
mutate 'the status check becomes a denylist of one' \
  "$AUTH_SUSPEND" src/healthee/core/supabase_auth.py \
  '    if status_value == ACTIVE_STATUS:' \
  '    if status_value != "suspended":'

# ── F3 ───────────────────────────────────────────────────────────────────────
# The legacy branch authenticates an owner who does not exist again — the
# documented post-condition of claim_sentinel, wearing a fallback's clothes.
mutate 'an absent sentinel row is invented rather than refused' \
  "$AUTH_SUSPEND" src/healthee/core/request_auth.py \
  '    if tz is None:
        log.warning("the sentinel app_user row is absent — refusing the legacy shared token")
        raise unauthorized("Invalid token")
    return RequestUser(id=SENTINEL_USER_ID, timezone=tz)' \
  '    if tz is None:
        tz = "Asia/Kolkata"
    return RequestUser(id=SENTINEL_USER_ID, timezone=tz)'

# ── D1 ───────────────────────────────────────────────────────────────────────
# `SampleIn` goes back to exactly what the audit found. The whole declaration, not
# just `allow_inf_nan`: the magnitude range refuses NaN on its own (every comparison
# against NaN is False), so mutating the flag alone SURVIVES — a mutation that proves
# nothing, which is why this one restores the four original lines.
mutate 'SampleIn goes back to accepting NaN, Infinity and 1e308' \
  "$INGEST_BOUNDS" src/healthee/ingest/models.py \
  '    model_config = ConfigDict(extra="ignore", allow_inf_nan=False)

    metric: str = Field(max_length=64)
    ts: int  # epoch milliseconds (seconds also tolerated downstream)
    value: float = Field(ge=-MAX_MAGNITUDE, le=MAX_MAGNITUDE)' \
  '    model_config = ConfigDict(extra="ignore")

    metric: str
    ts: int  # epoch milliseconds (seconds also tolerated downstream)
    value: float'

# A finite but absurd magnitude gets through, which allow_inf_nan alone would let
# past — one such row dominates every mean it enters.
mutate 'a 1e308 reading is accepted' \
  "$INGEST_BOUNDS" src/healthee/ingest/models.py \
  '    value: float = Field(ge=-MAX_MAGNITUDE, le=MAX_MAGNITUDE)' \
  '    value: float'

# ── D2 ───────────────────────────────────────────────────────────────────────
# The range check comes off the one shared conversion, so an out-of-range epoch is
# a 500 again and an in-range one writes a row dated centuries away.
mutate 'the event instant loses its range check' \
  "$INGEST_BOUNDS" src/healthee/core/bounds.py \
  '    if when < EVENT_TS_MIN or when > ceiling:' \
  '    if False:'

# ── D3 ───────────────────────────────────────────────────────────────────────
# The stage LIST loses its cap, so ten thousand one-minute stages is ten thousand
# `generate_series` statements in one request — the half the minutes cap cannot see.
mutate 'the hypnogram may hold unlimited stages' \
  "$INGEST_BOUNDS" src/healthee/ingest/models.py \
  '    stages: list[list[int]] = Field(default_factory=list, max_length=_MAX_STAGES)' \
  '    stages: list[list[int]] = Field(default_factory=list)'

# The per-stage cap survives and the total does not, which is the same attack in
# pieces — and the reason the session cap exists beside the stage cap.
mutate 'a session may materialise unlimited minutes in pieces' \
  "$INGEST_BOUNDS" src/healthee/ingest/models.py \
  '        if emitted > _MAX_SESSION_STAGE_MINUTES:' \
  '        if False:'

# The payload lists lose their caps, so one authenticated request is unbounded
# work again.
mutate 'the push lists become unbounded' \
  "$INGEST_BOUNDS" src/healthee/ingest/models.py \
  '    samples: list[SampleIn] = Field(default_factory=list, max_length=_MAX_SAMPLES)' \
  '    samples: list[SampleIn] = Field(default_factory=list)'

# stages: [[]] is an IndexError inside the arity check again — a 500 for a
# client's payload, and the arity the type annotation cannot express.
mutate 'a malformed hypnogram stage stops being a 422' \
  "$INGEST_BOUNDS" src/healthee/ingest/models.py \
  '            if len(stage) != _STAGE_ARITY:' \
  '            if False:'

# ── D4 ───────────────────────────────────────────────────────────────────────
# A weight that is not a body mass reaches weight_log.kg — the numeric(5,2) column
# that feeds BMI, VO2max and biological age.
mutate 'an impossible weight is stored again' \
  "$LOG_BOUNDS" src/healthee/core/bounds.py \
  '    if not (MIN_WEIGHT_KG <= kg <= MAX_WEIGHT_KG):' \
  '    if False:'

# `or 0` comes back: a weight log with no amount stores 0 kg, dated now, so no
# freshness gate can withhold it.
mutate 'a weight log with no amount becomes zero kilograms' \
  "$LOG_BOUNDS" src/healthee/read/logs.py \
  '        if req.amount is None:
            return {"ok": False, "error": "a weight log needs an amount in kilograms"}
        cur.execute(
            "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, %s) "
            "ON CONFLICT (user_id, ts) DO UPDATE SET kg = EXCLUDED.kg",
            (user_id, ts, assert_plausible_weight_kg(float(req.amount))),
        )' \
  '        cur.execute(
            "INSERT INTO weight_log (user_id, ts, kg) VALUES (%s, %s, %s) "
            "ON CONFLICT (user_id, ts) DO UPDATE SET kg = EXCLUDED.kg",
            (user_id, ts, float(req.amount or 0)),
        )'

# ── E1 ───────────────────────────────────────────────────────────────────────
# The interactive docs come back: a full machine-readable map of a health API,
# served unauthenticated because a framework default was left alone.
mutate 'the openapi schema is published again' \
  "$CONTRACT_MODELS" src/healthee/api/app.py \
  '        openapi_url=None,' \
  '        openapi_url="/openapi.json",'

# ⚠ Two E1 mutations were WRITTEN AND DROPPED, because both survived and a mutation
# that survives is a claim you cannot make:
#
#   * `docs_url="/docs"` alone — FastAPI mounts the Swagger route only when
#     `openapi_url` is also set, so with the schema off the page cannot come back on
#     its own. The mutation above is therefore the whole of E1's first half.
#   * re-adding `test_ai_gate`'s `generated` exclusion — with the routes gone the
#     exclusion is inert. That IS E1's second half: the blind spot was closed by
#     deleting the thing it was blind to, which is the one kind of fix no mutation can
#     be written for.

# ── E4 ───────────────────────────────────────────────────────────────────────
# A forced regeneration stops being metered, so polling ?refresh=true spends the
# OpenRouter budget in a loop.
mutate 'a forced insight refresh is free again' \
  "$REFRESH_BUDGET" src/healthee/api/refresh_budget.py \
  '    if not refresh:
        return False' \
  '    if True:
        return refresh'

# The limiter charges the CACHED read too — the worse bug in the other direction,
# and the one a refusal-only test would never notice.
mutate 'the limiter charges a cached read as well' \
  "$REFRESH_BUDGET" src/healthee/api/refresh_budget.py \
  '    if not refresh:' \
  '    if False:'

# The coach body loses its per-turn bound: the turn count stays bounded and the
# size does not, which is what made the 600M limit the only real ceiling.
mutate 'a coach turn becomes unbounded again' \
  "$COACH_BOUNDS" src/healthee/api/routers/coach.py \
  '    content: str = Field(max_length=_MAX_CONTENT)' \
  '    content: str'

# ── F1 ───────────────────────────────────────────────────────────────────────
# The "complete list" of admin_connection callers loses an entry, which is the
# defect: a list that claims completeness and is not.
mutate 'the admin-connection caller list goes back to being incomplete' \
  "$AUTH_CALLERS" src/healthee/core/db.py \
  '    * `db/grant_premium.py` — writes `subscription`' \
  '    * `db/grant_premium_NOT_LISTED.py` — writes `subscription`'

# ── F2 ───────────────────────────────────────────────────────────────────────
# The scoping guard goes back to a substring test, so `SELECT user_id, value FROM
# sample WHERE metric = %s` — user_id projected, nothing scoped — passes it.
mutate 'the tenant-scoping guard accepts user_id anywhere in the statement' \
  "$AUTH_SCOPING" tests/db/test_tenant_read_scoping.py \
  '_USER_ID_SCOPED = re.compile(
    r"\buser_id\s*(?:::\w+\s*)?(?:=|<>|!=|\sIN\b)|[(,]\s*user_id\s*[,)]",
    re.IGNORECASE,
)' \
  '_USER_ID_SCOPED = re.compile(r"user_id", re.IGNORECASE)'

# ── G · the knowledge audit (2026-09-08) ─────────────────────────────────────
# These mutate the CORPUS, not the source, and that is the point: the corpus is an
# interpretive channel with no calibration gate on its own prose (KNOWLEDGE_AUDIT.md
# section 1.1), so the only thing that can stop a false sentence coming back is a test
# that reads the note. Each one restores the exact sentence the audit found.

CORPUS_ENFORCEMENT=tests/insights/test_corpus_enforcement_claims.py
GUARD_DIRECTIVES=tests/insights/test_guard_directives.py
CORPUS_FIGURES=tests/insights/test_corpus_withdrawn_figures.py

# ── G1 ───────────────────────────────────────────────────────────────────────
# The false safety claim comes back: D14 asserts unqualified enforcement of
# "never advise drinking ahead of thirst", which the compiled rule cannot see.
mutate 'a directive claims a guardrail for a move the rule cannot see' \
  "$CORPUS_ENFORCEMENT" ../../packages/knowledge/sports-science/wellness/environmental-stress.md \
  '  (SAFETY-CRITICAL; **PARTLY enforced in code, and the part that is not is the part' \
  '  (SAFETY-CRITICAL; **enforced in code, fully and unqualified. The part that is not is the part'

# ── G2 ───────────────────────────────────────────────────────────────────────
# The same claim from the fuelling side, which is where it was first written.
mutate 'the fuelling note re-asserts the unqualified hydration guardrail' \
  "$CORPUS_ENFORCEMENT" ../../packages/knowledge/sports-science/wellness/fueling-and-hydration.md \
  '  Established (SAFETY-CRITICAL; **PARTLY enforced in code.** `[[hydration_everyday]]`' \
  '  Established (SAFETY-CRITICAL; **enforced in code.** `[[hydration_everyday]]`'

# ── G3 ───────────────────────────────────────────────────────────────────────
# The scope itself moves: the rule grows a "thirst" branch, so it now eats the
# corpus CORRECTING the myth. Widening is as much a defect as the overclaim was,
# and the two notes' prose stops being true either way.
mutate 'the fluid rule widens to catch a stance rather than a number' \
  "$GUARD_DIRECTIVES" src/healthee/insights/guard_directives.py \
  '    r"\b(?:drink|sip|hydrate)\s+(?:every|each)\s+\d+\s*(?:min\w*|km|miles?|hours?)\b",' \
  '    r"\b(?:ahead\s+of|before)\s+(?:your\s+)?thirst\b",'

# ── G4 ───────────────────────────────────────────────────────────────────────
# The withdrawn SpO2 precision figure returns to the frontmatter summary — the
# one field that ships to `research_summaries.json` and into every prompt.
mutate 'the withdrawn SpO2 RMSE figure returns to the shipped summary' \
  "$CORPUS_FIGURES" ../../packages/knowledge/notes/metrics/wearable_spo2_validity.md \
  'not for absolute precision (the true error is unquantified' \
  'not for absolute precision (±2–3% RMSE, the true error is unquantified'

# ── G5 ───────────────────────────────────────────────────────────────────────
# The withdrawn Jurca SEE returns to the method-comparison table, where it sits
# in the model's context beside the correct 5.075 in the same file.
mutate 'the withdrawn Jurca SEE returns to the comparison table' \
  "$CORPUS_FIGURES" ../../packages/knowledge/notes/activity/submaximal_vo2max.md \
  '| *Jurca 2005 (fallback baseline)* | r=0.81 overall, **SEE 1.45 METs = 5.075**' \
  '| *Jurca 2005 (fallback baseline)* | r≈0.78, **SEE≈5.6**'

# ── H · the audit's four gate fixes ──────────────────────────────────────────

MVPA_MET=tests/derive/test_mvpa_met_equivalent.py
CARDIO_RHR=tests/derive/test_cardio_load_rhr.py
SKIN_TEMP=tests/read/test_skin_temp_plausibility.py
REGISTRY=tests/challenges/test_registry.py

# ── H1 · audit C2 ────────────────────────────────────────────────────────────
# `mvpa_min` goes back to a raw minute count, measured against a MET-equivalent
# target of 150. The defect under-credits, which is why it survived every sweep.
mutate 'MVPA stops counting a vigorous minute as two' \
  "$MVPA_MET" src/healthee/derive/mvpa.py \
  '    mvpa = moderate + _VIGOROUS_MET_WEIGHT * vigorous' \
  '    mvpa = moderate + vigorous'

# The weighting moves into the flags instead, so the halves stop being the raw
# pair the weekly card's "moderate {m} + vigorous {v} x 2" subline needs.
mutate 'the un-weighted halves are weighted in the flags instead' \
  "$MVPA_MET" src/healthee/derive/mvpa.py \
  '{"moderate": moderate, "vigorous": vigorous})' \
  '{"moderate": moderate, "vigorous": _VIGOROUS_MET_WEIGHT * vigorous})'

# ── H2 · audit C5 ────────────────────────────────────────────────────────────
# The fabricated resting HR comes back — the one place in derive/ that invented
# an input rather than withholding. The row it publishes looks measured.
mutate 'cardio load invents a resting HR again' \
  "$CARDIO_RHR" src/healthee/derive/cardio_load.py \
  '    r = cur.fetchone()
    return float(r[0]) if r and r[0] is not None else None' \
  '    r = cur.fetchone()
    return float(r[0]) if r and r[0] is not None else 60.0'

# The freshness bound is dropped while the withhold stays, so a resting HR from a
# year ago is silently used as today's. Stale-as-current, in the reserve anchor.
mutate 'the resting-HR lookback goes back to unbounded' \
  "$CARDIO_RHR" src/healthee/derive/cardio_load.py \
  '        "AND day<=%s AND day>=%s ORDER BY day DESC LIMIT 1",
        (user_id, day, cutoff),' \
  '        "AND day<=%s AND day>=%s ORDER BY day DESC LIMIT 1",
        (user_id, day, cutoff - timedelta(days=100000)),'

# ── H3 · audit C7 ────────────────────────────────────────────────────────────
# One surface loses the plausibility filter again, so an off-wrist sample drags
# last night's skin temperature down here and not on the sleep page.
mutate 'the skin-temp average takes sentinel samples again' \
  "$SKIN_TEMP" src/healthee/read/sleep_extras.py \
  "  ROUND(AVG(CASE WHEN metric='skin_temp_c' AND value>25 THEN value END)::numeric, 1), " \
  "  ROUND(AVG(CASE WHEN metric='skin_temp_c' THEN value END)::numeric, 1), "

# ── H4 · audit C1 ────────────────────────────────────────────────────────────
# The challenge engine's sleep ceiling drops below the owner's own need again, so
# a sleep-duration target can never be raised past 7.5 h.
mutate 'the sleep ceiling drops back under the canonical need' \
  "$REGISTRY" src/healthee/challenges/scales.py \
  '    "tst_min": float(SLEEP_NEED_MIN_18_64),' \
  '    "tst_min": 450.0,'

# ── I · the two derived corpus guards, proven on their own subject ───────────

CORPUS_CAUSAL=tests/insights/test_corpus_causal_voice.py
MINETTI=tests/derive/test_minetti_coefficients.py

# ── I1 ───────────────────────────────────────────────────────────────────────
# An observational note goes back to causal voice in the "Act on confidently"
# line — the sentence that tells the model it may state a claim plainly, on a
# note whose own evidence bullets say "associated with".
mutate 'an observational claim ships in causal voice again' \
  "$CORPUS_CAUSAL" ../../packages/knowledge/notes/activity/sedentary_mortality.md \
  '**Act on confidently:** long sedentary time tracks with higher mortality, mostly in' \
  '**Act on confidently:** long sedentary time raises mortality, mostly in'

# ── I2 ───────────────────────────────────────────────────────────────────────
# One digit of one Minetti coefficient in the CODE. Before the note-side copy
# existed, nothing in the repo could see this: the polynomial still returns a
# plausible VO2 and every downstream number moves quietly with it.
mutate 'a Minetti gradient coefficient is mistyped' \
  "$MINETTI" src/healthee/derive/vo2max_submax.py \
  'cw = 155.4 * i**5 - 30.4 * i**4' \
  'cw = 155.4 * i**5 - 30.5 * i**4'

# And the other direction: the NOTE drifts away from the code it documents.
# Both halves matter — a table nobody checks is the state this replaced.
mutate 'the note-side Minetti table drifts from the code' \
  "$MINETTI" ../../packages/knowledge/notes/activity/submaximal_vo2max.md \
  '| **Walking** | 280.5 | −58.7 |' \
  '| **Walking** | 280.5 | −58.6 |'

# ── J · the write path: where every value is born (WRITE_PATH_AUDIT) ─────────
#
# Everything above breaks a READ. These break a WRITE, which is the more expensive
# kind: a value that is wrong on arrival is wrong everywhere downstream, forever,
# and a re-derive does not heal it.

DEVICE_TOTALS=tests/derive/test_device_totals.py
COUNTER_CARD=tests/read/test_honesty_b_c.py
UPSERT_UNIT=tests/test_ingest_upsert.py
PROFILE_RULE=tests/test_profile_one_rule.py
PARTIAL_STAGES=tests/derive/test_partial_stage_breakdown.py
DAY_CELL=tests/derive/test_gps_day_cell_precedence.py
DERIVE_PLAN=tests/test_ingest_derive_plan.py
SOURCE_NAME=tests/derive/test_session_source.py
FRAGMENTED=tests/derive/test_fragmented_night.py

# ── J1 · A1 ─────────────────────────────────────────────────────────────────
# THE defect, exactly as it shipped: the disclosure asks about the ARRIVAL instant
# instead of the READ instant. It looks right — `reported_at` is a real column with
# a real value — and it silences a true caveat on every push that crosses local
# midnight, which is the normal case.
mutate 'the partial-day caveat asks about the arrival again' \
  "$DEVICE_TOTALS $COUNTER_CARD" src/healthee/derive/device_totals.py \
  '    if device.read_at >= day_end_utc:' \
  '    if device.reported_at >= day_end_utc:'

# The other half, and the one the brief names as the failure to avoid: an unknown
# read time is folded back into "read after the day closed". The row looks clean,
# the caveat is gone, and nothing distinguishes it from a counter that really did
# cover the whole day.
mutate 'an unknown read time goes back to meaning "complete"' \
  "$DEVICE_TOTALS $COUNTER_CARD" src/healthee/derive/device_totals.py \
  '        return [_caveat(COUNTER_READ_TIME_UNKNOWN, _UNKNOWN_READ_MESSAGE, device, steps)]' \
  '        return []'

# And the write side: the column goes back to being invented rather than carried.
mutate 'the read instant is substituted when the client did not send one' \
  "$UPSERT_UNIT" src/healthee/ingest/daily_totals.py \
  '    return None if total.read_at is None else epoch_to_utc(total.read_at)' \
  '    return epoch_to_utc(total.read_at or 1_718_000_000_000)'

# ── J2 · B2 ─────────────────────────────────────────────────────────────────
# The profile write goes back to assigning what the push omitted. This is the one
# that erases a date of birth nothing else holds.
mutate 'an omitted demographic is assigned rather than preserved' \
  "$PROFILE_RULE" src/healthee/ingest/profile_write.py \
  'f"{col} = CASE WHEN %s THEN EXCLUDED.{col} ELSE profile.{col} END"' \
  'f"{col} = CASE WHEN %s THEN EXCLUDED.{col} ELSE EXCLUDED.{col} END"'

# ── J3 · B3 ─────────────────────────────────────────────────────────────────
# The stage gate goes back to `any`, so a partial breakdown becomes zeros — and an
# absent `wake_min` scores a fabricated 100% efficiency on a real dimension.
mutate 'a partial stage breakdown scores as zeros again' \
  "$PARTIAL_STAGES" src/healthee/derive/orchestrator.py \
  '    if sr and all(v is not None for v in sr):
        rem, light, deep, wake = (int(v) for v in sr)' \
  '    if sr and any(v is not None for v in sr):
        rem, light, deep, wake = (int(v or 0) for v in sr)'

# ── J4 · B1 ─────────────────────────────────────────────────────────────────
# Inside one day, recency beats precedence again: the later session takes the day's
# single cell whatever instrument read it, and the tier reads the wrong one.
mutate 'the later GPS session owns the day whatever measured it' \
  "$DAY_CELL" src/healthee/derive/gps.py \
  '    if not _day_cell_outranks(cur, user_id, day, str(flags["method"])):
        _upsert_daily(cur, user_id, day, "vo2max_submax", vo2max, {**flags, **common})' \
  '    _upsert_daily(cur, user_id, day, "vo2max_submax", vo2max, {**flags, **common})'

# And the subtler direction: the guard fires on EQUAL rank too, so a re-score can
# never move a value and `--rescore-tracks` silently does nothing.
mutate 'the day cell refuses a re-score by its own instrument' \
  "$DAY_CELL" src/healthee/derive/vo2max_tier.py \
  '    return order.get(challenger, last) < order.get(incumbent, last)' \
  '    return order.get(challenger, last) <= order.get(incumbent, last)'

# ── J5 · B4 ─────────────────────────────────────────────────────────────────
# A re-push that omits a duration zeroes the recorded one again, and the session
# drops out of three gates at once.
mutate 'a re-pushed workout zeroes its own duration' \
  "$UPSERT_UNIT" src/healthee/ingest/upsert.py \
  '"duration_s = COALESCE(%s::int, workout.duration_s), "' \
  '"duration_s = EXCLUDED.duration_s, "'

# ── J6 · B5 ─────────────────────────────────────────────────────────────────
# Naps stop marking their day, so a nap-only page derives nothing — while the day's
# calories and TRIMP still read every nap minute.
mutate 'a nap stops marking the day it falls in' \
  "$DERIVE_PLAN" src/healthee/ingest/service.py \
  '        if _marks_its_day(session, is_fresh):' \
  '        if _is_derivable_night(session, is_fresh):'

# The cost side of the same change: naps stop being gateable, so a re-push of
# history re-derives a day per stored nap on every sync.
mutate 'a re-pushed nap is permanently new' \
  "$UPSERT_UNIT" src/healthee/ingest/upsert.py \
  '        starts = [epoch_to_utc(s.start_ts) for s in sessions]' \
  '        starts = [epoch_to_utc(s.start_ts) for s in sessions if s.kind != "nap"]'

# ── J7 · C1 ─────────────────────────────────────────────────────────────────
# The rows go back to naming an instrument that took no reading. Nothing renders
# the string, which is exactly why only a test can see this one.
mutate 'the sleep rows name an instrument that did not read them' \
  "$SOURCE_NAME" src/healthee/derive/sleep_score.py \
  'SESSION_SOURCE = "strap_ble"' \
  'SESSION_SOURCE = "zepp_cloud"'

# ── J9 · B7 ─────────────────────────────────────────────────────────────────
# The fragmented night goes back to being invisible. B7 stays SUSPECTED on purpose —
# whether the strap produces the shape needs the device — so the only thing that can
# be broken here is the detection, and the only thing that can regress is silence.
mutate 'a wake date shared by two main sessions goes unrecorded' \
  "$FRAGMENTED" src/healthee/derive/orchestrator.py \
  '    if sessions > 1:' \
  '    if sessions > 2:'

# ── J8 · B6 ─────────────────────────────────────────────────────────────────
# The regression check stops firing, so a counter that ran backwards is invisible
# again — and the finding stays speculation forever because nothing records it.
mutate 'a counter running backwards goes unrecorded' \
  "$UPSERT_UNIT" src/healthee/ingest/daily_totals.py \
  '        if incoming[day] < int(stored):' \
  '        if incoming[day] < 0:'


# ── K1 · B1 ─────────────────────────────────────────────────────────────────
# The nightly chain marks the day done on `correlate` alone again. This IS the
# defect: `illness` fails, the day is recorded as run, and nothing retries it —
# and `derive_illness_flag` is not in `derive_batch`, so `rederive` cannot get it
# back. The mutation is deliberately the exact code that shipped.
CHAIN_MARK=tests/jobs/test_chain_mark_on_failure.py

mutate 'a failed step is marked done on correlate alone' \
  "$CHAIN_MARK" src/healthee/jobs/chain.py \
  '    if _nothing_failed(steps):
        _mark_chain_done(user_id, day)' \
  '    if correlate.status == "ok":
        _mark_chain_done(user_id, day)'

# The rule stays, but the mark moves back above the last step — so a briefing
# failure becomes unretryable BY CONSTRUCTION, whatever the rule says.
mutate 'the chain marks the day before its last step runs' \
  "$CHAIN_MARK" src/healthee/jobs/chain.py \
  '    steps.append(_briefing_step(day, user_id, tz, client=client, premium=premium))
    # LAST, and only on a clean run.' \
  '    if _nothing_failed(steps):
        _mark_chain_done(user_id, day)
    steps.append(_briefing_step(day, user_id, tz, client=client, premium=premium))
    # LAST, and only on a clean run.'

# A skip is read as a failure, so a free owner's chain never marks and re-enters
# every five minutes for the rest of their day.
mutate 'a skipped step counts as a failure' \
  "$CHAIN_MARK" src/healthee/jobs/chain.py \
  '    return all(step.status != "failed" for step in steps)' \
  '    return all(step.status == "ok" for step in steps)'

# ── K2 · C1 ─────────────────────────────────────────────────────────────────
# An entitlement row makes the claim refuse again, with the wrong diagnosis: the
# operator is told their target owns health data when it owns none.
CLAIM_TEST=tests/db/test_claim_sentinel.py

mutate 'an entitlement row is read as owned health data' \
  "$CLAIM_TEST" src/healthee/db/claim_sentinel.py \
  '_NON_HEALTH_TABLES = _NON_TENANT_TABLES | {"subscription"}' \
  '_NON_HEALTH_TABLES = _NON_TENANT_TABLES | set()'

# The target's entitlement stops being parked, so step 2's ON DELETE CASCADE
# takes it — silently, exactly as it would have taken their device token.
mutate 'the claim lets the cascade eat the target entitlement' \
  "$CLAIM_TEST" src/healthee/db/claim_sentinel.py \
  '    if _has_subscription(cur, claim_plan.target):' \
  '    if not _has_subscription(cur, claim_plan.target):'

# ── K3 · C2 ─────────────────────────────────────────────────────────────────
# Today's briefing goes out stamped with whatever day it was handed — the
# stale-as-current lie on the one channel with no other date beside it.
BRIEFING_DAY=tests/jobs/test_briefing_day.py

mutate 'the briefing stamps a day its content never answered for' \
  "$BRIEFING_DAY" src/healthee/jobs/briefing.py \
  '    if day is not None and day != today:' \
  '    if day is not None and day == today:'

# ── K4 · C3 ─────────────────────────────────────────────────────────────────
# The 60-day cooldown goes back to reading a 50-row tail, so an abandonment under
# deep history reads as never abandoned and the metric is re-offered.
COOLDOWN=tests/challenges/test_abandon_cooldown_window.py

mutate 'the abandon cooldown reads a row tail instead of its own window' \
  "$COOLDOWN" src/healthee/challenges/levers.py \
  '    for outcome in ledger.since(cur, user_id, window_opens):' \
  '    for outcome in ledger.recent(cur, user_id, limit=_HISTORY_ROWS):'

# The latest row per metric stops being the deciding one, so a completion after an
# abandonment no longer clears it.
mutate 'a later completion stops clearing the cooldown' \
  "$COOLDOWN" src/healthee/challenges/levers.py \
  '        decided.add(metric)' \
  '        decided.discard(metric)'

# ── K5 · D5 ─────────────────────────────────────────────────────────────────
# The gated-metric refusal goes back to living only in the CLI, so `run` and
# `rederive_owner` reach the DELETE with it — and every correctly GPS-scored
# session's row is deleted as "stale".
PURGE_GATE=tests/db/test_purge_gate.py

mutate 'the gated-metric refusal leaves the delete again' \
  "$PURGE_GATE" src/healthee/db/stale_derived.py \
  '    refuse_gated(metrics, gates)
    cur.execute(' \
  '    cur.execute('

# ── K6 · D6 ─────────────────────────────────────────────────────────────────
# The row lock stops locking. `INSERT … ON CONFLICT DO NOTHING` still serializes
# the FIRST use of a feature, which is exactly why this looks harmless: every
# call after the row exists races freely.
ALLOWANCE_LOCK=tests/premium/test_allowance_lock.py

mutate 'the allowance spend stops locking its row' \
  "$ALLOWANCE_LOCK" src/healthee/core/allowance.py \
  '_LOCK_SQL = "SELECT value FROM kv WHERE user_id = %s AND key = %s FOR UPDATE"' \
  '_LOCK_SQL = "SELECT value FROM kv WHERE user_id = %s AND key = %s"'

# ── K7 · D10 ────────────────────────────────────────────────────────────────
# The recovery ladder goes back to a bare absence, so "not enough of your data
# yet" reaches the owner as "this is probably a bug on our side".
SEVERITY_A_RECOVERY=tests/read/test_honesty_severity_a.py

mutate 'the empty recovery ladder stops saying why' \
  "$SEVERITY_A_RECOVERY" src/healthee/read/recovery_signals.py \
  '        return _withheld([c for c in candidates if isinstance(c, Unplaced)])' \
  '        return None'

# The reason survives but stops being per marker, so "which of the three, and
# why" becomes "something, somewhere".
mutate 'the withheld ladder stops naming which marker' \
  "$SEVERITY_A_RECOVERY" src/healthee/read/recovery_signals.py \
  '            "markers": {u.name: u.reason for u in unplaced},' \
  '            "markers": {},'

echo
echo "caught $PASS, survived $FAIL"
[ "$FAIL" -eq 0 ]
