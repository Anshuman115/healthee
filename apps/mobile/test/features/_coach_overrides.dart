/// The two providers every coach-screen bed has to stand in for.
///
/// Both exist because the coach now touches the DEVICE: its head asks whether
/// there are past conversations, and its controller writes each turn as it
/// lands. Neither is mocked away — `localStoreProvider` is given a real
/// in-memory database, so turns are genuinely written and read back; it just
/// does not reach for a file a widget test never set up.
///
/// Shared rather than pasted into each bed: four copies of a list of overrides
/// is four places to forget the next one, and the symptom of forgetting is a
/// `pumpAndSettle` timeout in a test about something else entirely.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/coach/coach_client.dart';
import 'package:healthee/data/coach/coach_history_store.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/features/coach/coach_history_provider.dart';

/// Wraps [child] in a scope with the coach's client and the device overrides.
///
/// Returns the SCOPE rather than a list of overrides: riverpod's override type
/// is not exported under a name this file can write, and inside `overrides:` the
/// analyser infers it. A bed should not have to know that either way.
Widget coachScope({required CoachClient client, required Widget child}) =>
    ProviderScope(
      overrides: [
        coachClientProvider.overrideWithValue(client),
        coachThreadsProvider.overrideWith(
          (ref) async => <CoachThreadSummary>[],
        ),
        localStoreProvider.overrideWith((ref) {
          final store = LocalStore.memory();
          ref.onDispose(store.close);
          return store;
        }),
      ],
      child: child,
    );
