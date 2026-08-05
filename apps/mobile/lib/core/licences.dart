/// The vendored font's licence, registered so the shipped app can show it.
///
/// **This is a licence obligation, not a nicety.** Manrope is SIL OFL 1.1, whose
/// terms require the copyright notice and licence to be bundled with the fonts
/// wherever they are redistributed — and an app binary containing three .ttf
/// files is a redistribution. `assets/fonts/OFL.txt` was sitting beside the
/// fonts in the repo and was **not** declared as an asset, so it shipped to
/// GitHub and not to a phone.
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
const String kFontLicenceAsset = 'assets/fonts/OFL.txt';

/// The name the licence is filed under on the licence page.
const String kFontLicencePackage = 'Manrope (SIL Open Font License 1.1)';

/// Adds the vendored font licence to Flutter's own licence registry.
void registerAssetLicences() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(kFontLicenceAsset);
    yield LicenseEntryWithLineBreaks(<String>[kFontLicencePackage], text);
  });
}
