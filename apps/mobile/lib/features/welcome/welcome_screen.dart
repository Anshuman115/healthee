/// Welcome — `H.screens.welcome`, minus the sign-in this product does not have.
///
/// ```js
/// H.screens.welcome = () => `<div class="page-header">
///     <a class="brand row" href="#today">${H.icon('leaf')}<h2>healthee</h2></a>
///     ${H.link('Explore','today')}</div>
///   <div class="coach-intro"><p class="small">…</p>
///     <h1 class="section">Your days.<br>Your nights.<br>A clearer picture.</h1>
///     <p>…</p></div>
///   <div class="card">…a glimpse of your day…</div>
///   <div class="stack section">${H.button('Continue with Google','demo-signin','full')}
///     ${H.button('Connect your server','server-setup','secondary full')}</div>
///   <p class="form-note center">Design preview. Sign-in is simulated.</p>
///   <div class="card flush section">${H.row('strap','Already have a Helio Strap?',…)}</div>
///   ${H.footer()}`;
/// ```
///
/// ## "Continue with Google" is not drawn, and that is the honesty contract
///
/// The prototype's own note under it says *"Design preview. Sign-in is
/// simulated."* This app has **no Google sign-in** — there is no OAuth client,
/// no account service, and nothing on the server that would accept one. A
/// button offering it would be the single most consequential false claim the
/// product could make: it invites the owner to hand credentials to something
/// that does not exist.
///
/// So the primary button is the one that is real — *Connect your server* — and
/// the form note says what this screen actually does instead of apologising for
/// a simulation. Every other pixel of the composition is the prototype's, in
/// the prototype's order.
///
/// ## The glimpse card draws the owner's day or no chart at all
///
/// The prototype fills it with a bundled sample heart-rate series. We have no
/// sample and will not invent one: the card keeps its heading and its rule, and
/// the plot appears only when this phone has actually read a series today. An
/// invented line under *"A glimpse of your day"* would be a picture of a day
/// nobody had.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/charts/v02/v02_sparkline.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/list_row.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:solar_icons/solar_icons.dart';

/// The first screen: what this app is, and the two ways to start it.
class WelcomeScreen extends ConsumerWidget {
  /// The welcome screen.
  const WelcomeScreen({super.key});

  /// `.coach-intro` — the kicker over the headline.
  static const String kicker = 'A health companion that knows your rhythm.';

  /// The prototype's own h1, its `<br>`s kept as newlines.
  static const String headline =
      'Your days.\nYour nights.\nA clearer picture.';

  /// And the paragraph under it.
  static const String opening =
      'Connect your strap. Understand your patterns. Make small changes that '
      'fit the life you actually live.';

  /// What this screen honestly does. **Not** the prototype's apology for a
  /// simulated sign-in — see the library docstring.
  static const String note =
      'Healthee has no account of its own. Your readings live on this phone, '
      'and on the server you choose.';

  /// `.coach-intro { padding: 20px 0 }`.
  static const double introPadding = 20;

  /// `.coach-intro h1 { margin-top: 24px }` — `.section`.
  static const double introGap = 24;

  /// `.stack { gap: 16px }`.
  static const double stackGap = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final day = ref.watch(deviceDayProvider).value;
    return SettingsPage.headed(
      header: _Brand(onExplore: () => context.go(Routes.today)),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: introPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SmallProse(kicker),
              const SizedBox(height: introGap),
              Text(
                headline,
                style: FormType.displayTitle.copyWith(color: colors.ink),
              ),
              const SizedBox(height: introGap),
              Text(
                opening,
                style: FormType.body.copyWith(color: colors.ink2),
              ),
            ],
          ),
        ),
        _Glimpse(day: day),
        const SectionGap(),
        HButton(
          label: 'Connect your server',
          onPressed: () => unawaited(context.push(Routes.serverSignIn)),
        ),
        const SizedBox(height: stackGap),
        HButton(
          label: 'Pair a strap first',
          kind: HButtonKind.secondary,
          onPressed: () => unawaited(context.push(Routes.pairing)),
        ),
        const FormNote(note, centred: true),
        FlushCard(
          children: <Widget>[
            ListRow(
              icon: SolarIconsOutline.watchRound,
              title: 'Already have a Helio Strap?',
              subtitle: 'See the connection flow',
              onTap: () => unawaited(context.push(Routes.pairing)),
            ),
          ],
        ),
        const DataFooter(),
      ],
    );
  }
}

/// `.page-header` carrying `.brand` and the *Explore* link.
class _Brand extends StatelessWidget {
  const _Brand({required this.onExplore});

  static const double gap = 10;
  static const double markSize = 25;
  static const double bottomGap = 16;

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: bottomGap),
      child: Row(
        children: <Widget>[
          Icon(SolarIconsOutline.leaf, size: markSize, color: colors.accent),
          const SizedBox(width: gap),
          Expanded(
            child: Text(
              'healthee',
              style: FormType.heading2.copyWith(color: colors.ink),
            ),
          ),
          HLinkButton(label: 'Explore', onPressed: onExplore),
        ],
      ),
    );
  }
}

/// The glimpse card. Its plot appears only when this phone has read a series.
class _Glimpse extends StatelessWidget {
  const _Glimpse({required this.day});

  static const double gap = 20;

  final DeviceDay? day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final series = day?.heartRateSeries ?? const <DevicePoint>[];
    return ToneScope(
      tone: Tone.heart,
      child: PlainCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // `<p class="stat-label">…</p><h3>…</h3>` — a label over a
                // heading, NOT a `.stat-number`; there is no figure here.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'A glimpse of your day',
                        style: FormType.statLabel.copyWith(color: colors.ink2),
                      ),
                      Text(
                        'Signals, with context.',
                        style: FormType.heading3.copyWith(color: colors.ink),
                      ),
                    ],
                  ),
                ),
                Icon(SolarIconsOutline.chart_2, color: colors.accent),
              ],
            ),
            if (series.length >= 2) ...<Widget>[
              const SizedBox(height: gap),
              V02Sparkline(
                <double?>[for (final DevicePoint point in series) point.value],
                // A specimen, not a reveal: nothing on this screen animates it.
                progress: 1,
                height: 60,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
