import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/completion_ledger.dart';
import 'package:healthee/data/store/local_store.dart';

void main() {
  test('initial history is quiet; failed deliveries retry until acknowledged', () async {
    final store = LocalStore.memory();
    addTearDown(store.close);
    final ledger = CompletionLedger(store, 'owner');
    expect(await ledger.takeNew([challenge(1)]), isEmpty);
    expect(await ledger.takeNew([challenge(1), challenge(2)], acknowledge: false), hasLength(1));
    expect(await ledger.takeNew([challenge(2)], acknowledge: false), hasLength(1));
    await ledger.takeNew([challenge(2)]);
    expect(await ledger.takeNew([challenge(2)]), isEmpty);
    expect(await ledger.takeNew([challenge(3, status: 'abandoned')]), isEmpty);
    expect(await CompletionLedger(store, 'other').takeNew([challenge(2)]), isEmpty);
    expect(await CompletionLedger(store, 'owner', channel: 'notify').takeNew([challenge(2)]), isEmpty);
  });
}

Challenge challenge(int id, {String status = 'completed'}) => Challenge(
  id: id, title: 'Recorded challenge', why: '', status: status,
  metric: 'steps', target: 100, comparator: 'gte', cadence: 'daily',
  windowDays: 7, difficulty: 'easy', kind: 'habit', citations: [],
);
