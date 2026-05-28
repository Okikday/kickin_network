part of '../rest_api_base.dart';

/// =================================================
/// KApiCache
/// =================================================
/// Mixin that adds in-memory caching with optional Hive persistence to any
/// [KRestApiBase] subclass.
///
/// Apply it on your concrete API root:
/// ```dart
/// class MainApi extends KRestApiBase with KApiCache {
///   static final on = MainApi._();
///   MainApi._();
/// }
/// ```
///
/// Storage sync is opt-in via [KRestApiBase.intialize]:
/// ```dart
/// await MainApi.on.intialize(syncCacheToStorage: true);
/// ```
mixin KApiCacheMixin on KRestApiBase {
  // =================================================
  // Private fields
  // =================================================

  final _cacheMap = <String, dynamic>{};
  final _pendingWrites = Queue<String>();
  Timer? _flushTimer;
  static const _flushDelay = Duration(milliseconds: 300);

  AppHive? _syncHive;
  bool _syncEnabled = false;

  // =================================================
  // Internal setup — called by KRestApiBase.intialize
  // =================================================

  Future<void> _initStorage(String cacheBoxName) async {
    _syncHive ??= AppHive(boxName: cacheBoxName);
    if (!_syncHive!.isInitialized) await _syncHive!.initialize();
    _syncEnabled = true;
    await _syncCacheFromStorage(_syncHive!);
  }

  // =================================================
  // Cache read / write / delete
  // =================================================

  /// Returns the cached value for [key], or `null` if absent.
  CacheType? getCache<CacheType>(String key) => _cacheMap[key] as CacheType?;

  /// Stores [value] under [key], scheduling a flush to Hive when sync is on.
  void setCache<CacheType>(String key, CacheType value) {
    _cacheMap[key] = value;
    if (_syncEnabled) _schedulePersist(key);
  }

  /// Removes the entry for [key], scheduling a flush to Hive when sync is on.
  void removeCache(String key) {
    _cacheMap.remove(key);
    if (_syncEnabled) _schedulePersist(key);
  }

  /// Returns true if [key] exists in the cache.
  bool hasCache(String key) => _cacheMap.containsKey(key);

  /// Clears the entire in-memory cache and schedules a full flush when sync
  /// is enabled.
  void clearCache() {
    final keys = List<String>.from(_cacheMap.keys);
    _cacheMap.clear();
    if (_syncEnabled) {
      for (final k in keys) {
        _schedulePersist(k);
      }
    }
  }

  // =================================================
  // Persistence
  // =================================================

  void _schedulePersist(String key) {
    if (!_pendingWrites.contains(key)) {
      _pendingWrites.addLast(key);
    }
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, _flushPendingWrites);
  }

  Future<void> _flushPendingWrites() async {
    if (_pendingWrites.isEmpty || _syncHive == null) return;
    final hive = _syncHive!;
    if (!hive.isInitialized) await hive.initialize();

    final keysToFlush = List<String>.from(_pendingWrites);
    _pendingWrites.clear();

    final kApiBaseKeysKey = "${runtimeType}_keys";

    for (final key in keysToFlush) {
      final value = _cacheMap[key];
      if (value != null) {
        await hive.setData(key: key, value: value);
      } else {
        await hive.deleteData(key: key);
      }
    }

    // Keep the stored key index up to date so _syncCacheFromStorage can
    // reconstruct the map on next cold start.
    final liveKeys = _cacheMap.keys.toList();
    await hive.setData(key: kApiBaseKeysKey, value: liveKeys);
  }

  Future<void> _syncCacheFromStorage(AppHive hive) async {
    if (!hive.isInitialized) await hive.initialize();
    final kApiBaseKeysKey = "${runtimeType}_keys";
    final storedKeys = hive.getData(key: kApiBaseKeysKey) as List<String>? ?? <String>[];
    for (final key in storedKeys) {
      final value = await hive.getData(key: key);
      if (value != null) _cacheMap[key] = value;
    }
  }

  // =================================================
  // Disposal
  // =================================================

  /// Cancels any pending flush timer. Call this from your API root's
  /// `dispose()` override alongside [disposeMonitor] if using [_ApiMonitor].
  void disposeCache() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingWrites.clear();
  }
}
