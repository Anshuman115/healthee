"""The Activity tab (``/api/activity``): VO2max north-star + the weekly inputs that
build it (MVPA / steps / calories / distance), training-load balance (strain +
acute:chronic ratio), and workouts. Pure aggregation over the fitness services.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.core.tenancy import reference_day
from healthee.derive._common import Cur
from healthee.read.acwr import acwr
from healthee.read.common import as_of_block
from healthee.read.fitness import (
    activity_metric,
    cardio_load_payload,
    mvpa_payload,
    workouts_list,
)
from healthee.read.fitness_plan import fitness_plan_payload
from healthee.read.vo2max import vo2max_payload


def activity_snapshot(cur: Cur, user_id: UUID, tz: str, day: date | None = None) -> dict:
    """Assemble the Activity tab from one cursor (no per-block reconnect), as of a day.

    The reference day is resolved ONCE and passed down, so the VO₂max the hero shows and
    the VO₂max the fitness plan projects from are the same day's number — they were two
    independent ``user_today`` lookups before, which agreed only because nothing could
    ask them a different question.

    ``acwr`` needs nothing: it is computed from ``cardio_load``'s own trend, so it
    inherits that block's window and cannot see past it.
    """
    as_of = reference_day(day, tz)
    cardio = cardio_load_payload(cur, user_id, tz, as_of)
    # Built ONCE and handed to the plan, which used to build its own. Two calls meant 11
    # of this endpoint's 22 statements were exact repeats of another statement in the same
    # request, and the same 96-point `trend_90d` on the wire twice — 12,466 of 22,401
    # bytes, 55.6% of the payload (`PERF_AUDIT.md` B1/C1). `fitness_plan_payload` now
    # REQUIRES the block, so the duplication cannot come back by omission.
    vo2max = vo2max_payload(cur, user_id, tz, as_of)
    return {
        "date": as_of.isoformat(),
        "as_of": as_of_block(cur, user_id, tz, as_of),
        "vo2max": vo2max,
        "fitness_plan": fitness_plan_payload(cur, user_id, tz, as_of, vo2max=vo2max),
        "cardio_load": cardio,
        "acwr": acwr(cardio),
        "mvpa": mvpa_payload(cur, user_id, tz, as_of),
        "steps": activity_metric(cur, user_id, tz, ["steps_total"], day=as_of),
        "active_calories": activity_metric(cur, user_id, tz, ["active_calories"], day=as_of),
        "total_calories": activity_metric(cur, user_id, tz, ["total_calories"], day=as_of),
        "distance": activity_metric(cur, user_id, tz, ["distance_m_daily"], day=as_of),
        "workouts": workouts_list(cur, user_id, tz, day=as_of),
        # Manifest IDs, never aliases. ``vo2max_fitness_mortality`` and
        # ``cardio_load_trimp`` are alias vocabulary for ``vo2max`` and
        # ``training_stress_score``; every consumer of a cited id resolves it by id
        # (``manifest.by_id`` / ``note_ids`` / ``grade_of``, none of which read
        # ``aliases``), so those two named nothing and the app's ⓘ sheet opened empty.
        # ``tests/test_source_citations.py`` states the rule for ``[[id]]`` citations in
        # source; the WIRE is held to it by ``tests/read/test_wire_honesty.py``'s
        # ``test_every_note_id_on_the_wire_resolves_to_a_manifest_id``, which walks
        # ``today_snapshot``, ``activity_snapshot`` and ``sleep_page``. This named a
        # ``test_wire_note_ids`` that exists nowhere — the guard was real under another
        # name, and the cost of the wrong name was paid during the audit: a reader who
        # checks concludes the net is fictional (audit D-b).
        "research_notes": [
            "vo2max",
            "mvpa_minutes_mortality",
            "training_stress_score",
            # The ratio's own note, Contested, added with the ``state`` verdict's removal:
            # ``acwr`` cited only ``training_stress_score`` (a Probable note about TRIMP),
            # so this endpoint published a ratio whose governing note named no surface.
            "training_load_acwr",
        ],
    }
