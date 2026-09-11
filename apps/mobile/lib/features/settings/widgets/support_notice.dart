/// Where to support this, on the screen that already says who made it.
///
/// ## On About, and nowhere else
///
/// Not Today, not Actions, not a banner. A donation prompt on the screen somebody
/// opened to read their recovery score makes a health app feel like it wants
/// something from them — which is exactly the posture this product is built
/// against. About is where "which build is this, who made it, how do I support
/// it" already belongs, and somebody reading that page is already asking.
///
/// ## It says what the money does NOT buy
///
/// There is no paid tier and nothing behind a wall — `SELF_HOST_UNLOCKED` exists
/// so a self-hoster paying their own AI bill gets the whole product. Saying so
/// beside the link matters more than the link: an ask that leaves the reader
/// wondering whether they are missing features is an ask that has quietly
/// invented a paid tier.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where one-off and recurring support goes.
const String kKofiUrl = 'https://ko-fi.com/afkcodes';

/// The project's own page, on a domain it controls.
const String kSponsorUrl = 'https://afk.codes/sponsor';

/// The sentence that keeps the ask honest. Public so a test can pin it.
const String kSupportBody =
    'Healthee is free and has no paid tier. Nothing here is behind a wall and '
    'nothing unlocks — support pays for hosting and research time.';

/// The heading the prominent card carries. Public so a test can pin it.
const String kSupportHeading = 'Keep Healthee free';

/// The louder form, for the top of the profile screen.
///
/// Same two destinations and the same honesty line as [SupportNotice] — one set of
/// constants, so the repository, the About screen and this cannot drift apart and
/// send somebody to an account nobody watches.
///
/// ⚠ It is the FIRST thing on that screen, which is a real cost: it pushes the
/// owner's own details down. That is a deliberate choice and not an accident of
/// layout — the ask only works if people see it. It stays off Today, Sleep,
/// Activity and Actions, which are the screens somebody opens to read a number
/// about their body; a donation card above a recovery score is a health app
/// wanting something from you at the moment you are most vulnerable to it.
class SupportCard extends StatelessWidget {
  /// Const constructor.
  const SupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(SolarIconsBold.heart, color: colors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  kSupportHeading,
                  style: FormType.heading3.copyWith(color: colors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SmallProse(kSupportBody),
          const SizedBox(height: 14),
          HButton(
            label: 'Support on Ko-fi',
            onPressed: () => unawaited(SupportNotice.open(kKofiUrl)),
          ),
          const SizedBox(height: 8),
          HLinkButton(
            label: 'Other ways to support',
            onPressed: () => unawaited(SupportNotice.open(kSponsorUrl)),
          ),
        ],
      ),
    );
  }
}

/// The support block: what it does not buy, then the two ways to give.
class SupportNotice extends StatelessWidget {
  /// Const constructor.
  const SupportNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          kSupportBody,
          style: FormType.fieldHint.copyWith(color: colors.ink3),
        ),
        const SizedBox(height: 12),
        HButton(
          label: 'Support on Ko-fi',
          kind: HButtonKind.secondary,
          onPressed: () => unawaited(SupportNotice.open(kKofiUrl)),
        ),
        const SizedBox(height: 8),
        HLinkButton(
          label: 'Other ways to support',
          onPressed: () => unawaited(SupportNotice.open(kSponsorUrl)),
        ),
      ],
    );
  }

  /// Opens [url], and says so in the log when the phone has nothing that can.
  ///
  /// A button that silently does nothing is worse than one that never appeared.
  /// Static and shared, so both presentations open the same way.
  static Future<void> open(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      AppLog.info('settings', 'nothing on this phone would open $url');
    }
  }
}
