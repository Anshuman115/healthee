import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Preserve a same-account refresh, but never data inherited from a dependency
/// reload (which includes sign-in changes) or from a failed replacement read.
AsyncValue<T> currentAccountValue<T>(AsyncValue<T> value) =>
    value is AsyncData<T> && value.isRefreshing
    ? value
    : value.unwrapPrevious();
