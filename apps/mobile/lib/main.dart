/// Entry point. Wiring only — everything else lives where it belongs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/app.dart';
import 'package:healthee/core/licences.dart';
import 'package:healthee/core/provider_logger.dart';
import 'package:healthee/data/api/provider_retry.dart';
import 'package:refresh_rate/refresh_rate.dart';

void main() {
  // `enable()` talks to the platform over a Pigeon channel, so the binding has
  // to exist first. `runApp` would create it, but only after this line.
  WidgetsFlutterBinding.ensureInitialized();
  // **Opt into the panel's peak refresh rate.**
  //
  // Android hands an app 60 Hz on a 120 Hz panel unless the window asks for a
  // higher `preferredDisplayModeId`; the panel is already running at 120 for
  // the launcher, and the app is the thing being stepped down. This screen is
  // scrolled more than it is read — chart reveals, the day strip, every list —
  // and at 60 the reveal animations drop half their frames.
  //
  // It is a no-op on a display with one mode, and the call itself does not
  // throw on a platform without variable refresh: the plugin's own contract is
  // "has no effect on platforms that do not support variable refresh rates".
  // Nothing downstream reads a result, so there is nothing here to fail open.
  RefreshRate.enable();
  // The vendored font's SIL OFL notice, added to Flutter's own licence registry
  // so `showLicensePage` can find it. Registration is lazy — the stream is not
  // run until somebody opens the page — so this costs nothing at start-up, and
  // it has to happen before `runApp` because the registry is read from there on.
  registerAssetLicences();
  // The ProviderScope is the app's whole dependency graph. riverpod_lint's
  // `missing_provider_scope` fails the build if this is ever dropped.
  runApp(
    const ProviderScope(
      retry: apiProviderRetry,
      // Every provider failure reaches the one logging path from here, so no
      // repository has to remember to log its own.
      observers: [ProviderLogger()],
      child: HealtheeApp(),
    ),
  );
}
