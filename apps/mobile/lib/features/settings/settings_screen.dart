/// Settings — v02's index of rows, each opening a screen of its own.
///
/// ## What changed, and what did not
///
/// **Not one row's behaviour.** Every setting this screen used to hold inline —
/// the appearance segmented button, the two expanding preference cards, the
/// server card, the strap card, the diagnostics door and the licence door — is
/// still exactly one tap from here and still writes exactly the same provider.
/// What changed is that they are now *screens* rather than cards stacked on one
/// scroll, which is what `design/mobile-preview/screens-settings.js` specifies:
///
/// ```js
/// H.screens.settings = () => `${H.header('Make it yours.','Profile & settings',true)}
///   <a href="#profile" class="card row">…</a>
///   ${H.section('Your connected device', …)}
///   ${H.section('Your experience', …)}
///   ${H.section('Your account', …)}
///   ${H.footer()}`;
/// ```
///
/// The two rules the previous screen was built to keep are unchanged and are
/// now enforced one level down:
///
///   * **One source of truth per setting.** The appearance screen reads and
///     writes `themeControllerProvider`, the same object the header toggle
///     writes. Moving the control onto its own screen did not give it a copy.
///   * **No row that controls nothing.** Every row here opens a registered
///     route; `test/features/reachability_test.dart` taps all of them.
///
/// ## One row the prototype does not have
///
/// **Instruments → `/diagnostics`.** The prototype has no diagnostics screen to
/// draw a row for, and this product does: `diagnostics_screen.dart` argues that
/// the baselines and the strap's raw streams belong somewhere the owner goes
/// when something looks wrong, and that argument *"is only sound while there is
/// a door"*. Settings is the only door. It is added inside the prototype's own
/// `Your connected device` section, because that is what it is about — the
/// section ORDER is the prototype's, and one row is added to a section rather
/// than a section invented for it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/data/profile/profile_repository.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/states/current_account_value.dart';
import 'package:healthee/shared/v02/list_row.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:solar_icons/solar_icons.dart';

/// The index: the owner, their device, their experience, their account.
class SettingsScreen extends ConsumerWidget {
  /// [now] is threaded to the screens that quote an age; this one quotes none.
  const SettingsScreen({this.now, super.key});

  /// The prototype's own h1 and eyebrow for this screen.
  static const String title = 'Make it yours.';

  /// The line above it.
  static const String eyebrow = 'Profile & settings';

  /// The instant a freshness label would be measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value?.` and never `.requireValue`: the profile is a server read, and a
    // navigation index must not wait on a network before it will draw its rows.
    final profile = currentAccountValue(
      ref.watch(healthProfileProvider),
    ).value;
    final paired = ref.watch(pairingSummaryProvider).value?.strap != null;
    return SettingsPage(
      title: title,
      eyebrow: eyebrow,
      children: <Widget>[
        _ProfileCard(
          name: profile?.name,
          onOpen: () => unawaited(context.push(Routes.profile)),
        ),
        const SectionGap(),
        const SectionHead(title: 'Your connected device'),
        FlushCard(
          children: <Widget>[
            ListRow(
              icon: SolarIconsOutline.watchRound,
              title: 'Amazfit Helio Strap',
              subtitle: paired
                  ? 'Your device, its charge and its last read'
                  : 'Nothing paired yet · connect a strap',
              onTap: () => unawaited(context.push(Routes.device)),
            ),
            ListRow(
              icon: SolarIconsOutline.refresh,
              title: 'Data & sync',
              subtitle: 'From your strap to your personal insights',
              onTap: () => unawaited(context.push(Routes.dataFreshness)),
            ),
            ListRow(
              icon: SolarIconsOutline.chartSquare,
              title: 'Instruments',
              // Names what is behind it in the owner's words. "Diagnostics"
              // alone would be a control whose only documentation is the screen
              // you have to open to read it.
              subtitle: 'Every baseline, and every stream this phone read — '
                  'each saying how it was measured.',
              onTap: () => unawaited(context.push(Routes.diagnostics)),
            ),
          ],
        ),
        const SectionGap(),
        const SectionHead(title: 'Your experience'),
        FlushCard(
          children: <Widget>[
            ListRow(
              icon: SolarIconsOutline.sun,
              title: 'Appearance',
              subtitle: 'Light, dark or follow your device',
              onTap: () => unawaited(context.push(Routes.appearance)),
            ),
            ListRow(
              icon: SolarIconsOutline.bell,
              title: 'Reminders',
              subtitle: 'A gentle nudge, on your terms',
              onTap: () => unawaited(context.push(Routes.reminders)),
            ),
            ListRow(
              icon: SolarIconsOutline.cloud,
              title: 'Background sync',
              subtitle: 'Collection, upload and network preferences',
              onTap: () => unawaited(context.push(Routes.background)),
            ),
            ListRow(
              icon: SolarIconsOutline.notes,
              title: 'Health journal',
              subtitle: 'The moments beyond your measurements',
              onTap: () => unawaited(context.push(Routes.journal)),
            ),
          ],
        ),
        const SectionGap(),
        const SectionHead(title: 'Your account'),
        FlushCard(
          children: <Widget>[
            ListRow(
              icon: SolarIconsOutline.shieldCheck,
              title: 'Account & server',
              subtitle: 'Your data, on your server',
              onTap: () => unawaited(context.push(Routes.serverSignIn)),
            ),
            ListRow(
              icon: SolarIconsOutline.infoCircle,
              title: 'About Healthee',
              subtitle: 'An honest health companion',
              onTap: () => unawaited(context.push(Routes.about)),
            ),
          ],
        ),
        const DataFooter(),
      ],
    );
  }
}

/// `a.card.row` — the owner's own row, above the sections.
///
/// ```css
/// .card              { padding:20px; border-radius:22px; }
/// .row               { display:flex; align-items:center; gap:12px; }
/// .icon-button       { display:grid; place-items:center; width:44px;
///                      height:44px; border-radius:50%; }
/// .icon-button.filled{ background:var(--surface); color:var(--ink);
///                      border:1px solid var(--line); }
/// ```
///
/// A phone whose profile has no name shows the row's purpose rather than an
/// empty heading. That is not a placeholder for a value — it is the row's own
/// label, and there is no value being claimed.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.onOpen});

  static const double avatarSize = 44;
  static const double gap = 12;
  static const double chevronSize = 16;

  final String? name;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = this.name;
    final heading = name == null || name.trim().isEmpty
        ? 'Your profile'
        : name.trim();
    return Semantics(
      button: true,
      label: '$heading · your profile and measurements',
      child: GestureDetector(
        onTap: onOpen,
        child: PlainCard(
          child: Row(
            children: <Widget>[
              Container(
                width: avatarSize,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.line),
                ),
                child: Icon(SolarIconsOutline.userCircle, color: colors.ink),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FormType.heading3.copyWith(color: colors.ink),
                    ),
                    Text(
                      'Your profile & measurements',
                      style: FormType.small.copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: gap),
              Icon(
                SolarIconsOutline.altArrowRight,
                size: chevronSize,
                color: colors.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
