"""WP-C3 — grounded challenge generation. The model authors; two gates dispose.

CHALLENGES.md §5.1. The LLM writes the whole challenge (metric, target, cadence,
window, copy) because that judgement is genuinely valuable and a rules table cannot
encode it — a chronic ~3.7 h sleeper needs a sleep-REGULARITY challenge, not a
sleep-duration one. What makes that safe is not taking the pen away, but grounding both
inputs and bounding the output:

* **Gate A — baseline bounds** (``bounds``): the proposed ``target_value`` must sit in
  the owner's own progressive-overload band. Out of band ⇒ the proposal is DROPPED, never
  clamped, so the stored number is always the number the model wrote its copy around.
* **Gate B — cite-or-refuse**: generation runs through ``insights.grounded_ask``, whose
  validator is BLOCKING. A fabricated id, an uncited interpretive sentence or wording
  that overstates a note's grade means the whole batch fails validation twice and the
  choke point returns its honest fallback — from which nothing is parsed and nothing is
  written. This is the fix for legacy's ``_validate`` (:390), which merely *dropped* bad
  citations and persisted the challenge anyway (§2.2).

On top of those, the structural invariants: the metric must resolve in
``CHALLENGE_METRICS`` (a challenge we cannot measure is a promise we cannot keep), every
cited note must exist AND prove at least Probable evidence, the write is owner-scoped,
the per-owner ``MAX_ACTIVE`` cap bounds how many suggestions are worth making, and
nothing may duplicate a metric the owner is already running.

## Lazy only — never the scheduler

There is deliberately no chain step and no cron hook here (§5.1). Legacy never generated
from its scheduler either, and spending tokens on a feed nobody opened is money spent to
show somebody nothing. The entry point is called by an empty feed or an explicit
refresh — and, from WP-C5, by the coach.

## The WP-C5 seam

``intent`` is that seam. ``create_challenge`` (§6a) reuses THIS pipeline with the
owner's stated intent rather than forking a second path, because a second path is a
second set of gates to keep in step. Passing an intent narrows what the model may
choose; it grants nothing — an intent that resolves to no trackable metric still
produces nothing, which is what the coach then reports honestly. The tool itself lives
in ``insights.challenge_tools`` (WP-C5).

``replace_feed`` is the seam's second half, added by WP-C5 because the first half was
not sufficient. A refresh REPLACES the suggestion feed (:func:`_persist`) — right for a
refresh, wrong for a chat message, because a coach turn must not silently delete the
suggestions somebody is looking at in another tab. With ``replace_feed=False`` nothing
is deleted and the duplicate check widens to cover suggested metrics too, so the added
row cannot shadow one already on the menu.

## Not premium-gated, because 6.6 does not exist

The whole challenges system is premium per PRICING §1a. There is no ``subscription``
table and no ``require_ai_access`` (MULTI_USER.md §12), so this is reachable by any
authenticated owner exactly like every other AI surface today. Noted rather than faked:
a comment claiming a gate that is not there is worse than a missing gate.

## Two transactions, not one

The context read and the persist are separate transactions with the LLM call between
them, because holding a pooled connection across a network round-trip is how a pool
deadlocks (standards §Performance). The cap and the active-metric set are therefore
re-read inside the write transaction — the world may have moved while the model was
thinking, and the second read is what stops a race from breaching the cap.
"""

from __future__ import annotations

from datetime import date
from uuid import UUID

from healthee.challenges import gen_context, gen_prompt, lifecycle, store
from healthee.challenges.metrics import CHALLENGE_METRICS, DerivedSource
from healthee.challenges.screen import screen
from healthee.core.db import tenant_transaction
from healthee.core.logging import get_logger
from healthee.core.tenancy import user_today
from healthee.insights.client import LLMClient
from healthee.insights.grounded import grounded_ask

log = get_logger(__name__)

# One outer retry when EVERY proposal was rejected by the deterministic gates. It is not
# the choke point's retry (that one answers a grounding failure and lives inside
# `grounded_ask`); this one answers a bounds failure, which is a different problem with a
# different fix. Bounded at one because a model that ignored the printed band twice is
# not going to honour it on a third ask, and an empty feed is an honest answer.
_MAX_BOUNDS_RETRIES = 1

