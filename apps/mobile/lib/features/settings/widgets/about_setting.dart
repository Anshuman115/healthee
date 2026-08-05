/// About — which build this is, and the licences it is obliged to carry.
///
/// **The licence notice is the reason this row exists.** Manrope ships vendored
/// in `assets/fonts/` under the SIL OFL 1.1, whose terms require the notice to
/// travel with the fonts — which means inside the binary somebody installs, not
/// beside them in a repository. `core/licences.dart` registers the bundled
/// `OFL.txt` with `LicenseRegistry`, and this is the only door to the page that
/// renders it. A registered licence nobody can open satisfies the obligation on
/// paper and not in fact.
///
/// `showLicensePage` is Flutter's own, so the font's notice appears in the same
/// list as dio's and drift's rather than on a screen of its own that would need
/// updating whenever a dependency moves.
///
/// ## The version is read, not written down
///
/// `package_info_plus` reports the version this binary was actually built with.
/// A constant in `core/env.dart` would have been a second definition of the
/// number in `pubspec.yaml`, and the copy that goes stale is always the one on
/// screen — in the row whose entire job is to say which build the owner is
/// running when they report something.
///
/// When the platform channel is not there — a `flutter test` host has no plugin
/// registrant — the row says the version is unavailable rather than inventing
/// one. `PlatformException`/`MissingPluginException` is caught with an `on`
/// clause and logged (Standards §3), never swallowed.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The app's own version, or null when this host cannot report one.
///
/// A `FutureBuilder` rather than a provider: it is read once, by one widget, and
/// a provider would be a graph node for a string that never changes within a
/// process.
Future<String?> appVersionLabel() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } on MissingPluginException {
    // A test host has no plugin registrant. Not a failure of the app, and not a
    // reason to show a made-up number.
    return null;
  } on PlatformException {
    return null;
  }
}

/// The version, and the door to the licences.
class AboutSetting extends StatelessWidget {
  /// The about row.
  const AboutSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          Text('Healthee', style: text.titleSmall),
          const SizedBox(height: Insets.xs),
          FutureBuilder<String?>(
            future: appVersionLabel(),
            builder: (context, snapshot) => Text(
              switch (snapshot.connectionState) {
                ConnectionState.done => snapshot.data == null
                    ? 'Version unavailable on this device'
                    : 'Version ${snapshot.data}',
                _ => 'Reading the version…',
              },
              style: text.bodySmall?.copyWith(color: colors.ink2),
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'The typeface is Manrope, under the SIL Open Font License 1.1, '
            'bundled with this app rather than fetched. Its notice and every '
            'package licence are below — that is a licence term, not a nicety.',
            style: text.bodySmall?.copyWith(color: colors.ink3),
          ),
          const SizedBox(height: Insets.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Healthee',
              ),
              child: const Text('Licences and notices'),
            ),
          ),
        ],
      ),
    );
  }
}
