import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';

/// Opens one metric's own dated series — every panel's `Details` action.
///
/// `H.panel(…, 'metric/:key')` in the prototype, and six screens reach it: the
/// three tabs that carry panels, and the three detail screens that carry dated
/// ones on a past day. Six copies of one URL is six chances for one of them to
/// forget the encoding, which is why it is a function (Standards section 1).
void openMetricHistory(BuildContext context, String metric) => unawaited(
  context.push('${Routes.history}?metric=${Uri.encodeComponent(metric)}'),
);

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
