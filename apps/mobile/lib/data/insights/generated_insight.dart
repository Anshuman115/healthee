import 'package:healthee/data/models/sleep_insight.dart';

/// Validated prose or an explicit refusal; unvalidated generated claims stay hidden.
class GeneratedInsight {
  const GeneratedInsight({
    required this.text,
    required this.citations,
    this.date,
    this.gradeFloor,
  });

  factory GeneratedInsight.fromJson(Map<String, Object?> json) {
    final mayShow = json['validated'] == true || json['refused'] == true;
    final parsed = SleepInsight.fromJson(json);
    return GeneratedInsight(
      text: mayShow ? parsed.text : '',
      citations: parsed.citations,
      gradeFloor: parsed.gradeFloor,
      date: json['date'] as String?,
    );
  }
  final String text;
  final List<String> citations;
  final String? date;
  final String? gradeFloor;
}
