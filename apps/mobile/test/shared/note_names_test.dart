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

Map<String, String> _corpusNames() {
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
  return <String, String>{
    for (final record in records.cast<Map<String, Object?>>())
      record['id']! as String: record['name']! as String,
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

  test('an unknown id resolves to null rather than a manufactured phrase', () {
    // `citation_row.dart` renders the id itself in this case and logs it. An app
    // older than the corpus should look behind, not fluent.
    expect(noteName('a_note_this_build_has_never_heard_of'), isNull);
    expect(noteName('sleep_need_debt'), 'Sleep need & cumulative sleep debt');
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
