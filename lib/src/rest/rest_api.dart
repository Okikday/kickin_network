part of 'rest_api_base.dart';

/// Base class for concrete API clients owned by a [KRestApiBase].
///
/// Subclasses receive their parent [KRestApiBase] through the constructor and
/// can read shared state such as [baseUrl] and per-client cache values from it.
///
/// Example:
/// ```dart
/// class ChatsApi extends KRestApi<Map<String, dynamic>> {
///   ChatsApi(super.parent);
/// }
/// ```
///
/// Cache accessors ([cache], [setCache], [clearCache]) require the parent to
/// have the [KApiCacheMixin] mixin applied. A clear assert fires at runtime if it
/// doesn't.
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

  /// Returns the [KApiCacheMixin] mixin from the parent, asserting it is present.
  KApiCacheMixin get _cache {
    assert(
      _parent is KApiCacheMixin,
      '$runtimeType tried to access the cache but ${_parent.runtimeType} '
      'does not have the KApiCacheMixin mixin. '
      'Add it: `class ${_parent.runtimeType} extends KRestApiBase with KApiCacheMixin`',
    );
    return _parent as KApiCacheMixin;
  }

  // =================================================
  // Cache accessors
  // =================================================

  @protected
  CacheType? get cache => _cache.getCache<CacheType>(id);

  @protected
  void setCache(CacheType value) => _cache.setCache<CacheType>(id, value);

  @protected
  void clearCache() => _cache.removeCache(id);

  // =================================================
  // Helpers
  // =================================================

  @protected
  Map<String, String> headerWithJsonContentType([Map<String, String>? headers]) {
    final h = headers ?? {};
    h['Content-Type'] = 'application/json';
    return h;
  }

  /// Use only when [baseUrl] is absent on the parent or you need to override
  /// it for a specific client.
  @protected
  String joinWithBaseUrl(String endpoint) => "$baseUrl$endpoint";
}
