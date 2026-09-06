import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';

/// Shared entry point from daily actions and settings.
class JournalLink extends StatelessWidget {
  const JournalLink({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.edit_note),
    title: const Text('Health journal'),
    subtitle: const Text('Log habits, weight, exercise and how you feel'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => unawaited(context.push(Routes.journal)),
  );
}
