import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:kickin_storage/kickin_storage.dart';
import 'src/network_logger.dart';

export 'package:dio/dio.dart' show CancelToken, Options, FileAccessMode;

part '../../models/api_response.dart';
part '../../models/log_options.dart';

part 'src/api_monitor_mixin.dart';
part 'src/api_cache_mixin.dart';
part 'src/rest_request.dart';

part 'rest_api.dart';

const kApiCacheBoxName = "kickin_api_cache";

/// =================================================
/// ApiBase
/// =================================================
/// Base class for the top-level API container in this package.
///
/// Extend this class once per app-level API root and let that object own the
/// concrete API clients for the app, such as `ChatsApi` and `UsersApi`.
/// Shared configuration such as API keys, monitoring, and cache setup lives
/// here.
///
/// Create the child API objects after the `ApiBase` instance exists, either in
/// the constructor body or through a lazy getter / `late final` field.
///
/// Example:
/// ```dart
/// class MainApi extends KRestApiBase with KApiCache {
///   static final on = MainApi._();
///   MainApi._();
///
///   late final ChatsApi chats = ChatsApi(this);
///   late final UsersApi users = UsersApi(this);
/// }
/// ```
///
/// Use a single shared instance for each API root to avoid cache or state
/// conflicts between clients.
abstract class KRestApiBase {
  KRestApiBase();

  // =================================================
  // Internet connectivity
  // =================================================

  final internetCheckerStream = InternetConnection().onStatusChange.asBroadcastStream();

  // =================================================
  // Internal config
  // =================================================

  bool _enabledMonitoring = kDebugMode;
  String _baseUrl = '';

  Dio _primaryDio = Dio();
  Dio _externalDio = Dio();

  LogOptions _logOptions = const LogOptions();

  // =================================================
  // Initialization
  // =================================================

  /// Initialises shared configuration for the API root.
  ///
  /// [baseUrl]            – Prefix applied to every request. Leave empty to
  ///                        disable prefixing.
  /// [monitorActivities]  – Enables activity logging (debug mode only).
  /// [cacheBoxName]       – Hive box name used when [syncCacheToStorage] is on.
  /// [syncCacheToStorage] – Persists the in-memory cache to Hive on each write.
  ///                        Requires the [KApiCacheMixin] mixin to be applied.
  /// [logOptions]         – Controls log verbosity and format.
  Future<void> intialize({
    String? baseUrl,
    bool monitorActivities = kDebugMode,
    String cacheBoxName = kApiCacheBoxName,
    bool syncCacheToStorage = false,
    LogOptions logOptions = const LogOptions.normal(),
  }) async {
    _enabledMonitoring = monitorActivities;
    _baseUrl = baseUrl ?? '';
    _logOptions = logOptions;

    if (syncCacheToStorage) {
      // Delegate persistence setup to KApiCache — will throw a clear error
      // if the mixin hasn't been applied.
      assert(
        this is KApiCacheMixin,
        'syncCacheToStorage requires the KApiCache mixin: '
        '`class MyApi extends KRestApiBase with KApiCache`',
      );
      await (this as KApiCacheMixin)._initStorage(cacheBoxName);
    }
  }

  // =================================================
  // Dio accessors
  // =================================================

  /// Replaces the primary Dio instance used by requests that opt into it.
  void setPrimaryDio(Dio dio) => _primaryDio = dio;

  /// Replaces the external Dio instance used by requests that opt out of the
  /// primary client.
  void setExternalDio(Dio dio) => _externalDio = dio;

  Object? globalErrorOverride(Object? error) {
    if (error == null) return null;
    if (error is Map && error.containsKey("error")) return error["error"];
    return null;
  }
}
