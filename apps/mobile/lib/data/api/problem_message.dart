import 'package:dio/dio.dart';

/// Owner-facing API failures; server internals and request secrets stay hidden.
String apiProblem(Object error) {
  if (error is FormatException) return error.message;
  if (error is! DioException) return 'The operation could not be completed.';
  return switch (error.response?.statusCode) {
    401 || 403 => 'Sign in to your server to use this feature.',
    402 => 'This feature requires access enabled on your server.',
    404 => 'This item or endpoint is not available on your server.',
    409 =>
      _refusal(error.response?.data) ??
          'The current state does not allow this action. Refresh and try again.',
    422 =>
      'The server could not accept these inputs. Check the values and try again.',
    // **The server's own sentence, exactly as 409 already does.** The budget
    // refusal ships a written explanation — that the allowance is three a day,
    // that a fresh suggestion is calibrated from whole days of data so another
    // one today would be the same question in different words, that it resets
    // at local midnight, and that the app and the coach share it — plus
    // `limit`, `used`, `resets_at` and `retry_after_s`. All of that was being
    // replaced with "The server limit has been reached", which says none of it
    // and reads like a fault in the server rather than a deliberate cap.
    429 =>
      _refusal(error.response?.data) ??
          'The server limit has been reached. Try again later.',
    _ =>
      error.type == DioExceptionType.cancel
          ? 'Your server session changed. Reopen this screen.'
          : 'Could not reach the server. Check your connection and try again.',
  };
}

String? _refusal(Object? data) {
  if (data is! Map<String, Object?>) return null;
  final detail = data['detail'];
  if (detail is String) return detail;
  if (detail is Map<String, Object?> && detail['error'] is String) {
    return detail['error']! as String;
  }
  return null;
}
