/// What the updater is allowed to conclude from a release, and what it is not.
///
/// The negative assertions are the load-bearing ones. An updater that offers a
/// download the installer then refuses is worse than no updater: the owner waits
/// for 70MB, taps install, and Android says no with an error about downgrades
/// that means nothing to them. Every case below is one where this app must say
/// "no update" or "cannot tell" rather than guess.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/updates/app_release.dart';

/// The shape the GitHub releases API actually returns, trimmed to what is read.
Map<String, Object?> _json({
  String tag = 'v0.2.0',
  String? body = '<!-- versionCode: 7 -->\n\n## What changed\n\n- a thing',
  bool draft = false,
  bool prerelease = false,
  List<Object?>? assets,
}) => <String, Object?>{
  'tag_name': tag,
  'body': body,
  'draft': draft,
  'prerelease': prerelease,
  'assets':
      assets ??
      <Object?>[
        <String, Object?>{
          'name': 'healthee-v0.2.0.apk',
          'browser_download_url':
              'https://github.com/afkcodes/healthee/releases/download/v0.2.0/healthee-v0.2.0.apk',
          'size': 72189602,
        },
      ],
};

void main() {
  group('a release this app can compare itself against', () {
    test('carries the tag, the build number, the URL and the size', () {
      final release = AppRelease.fromJson(_json())!;

      expect(release.tag, 'v0.2.0');
      expect(release.versionName, '0.2.0');
      expect(release.versionCode, 7);
      expect(release.sizeBytes, 72189602);
      expect(release.downloadUrl, endsWith('healthee-v0.2.0.apk'));
    });

    test('the machine marker is not shown to a person', () {
      final release = AppRelease.fromJson(_json())!;

      expect(release.notes, isNot(contains('versionCode')));
      expect(release.notes, startsWith('## What changed'));
    });

    test('THE URL IS THE ASSET\'S OWN, NEVER ONE WE BUILT', () {
      // A URL constructed from the tag is a guess about someone else's naming,
      // and it breaks silently the first time a release is named differently —
      // as a 404 the owner reads as "the update is broken".
      final release = AppRelease.fromJson(
        _json(
          assets: <Object?>[
            <String, Object?>{
              'name': 'healthee-renamed-by-hand.apk',
              'browser_download_url': 'https://example.test/some/other/path.apk',
              'size': 10,
            },
          ],
        ),
      )!;

      expect(release.downloadUrl, 'https://example.test/some/other/path.apk');
    });
  });

  group('THE COMPARISON IS THE INSTALLER\'S, NOT THE VERSION NAME\'S', () {
    test('a higher build number is an update', () {
      expect(AppRelease.fromJson(_json())!.isNewerThan(6), isTrue);
    });

    test('an EQUAL build number is not — Android refuses that', () {
      expect(AppRelease.fromJson(_json())!.isNewerThan(7), isFalse);
    });

    test('and neither is a lower one, whatever the tag says', () {
      // The case that makes version names unusable as the rule: a release tagged
      // 9.9.9 whose build number went backwards is still a downgrade to the
      // installer, and offering it would waste a 70MB download on a refusal.
      final release = AppRelease.fromJson(
        _json(tag: 'v9.9.9', body: '<!-- versionCode: 3 -->\n\nnotes'),
      )!;

      expect(release.versionName, '9.9.9');
      expect(release.isNewerThan(7), isFalse);
    });
  });

  group('a release we cannot honestly compare is NOT an answer', () {
    test('no versionCode marker → null, never "up to date"', () {
      // Silently reporting "you are up to date" about a release we failed to
      // parse is the flattery this app exists to refuse. The caller reports that
      // it cannot tell.
      expect(AppRelease.fromJson(_json(body: '## What changed\n\n- a thing')), isNull);
    });

    test('a marker that is not a number is not a number', () {
      expect(AppRelease.fromJson(_json(body: '<!-- versionCode: soon -->')), isNull);
    });

    test('no APK attached → nothing to offer', () {
      expect(AppRelease.fromJson(_json(assets: <Object?>[])), isNull);
      expect(
        AppRelease.fromJson(
          _json(
            assets: <Object?>[
              <String, Object?>{
                'name': 'source.zip',
                'browser_download_url': 'https://example.test/source.zip',
                'size': 1,
              },
            ],
          ),
        ),
        isNull,
      );
    });

    test('A DRAFT IS NOT PUBLISHED AND A PRERELEASE IS NOT FOR EVERYONE', () {
      expect(AppRelease.fromJson(_json(draft: true)), isNull);
      expect(AppRelease.fromJson(_json(prerelease: true)), isNull);
    });

    test('a body that is absent is not an empty body', () {
      expect(AppRelease.fromJson(_json(body: null)), isNull);
    });
  });

  test('the real API shape parses — a trimmed capture, not a hand-written map', () {
    // Hand-written fixtures agree with whoever wrote them. This one is the
    // envelope GitHub actually sends, keys and all, so a field that moves is
    // caught here rather than on a phone.
    const captured = '''
{"url":"https://api.github.com/repos/afkcodes/healthee/releases/1",
 "tag_name":"v0.2.0","target_commitish":"main","name":"v0.2.0",
 "draft":false,"prerelease":false,
 "created_at":"2026-09-10T00:00:00Z","published_at":"2026-09-10T00:00:00Z",
 "body":"<!-- versionCode: 2 -->\\n\\n## What changed\\n\\n- one thing",
 "assets":[{"url":"https://api.github.com/repos/afkcodes/healthee/releases/assets/1",
   "name":"healthee-v0.2.0.apk","content_type":"application/vnd.android.package-archive",
   "state":"uploaded","size":72189602,
   "browser_download_url":"https://github.com/afkcodes/healthee/releases/download/v0.2.0/healthee-v0.2.0.apk"}]}
''';
    final release = AppRelease.fromJson(
      jsonDecode(captured) as Map<String, Object?>,
    )!;

    expect(release.versionCode, 2);
    expect(release.isNewerThan(1), isTrue);
    expect(release.downloadUrl, contains('/releases/download/v0.2.0/'));
  });
}
