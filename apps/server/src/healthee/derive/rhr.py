"""Resting heart rate for one sleep window.

RHR = the lowest sustained at-rest heart rate during sleep: the minimum over
5-minute rolling averages of HR inside the session window. Ported verbatim from
legacy v2 ``derive_rhr``. Knowledge notes: ``resting_hr_health_marker`` (Aune
2017 — RHR predicts CV/all-cause mortality), ``resting_heart_rate``.
"""

from __future__ import annotations

from datetime import datetime

from healthee.derive._common import Cur


def derive_rhr(cur: Cur, start_ts: datetime, end_ts: datetime) -> tuple[float | None, int]:
    """Min of 5-min rolling-average HR in the sleep window.

    Returns (rhr_bpm, n_samples). Only 5-min buckets with >=3 HR samples count,
    and HR is bounded to a physiological 30-220 bpm. (None, 0) when the window
    holds no qualifying HR data. Knowledge: ``resting_hr_health_marker``.
    """
    cur.execute(
        """
        SELECT MIN(bucket_avg)::float, SUM(n)::int
        FROM (
          SELECT AVG(value) AS bucket_avg, COUNT(*) AS n
          FROM sample
          WHERE metric='hr' AND value BETWEEN 30 AND 220
            AND ts >= %s AND ts < %s
          GROUP BY time_bucket('5 minutes', ts)
          HAVING COUNT(*) >= 3
        ) buckets
        """,
        (start_ts, end_ts),
    )
    row = cur.fetchone()
    if not row or row[0] is None:
        return None, 0
    return float(row[0]), int(row[1])
