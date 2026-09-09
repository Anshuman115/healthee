/// The two panels that close the biological-age screen: what is left out, and
/// how much confidence to place in what is left in.
///
/// `design/mobile-preview/screens-fitness.js::H.screens.body`:
///
/// ```js
/// H.panel('Excluded, not counted as zero','sleep',
///         `<h3>Sleep regularity</h3>${H.note(age.excluded[0].message)}
///          ${H.link('Still visible in Sleep','sleep')}`,'','info')
/// H.panel('How much confidence to place in it','fitness',
///         `${H.note(…)}<details class="section">
///          <summary>Method and important caveats</summary>
///          ${age.caveats.map(c => `<p class="panel-note">${c.message}</p>`)}
///          </details>${H.evidence('biological_age','Research & method')}`,'','shield')
/// ```
///
/// ## `excluded` is not `withheld`, and this panel is where that is visible
///
/// `reading.dart` fixes the difference and it decides what this panel may offer:
/// *"'Log a weight and this comes back' is an action. 'Sleep regularity cannot
/// honestly be converted into years' is a permanent property of the evidence,
/// and offering a retry button for it would be a lie about what we are able to
/// do."* So there is no retry here, the server's paragraph ships **verbatim**,
/// and the only control is the one that takes the owner to where the excluded
/// measurement IS shown.
///
/// The panel draws on every payload that carries an exclusion — including one
/// where the estimate itself was withheld, because the term is not one of the
/// levers on a day the number ships and on a day it does not.
///
/// ## The caveats go behind the app's disclosure, not into a `<details>`
///
/// `Panel`'s own `caveats` slot draws a counted signpost with the sentences one
/// tap behind it. That is the same shape as the prototype's `<details>` and it
/// is the mechanism every other caveated card in this app already uses, so the
/// biological-age caveats read the way the VO₂max ones do rather than being a
/// second kind of disclosure on the same screen.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// The prototype's line under the confidence heading.
const String kConfidenceNote =
    'This is a population-based motivational model, not a clinical age. The '
    'fitness input is estimated, and its uncertainty carries into the result.';

/// `Excluded, not counted as zero` — a lever nobody can price, named as one.
class ExcludedTermsPanel extends StatelessWidget {
  /// [exclusions] is the payload's `excluded[]`, drawn in its own order.
  const ExcludedTermsPanel({
    required this.exclusions,
    this.onOpenSleep,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Excluded, not counted as zero';

  /// The gap above each excluded term's name.
  static const double termGap = 12;

  /// The levers this estimate permanently does not price.
  final List<Disclosure> exclusions;

  /// Opens the screen where the excluded measurement IS shown.
  final VoidCallback? onOpenSleep;

  /// `regularity` → `Regularity`. The server's own word for the term, not a
  /// label invented here — a term the model renames must rename itself on
  /// screen too.
  static String termName(Disclosure exclusion) {
    final term = exclusion.term ?? '';
    return term.isEmpty
        ? 'This term'
        : term[0].toUpperCase() + term.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Panel(
      tone: Tone.sleep,
      label: 'Biological age · excluded',
      head: const PanelHead(title: title, icon: SolarIconsOutline.infoCircle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < exclusions.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: termGap),
            Text(
              termName(exclusions[i]),
              style: TypeScale.panelTitle.copyWith(color: colors.ink),
            ),
            // Verbatim. The reasoning about the two SRI calculators is the
            // server's, and re-wording it here would soften a statement about
            // what is knowable.
            PanelNote(exclusions[i].message),
          ],
          if (onOpenSleep case final VoidCallback open)
            Padding(
              padding: const EdgeInsets.only(top: termGap),
              child: Align(
                alignment: Alignment.centerLeft,
                child: HLinkButton(
                  label: 'Still visible in Sleep',
                  onPressed: open,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `How much confidence to place in it` — the model's own limits.
class AgeConfidencePanel extends StatelessWidget {
  /// [caveats] are the payload's, drawn behind the panel's disclosure.
  const AgeConfidencePanel({
    required this.caveats,
    this.researchNotes = const <String>[],
    super.key,
  });

  /// The prototype's title.
  static const String title = 'How much confidence to place in it';

  /// What tilts the estimate, in the server's own words.
  final List<Disclosure> caveats;

  /// The notes licensing the estimate — the prototype's `Research & method`.
  final List<String> researchNotes;

  @override
  Widget build(BuildContext context) => Panel(
    tone: Tone.fitness,
    label: 'Biological age · estimate',
    caveats: caveats,
    head: PanelHead(
      title: title,
      icon: SolarIconsOutline.shieldCheck,
      infoKey: 'biological_age',
      detail: MetricDetail(notes: researchNotes),
    ),
    child: const PanelNote(kConfidenceNote),
  );
}
