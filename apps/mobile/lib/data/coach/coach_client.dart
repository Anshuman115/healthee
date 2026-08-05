/// The two calls the coach surface makes, and the named failures they can have.
///
/// `POST /api/coach` costs one of the owner's twenty included questions per
/// rolling thirty days (`PRICING.md` §0), and `GET /api/entitlement` is how many
/// are left. They are in one file because they are one transaction from the
/// owner's point of view: the meter is read before the question is asked and again
/// after it is answered, and a surface that could do one without the other is the
/// silent spend this feature is not allowed to have.
///
/// ## Why the meter is re-read rather than decremented
///
/// The server refunds the question on a refusal, on an unvalidated answer, and on
/// a transport failure (`routers/coach.py`). A client that subtracted one locally
/// would be wrong in all three cases and would be wrong in the *flattering*
/// direction — showing fewer questions than the owner has. Re-reading is one cheap
/// ungated call and it is the number the gate itself will enforce.
///
/// ## 402 is an answer, not a crash
///
/// The gate refuses with `402` and a body carrying `limit`, `used`, `resets_at`
/// and `retry_after_s`. That is the same information `/api/entitlement.included`
/// carries, so it is parsed into the same [CoachRefusal] shape rather than shown
/// as an HTTP status — a `DioException` type is never rendered to anybody
/// (`data/api/signin_failure.dart` sets the precedent).
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/coach/coach_answer.dart';
import 'package:healthee/data/models/entitlement.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'coach_client.g.dart';

/// The gate refused: the window is spent, or the feature is not included.
@immutable
class CoachRefusal implements Exception {
  /// [resetsAt] is null when the refusal is a hard lock rather than a full window.
  const CoachRefusal({required this.message, this.resetsAt});

  /// What to tell the owner, in this app's own words.
  final String message;

  /// When the window reopens, when the server said.
  final DateTime? resetsAt;

  @override
  String toString() => 'CoachRefusal($message)';
}

/// The request did not complete. Ours or the network's, never the owner's.
@immutable
class CoachUnreachable implements Exception {
  /// [message] is already owner-facing.
  const CoachUnreachable(this.message);

  /// The sentence to show, with no status code and no exception type in it.
  final String message;

  @override
  String toString() => 'CoachUnreachable($message)';
}

/// Asks the coach, and reads the meter.
class CoachClient {
  /// [dio] is the app's one authenticated client.
  const CoachClient(this._dio);

  final Dio _dio;

  /// What this owner is entitled to right now. Ungated, uncached, cheap.
  Future<Entitlement> entitlement() async {
    try {
      final response = await _dio.get<Map<String, Object?>>('/api/entitlement');
      final body = response.data;
      if (body == null) {
        throw const CoachUnreachable(
          'Your server answered the entitlement check with nothing at all.',
        );
      }
      return Entitlement.fromJson(body);
    } on DioException catch (error, stackTrace) {
      AppLog.failure('coach', 'reading /api/entitlement', error, stackTrace);
      throw CoachUnreachable(_unreachableSentence(error));
    }
  }

  /// Asks one question over [messages] — the whole conversation so far.
  ///
  /// **This is the call that spends a question.** Every caller must have shown the
  /// meter first; `features/coach/coach_controller.dart` is the only caller and
  /// its sheet cannot render an input without one.
  Future<CoachAnswer> ask(List<CoachTurn> messages) async {
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/api/coach',
        data: <String, Object?>{
          'messages': [for (final turn in messages) turn.toJson()],
        },
      );
      final body = response.data;
      if (body == null) {
        throw const CoachUnreachable(
          'Your server accepted the question and sent no answer back.',
        );
      }
      return CoachAnswer.fromJson(body);
    } on DioException catch (error, stackTrace) {
      AppLog.failure('coach', 'asking /api/coach', error, stackTrace);
      final refusal = _refusalFrom(error);
      if (refusal != null) {
        throw refusal;
      }
      throw CoachUnreachable(_unreachableSentence(error));
    }
  }

  /// The gate's 402 body, as this app's own refusal. Null for anything else.
  static CoachRefusal? _refusalFrom(DioException error) {
    if (error.response?.statusCode != 402) {
      return null;
    }
    final detail = switch (error.response?.data) {
      final Map<String, Object?> body => switch (body['detail']) {
        final Map<String, Object?> inner => inner,
        _ => body,
      },
      _ => const <String, Object?>{},
    };
    final resetsAt = switch (detail['resets_at']) {
      final String at => DateTime.tryParse(at),
      _ => null,
    };
    final limit = (detail['limit'] as num?)?.toInt();
    return CoachRefusal(
      message: limit == null
          ? 'Your server says the coach is not included on this account.'
          : 'You have used all $limit coach questions in this window.',
      resetsAt: resetsAt,
    );
  }

  /// One sentence, in the owner's terms, for a request that did not complete.
  ///
  /// The status is deliberately not shown. A 401 and a dead socket need different
  /// words because they need different actions, and everything else is one
  /// sentence — which is the taxonomy `signin_failure.dart` already argues for.
  static String _unreachableSentence(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'Your server refused the sign-in this phone holds. Sign in again '
          'from Settings and the coach will work.';
    }
    return "Couldn't reach your server. Nothing was asked and nothing was "
        'spent — your questions are untouched.';
  }
}

/// One turn of the conversation, as the router's `CoachMessage` expects it.
@immutable
class CoachTurn {
  /// [role] is `user` or `assistant`; system turns are ignored server-side.
  const CoachTurn({required this.role, required this.content});

  /// Who said it.
  final String role;

  /// What they said.
  final String content;

  /// The wire shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'role': role,
    'content': content,
  };

  /// Whether this turn came from the owner.
  bool get isOwner => role == 'user';
}

/// The app's [CoachClient].
@Riverpod(keepAlive: true)
CoachClient coachClient(Ref ref) => CoachClient(ref.watch(apiClientProvider));

/// What the owner is entitled to, re-read on demand.
///
/// Not `keepAlive`: the whole point of the endpoint being uncached server-side is
/// that a balance is only true at the moment it was read, and a provider that held
/// one across the life of the app would put a stale meter in front of a spend.
@riverpod
Future<Entitlement> coachEntitlement(Ref ref) =>
    ref.watch(coachClientProvider).entitlement();
