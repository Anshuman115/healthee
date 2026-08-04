/// The root widget: theme, router, nothing else.
///
/// Separate from `main.dart` so tests can pump the app without going through
/// `runApp` — a widget test builds [HealtheeApp] directly inside its own
/// `ProviderScope` and can override any provider on the way in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/theme_controller.dart';

/// The Healthee app.
class HealtheeApp extends ConsumerStatefulWidget {
  /// Builds the app.
  const HealtheeApp({super.key});

  @override
  ConsumerState<HealtheeApp> createState() => _HealtheeAppState();
}

class _HealtheeAppState extends ConsumerState<HealtheeApp> {
  // Built once and held: a GoRouter rebuilt on every frame loses its navigation
  // stack, which shows up as the back button doing nothing.
  late final GoRouter _router = buildRouter(ref);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Healthee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeControllerProvider),
      routerConfig: _router,
    );
  }
}
