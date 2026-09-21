import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:logger/logger.dart';

export 'package:dio/dio.dart' show CancelToken, Options, FileAccessMode;

part '../models/api_response.dart';
part '../models/log_options.dart';

part 'src/network_logger.dart';
part 'src/api_monitor_mixin.dart';
part 'src/rest_request.dart';
part 'src/ext_on_rest_request.dart';
part 'src/rest_uri_request.dart';
part 'src/ext_on_rest_uri_request.dart';

part 'rest_api.dart';

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
/// Includes a built-in in-memory cache accessible via [getCache], [setCache],
/// [removeCache], [hasCache], [clearCache], and [disposeCache]. Child
/// [KRestApi] clients get scoped cache slots automatically.
///
/// Example:
/// ```dart
/// class MainApi extends KRestApiBase {
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
  // In-memory cache
  // =================================================

  final _cacheMap = <String, dynamic>{};

  /// Returns the cached value for [key], or `null` if absent.
  CacheType? getCache<CacheType>(String key) => _cacheMap[key] as CacheType?;

  /// Stores [value] under [key].
  void setCache<CacheType>(String key, CacheType value) =>
      _cacheMap[key] = value;

  /// Removes the entry for [key].
  void removeCache(String key) => _cacheMap.remove(key);

  /// Returns true if [key] exists in the cache.
  bool hasCache(String key) => _cacheMap.containsKey(key);

  /// Clears the entire in-memory cache.
  void clearCache() => _cacheMap.clear();

  /// Releases cache resources. Call from your dispose method.
  void disposeCache() => _cacheMap.clear();

  // =================================================
  // Internal config
  // =================================================

  bool _enabledMonitoring = kDebugMode;
  String _baseUrl = '';

  Dio? _pDio;
  Dio? _eDio;

  Dio get _primaryDio {
    _pDio ??= Dio();
    return _pDio!;
  }

  Dio get _externalDio {
    _eDio ??= Dio();
    return _eDio!;
  }

  LogOptions _logOptions = const LogOptions();

  // =================================================
  // Initialization
  // =================================================

  /// Initialises shared configuration for the API root.
  ///
  /// [baseUrl]            – Prefix applied to every request. Leave empty to
  ///                        disable prefixing.
  /// [monitorActivities]  – Enables activity logging (debug mode only).
  /// [logOptions]         – Controls log verbosity and format.
  Future<void> initialize({
    String? baseUrl,
    bool monitorActivities = kDebugMode,
    LogOptions logOptions = const LogOptions.normal(),
  }) async {
    _enabledMonitoring = monitorActivities;
    _baseUrl = baseUrl ?? '';
    _logOptions = logOptions;
    if (baseUrl != null && baseUrl.endsWith('/')) {
      log(
        "Warning: baseUrl should not end with a trailing slash. "
        "You may encounter unexpected behavior when constructing request URLs."
        "You can fix this by removing the trailing slash from the baseUrl.",
        name: "KRestApiBase.initialize",
        level: 900,
      );
    }
  }

  // =================================================
  // Dio accessors
  // =================================================

  /// Replaces the primary Dio instance used by requests that opt into it.
  void setPrimaryDio(Dio dio) => _pDio = dio;

  /// Replaces the external Dio instance used by requests that opt out of the
  /// primary client.
  void setExternalDio(Dio dio) => _eDio = dio;

  /// The base URL prepended to all requests sent through this API root.
  String get baseUrl => _baseUrl;

  /// Modifiable list of interceptors for the primary Dio client.
  Interceptors get primaryInterceptors => _primaryDio.interceptors;

  /// Access or update the base options for the primary Dio client.
  BaseOptions get primaryOptions => _primaryDio.options;
  set primaryOptions(BaseOptions options) => _primaryDio.options = options;
  Transformer get primaryTransformer => _primaryDio.transformer;
  set primaryTransformer(Transformer transformer) =>
      _primaryDio.transformer = transformer;

  Interceptors get externalInterceptors => _externalDio.interceptors;
  BaseOptions get externalOptions => _externalDio.options;
  set externalOptions(BaseOptions options) => _externalDio.options = options;
  Transformer get externalTransformer => _externalDio.transformer;
  set externalTransformer(Transformer transformer) =>
      _externalDio.transformer = transformer;

  /// Creates a clone of the primary Dio client, allowing for local overrides.
  Dio primaryClone({
    BaseOptions? options,
    Interceptors? interceptors,
    HttpClientAdapter? httpClientAdapter,
    Transformer? transformer,
  }) => _primaryDio.clone(
    options: options,
    interceptors: interceptors,
    httpClientAdapter: httpClientAdapter,
    transformer: transformer,
  );

  /// Creates a clone of the external Dio client, allowing for local overrides.
  Dio externalClone({
    BaseOptions? options,
    Interceptors? interceptors,
    HttpClientAdapter? httpClientAdapter,
    Transformer? transformer,
  }) => _externalDio.clone(
    options: options,
    interceptors: interceptors,
    httpClientAdapter: httpClientAdapter,
    transformer: transformer,
  );

  /// Global error interceptor to format errors into a unified structure.
  /// Subclasses can override this to implement custom error parsing logic.
  Object? globalErrorOverride(
    Response<dynamic> response,
    Object? error, [
    StackTrace? st,
  ]) {
    try {
      return defaultErrorOverride(_logOptions, response, error, st);
    } catch (e) {
      shouldLogError(
        _logOptions,
        error,
        "Error swallowed by globalErrorOverride. Override defaultErrorOverride for explicit catching. ",
        st,
      );
      return null;
    }
  }

  Object? defaultErrorOverride(
    LogOptions logOptions,
    Response<dynamic> response,
    Object? error, [
    StackTrace? st,
  ]) {
    Object? errorObj;
    final data =
        response.data ?? (error is DioException ? error.response?.data : null);
    if (data != null) {
      errorObj = resolveErrorObj(response.data);
      shouldLogError(logOptions, error, errorObj, st);
      return errorObj;
    }

    errorObj = switch (error) {
      DioException d => switch (d.type) {
        DioExceptionType.connectionTimeout =>
          'Connection timed out. Please check your internet and try again.',
        DioExceptionType.sendTimeout =>
          'Request took too long to send. Please try again.',
        DioExceptionType.receiveTimeout =>
          'Server took too long to respond. Please try again.',
        DioExceptionType.badCertificate =>
          'Secure connection failed. Please update the app or contact support.',
        DioExceptionType.badResponse => switch (error.response?.statusCode) {
          400 => 'Bad request. Please check your input.',
          401 => 'Session expired. Please sign in again or refresh.',
          403 => 'You don\'t have permission to do that.',
          404 => 'The requested resource was not found.',
          408 => 'Request timed out. Please try again.',
          409 => 'Conflict. This action can\'t be completed right now.',
          422 => 'Invalid data submitted. Please check your input.',
          429 => 'Too many requests. Please slow down and try again.',
          500 => 'Something went wrong on our end. Please try again later.',
          502 => 'Server is temporarily unavailable. Please try again.',
          503 => 'Service is down for maintenance. Please try again later.',
          504 => 'Server gateway timed out. Please try again.',
          _ =>
            'Unexpected error (${error.response?.statusCode}). Please try again.',
        },
        DioExceptionType.cancel => 'Request was cancelled.',
        DioExceptionType.connectionError =>
          'No internet connection. Please check your network.',
        DioExceptionType.transformTimeout =>
          'Data processing took too long. Please try again.',
        DioExceptionType.unknown =>
          'An unexpected error occurred. Please try again.',
      },
      CertificateException c => c.message,
      HandshakeException h => h.message,
      SocketException s => s.message,
      TimeoutException t => t.message,
      FormatException f => f.message,
      _ => null,
    };

    shouldLogError(logOptions, error, errorObj, st);
    if (errorObj == null) {
      throw ("Error: Override Global error and catch the super override in [KRestApiBase] for more info or set validateStatus to always return true");
    }
    return errorObj;
  }

  /// Attempts to extract a readable error message or object from the raw response data.
  Object? resolveErrorObj(dynamic data) => switch (data) {
    Map m => m["error"] ?? m["data"]["error"],
    String s => () {
      try {
        final decoded = jsonDecode(s) as Map;
        return decoded["data"]["error"] ?? decoded["error"];
      } catch (e) {
        return s;
      }
    }(),
    _ => data,
  };

  /// Conditionally logs an error if [LogOptions.logAllError] is enabled.
  void shouldLogError(
    LogOptions logOptions,
    Object? error,
    Object? errorObj,
    StackTrace? st,
  ) {
    if (logOptions.logAllError) {
      log(
        "${errorObj ?? error}",
        error: error,
        stackTrace: st,
        name: "KRestApiBase.globalErrorOverride",
        level: 1000,
      );
    }
  }
}
