import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/journal/journal_repository.dart';
import 'package:healthee/features/journal/widgets/journal_editor.dart';
import 'package:healthee/shared/states/async_view.dart';
import 'package:healthee/shared/states/current_account_value.dart';

/// Legacy quick logging, with retained drafts until the server acknowledges.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Health journal')),
    body: Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: AsyncView<ServerSessionStatus>(
        value: currentAccountValue(ref.watch(serverSessionProvider)),
        onRetry: () => ref.invalidate(serverSessionProvider),
        builder: (context, status) => status.signedIn
            ? _editor(ref)
            : Center(
                child: FilledButton(
                  onPressed: () => unawaited(context.push(Routes.serverSignIn)),
                  child: const Text('Sign in to save your journal'),
                ),
              ),
      ),
    ),
  );

  Widget _editor(WidgetRef ref) => AsyncView<JournalRepository>(
    value: currentAccountValue(ref.watch(journalRepositoryProvider)),
    onRetry: () => ref.invalidate(journalRepositoryProvider),
    builder: (context, repository) =>
        JournalEditor(key: ObjectKey(repository), repository: repository),
  );
}
