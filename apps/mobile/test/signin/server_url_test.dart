/// The address rules, and the one that is a security boundary.
///
/// Cleartext is the case worth the file: a bearer token on a plain `http://`
/// connection to a remote host is readable by every hop in between, and by the
/// time the server answers it has already leaked. It has to be refused *before*
/// the request exists, which means it has to be refused here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/server_url.dart';
import 'package:healthee/data/api/signin_failure.dart';

/// The failure a call throws, or null when it returned.
ServerSignInFailure? _failureOf(String raw) {
  try {
    ServerUrl.parse(raw);
    return null;
  } on ServerSignInException catch (error) {
    return error.failure;
  }
}

void main() {
  group('a remote http:// address is REFUSED, and says why', () {
    test('a plain-http host is cleartext and names the host', () {
      final failure = _failureOf('http://healthee.example.com');

      expect(failure, isA<CleartextServerUrl>());
      expect((failure! as CleartextServerUrl).host, 'healthee.example.com');
      expect(failure.headline, contains('in the clear'));
      expect(failure.remedy, contains('readable by every hop'));
      // Not retryable: pressing the button again sends the same cleartext.
      expect(failure.canRetry, isFalse);
    });

    test('a port does not make it local', () {
      expect(_failureOf('http://192.168.1.40:8765'), isA<CleartextServerUrl>());
    });

    test("the Android emulator's host alias is NOT treated as loopback", () {
      // 10.0.2.2 is routed over the emulated NIC. A rule that lets a token onto
      // a wire because the wire is short is not a rule.
      expect(_failureOf('http://10.0.2.2:8765'), isA<CleartextServerUrl>());
      expect(ServerUrl.isLoopbackHost('10.0.2.2'), isFalse);
    });

    test('https to the same host is accepted', () {
      expect(_failureOf('https://healthee.example.com'), isNull);
    });
  });

  group('loopback is the one http:// exception', () {
    test('127.0.0.1, localhost, ::1 and the rest of 127/8 all pass', () {
      for (final address in [
        'http://127.0.0.1:8765',
        'http://localhost:8765',
        'http://[::1]:8765',
        'http://127.1.2.3:8765',
      ]) {
        expect(_failureOf(address), isNull, reason: address);
      }
    });

    test("the build's own fallback default is one of them", () {
      // `Env.apiBaseUrl` defaults to http://127.0.0.1:8765; a form prefilled
      // with a value this parser rejects would be an unusable first run.
      expect(_failureOf('http://127.0.0.1:8765'), isNull);
    });
  });

  group('a missing scheme becomes https, never http', () {
    test('a bare host is read as https', () {
      expect(ServerUrl.parse('healthee.example.com').value,
          'https://healthee.example.com');
    });

    test('a bare host with a port is not parsed as a scheme', () {
      // Uri.parse('a.example.com:8765') alone reads the HOST as the scheme.
      expect(ServerUrl.parse('healthee.example.com:8765').value,
          'https://healthee.example.com:8765');
    });
  });

  group('what is not an address at all', () {
    test('empty is refused with a reason, not silently', () {
      expect(_failureOf('   '), isA<MalformedServerUrl>());
    });

    test('a non-web scheme is named', () {
      final failure = _failureOf('ftp://healthee.example.com');
      expect(failure, isA<MalformedServerUrl>());
      expect((failure! as MalformedServerUrl).detail, contains('ftp'));
    });

    test('a credential in the URL is refused outright', () {
      final failure = _failureOf('https://owner:hunter2@healthee.example.com');
      expect(failure, isA<MalformedServerUrl>());
      expect(failure!.remedy, contains('never puts a credential in a URL'));
    });
  });

  group('normalisation, so today and tomorrow talk to the same server', () {
    test('a trailing slash is dropped', () {
      expect(ServerUrl.parse('https://healthee.example.com/').value,
          'https://healthee.example.com');
    });

    test('a path prefix survives — a reverse proxy may mount the API under one', () {
      expect(ServerUrl.parse('https://example.com/healthee/').value,
          'https://example.com/healthee');
    });

    test('a query and a fragment do not', () {
      expect(ServerUrl.parse('https://example.com/?token=nope#x').value,
          'https://example.com');
    });

    test('resolve builds the endpoint without a doubled slash', () {
      expect(
        ServerUrl.parse('https://example.com/').resolve('/api/entitlement'),
        Uri.parse('https://example.com/api/entitlement'),
      );
    });

    test('the host is carried out for log lines and copy', () {
      expect(ServerUrl.parse('https://example.com:8765/x').host, 'example.com');
    });
  });
}
