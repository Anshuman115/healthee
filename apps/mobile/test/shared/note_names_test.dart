/// The app's source names are the CORPUS's source names, and cannot drift.
///
/// `lib/shared/format/note_names.dart` is generated from
/// `packages/knowledge/manifest.json`, which is itself generated from the notes.
/// The failure this file exists to catch is the app quietly disagreeing with the
/// corpus about what a note is called — a note renamed, retired or added on the
/// server side, with the phone still showing yesterday's title beside today's
/// claim.
///
/// It reads the manifest **out of the repo**, not a vendored copy, for the same
/// reason `today_snapshot_golden_test.dart` reads the contract snapshot that way:
/// a copy goes green while the thing it copies moves.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/format/note_names.dart';

/// The corpus manifest, relative to `apps/mobile` — `flutter test`'s cwd.
const String _manifestPath = '../../packages/knowledge/manifest.json';

const String _howToFix =
    'Run `python3 tool/gen_note_names.py` from apps/mobile and commit the '
    'result. The corpus owns these names; the app transcribes them.';

List<Map<String, Object?>> _records() {
  final file = File(_manifestPath);
  if (!file.existsSync()) {
    fail(
      'Corpus manifest not found at $_manifestPath '
      '(cwd ${Directory.current.path}).',
    );
  }
  final records =
      (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['records']!
          as List<Object?>;
  return records.cast<Map<String, Object?>>();
}

Map<String, String> _corpusNames() => <String, String>{
  for (final record in _records())
    record['id']! as String: record['name']! as String,
};

/// The same rule the generator applies: id-shaped, not itself an id, and owned
/// by exactly one note. Written out rather than imported, so this is a check and
/// not a restatement.
Map<String, String> _corpusAliases() {
  final records = _records();
  final ids = <String>{for (final record in records) record['id']! as String};
  final shaped = RegExp(r'^[a-z0-9_]+$');
  final owners = <String, Set<String>>{};
  for (final record in records) {
    for (final alias in (record['aliases'] as List? ?? const []).cast<String>()) {
      if (shaped.hasMatch(alias) && !ids.contains(alias)) {
        owners.putIfAbsent(alias, () => <String>{}).add(record['id']! as String);
      }
    }
  }
  return <String, String>{
    for (final entry in owners.entries)
      if (entry.value.length == 1) entry.key: entry.value.single,
  };
}

void main() {
  test('EVERY NOTE IN THE CORPUS HAS ITS OWN NAME IN THE APP', () {
    expect(kNoteNames, _corpusNames(), reason: _howToFix);
  });

  test('the table names nothing the corpus does not have', () {
    // The other direction, stated separately so a failure says which way it
    // went: an entry with no note behind it is a name the app invented.
    expect(kNoteNames.keys.toSet(), _corpusNames().keys.toSet(), reason: _howToFix);
  });

  test('THE ALIAS TABLE IS THE CORPUS’S, AND NEVER AMBIGUOUS', () {
    expect(kNoteAliases, _corpusAliases(), reason: _howToFix);
    for (final target in kNoteAliases.values) {
      expect(kNoteNames, contains(target), reason: '$target is not a note');
    }
  });

  test('THE IDS THE SERVER ACTUALLY CITES ALL RESOLVE', () {
    // Not hypothetical: `read/activity.py` cites `cardio_load_trimp` and
    // `read/vo2max.py` cites `vo2max_fitness_mortality`. Neither is a note id —
    // both are aliases — and an ids-only table left them on screen as raw
    // snake_case, which is the whole defect.
    expect(noteName('cardio_load_trimp'), isNotNull);
    expect(noteName('vo2max_fitness_mortality'), isNotNull);
    expect(canonicalNoteId('cardio_load_trimp'), 'training_stress_score');
    expect(canonicalNoteId('vo2max_fitness_mortality'), 'vo2max');
  });

  test('an unknown id resolves to null rather than a manufactured phrase', () {
    // `citation_row.dart` renders the id itself in this case and logs it. An app
    // older than the corpus should look behind, not fluent.
    expect(noteName('a_note_this_build_has_never_heard_of'), isNull);
    expect(noteName('sleep_need_debt'), 'Sleep need & cumulative sleep debt');
    expect(canonicalNoteId('sleep_need_debt'), 'sleep_need_debt');
  });

  test('no name is a snake_case id wearing a name-shaped label', () {
    // The defect these chips had: `recovery_readiness` on screen. A generated
    // table cannot reintroduce it unless the corpus does, and this says so.
    for (final entry in kNoteNames.entries) {
      expect(
        entry.value,
        isNot(matches(r'^[a-z0-9_]+$')),
        reason: '${entry.key} has no real name in the corpus',
      );
    }
  });
}
