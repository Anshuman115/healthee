/// Which release the owner has already been shown, so the sheet asks ONCE.
///
/// ## The failure this exists to prevent
///
/// An update sheet that opens on every cold start is not a notice, it is a nag —
/// and the thing being nagged about is never urgent here. This app is sideloaded,
/// the owner updates when they choose, and nothing breaks if they never do. So a
/// release gets exactly one unprompted appearance, and after that the owner finds
/// it where they have always found it: About, on purpose, when they went looking.
///
/// ## It records SHOWN, not ACTED ON
///
/// The mark is written when the sheet opens, not when the owner taps through to
/// the release page. Writing it on the tap would mean "Not now" re-asks on the
/// next launch, which is the nag again wearing a politer word: "not now" said
/// once about a specific version is an answer, not a postponement.
///
/// The consequence is deliberate and worth naming: if the app is killed between
/// the sheet opening and the owner reading it, that release is spent. They can
/// still reach it from About, and a lost notice is cheaper than a loop.
///
/// The store is the `syncMeta` key-value table `BackgroundStore` already uses —
/// one row, one integer, and nothing here is a secret.
library;

import 'package:drift/drift.dart';
import 'package:healthee/data/store/local_store.dart';

/// The `syncMeta` row this keeps.
const String kUpdatePromptKey = 'update_prompt_offered_code';

/// Remembers which `versionCode` has already had its sheet.
class UpdatePromptStore {
  /// Wraps the app's local store.
  const UpdatePromptStore(this.store);

  /// The drift database.
  final LocalStore store;

  /// The last `versionCode` offered, or null when none ever was.
  ///
  /// An unparseable row reads as null — the same as absent, because both mean
  /// "we cannot show this was already offered", and re-offering once is a far
  /// smaller harm than silently swallowing a real release.
  Future<int?> offeredCode() async {
    final row = await (store.select(
      store.syncMeta,
    )..where((row) => row.name.equals(kUpdatePromptKey))).getSingleOrNull();
    final value = row?.value;
    return value == null ? null : int.tryParse(value);
  }

  /// Records that [versionCode] has now been put in front of the owner.
  Future<void> markOffered(int versionCode) => store
      .into(store.syncMeta)
      .insertOnConflictUpdate(
        SyncMetaCompanion(
          name: const Value(kUpdatePromptKey),
          value: Value('$versionCode'),
        ),
      );

  /// Whether [versionCode] still deserves a sheet.
  ///
  /// Pure enough to assert directly: greater-than rather than not-equal, so a
  /// release that is somehow OLDER than the one already offered cannot re-open
  /// the sheet by going backwards.
  static bool shouldOffer({required int versionCode, required int? offered}) =>
      offered == null || versionCode > offered;
}
