import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';

/// One atomic keystore value: credentials and an opaque cache namespace.
@immutable
class StoredServerSession {
  /// An existing session, including the legacy migration path.
  const StoredServerSession({
    required this.baseUrl,
    required this.token,
    required this.cacheScope,
  });

  /// Each verified sign-in gets a private namespace, even on the same server.
  factory StoredServerSession.create(String baseUrl, String token) {
    final random = Random.secure();
    return StoredServerSession(
      baseUrl: baseUrl,
      token: token,
      cacheScope: base64UrlEncode(
        List.generate(18, (_) => random.nextInt(256)),
      ),
    );
  }

  /// Read a previously committed snapshot. A null record means signed out.
  static StoredServerSession? decode(String encoded) {
    final Object? data;
    try {
      data = jsonDecode(encoded);
    } on FormatException {
      // jsonDecode includes the input in its exception; this input is a secret.
      throw const FormatException('Stored server session is malformed');
    }
    if (data == null) return null;
    if (data is! Map<String, dynamic> ||
        data['baseUrl'] is! String ||
        data['token'] is! String ||
        data['cacheScope'] is! String) {
      throw const FormatException('Stored server session is malformed');
    }
    return StoredServerSession(
      baseUrl: data['baseUrl'] as String,
      token: data['token'] as String,
      cacheScope: data['cacheScope'] as String,
    );
  }

  /// Where this token was verified.
  final String baseUrl;

  /// Never printed or used as a cache key.
  final String token;

  /// Contains no credentials; rotates when another session is installed.
  final String cacheScope;

  /// Serialized once and committed with one keystore write.
  String encode() => jsonEncode({
    'baseUrl': baseUrl,
    'token': token,
    'cacheScope': cacheScope,
  });

  @override
  String toString() => 'StoredServerSession(redacted)';
}
