/// The stored conversations, read for the history screen.
library;

import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/coach/coach_history_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'coach_history_provider.g.dart';

/// Every conversation this sign-in has had on this device, most recent first.
///
/// Scoped through `CacheSession` like every other local read: a provider that
/// forgot to would hand a second owner on one handset the first owner's threads.
@riverpod
Future<List<CoachThreadSummary>> coachThreads(Ref ref) async {
  final session = await CacheSession.capture(ref.watch(credentialsProvider));
  return CoachHistoryStore(
    ref.watch(localStoreProvider),
  ).threads(session.scope);
}
