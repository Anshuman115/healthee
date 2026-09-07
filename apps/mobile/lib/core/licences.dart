/// The vendored font's licence, registered so the shipped app can show it.
///
/// **This is a licence obligation, not a nicety.** Inter is SIL OFL 1.1, whose
/// terms require the copyright notice and licence to be bundled with the fonts
/// wherever they are redistributed — and an app binary containing four .ttf
/// files is a redistribution. The licence file was once sitting beside the
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
const String kFontLicenceAsset = 'assets/fonts/OFL-Inter.txt';

/// The name the licence is filed under on the licence page.
const String kFontLicencePackage = 'Inter (SIL Open Font License 1.1)';

/// Adds the vendored font licence to Flutter's own licence registry.
void registerAssetLicences() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(kFontLicenceAsset);
    yield LicenseEntryWithLineBreaks(<String>[kFontLicencePackage], text);
  });
}
