/// A published release, and the one question worth asking about it.
///
/// ## The comparison is `versionCode`, not the version name
///
/// An updater's only real job is to answer "will this install, and is it newer".
/// Android answers the first for us and it answers it by ONE number: the
/// `versionCode`, which is `pubspec.yaml`'s `+N`. An equal or lower one is a
/// downgrade and the installer refuses it, whatever the version name says.
///
/// So that integer is what this compares. Comparing `0.2.0` against `0.1.0`
/// instead would let the app offer a download that the installer then refuses —
/// an update button that does nothing, with no way for the owner to tell whether
/// the fault was theirs. Semver is what we SHOW; the build number is what we
/// decide on.
///
/// ## Where the number comes from
///
/// `release.yml` writes `<!-- versionCode: N -->` as the first line of the
/// release notes, and the same workflow refuses to publish a release whose N is
/// not greater than the last one's. One number, written by the build that
/// produced the APK, read by the app that has to decide about it.
///
/// **A release with no marker is "cannot tell", never "no update".** That is the
/// product's rule applied to itself: not enough data beats an optimistic guess,
/// and it beats a pessimistic one too — silently reporting "you are up to date"
/// about a release we failed to parse is exactly the flattery this app refuses.
library;

import 'package:meta/meta.dart';

/// The marker `release.yml` writes into the notes, and this reads back.
final RegExp kVersionCodeMarker = RegExp(r'<!--\s*versionCode:\s*(\d+)\s*-->');

/// The published APK's filename prefix, so an asset list can be filtered.
const String kApkSuffix = '.apk';

/// One release, as much of it as this app has any business knowing.
@immutable
class AppRelease {
  /// All fields come from the GitHub releases API.
  const AppRelease({
    required this.tag,
    required this.versionCode,
    required this.notes,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  /// Builds one from the API's JSON, or null when it cannot answer the question.
  ///
  /// Null for a draft, a prerelease, a release with no APK attached, or one whose
  /// notes carry no `versionCode` marker. Each of those is a release this app
  /// cannot honestly compare itself against, and a partial answer here becomes a
  /// wrong prompt on a screen.
  static AppRelease? fromJson(Map<String, Object?> json) {
    if (json['draft'] == true || json['prerelease'] == true) {
      return null;
    }
    final tag = json['tag_name'];
    final notes = json['body'];
    if (tag is! String || tag.isEmpty || notes is! String) {
      return null;
    }
    final code = kVersionCodeMarker.firstMatch(notes)?.group(1);
    final versionCode = code == null ? null : int.tryParse(code);
    if (versionCode == null) {
      return null;
    }
    final asset = _apkAsset(json['assets']);
    if (asset == null) {
      return null;
    }
    return AppRelease(
      tag: tag,
      versionCode: versionCode,
      notes: notes.replaceAll(kVersionCodeMarker, '').trim(),
      downloadUrl: asset.$1,
      sizeBytes: asset.$2,
    );
  }

  /// The first `.apk` asset's `(url, size)`, or null when there is none.
  ///
  /// The URL is taken from the asset entry rather than built from the tag: a
  /// constructed download URL is a guess about someone else's naming scheme, and
  /// it goes wrong silently the first time a release is named differently.
  static (String, int)? _apkAsset(Object? assets) {
    if (assets is! List) {
      return null;
    }
    for (final entry in assets) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final name = entry['name'];
      final url = entry['browser_download_url'];
      if (name is String && name.endsWith(kApkSuffix) && url is String) {
        final size = entry['size'];
        return (url, size is int ? size : 0);
      }
    }
    return null;
  }

  /// `v0.2.0` — what the release is called.
  final String tag;

  /// `pubspec.yaml`'s `+N`, and Android's own ordering.
  final int versionCode;

  /// The human notes, with the machine marker removed.
  final String notes;

  /// Where the APK is, as the release itself reported it.
  final String downloadUrl;

  /// Its size in bytes; 0 when the API did not say.
  final int sizeBytes;

  /// The version name to show — the tag without its `v`.
  String get versionName => tag.startsWith('v') ? tag.substring(1) : tag;

  /// Whether this release would actually install over build [current].
  ///
  /// The same test Android's installer applies, asked before the owner is
  /// offered the download rather than after they have waited for it.
  bool isNewerThan(int current) => versionCode > current;
}
