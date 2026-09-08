/// One generated insight card's payload.
///
/// ## Why nothing is suppressed here any more
///
/// This used to blank the text unless `validated` or `refused` was true. That
/// looks like a safety gate and was not one: `validated: false, refused: false`
/// is the **honest fallback** — `insights/prompts.py::FALLBACK`, *"I can't
/// ground that in our evidence base right now, so I'd rather not guess…"* — and
/// it is a sentence this product wrote, not the model.
///
/// The server has no branch that ships a model's unvalidated text.
/// `insights/grounded.py::_result` replaces the candidate with `FALLBACK` on
/// `not validated`, a hard output guardrail returns its own fixed response, and
/// a pre-LLM refusal returns a refusal template — three of our own strings and
/// no fourth case. So the field this parsed was never carrying an ungrounded
/// claim, and blanking it deleted the one answer the whole honesty layer exists
/// to be able to give, leaving an empty card where a plain "not enough
/// evidence" belonged. Standards section 3 asks every async consumer to render loading,
/// error and empty; this was none of those — it was an answer.
///
/// `validated` rides along so the card can *frame* the fallback rather than
/// present it as a finding. It qualifies the sentence; it no longer censors it.
library;

import 'package:healthee/data/models/sleep_insight.dart';

/// Validated prose, a refusal, or the honest fallback — all of them shown.
class GeneratedInsight {
  const GeneratedInsight({
    required this.text,
    required this.citations,
    required this.validated,
    this.date,
    this.gradeFloor,
  });

  factory GeneratedInsight.fromJson(Map<String, Object?> json) {
    final parsed = SleepInsight.fromJson(json);
    return GeneratedInsight(
      text: parsed.text,
      citations: parsed.citations,
      // Absent means "this surface does not say", and the strict reading of a
      // missing flag is that the text is not claimed to be validated.
      validated: json['validated'] == true,
      gradeFloor: parsed.gradeFloor,
      date: json['date'] as String?,
    );
  }
  final String text;
  final List<String> citations;

  /// Whether the server's blocking validator passed this text.
  ///
  /// False means [text] is one of our own sentences — the honest fallback, a
  /// refusal template or a guardrail's fixed response — never the model's own
  /// claim. It is a reason to say so beside the sentence, not a reason to hide it.
  final bool validated;
  final String? date;
  final String? gradeFloor;
}
