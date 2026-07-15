"""The Activity tab (``/api/activity``): VO2max north-star + the weekly inputs that
build it (MVPA / steps / calories / distance), training-load balance (strain +
acute:chronic ratio), and workouts. Pure aggregation over the fitness services.
"""

from __future__ import annotations

from healthee.derive._common import Cur
from healthee.read.fitness import (
    activity_metric,
    acwr,
    cardio_load_payload,
    fitness_plan_payload,
    mvpa_payload,
    vo2max_payload,
    workouts_list,
)


def activity_snapshot(cur: Cur) -> dict:
    """Assemble the Activity tab from one cursor (no per-block reconnect)."""
    cardio = cardio_load_payload(cur)
    return {
        "vo2max": vo2max_payload(cur),
        "fitness_plan": fitness_plan_payload(cur),
        "cardio_load": cardio,
        "acwr": acwr(cardio),
        "mvpa": mvpa_payload(cur),
        "steps": activity_metric(cur, ["steps_total"]),
        "active_calories": activity_metric(cur, ["active_calories"]),
        "total_calories": activity_metric(cur, ["total_calories"]),
        "distance": activity_metric(cur, ["distance_m_daily"]),
        "workouts": workouts_list(cur),
        "research_notes": [
            "vo2max_fitness_mortality",
            "mvpa_minutes_mortality",
            "cardio_load_trimp",
        ],
    }
