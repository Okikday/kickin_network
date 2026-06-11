import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

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
part 'src/ext_on_rest_request.dart';
part 'src/rest_uri_request.dart';
part 'src/ext_on_rest_uri_request.dart';

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
  void setPrimaryDio(Dio dio) => _pDio = dio;

  /// Replaces the external Dio instance used by requests that opt out of the
  /// primary client.
  void setExternalDio(Dio dio) => _eDio = dio;

  String get baseUrl => _baseUrl;

  Interceptors get primaryInterceptors => _primaryDio.interceptors;
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
}

extension KRestApiBaseErrorHandlerExtension on KRestApiBase {
  Object? globalErrorOverride(
    Response<dynamic> response,
    Object? error, [
    StackTrace? st,
    Object? Function(Response<dynamic> data, Object? error, StackTrace? st)?
    handleRawError,
  ]) => defaultErrorOverride(_logOptions, response, error, st, handleRawError);

  Object? defaultErrorOverride(
    LogOptions logOptions,
    Response<dynamic> response,
    Object? error, [
    StackTrace? st,
    Object? Function(Response<dynamic> response, Object? error, StackTrace? st)?
    handleRawError,
  ]) {
    if (handleRawError != null) return handleRawError(response, error, st);
    String? errorStr;
    final data =
        response.data ?? (error is DioException ? error.response?.data : null);
    if (data != null) {
      errorStr = resolveErrorStr(response.data);
      if (errorStr != null) {
        shouldLogError(logOptions, error, errorStr, st);
        return errorStr;
      }
    }

    errorStr = switch (error) {
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

    shouldLogError(logOptions, error, errorStr, st);

    return errorStr ??
        "Error: Override Global error in [KRestApiBase] for more info";
  }

  String? resolveErrorStr(dynamic data) => switch (data) {
    Map m => m["error"] ?? m["data"]["error"],
    String s => () {
      try {
        final decoded = jsonDecode(s) as Map;
        return decoded["data"]["error"] ?? decoded["error"];
      } catch (e) {
        return null;
      }
    }(),
    _ => null,
  };

  void shouldLogError(
    LogOptions logOptions,
    Object? error,
    String? errorStr,
    StackTrace? st,
  ) {
    if (logOptions.logAllError) {
      log(
        "${errorStr ?? error}",
        error: error,
        stackTrace: st,
        name: "KRestApiBase.globalErrorOverride",
        level: 1000,
      );
    }
  }
}
