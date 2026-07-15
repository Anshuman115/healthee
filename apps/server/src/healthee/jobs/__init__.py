"""Scheduler + supervised job chain (WP8).

The one place background work is orchestrated. Nothing here shells out: the
legacy ``subprocess.Popen("healthee correlate && healthee recs && …")`` (the
swallowed-error event chain) is replaced by ``chain.run_chain`` — in-process,
SUPERVISED function calls where every step failure is logged through
``core.logging`` and reported to Telegram via ``core.notify`` (standards §1:
"jobs run as supervised functions"; §2: "no ``subprocess``/``Popen`` for
in-process work").

Modules:
  * ``correlate``  — recompute personal findings (reuses ``analytics``);
  * ``recs``       — daily recommendations, v2-native, THROUGH the grounded
                     choke point (``insights.grounded``), cite-or-drop;
  * ``briefing``   — the morning Telegram "daily-insight", grounded + validated;
  * ``chain``      — ``run_chain`` (ordered, dependency-aware, deduped) + the
                     supervised single-step runner both it and the scheduler use;
  * ``scheduler``  — the self-rescheduling loop (``python -m healthee.jobs.scheduler``).
"""
