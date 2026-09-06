import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';

/// Opens the bounded daily history browser.
class HistoryLink extends StatelessWidget {
  const HistoryLink({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.show_chart),
    title: const Text('Metric history'),
    subtitle: const Text('Explore 30 days to 5 years'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => unawaited(context.push(Routes.history)),
  );
}
