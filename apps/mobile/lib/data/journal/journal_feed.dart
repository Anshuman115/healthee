import 'package:healthee/data/journal/journal_entry.dart';

/// The server's recent observations and current fasting state.
class JournalFeed {
  const JournalFeed({
    required this.entries,
    required this.fastOpen,
    this.fastMinutes,
  });

  factory JournalFeed.fromJson(Map<String, Object?> json) {
    final fast = json['fast']! as Map<String, Object?>;
    final current = fast['current'] as Map<String, Object?>?;
    return JournalFeed(
      entries: [
        for (final entry in json['entries']! as List<Object?>)
          JournalEntry.fromJson(entry! as Map<String, Object?>),
      ],
      fastOpen: fast['open']! as bool,
      fastMinutes: (current?['duration_min'] as num?)?.toInt(),
    );
  }

  final List<JournalEntry> entries;
  final bool fastOpen;
  final int? fastMinutes;
}
