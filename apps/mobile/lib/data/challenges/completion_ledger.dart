import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/store/local_store.dart';

/// First observation seeds history. Only new server-confirmed successes celebrate.
class CompletionLedger {
  const CompletionLedger(this.store, this.owner, {this.channel = 'celebrate'});
  final LocalStore store;
  final String owner;
  final String channel;
  String get key =>
      '$channel:${sha256.convert(utf8.encode(owner)).toString().substring(0, 32)}';
  Future<List<Challenge>> takeNew(
    List<Challenge> recent, {
    bool acknowledge = true,
  }) => store.transaction(() async {
    final completed = recent.where((c) => c.status == 'completed').toList();
    final row = await (store.select(
      store.syncMeta,
    )..where((r) => r.name.equals(key))).getSingleOrNull();
    final seen = row == null
        ? <int>{}
        : (jsonDecode(row.value) as List<Object?>).cast<int>().toSet();
    final fresh = row == null
        ? <Challenge>[]
        : completed.where((c) => !seen.contains(c.id)).toList();
    if (acknowledge || row == null) seen.addAll(completed.map((c) => c.id));
    // The feed is bounded; retain the latest 1000 ids to bound device metadata.
    final ids = seen.toList()..sort();
    await store
        .into(store.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion(
            name: Value(key),
            value: Value(
              jsonEncode(
                ids.skip(ids.length > 1000 ? ids.length - 1000 : 0).toList(),
              ),
            ),
          ),
        );
    return fresh;
  });
}
