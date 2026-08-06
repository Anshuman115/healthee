/// Which build this is — read from the platform, bounded, and injectable.
///
/// ## Read, never written down
///
/// `package_info_plus` reports the version this binary was actually built with.
/// A constant in `core/env.dart` would have been a second definition of the
/// number in `pubspec.yaml`, and the copy that goes stale is always the one on
/// screen — in the row whose entire job is to say which build the owner is
/// running when they report something.
///
/// ## Bounded, because an unanswered channel has no other end
///
/// On a host with no plugin registrant the channel message goes out and nothing
/// ever comes back — the About row sat on "Reading the version…" for the life of
/// the process. That is the small version of the failure this whole app is built
/// against, so the read has a deadline and the deadline is an *answer*: we do not
/// know which build this is. Every failure is named, logged through the one
/// logging path (Standards §3) and produces the same honest null. None of them
/// produces a made-up number.
///
/// ## A provider, not a bare function
///
/// Standards §3: "everything injectable via providers (testability is the
/// point)". It is also the difference between a widget test that overrides one
/// provider and a widget test that has to pump past a three-second timer it did
/// not ask for.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:healthee/core/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version.g.dart';

/// How long the platform is given to name its own build.
///
/// Generous — this is a label, not a read path — and finite, because there is no
/// other end to an unanswered channel message.
const Duration kVersionTimeout = Duration(seconds: 3);

/// `0.1.0 (1)`, or null when this host cannot report one.
@riverpod
Future<String?> appVersion(Ref ref) async {
  try {
    final info = await PackageInfo.fromPlatform().timeout(kVersionTimeout);
    return '${info.version} (${info.buildNumber})';
  } on MissingPluginException {
    // No plugin registrant. Not a failure of the app, and not a reason to show
    // a made-up number.
    AppLog.info('settings', 'no package_info plugin on this host');
    return null;
  } on TimeoutException {
    AppLog.info('settings', 'the platform did not answer with its version');
    return null;
  } on PlatformException catch (error, stackTrace) {
    AppLog.failure('settings', 'reading the app version', error, stackTrace);
    return null;
  }
}
