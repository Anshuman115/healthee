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
/// The version comes from `features/settings/app_version.dart`, which explains
/// why it is read rather than written down and why the read is bounded. A host
/// that cannot answer gets the sentence saying so, never a number.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/features/settings/app_version.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The version, and the door to the licences.
class AboutSetting extends ConsumerWidget {
  /// The about row.
  const AboutSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Text(
            versionLine(ref.watch(appVersionProvider)),
            style: text.bodySmall?.copyWith(color: colors.ink2),
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

/// What the version line says for each state of the read.
///
/// Public so a test can pin the three sentences without pumping a widget. An
/// error and a null answer say the same thing on purpose: both mean *we do not
/// know which build this is*, and the difference between them is a fact about
/// the platform channel rather than about the owner's app.
String versionLine(AsyncValue<String?> version) => switch (version) {
  AsyncData(:final String value) => 'Version $value',
  AsyncData() => 'Version unavailable on this device',
  AsyncError() => 'Version unavailable on this device',
  _ => 'Reading the version…',
};
