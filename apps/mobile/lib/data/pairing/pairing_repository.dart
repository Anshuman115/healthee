/// Pairing, end to end: sign in, list, confirm, store.
///
/// The screen calls these four things and nothing else. Keeping the order and
/// the storage decisions here rather than in a controller means the rule "the
/// auth key goes to the keystore and nowhere else" is enforced in one file that
/// a reviewer can read in a minute.
///
/// ## What leaves the device, and what does not
///
/// Out: the Zepp email and password, once, to `api-user-us2.zepp.com` — Zepp's
/// own sign-in, which is the only party that can check them.
///
/// **Not out, ever:** the auth key and the MAC are never sent to the Healthee
/// API. There is no endpoint that takes them and this module adds none. They
/// identify a device the owner already owns, to software running on hardware the
/// owner already controls; putting them on a wire would give a server a reason to
/// exist that this product's whole premise says it should not have.
library;

import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/zepp_client.dart';
import 'package:healthee/data/pairing/zepp_device.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pairing_repository.g.dart';

/// The storage claims the pairing screen makes, written where they are kept true.
///
/// Copy usually belongs in the widget. These two sentences do not, because they
/// are assertions about what this file writes — if the code below changes and
/// the sentence does not, the app has lied about a password. Next to each other,
/// one diff shows both.
abstract final class PairingDisclosure {
  /// Always true, whatever the owner chooses.
  static const String whatIsAlwaysStored =
      "The strap's address and pairing key are saved to this phone's secure "
      'keystore — the same place a password manager uses. They are never sent to '
      'the Healthee server.';

  /// The opt-in, stated as what it adds and what it costs.
  static const String whatRememberingAdds =
      'Your Zepp email and password go into that same keystore, so pairing '
      'another strap later does not mean typing them again. Leave this off and '
      'nothing about the Zepp account is kept — only the strap.';
}

/// Runs the pairing flow and owns what it stores.
class PairingRepository {
  /// [zepp] talks to the account API; [scanner] confirms the strap is present;
  /// [credentials] is the keystore.
  const PairingRepository({
    required this.credentials,
    required this.zepp,
    required this.scanner,
  });

  /// The keystore. Public because the constructor takes it by name and Dart has
  /// no private named parameters; nothing outside this file reaches for it.
  final Credentials credentials;

  /// The Zepp account API.
  final ZeppClient zepp;

  /// The BLE presence check.
  final StrapScanner scanner;

  /// Signs in to Zepp and returns the account's usable devices.
  ///
  /// The session is local to this call and is dropped on return — see
  /// `zepp_session.dart` for why nothing keeps it.
  Future<List<ZeppDevice>> devicesForAccount({
    required String email,
    required String password,
  }) async {
    final session = await zepp.signIn(email: email, password: password);
    return zepp.devices(session);
  }

  /// Looks for [strap] on the air. See [StrapScanner.confirmInRange].
  Future<ScanOutcome> confirmInRange(PairedStrap strap) =>
      scanner.confirmInRange(strap.mac);

  /// Stores the pairing, and either remembers or forgets the Zepp sign-in.
  ///
  /// [rememberZepp] is the owner's checkbox, and it is honoured in both
  /// directions: passing null does not merely skip writing, it **deletes** any
  /// sign-in an earlier pairing stored. An opt-in that cannot be taken back by
  /// doing the obvious thing is not really an opt-in.
  Future<void> pair(
    PairedStrap strap, {
    ({String email, String password})? rememberZepp,
  }) async {
    await credentials.setStrapPairing(mac: strap.mac, authKey: strap.authKey);
    if (rememberZepp == null) {
      await credentials.forgetZeppAccount();
    } else {
      await credentials.setZeppAccount(
        email: rememberZepp.email,
        password: rememberZepp.password,
      );
    }
    // The last two octets only. A log line naming a whole MAC is a device
    // fingerprint sitting in the platform log for anyone with adb.
    AppLog.info(
      'pairing',
      'paired strap …${strap.shortMac} (zepp sign-in kept: ${rememberZepp != null})',
    );
  }

  /// The currently paired strap, or null.
  ///
  /// Half a pairing reads as none: a MAC with no key cannot open a session, and
  /// treating it as "paired" would send the BLE layer at a handshake it must
  /// fail. Standards §1 — "no data" and "operation failed" stay distinguishable,
  /// and this is the former.
  Future<PairedStrap?> pairedStrap() async {
    final mac = await credentials.strapMac();
    final key = await credentials.strapAuthKey();
    if (mac == null || key == null) {
      return null;
    }
    return PairedStrap(mac: mac, authKey: key);
  }

  /// A Zepp sign-in the owner asked us to remember, or null.
  Future<({String email, String password})?> rememberedZeppAccount() async {
    final email = await credentials.zeppEmail();
    final password = await credentials.zeppPassword();
    if (email == null || password == null) {
      return null;
    }
    return (email: email, password: password);
  }

  /// Forgets the strap AND any remembered Zepp sign-in.
  ///
  /// Both, because "unpair" means what it says. Leaving the account credential
  /// behind after the owner has cut the device loose is the kind of residue
  /// nobody goes looking for.
  Future<void> unpair() async {
    await credentials.forgetStrapPairing();
    await credentials.forgetZeppAccount();
    AppLog.info('pairing', 'strap unpaired and zepp sign-in forgotten');
  }
}

/// The app's pairing repository.
@Riverpod(keepAlive: true)
PairingRepository pairingRepository(Ref ref) {
  return PairingRepository(
    credentials: ref.watch(credentialsProvider),
    zepp: ZeppClient(ZeppClient.dioFor()),
    scanner: ref.watch(strapScannerProvider),
  );
}

/// Everything the app needs to know about the current pairing, in one read.
///
/// One provider rather than two because both halves come from the same keystore
/// and are always wanted together — the screen has to say what is stored, and
/// "the strap" is only half of that answer. Two providers would also mean two
/// async consumers on one card, each with its own loading state, flickering
/// independently.
///
/// A null `strap` means nothing is paired, which is what the router keys on.
@Riverpod(keepAlive: true)
Future<({PairedStrap? strap, bool zeppRemembered})> pairingSummary(Ref ref) async {
  final repository = ref.watch(pairingRepositoryProvider);
  return (
    strap: await repository.pairedStrap(),
    zeppRemembered: await repository.rememberedZeppAccount() != null,
  );
}
