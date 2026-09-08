/// The opening messages this app writes on the owner's behalf.
///
/// Three surfaces link to the coach **about something** — `Ask about this
/// trend`, `Discuss this workout`, `Talk this through` — and each opens the
/// coach with the subject already written into the input as the first user
/// turn. That turn is a sentence the app puts in the owner's mouth, which is why
/// all three live in one file instead of being composed at their call sites:
/// they are read as the owner's own words, and a claim smuggled into one of them
/// would be this product asserting something in the owner's voice.
///
/// The same string is also sent to the server as `POST /api/coach`'s optional
/// `topic`, where it is used to rank the context and the evidence. That makes
/// the rule below stricter rather than looser: a sentence here is now read by a
/// person AND by a retrieval ranker, and in neither place is it allowed to be a
/// claim. The server enforces its own half — it screens the topic with the
/// refusal gate and fences it as a label — but a topic that characterised
/// instead of naming would still be this app asserting something.
///
/// **They therefore name and never characterise.** Each one carries the thing
/// the owner tapped — a metric's name, a session's sport and date, a finding's
/// own title — and asks an open question about it. None says the trend is
/// improving, the session was good, or the pattern is real; the coach's job is
/// to answer that, against the corpus, with its own grade floor attached.
///
/// The owner sees every one of them in the input before anything is sent
/// (`coach_screen.dart`), so a sentence they would not have written is a
/// sentence they can edit or delete.
library;

import 'package:healthee/shared/format/metric_names.dart';

/// `Ask about this trend` — [metric] is the canonical id the screen is showing.
///
/// [metricName], not [metricTitle]: this is a metric inside a sentence, which is
/// the position that table is cased for. Lower-casing the heading form instead
/// would have written `vo2max` and `hrv` in the owner's own question.
String trendTopic(String metric) =>
    'What should I notice in my ${metricName(metric)} trend?';

/// `Discuss this workout` — [sport] and [date] are the session's own two facts.
///
/// The date is the short form the screen's own eyebrow prints, so the question
/// names the session the owner is looking at and not a different one.
String workoutTopic({required String sport, required String date}) =>
    'What should I take from my $sport session on $date?';

/// `Talk this through` — [title] is `findingTitle`, which ends in a full stop.
///
/// The trailing stop is trimmed rather than left mid-sentence; nothing else
/// about the title is touched, because it is the pair the analysis actually
/// found and rewording it here would be a second name for one finding. The
/// title is quoted after a colon rather than inlined, so the generic form
/// (*"A pattern in your own data."*, which `findingTitle` returns when the
/// server named neither metric) still reads as a sentence.
String findingTopic(String title) {
  final String subject = title.endsWith('.')
      ? title.substring(0, title.length - 1)
      : title;
  return 'Talk me through this pattern in my own data: $subject.';
}
