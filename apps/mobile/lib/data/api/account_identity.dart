import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_identity.g.dart';

/// Verified identity survives offline use, but never crosses a login namespace.
class AccountIdentity {
  const AccountIdentity({
    required this.ownerId,
    required this.timezone,
    required this.origin,
  });
  final String ownerId;
  final String timezone;
  final String origin;
  String get storageScope => '$origin|$ownerId';
}

@Riverpod(keepAlive: true)
Future<AccountIdentity> accountIdentity(Ref ref) async {
  final store = ref.watch(localStoreProvider);
  final api = await ref.watch(accountApiProvider.future);
  final key = 'account_identity:${api.sessionScope}';
  Map<String, Object?> data;
  try {
    data = await api.get('/api/account');
    await store
        .into(store.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion(name: Value(key), value: Value(jsonEncode(data))),
        );
  } on DioException catch (error, stack) {
    AppLog.failure('account', 'loading stable account identity', error, stack);
    await api.ensureCurrent();
    final row = await (store.select(
      store.syncMeta,
    )..where((row) => row.name.equals(key))).getSingleOrNull();
    if (row == null) rethrow;
    data = jsonDecode(row.value) as Map<String, Object?>;
  }
  await api.ensureCurrent();
  return AccountIdentity(
    ownerId: data['user_id']! as String,
    timezone: data['timezone']! as String,
    origin: api.origin,
  );
}
