/// The payload and its freshness travel together; cached targets are never current.
class ServerSnapshot<T> {
  const ServerSnapshot(
    this.data, {
    required this.fetchedAt,
    this.stale = false,
    this.refreshError,
  });
  final T data;
  final DateTime fetchedAt;
  final bool stale;
  final String? refreshError;
}