# Days of the owner's history the choke point builds its context over. Wider than recs'
# 14: a challenge is a commitment for the weeks ahead, and the trend that justifies it
# is not visible in a fortnight.
_CONTEXT_DAYS = 30

# The corpus metrics retrieval should rank notes against — the registry's own keys plus
# the `derived_daily` metric each one actually reads, because notes declare
# `applies_to_metrics` in the derive layer's vocabulary (`sleep_regularity_index`), not
# the registry's shorthand (`sri`).
GENERATION_METRICS: list[str] = sorted(
    set(CHALLENGE_METRICS)
    | {s.source.metric for s in CHALLENGE_METRICS.values() if isinstance(s.source, DerivedSource)}
)


def generate_challenges(
    user_id: UUID,
    tz: str,
    *,
    intent: str | None = None,
    max_new: int | None = None,
    replace_feed: bool = True,
    client: LLMClient | None = None,
    model: str | None = None,
    today: date | None = None,
) -> dict:
    """Author, gate and persist suggested challenges for ONE owner. Never raises on a rule.

    Returns ``{"ok": True, "generated": n, "rejected": [...], "challenges": [...]}`` or a
    named refusal ``{"ok": False, "reason": …, "error": …}``. A refusal is a real answer
    and says which rule produced it; a genuine failure (a broken transport, an unreadable
    manifest) propagates to the caller (standards §Errors).

    ``rejected`` carries one sentence per proposal that did not make it, and it is part of
    the ANSWER rather than only a log line: an empty feed with no reason is exactly the
    silent degraded state §2.5 forbids, and WP-C5's coach can only say "I could not build
    that, because…" if the pipeline told it because-what.

    ``replace_feed=False`` ADDS to the suggestion feed instead of replacing it — the
    coach's mode (module docstring).
    """
    today = today or user_today(tz)
    prepared = _prepare(user_id, tz, today, max_new, replace_feed)
    if "error" in prepared:
        return prepared
    accepted, rejected = _author(user_id, tz, prepared, intent=intent, client=client, model=model)
    if accepted is None:
        return _refused("no_grounded_output", "the evidence base could not ground a challenge")
    return _persist(user_id, today, accepted, rejected, replace_feed)


def _prepare(user_id: UUID, tz: str, today: date, max_new: int | None, replace_feed: bool) -> dict:
    """The pre-LLM read: close what has ended, count the slots, build the context.

    ``finalize_due`` runs first for the same reason ``lifecycle.adopt`` runs it — the cap
    is computed from the active count, and a challenge that finished but has not been
    closed would silently cost the owner a slot they should have back.

    Two metric sets come out of here, not one, and they are different questions. The
    LEVER analysis is told only what is *active*, because its exclusion reason says
    "already running as a live challenge" and a suggestion is not that. ``screen`` is
    told what is *claimed*, which when the feed is being kept also covers the metrics
    already sitting on it — ``screen``'s own refusal already reads "already has a live
    or proposed challenge", so the widened set is the sentence it was written for.
    """
    with tenant_transaction(user_id) as cur:
        lifecycle.finalize_due(cur, user_id, tz, today)
        slots = lifecycle.MAX_ACTIVE - store.count_active(cur, user_id)
        if slots <= 0:
            return _refused("too_many_active", f"already running {lifecycle.MAX_ACTIVE} challenges")
        active_metrics = store.active_metrics(cur, user_id)
        claimed = (
            active_metrics
            if replace_feed
            else store.metrics_in_status(cur, user_id, ("active", "suggested"))
        )
        context, calibrations, analysis = gen_context.build_generation_context(
            cur, user_id, tz, today, active_metrics
        )
    if not any(c.band for c in calibrations.values()):
        return _refused("no_calibratable_metric", "no metric has enough of this owner's data")
    return {
        "context": context,
        "calibrations": calibrations,
        "claimed_metrics": claimed,
        "blocked": analysis.blocked_metrics(),
        "max_new": max(1, min(max_new or slots, slots)),
    }


