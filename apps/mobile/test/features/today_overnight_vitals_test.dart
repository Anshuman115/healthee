/// **The two tiles that were withheld forever, and the shape of the fix.**
///
/// The Resp tile and the blood-oxygen module read `metrics`, and `metrics` is
/// built from `read/meta.py::TODAY_SECONDARY_METRICS` — seven slots, none of
/// them respiratory or SpO₂. So the lookup chain fell through every candidate,
/// found no recovery marker to rescue it, and returned an unexplained absence.
/// Both surfaces said *"No value for today, and the server did not say why"*
/// about numbers the same payload was carrying, and would have said it forever.
///
/// The contract snapshot is what proves this is not hypothetical: it is the
/// committed wire shape, its `metrics` array is exactly those seven ids, and its
/// `last_sleep_extras` carries `respiratory_rate: 14` and `spo2_avg: 97`. The
/// first test below asserts that combination directly, so the day the server
/// starts sending the cards it fails and this file gets simplified rather than
/// quietly outliving its reason.
///
/// The value arrives **caveated, not present**: `last_sleep_extras` is a raw
/// session average with no envelope, no provenance and no date, where the
/// derived metric is a bounded window mean. CLAUDE.md's one-definition rule is
/// what makes the difference matter, so the sentence naming the instrument is
/// part of the fix and is asserted here, not just the number.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/honesty/envelope.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/features/today/today_facts.dart';

import '../_today_stubs.dart';

/// The morning the fixture payload was received.
final DateTime _now = DateTime(2026, 8, 4, 9, 20);

TodayFacts _facts({
  Map<String, Object?> Function(Map<String, Object?> json)? mutate,
}) {
  final json = loadTodayJson();
  return TodayFacts.of(
    TodaySnapshot.fromJson(mutate == null ? json : mutate(json)),
    _now,
  );
}

