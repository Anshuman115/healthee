import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/problem_message.dart';
import 'package:healthee/data/api/server_snapshot.dart';
import 'package:healthee/data/store/local_store.dart';

/// Cache-first reads; authorization refusals remove the displayed cached result.
Stream<ServerSnapshot<T>> cachedAccountRead<T>({
  required AccountApi api,
  required LocalStore store,
  required String path,
  required String key,
  required T Function(Map<String, Object?>) parse,
}) async* {
  final cached = await store.readLatest(key, scope: api.sessionScope);
  await api.ensureCurrent();
  T? previous;
  if (cached != null) {
    final parsed = parse(jsonDecode(cached.payload) as Map<String, Object?>);
    previous = parsed;
    yield ServerSnapshot(parsed, fetchedAt: cached.fetchedAt, stale: true);
  }
  try {
    final response = await api.get(path);
    final data = parse(response);
    final now = DateTime.now();
    await api.ensureCurrent();
    // Feed caches have no single health-data day. This is the local fetch day,
    // used solely for the existing 60-day cache retention policy.
    await store.write(
      metric: key,
      day: isoDay(now),
      payload: jsonEncode(response),
      fetchedAt: now,
      scope: api.sessionScope,
    );
    await api.ensureCurrent();
    yield ServerSnapshot(data, fetchedAt: now);
  } on DioException catch (error, stack) {
    AppLog.failure('cache', 'refreshing $key', error, stack);
    await api.ensureCurrent();
    if ({401, 402, 403}.contains(error.response?.statusCode)) {
      await (store.delete(store.cachedPayloads)..where(
        (row) => row.scope.equals(api.sessionScope) & row.metric.equals(key),
      )).go();
      rethrow;
    }
    if (previous == null) rethrow;
    yield ServerSnapshot(
      previous,
      fetchedAt: cached!.fetchedAt,
      stale: true,
      refreshError: apiProblem(error),
    );
  }
}
