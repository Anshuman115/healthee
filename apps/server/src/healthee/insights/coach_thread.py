"""The conversation the coach is handed: what is kept, what is screened, what it is about.

Three questions about the INPUT to a coach turn, in one place because they are one
question asked three ways — *what exactly will be sent to the model?*

  * :func:`recent` bounds the history (context-window discipline);
  * :func:`screen` runs the refusal gate over everything in that bound, plus the topic;
  * :func:`topic_block` renders the subject the owner arrived with, marked as a subject.

It lives beside ``coach.py`` rather than inside it because the file was at the standards'
400-line ceiling and because these three have one reason to change — the shape of what
reaches the prompt — while ``coach.py``'s reason is the tool loop.
"""

from __future__ import annotations

from healthee.insights import pipeline

# Last N conversation turns kept. A bound rather than the whole thread: the owner's
# allowance is 20 questions per rolling 30 days at a measured $0.179 each, and every
# question re-sends the conversation.
HISTORY_LIMIT = 12

# The longest topic this module will render. The app's own topics are one short sentence
# built from a metric name, a sport and a date, or a finding's title
# (``features/coach/coach_topics.dart``), so nothing it sends comes near this; the bound
# is here because a subject label arriving from anywhere else is still text going into a
# prompt, and ``read/logs.py`` carries the same argument at greater length.
TOPIC_MAX_CHARS = 200

# ── The topic fence ──────────────────────────────────────────────────────────
#
# A topic says which screen the owner pressed "ask the coach" on. That is genuinely
# useful — it is the difference between retrieval ranked on a question's prose and
# retrieval ranked on the subject the owner is actually looking at — and it is
# *exactly* as much as it is.
#
# ⛔ A TOPIC IS CONTEXT, NOT EVIDENCE. It is not a measurement, not a finding, not a
# claim, and it must never become one the model then justifies: an app-written label
# saying "your HRV trend" is not a statement that there IS a trend. So the block says
# so, in the same voice the manual-entry fence uses for owner text, and the topic is
# not exempt from anything — it is screened by the refusal gate before the model runs
# (``screen``), it reaches the model only inside this fence, and every sentence the
# model writes afterwards faces the same validator, the same hard output guardrails and
# the same personal-claims gate as an answer to a typed question.
_TOPIC_FENCE = (
    "The owner opened the coach from a screen about the subject quoted below. It is a "
    "SUBJECT LABEL written by the app to say what they were looking at — not a "
    "measurement, not a finding, and not a claim. Nothing in it is evidence: do not "
    "restate it as fact, do not argue for it, do not cite anything to it, and do not "
    "treat it as something the data has already shown. Use it only to understand what "
    "the question is about."
)


def recent(messages: list[dict]) -> list[dict]:
    """Keep the last :data:`HISTORY_LIMIT` well-formed turns (role+content)."""
    clean = [
        {"role": m["role"], "content": m["content"]}
        for m in messages
        if m.get("role") in ("user", "assistant") and m.get("content")
    ]
    return clean[-HISTORY_LIMIT:]


def last_user(history: list[dict]) -> str:
    """The most recent user message text, or '' if there is none."""
    return next((m["content"] for m in reversed(history) if m["role"] == "user"), "")


def screen(history: list[dict], topic: str | None = None) -> pipeline.Domain | None:
    """The first refusal domain anything SENT to the model hits, or None.

    The gate is asked about everything that will be sent, not about what was last typed.
    ``pipeline.check_question``'s guarantee is that "the model is never called, so it
    cannot be prompted, jailbroken or cajoled past a hard guardrail" — and
    ``coach._initial_messages`` sends the whole bounded history, so screening only
    :func:`last_user` made that guarantee true of one message and false of the
    conversation. The ordinary flow it broke needs no bad actor at all:

      1. turn 1 reports an exertional collapse — ``exertional_emergency`` fires, the
         model is never called, the owner gets the emergency template;
      2. turn 2 asks something benign — and the collapse re-entered the model's context
         unscreened, with ``output_guard``'s ``advise_through_red_flag_symptom`` the only
         thing left, and that fires only when ONE sentence carries both a red flag and a
         train-through phrase. ``red_flags`` records the same argument about D12: it
         "cannot fire when the owner reports the emergency and the model's reply happens
         to be innocuous". So the escalation ``refusals`` exists to produce never
         happened, one turn after it did.

    A hit on an earlier turn refuses the current turn too — an emergency somebody
    reported two messages ago has not stopped being one. Oldest first, so the reply is
    attributed to the domain that actually fired rather than to whichever is newest.

    The topic is screened for the same reason and with the same gate: it is text the app
    puts into the prompt, so "screen what is sent" covers it or it does not mean anything.
    It is screened LAST, after the owner's own words, so a thread carrying a real
    emergency is named by that emergency rather than by the screen it was opened from.

    Assistant turns are not screened: they are this product's own already-validated
    output, and the refusal vocabulary is written for questions.

    ``check_question`` is pure regex, so a pass per turn costs nothing beside one model
    call — which is the whole reason screening every turn is affordable.
    """
    for message in history:
        if message["role"] != "user":
            continue
        hit = pipeline.check_question(message["content"])
        if hit is not None:
            return hit
    return pipeline.check_question(topic) if topic else None


def normalized_topic(topic: str | None) -> str | None:
    """The topic as one line of at most :data:`TOPIC_MAX_CHARS`, or None for no topic.

    Whitespace-collapsed for the same reason the manual-entry fence collapses it: a
    newline inside a fenced span ends the fence and puts the rest of the string at the
    top level of the prompt. Blank-after-trimming is *no topic*, never an empty label —
    the same answer ``core/routes.dart`` gives a blank ``?topic=`` on the client.
    """
    if topic is None:
        return None
    collapsed = " ".join(topic.split())
    return collapsed[:TOPIC_MAX_CHARS] or None


def topic_block(topic: str | None) -> str:
    """The fenced subject line for the system turn, or '' when there is no topic."""
    subject = normalized_topic(topic)
    if subject is None:
        return ""
    return f'\n\n# WHAT THIS CONVERSATION IS ABOUT\n\n{_TOPIC_FENCE}\n\n  "{subject}"'


def retrieval_key(question: str, topic: str | None) -> str:
    """What the context and evidence builders RANK on for this turn.

    The topic joins the question here and only here. Retrieval is a ranking, not an
    assertion — ``retrieval.evidence_section`` picks which graded notes to embed and
    ``context.build_context`` floats findings that name a metric the text mentions — so
    a subject label steers what the model is shown to reason FROM without becoming
    anything it is asked to reason ABOUT. That is the whole of what "ground on the
    topic" can honestly mean: the corpus a question is answered against is chosen better
    when the server knows the question is about VO2max, and nothing in the topic gets to
    be true because it was sent.
    """
    subject = normalized_topic(topic)
    return f"{subject}\n{question}" if subject else question