def _author(
    user_id: UUID,
    tz: str,
    prepared: dict,
    *,
    intent: str | None,
    client: LLMClient | None,
    model: str | None,
) -> tuple[list[dict] | None, list[str]]:
    """Ask, screen, and (at most once) re-ask with the rejections named.

    ``None`` for the accepted list means Gate B refused — the choke point returned a
    refusal or its honest fallback, so there is no payload to screen and nothing ships.
    """
    task = gen_prompt.generation_task(prepared["max_new"], intent)
    issues: list[str] = []
    for attempt in range(_MAX_BOUNDS_RETRIES + 1):
        result = grounded_ask(
            f"{task}\n\n{prepared['context']}",
            user_id,
            tz,
            metrics=GENERATION_METRICS,
            context_days=_CONTEXT_DAYS,
            response_format="json",
            client=client,
            model=model,
        )
        if result.refused or not result.validated or result.data is None:
            log.info("challenge generation for %s: no grounded output", user_id)
            return None, issues
        accepted, issues = screen(
            result.data,
            prepared["calibrations"],
            prepared["claimed_metrics"],
            prepared["max_new"],
            prepared["blocked"],
        )
        _log_rejections(user_id, issues)
        if accepted or attempt >= _MAX_BOUNDS_RETRIES:
            return accepted, issues
        task = gen_prompt.generation_task(prepared["max_new"], intent) + (
            gen_prompt.REJECTION_NUDGE.format(issues="\n".join(f"- {i}" for i in issues))
        )
    return [], issues


def _persist(
    user_id: UUID, today: date, accepted: list[dict], rejected: list[str], replace_feed: bool
) -> dict:
    """Write what survived the gates — replacing the owner's feed, or adding to it.

    The cap and the taken metrics are re-read HERE (module docstring): the model was
    thinking outside this transaction, and a challenge adopted meanwhile must still be
    able to block a duplicate. When the feed is being KEPT, "taken" also covers the
    suggestions on it, so an added row cannot shadow one already there.

    A run that survived the gates with NOTHING leaves the existing feed alone. The
    delete is the first half of a replacement, and there is nothing to replace with — a
    refresh whose proposals were all rejected should cost the owner the refresh, not the
    suggestions they already had.
    """
    written: list[dict] = []
    rejected = list(rejected)  # the caller's list is not ours to extend
    if not accepted:
        log.info("generation for %s produced nothing — the existing feed is left alone", user_id)
        return {"ok": True, "generated": 0, "rejected": rejected, "challenges": []}
    statuses = ("active",) if replace_feed else ("active", "suggested")
    with tenant_transaction(user_id) as cur:
        if replace_feed:
            store.delete_suggestions(cur, user_id)
        slots = lifecycle.MAX_ACTIVE - store.count_active(cur, user_id)
        taken = store.metrics_in_status(cur, user_id, statuses)
        for proposal in accepted:
            if len(written) >= slots:
                break
            if proposal["metric"] in taken:
                rejected.append(
                    f"{proposal['metric']} was already spoken for by the time the model "
                    "finished thinking"
                )
                continue
            taken.add(proposal["metric"])
            new_id = store.insert_suggested(cur, user_id, today, proposal)
            row = store.fetch(cur, user_id, new_id)
            if row is None:  # the row we just wrote must be visible on this cursor
                raise RuntimeError(f"challenge {new_id} vanished inside its own transaction")
            written.append(row)
    log.info("generated %d challenge(s) for %s (%d rejected)", len(written), user_id, len(rejected))
    return {"ok": True, "generated": len(written), "rejected": rejected, "challenges": written}


def _log_rejections(user_id: UUID, issues: list[str]) -> None:
    """Rejections are logged, never swallowed (CHALLENGES.md §5.1, standards §Errors)."""
    for issue in issues:
        log.info("challenge proposal rejected for %s: %s", user_id, issue)


def _refused(reason: str, message: str) -> dict:
    """A rule outcome — explicit and named, matching ``lifecycle``'s refusal shape."""
    return {"ok": False, "reason": reason, "error": message}