void main() {
  test('THE PREMISE — the wire has the numbers and the metrics array has not', () {
    // If this ever fails it is good news: the server started sending the cards.
    final json = loadTodayJson();
    final ids = <String>[
      for (final card in json['metrics']! as List<Object?>)
        (card! as Map<String, Object?>)['metric']! as String,
    ];
    expect(ids, isNot(contains('respiratory_rate_sleep')));
    expect(ids, isNot(contains('spo2_overnight')));
    expect(ids, isNot(contains('spo2_sleep_avg')));

    final extras = json['last_sleep_extras']! as Map<String, Object?>;
    expect(extras['respiratory_rate'], isNotNull);
    expect(extras['spo2_avg'], isNotNull);
  });

  test('BOTH TILES CARRY A VALUE — they were withheld on this exact payload', () {
    final facts = _facts();
    expect(facts.respiratoryRate.valueOrNull, 14);
    expect(facts.bloodOxygen.valueOrNull, 97);
  });

  test('MUTATION — remove the overnight block and both go back to withheld', () {
    // This is the assertion that makes the one above mean something. Deleting
    // `last_sleep_extras` restores the pre-fix payload shape exactly, and both
    // surfaces must return to the state the bug had them in — which also proves
    // no OTHER source is quietly supplying these two.
    final facts = _facts(
      mutate: (json) => <String, Object?>{...json}..remove('last_sleep_extras'),
    );
    expect(facts.respiratoryRate, isA<Withheld<double>>());
    expect(facts.bloodOxygen, isA<Withheld<double>>());
    expect(
      (facts.respiratoryRate as Withheld<double>).disclosure.reason,
      unexplainedAbsenceReason,
    );
  });

  test('THE INSTRUMENT IS NAMED — the value is caveated, never bare', () {
    // "Keep the instrument naming honest": this number is a plain average over
    // a sleep session, not the bounded daily figure the working tiles show, and
    // it is not today's. A `Present` here would be the honest bug replacing the
    // dishonest one.
    final resp = _facts().respiratoryRate;
    expect(resp, isA<Caveated<double>>());
    final disclosure = (resp as Caveated<double>).caveats.single;
    expect(disclosure.reason, 'overnight_session_mean');
    expect(disclosure.message, contains('sleep session'));
    expect(disclosure.message, contains('average'));
    expect(
      disclosure.message,
      contains('not today'),
      reason: 'an overnight figure on a card labelled today must say so',
    );
  });

  test('the caveat DATES the night it came from', () {
    // The block carries no date of its own — the session's does that job. A
    // reading from three nights ago must not read as last night's.
    final stale = TodayFacts.of(
      TodaySnapshot.fromJson(loadTodayJson()),
      _now.add(const Duration(days: 3)),
    );
    final message =
        (stale.respiratoryRate as Caveated<double>).caveats.single.message;
    expect(message, contains('nights ago'));
    expect(message, isNot(contains('last night')));
  });

  test('A DERIVED CARD STILL WINS — the fallback is last, not first', () {
    // The fix must disappear on its own the day the server adds the metric. If
    // the overnight block took precedence, a bounded derived value would be
    // shadowed by a raw session mean and the two definitions would swap
    // silently — the failure CLAUDE.md's one-definition rule names.
    final facts = _facts(
      mutate: (json) => <String, Object?>{
        ...json,
        'metrics': <Object?>[
          ...json['metrics']! as List<Object?>,
          <String, Object?>{
            'metric': 'respiratory_rate_sleep',
            'label': 'Respiratory rate',
            'value': 16,
          },
        ],
      },
    );
    expect(facts.respiratoryRate.valueOrNull, 16);
    expect(
      facts.respiratoryRate,
      isA<Present<double>>(),
      reason: 'a real derived card needs no instrument caveat',
    );
  });

  test('a WITHHELD derived card is still a refusal, not a fallback', () {
    // The other precedence question, and the one that could quietly defeat a
    // server-side gate: if the server refuses to report a value, an unbounded
    // raw average must not walk in behind it. `_chain` returns the recorded
    // refusal, so the withhold survives.
    final facts = _facts(
      mutate: (json) => <String, Object?>{
        ...json,
        'metrics': <Object?>[
          ...json['metrics']! as List<Object?>,
          <String, Object?>{
            'metric': 'spo2_overnight',
            'label': 'Blood oxygen',
            'value': null,
            'withheld': <String, Object?>{
              'reason': 'too_few_samples',
              'message': 'Not enough overnight samples to report this.',
            },
          },
        ],
      },
    );
    expect(facts.bloodOxygen, isA<Withheld<double>>());
    expect(
      (facts.bloodOxygen as Withheld<double>).disclosure.reason,
      'too_few_samples',
    );
  });

  test('an EMPTY overnight block renders nothing rather than a zero', () {
    // The governing rule: a null or empty field renders NOTHING. `last_sleep`
    // exists here, so this is the shape where the session was staged but the
    // strap sampled no physiology.
    final facts = _facts(
      mutate: (json) => <String, Object?>{
        ...json,
        'last_sleep_extras': const <String, Object?>{},
      },
    );
    expect(facts.respiratoryRate, isA<Withheld<double>>());
    expect(facts.bloodOxygen, isA<Withheld<double>>());
    expect(facts.respiratoryRate.valueOrNull, isNull);
  });

  test('one vital present and the other absent does not carry the other', () {
    // Two independent keys read independently. Sharing a `hasValue` between
    // them would put last night's breathing rate under the SpO₂ figure.
    final facts = _facts(
      mutate: (json) => <String, Object?>{
        ...json,
        'last_sleep_extras': <String, Object?>{
          ...json['last_sleep_extras']! as Map<String, Object?>,
          'spo2_avg': null,
        },
      },
    );
    expect(facts.respiratoryRate.valueOrNull, 14);
    expect(facts.bloodOxygen, isA<Withheld<double>>());
  });
}
