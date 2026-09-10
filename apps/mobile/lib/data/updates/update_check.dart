/// Is there a newer build, and can we even say?
///
/// Three answers, not two. "Up to date" and "an update is available" are claims
/// about the world; "we could not check" is the honest third that every offline
/// phone, rate limit and unparseable release falls into. Collapsing it into
/// "up to date" would be the app reassuring somebody about something it does not
/// know, which is the failure this whole product is built against.
///
/// The comparison itself is `AppRelease.isNewerThan` — Android's own rule, on the
/// `versionCode`. See that file for why the version NAME is shown but never
/// decided on.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/updates/app_release.dart';
import 'package:healthee/data/updates/release_client.dart';
import 'package:meta/meta.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_check.g.dart';

/// How long the platform is given to name this build, mirroring `app_version`.
const Duration kBuildNumberTimeout = Duration(seconds: 3);

/// What the app knows about whether it is current.
@immutable
sealed class UpdateStatus {
  /// Const base.
  const UpdateStatus();
}

/// A newer build exists and would install over this one.
@immutable
final class UpdateAvailable extends UpdateStatus {
  /// Wraps the release to offer.
  const UpdateAvailable(this.release);

  /// The release the owner would be moving to.
  final AppRelease release;
}

/// This build is the latest published one.
@immutable
final class UpToDate extends UpdateStatus {
  /// Nothing to carry.
  const UpToDate();
}

/// The check could not be made, and this app will not guess which way.
@immutable
final class UpdateUnknown extends UpdateStatus {
  /// Nothing to carry: the CAUSE is in the log, and the owner's options are the
  /// same whichever it was.
  const UpdateUnknown();
}

/// This build's `versionCode`, or null when the platform will not say.
///
/// The same bounded read as `settings/app_version.dart` and for the same reason:
/// on a host with no plugin registrant the channel message goes out and nothing
/// comes back, so the read has a deadline and the deadline is an answer.
Future<int?> currentBuildNumber() async {
  try {
    final info = await PackageInfo.fromPlatform().timeout(kBuildNumberTimeout);
    return int.tryParse(info.buildNumber);
  } on MissingPluginException {
    AppLog.info('updates', 'no package_info plugin on this host');
    return null;
  } on TimeoutException {
    AppLog.info('updates', 'the platform did not answer with its build number');
    return null;
  } on PlatformException catch (error, stackTrace) {
    AppLog.failure('updates', 'reading the build number', error, stackTrace);
    return null;
  }
}

/// Compares [current] against [release] into one of the three answers.
///
/// Pure, so the decision can be asserted without a platform channel or a network.
UpdateStatus statusFor({required int? current, required AppRelease? release}) {
  if (current == null || release == null) {
    return const UpdateUnknown();
  }
  return release.isNewerThan(current)
      ? UpdateAvailable(release)
      : const UpToDate();
}

/// Whether a newer build is published. Never throws; unknown is an answer.
@riverpod
Future<UpdateStatus> updateStatus(Ref ref) async {
  final client = ReleaseClient(ReleaseClient.dioFor());
  ref.onDispose(client.close);
  final current = await currentBuildNumber();
  // Asked even when the build number is unknown, so the log says which half
  // failed. A check that stops at the first missing piece cannot tell an offline
  // phone from a host with no plugin registrant.
  final release = await client.latest();
  final status = statusFor(current: current, release: release);
  AppLog.info(
    'updates',
    'update check: ${status.runtimeType} (this build $current, '
        'latest ${release?.versionCode})',
  );
  return status;
}
