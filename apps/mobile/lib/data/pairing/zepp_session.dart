/// A signed-in Zepp session — held in memory, for the length of one pairing.
///
/// ## This is never persisted, and that is the decision
///
/// The app token has roughly a 30-day life, which invites caching it so the
/// device list can be reopened without signing in again. We do not, and the
/// reason is that **nothing after pairing needs it**. Once the MAC and the auth
/// key are in the keystore the strap is reachable directly over BLE; the Zepp
/// account is not in the sync path, the read path, or anywhere else. A token
/// kept "in case" is a credential with a 30-day blast radius and no consumer —
/// and a stored token that quietly expires is a class of bug this codebase has
/// already paid for once, in a value that looked current and was not.
///
/// So: sign in, read the list, pair, and the session goes out of scope. What the
/// owner may *choose* to keep is the Zepp email and password, behind an explicit
/// opt-in on the pairing screen (`pairing_repository.dart`) — their credential,
/// their call, and the screen says plainly what it stores and where.
library;

import 'package:meta/meta.dart';

/// The result of a successful Zepp sign-in.
@immutable
class ZeppSession {
  /// Holds the app token and the account's user id.
  const ZeppSession({required this.userId, required this.appToken});

  /// The Zepp account id. Goes in the device-list path and query.
  final String userId;

  /// **A bearer credential.** Sent as the `apptoken` header, never stored, never
  /// logged, and never sent to the Healthee API. [toString] omits it and the
  /// secrecy test proves nothing else prints it.
  final String appToken;

  @override
  String toString() => 'ZeppSession($userId, appToken: <redacted>)';
}
