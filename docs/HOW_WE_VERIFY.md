# How we verify

`ENGINEERING_STANDARDS.md` says what the code must be. This says how we find out
whether it is — the practices, why each exists, and the specific ways each one
has failed on this project.

Everything here was learned by getting it wrong first. The failures are named on
purpose: a practice whose failure mode is forgotten stops being a practice.

---

## 1. The four gates

Nothing merges without all four green, run as one command at the end of a job:

```
flutter analyze --fatal-warnings --fatal-infos     # infos are errors here
flutter test
python3 ../../scripts/check_file_length.py         # 400 lines, hard
bash test/mutations.sh                             # every guard, broken on purpose
```

Server adds `pytest`, `ruff check`, `ruff format`, `pyright`, and its own
`tests/read/mutations.sh`.

**Measure the baseline BEFORE changing anything, and state it back.** An agent
that measures only afterwards can report an improvement it did not make. One
job could only report its server baseline as arithmetic because it measured
after changing, and said so — that admission is the standard, not the lapse.

---

## 2. Mutation testing — the practice this project leans on hardest

### Why

A green suite says the tests passed. It does not say they would have **failed**
if the code were wrong. Those are different claims and only the second is worth
anything.

Three guards here cannot be reached by using the app at all:

- the 60-day horizon fires two months after a row is written;
- the `pushed_at_ms` retention guard fires a year after that;
- the daily-counter write is invisible until the day it was needed is over.

For those, mutation testing is not a nicety. It is the only evidence.

### How

`test/mutations.sh` applies one small, realistic, *exact-string* change, runs a
named test target, and requires it to go red. Example:

```bash
mutate 'the pair arrow becomes single-headed' \
  "$NAMES_TEST" "$NAMES" \
  "const String kPairArrow = '↔';" \
  "const String kPairArrow = '→';"
```

That is not a typo check. `→` between two correlated metrics **claims a
direction the statistic does not have**. The mutation asks whether anything
would stop someone making that claim.

Each mutation is one sentence about one defect that must not return. The count
rising is the point; `survived 0` is the gate.

### The four ways a mutation lies

**1. The stale patch.** A refactor moves the anchor string, the replacement
matches nothing, the unmutated suite runs, and it reports a pass. **This reads
exactly like a working guard.** It has happened three times here. The harness
asserts the patch changed something and prints `PATCH FAILED` instead — treat
that as louder than a survivor, because a survivor is at least honest.

**2. The fictional mutation.** A hand-written server mutation that fails on a
`NameError` rather than on behaviour. It goes red, so it looks caught, but it
proved nothing except that the mutation was misspelled. **Check each one
actually exercises the guard.**

**3. The poisoned checkout.** The server harness restored files with `cp`+`mv`,
giving an mtime that could land in the same second as the mutation's write — so
CPython accepted the **mutated `.pyc`** as current. A test failing against a
provably correct file, `git status` clean, only `dis` disagreeing. It had hidden
a real survivor. Fixed with `PYTHONDONTWRITEBYTECODE=1` and a cache sweep.

**4. The mutation with no test.** One added mutation survived because the value
it broke (`± σ`) was parsed and never asserted on screen. The mutation was
right; the suite was thin. Add the test, do not drop the mutation.

### Two operating rules

- **Never edit a file while a mutation script runs.** They mutate in place.
- **Never build or install while one runs** — the tree holds deliberately broken
  code, and the APK would carry it to the phone. Build from a clean detached
  worktree at the committed SHA instead.
- **After an interrupted run, `git status`.** A killed sweep leaves a mutated
  file and a `.orig` beside it. Verify the `.orig` matches HEAD before restoring.

---

## 3. The honesty layer, and how it is enforced

The product's premise is that *"not enough data" always beats an optimistic
guess*. That is enforced structurally, not by care.

- **`Reading<T>`** is a sealed union — `Present | Caveated | Withheld |
  Excluded`. A number cannot reach a screen without its confidence.
- **`LastKnown<T>` cannot be constructed without its day**, and is deliberately
  not a `Reading`, so "stale value shown as current" is unrepresentable rather
  than merely discouraged.
- **`withheld` is not `excluded`.** Withheld means we cannot price it *today*;
  excluded means nobody can, ever. Collapsing them loses a real distinction.
- **No widget takes a `Color`.** Tone comes from `ToneScope`, asserted by a
  source scan, so a hue cannot disagree with the family it sits in.
- **Citations live in the ⓘ, never as chips on a card.** A source-enumeration
  test names the only two files allowed to build a `CitationRow`.

### The two symmetric lies

**Stale-as-current** — new data shown under an old date, or an old judgement
shown as today's. Swept three times.

**Future leak** — an answer for a past day containing something measured or
computed *after* it. Introduced by the as-of-day work and guarded from the
start: every shared read primitive takes `on_or_before` as a **required**
argument, because a default would have been today and a caller that forgot would
silently get the unbounded behaviour back.

They are the same error in opposite directions. See `AS_OF_DAY.md`.

**A required argument beats a remembered rule.** So does a type that cannot
express the wrong thing. Reach for those before reaching for a comment.

---

## 4. Verifying against the design

- **Walk the prototype, do not grep it.** Three separate static reads produced
  wrong maps here — one attributed a file's links to another file's screen, and
  the error survived into a committed document. Serve it and click:
  `cd design/mobile-preview && python3 -m http.server 8765`.
- **A screenshot is evidence; an assertion is not.** The emoji arrow was
  "fixed" twice by reasoning and stayed broken both times. What settled it was
  looking at the phone.
- **A codepoint test cannot see a font.** It passed while the screen was wrong.
  Test the property that actually fails.
- **A derived check beats a listed one.** The font-coverage test was eight
  hand-written characters, added once and never extended — which is exactly why
  the arrow slipped through. It now walks `lib/` for every non-ASCII character
  in screen-bound strings. A list cannot cover what nobody thought to add.

---

## 5. Working with agents

- **Brief with the constraint, not just the task.** State the baseline, the
  honesty rules that bind, and the specific failure to avoid.
- **Require departures to be declared.** Quiet substitution is the failure;
  a stated departure with a reason is often the right call — three agents have
  correctly refused to build something as drawn and said why.
- **Do not trust the report — merge, then run the gates yourself.**
- **Efficiency is tool calls, not tokens.** Wall time is dominated by
  round-trips: read up front, batch writes, never re-read a file just edited,
  run the gates once at the end. One job went from 305 calls to 77 on this alone.
- **One agent at a time**, unless two jobs provably touch disjoint files — and
  prove it by comparing the actual changed set, not by assuming.

---

## 6. Contract snapshots

**Never regenerate them wholesale.** `packages/contracts/generate.py` seeds from
`now()`, so a full regeneration re-dates every payload and turns hundreds of
mobile tests red while changing nothing about the contract. Hand-apply the new
keys only. Recorded in `packages/contracts/README.md`.
