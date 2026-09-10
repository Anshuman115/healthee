"""The three budgets one grounded run spends, and the state that tracks them.

Split out of ``pipeline`` when that file passed the 400-line gate; nothing about
the split is decorative. These four things answer one question — *how much may
this run spend before it must answer?* — and they answer it in three different
units:

* **rewrites** (:func:`validation_retries`) — how many nudged repairs an answer
  gets before the honest fallback ships;
* **rounds** (``Loop.max_gathering_turns``, ceiling in :func:`turn_budget`) — how
  much tool-running is *useful*;
* **seconds** (:func:`gathering_deadline_s`) — how much is *affordable*, which is
  the one that was missing and the one a caller actually experiences.

Every number is read from settings at call time rather than captured at import,
so a deployment can change one without a code change and a test can set one
without reloading a module.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

from healthee.core.config import get_settings
from healthee.core.logging import get_logger

if TYPE_CHECKING:  # pragma: no cover - import cycle at runtime, not at type time
    # `pipeline` imports this module, so importing its types back would cycle.
    # `from __future__ import annotations` makes every annotation a string, so the
    # names are only ever needed by the type checker. Same reason `gate_types`
    # exists as its own module.
    from healthee.insights.pipeline import Loop, Turn

log = get_logger(__name__)


def validation_retries() -> int:
    """How many NUDGED REWRITES one answer gets before the honest fallback ships.

    It was the constant ``MAX_VALIDATION_RETRIES = 1``, set when a retry cost real money
    on the tier we ran then; it is now ``LLM_VALIDATION_RETRIES`` (default **2**), and
    ``core.config`` carries why that is one setting rather than a per-model price table.

    A retry is what FIXES the failures this pipeline actually has — measured (INTELLIGENCE
    §9.1, §9.5), ~80 % of everything the product paid for and never shipped failed on
    citation or grade-calibration WORDING, which a nudge naming the exact issue repairs.
    Only a candidate that already failed spends one, and the budget is RESERVED on top of
    the gathering allowance (:func:`turn_budget`), never taken from it. Zero is legal and
    means "one attempt, then the fallback"; no value reaches the floor, which is that
    unvalidated text never ships.
    """
    return max(0, get_settings().llm_validation_retries)


def gathering_deadline_s() -> float:
    """How long one run may spend GATHERING before it must answer with what it has.

    Read from settings on every call rather than captured at import, so a deployment
    can change it without a code change and a test can set it without reloading a
    module. It is deliberately smaller than the client's own wait: the answering
    turns happen after this, and a deadline that used the whole budget would produce
    a run that stopped gathering exactly as the socket closed. `core/config.py` shows
    the arithmetic that picks it.
    """
    return get_settings().gathering_deadline_s


def turn_budget(loop: Loop) -> int:
    """The hard ceiling on LLM calls for one run: gathering + the reserved answers.

    A ceiling, not a spend. Nothing consumes a gathering round unless the model actually
    asked for a tool, and the two answer attempts are the same two every surface gets.
    """
    return loop.max_gathering_turns + validation_retries() + 1


@dataclass
class _Progress:
    """The driver's running state — how much gathering happened, how many retries, stalled."""

    gathered: int = 0
    retries: int = 0
    stalled: bool = False
    started_at: float = field(default_factory=time.monotonic)

    def out_of_time(self) -> bool:
        """True once gathering has spent its wall-clock share of the caller's wait."""
        return self.elapsed() >= gathering_deadline_s()

    def elapsed(self) -> float:
        """Seconds since this run began. Monotonic — a clock step must not end a run."""
        return time.monotonic() - self.started_at

    def may_gather(self, loop: Loop) -> bool:
        """True while this run may still spend a round on tools instead of an answer.

        ## ⛔ Three budgets, and the third one is why anybody got an answer at all

        Rounds and stalling bound how much gathering is *useful*. Neither bounds how
        LONG it takes, and the caller is a person holding a phone. Measured in
        production on 2026-09-10: coach rounds were taking ~103 s each against a
        ceiling of 20, so the worst case was over half an hour while the app hangs
        up at six minutes. **Zero coach requests had ever completed on that
        deployment** — the server kept working, produced an answer, and delivered
        it to a socket that had closed.

        The deadline does not abandon the run: it stops GATHERING, which forces the
        next turn to answer with what is already collected. An answer built from
        partial data, saying so, is worth more than a timeout — and it is the same
        rule the rest of this product follows about not having enough.
        """
        if self.stalled or self.out_of_time():
            return False
        return self.gathered < loop.max_gathering_turns

    def note_round(self, loop: Loop, turn: Turn) -> None:
        """Count one gathering round, and latch the stall when it added nothing new."""
        self.gathered += 1
        if turn.progressed:
            return
        self.stalled = True
        log.info(
            "%s: gathering round %d repeated an earlier call — forcing the answer",
            loop.label,
            self.gathered,
        )
