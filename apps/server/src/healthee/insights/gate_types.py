"""The vocabulary every answer gate speaks — what a gate is given, what it may conclude.

Types only: no rule, no IO, no policy. They live apart from ``pipeline.py`` for one
reason, and it is a structural one rather than tidiness. A gate whose subject matter has
its own module (``personal_claims``) needs these names to state its verdict; if they
lived in ``pipeline`` — which imports that module to register the gate — the two would
form an import cycle, and the escape hatches from a cycle are all worse than a types
module (a local import is banned by standards §2, and re-typing the dataclass would be
two definitions of what a gate returns).

``pipeline`` re-exports every name here, so ``pipeline.AnswerContext`` and
``pipeline.GateOutcome`` remain what a caller and a test write. The choke point is still
one module; this is its dictionary.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from healthee.insights.validator import ValidationResult

__all__ = ["AnswerContext", "AnswerGate", "Block", "GateOutcome", "Verdict"]


@dataclass(frozen=True)
class AnswerContext:
    """The per-surface facts the shared gates need — defaults are the STRICTEST reading.

    ``json_mode`` selects the validator flavour. ``acted_ok`` names the action tools that
    returned ok this turn; a surface with no tools leaves it empty, which is not an
    exemption but the strictest possible setting — every action claim is then an issue.

    ``structure_issues`` is how a surface whose model output has a CONTRACT reports that
    the contract was broken (``coach_answer``). Carried here rather than raised where it
    is found, so the driver's one policy — nudge, then the honest fallback — applies to it
    exactly as it applies to a missing citation instead of a second retry loop growing
    beside the shared one. Empty is the truth for a surface that has no structure.

    ``asserted`` / ``without_data`` are the personal-claim gate's two facts (#129): the
    owner-subjects the answer declares it states a value for, and which of those — plus
    any the prose records as having happened — this owner has no stored data for at all.
    Both are gathered by the surface, because only the surface knows its owner and its own
    payload; the RULE over them lives in ``personal_claims`` and runs in the registry.
    Empty defaults are the truth for a surface with no claims contract, not a loophole:
    nothing is being exempted, there is simply nothing declared to check.
    """

    json_mode: bool = False
    acted_ok: frozenset[str] = frozenset()
    structure_issues: tuple[str, ...] = ()
    asserted: tuple[str, ...] = ()
    without_data: frozenset[str] = frozenset()


@dataclass(frozen=True)
class Block:
    """A hard stop: this exact response ships, and the model is NEVER nudged toward another."""

    name: str
    response: str


@dataclass(frozen=True)
class GateOutcome:
    """What one gate concluded: a hard block, retryable issues, or nothing at all.

    ``validation`` is how the validator gate publishes the citations / personal findings /
    grade floor the surfaces put on their result — no other gate needs to set it.
    """

    block: Block | None = None
    issues: tuple[str, ...] = ()
    validation: ValidationResult | None = None


AnswerGate = Callable[[str, AnswerContext], GateOutcome]


@dataclass(frozen=True)
class Verdict:
    """The folded outcome of every answer gate over one candidate."""

    block: Block | None = None
    issues: tuple[str, ...] = ()
    validation: ValidationResult | None = None

    @property
    def ok(self) -> bool:
        """True only when nothing blocked and no gate raised an issue (blocking)."""
        return self.block is None and not self.issues
