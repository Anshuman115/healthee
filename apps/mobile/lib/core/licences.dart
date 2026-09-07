/// The vendored font's licence, registered so the shipped app can show it.
///
/// **This is a licence obligation, not a nicety.** Both bundled faces are SIL
/// OFL 1.1, whose terms require the copyright notice and licence to be bundled
/// with the fonts wherever they are redistributed — and an app binary
/// containing a .ttf is a redistribution.
///
/// **There are TWO faces and therefore two notices.** Figtree is the typeface;
/// Inter rides along as `HealtheeSymbols`, the bundled fallback that covers the
/// characters Figtree has no glyph for. A reader who never sees Inter's name
/// still has Inter's outlines on their phone, so its notice ships too. The licence file was once sitting beside the
/// fonts in the repo and **not** declared as an asset, so it shipped to GitHub
/// and not to a phone.
///
/// **The asset path and the filed name move with the font.** When Manrope was
/// replaced by Inter (2026-09-07) this file had to change in the same commit:
/// shipping one family's .ttf under another family's copyright notice is a
/// worse failure than shipping no notice at all, because it looks complied
/// with.
///
/// Flutter already collects every package's `LICENSE` file and renders them in
/// `showLicensePage`. Vendored assets are the one thing it cannot find on its
/// own, because there is no package to look inside — so the notice is added to
/// the same registry by hand, and it appears in the same list beside dio's and
/// drift's rather than on a screen of its own that somebody has to remember to
/// build.
///
/// [registerAssetLicences] is called from `main()` before `runApp`.
/// `LicenseRegistry` takes a stream builder and does not run it until the licence
/// page is opened, so this costs nothing at start-up.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The licence file bundled beside the fonts.
/// The bundled faces, each with the licence file that must ship beside it.
const Map<String, String> kFontLicences = <String, String>{
  'Figtree (SIL Open Font License 1.1)': 'assets/fonts/OFL-Figtree.txt',
  'Inter (SIL Open Font License 1.1)': 'assets/fonts/OFL-Inter.txt',
};

/// The name the licence is filed under on the licence page.


/// Adds the vendored font licence to Flutter's own licence registry.
void registerAssetLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in kFontLicences.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks(<String>[entry.key], text);
    }
  });
}
