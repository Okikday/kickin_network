part of 'rest_api_base.dart';

/// Base class for concrete API clients owned by a [KRestApiBase].
///
/// Subclasses receive their parent [KRestApiBase] through the constructor and
/// can read shared state such as [baseUrl] and per-client cache values from it.
///
/// Cache accessors ([cache], [setCache], [clearCache]) delegate to the parent's
/// built-in in-memory cache, scoped by [id].
///
/// Example:
/// ```dart
/// class ChatsApi extends KRestApi<Map<String, dynamic>> {
///   ChatsApi(super.parent);
/// }
/// ```
abstract class KRestApi<CacheType> {
  final KRestApiBase _parent;
  KRestApi(this._parent);

  /// Unique key used to namespace this client's cache entry on the parent.
  /// Override if you have multiple [KRestApi] instances of the same type on
  /// the same parent.
  late final id = "${_parent.runtimeType}_$runtimeType";

  // =================================================
  // Convenience getters
  // =================================================

  @protected
  String get baseUrl => _parent._baseUrl;

  // =================================================
  // Cache accessors
  // =================================================

  @protected
  CacheType? get cache => _parent.getCache<CacheType>(id);

  @protected
  void setCache(CacheType value) => _parent.setCache<CacheType>(id, value);

  @protected
  void clearCache() => _parent.removeCache(id);

  // =================================================
  // Helpers
  // =================================================

  @protected
  Map<String, String> headerWithJsonContentType([
    Map<String, String>? headers,
  ]) {
    final h = headers ?? {};
    h['Content-Type'] = 'application/json';
    return h;
  }

  /// Use only when [baseUrl] is absent on the parent or you need to override
  /// it for a specific client.
  @protected
  String joinWithBaseUrl(String endpoint) => "$baseUrl$endpoint";
}
