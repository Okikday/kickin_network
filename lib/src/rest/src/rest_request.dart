// ignore_for_file: public_member_api_docs, sort_constructors_first
// remember variants
part of '../rest_api_base.dart';

typedef ErrorOverrideCallback = Object? Function(dynamic data);
typedef DecodedCallback<TDecoded> = TDecoded Function(dynamic data, Response _);

class KRestRequest<TDecoded> {
  /// Shared request configuration used by every request wrapper in this file.
  /// Mostly use static values to declare. You can use copyWith from the other kind of requests to make proper changes
  KRestRequest(
    this._api, {
    required this.path,
    this.usePrimary = true,
    this.headers,
    this.data,
    Options? options,
    this.queryParams,
    this.cancelToken,
    this.onReceiveProgress,
    this.decoder,
    this.logOptions,
    this.useBaseUrl = true,
    this.errorOverride,
  }) : options = options?.copyWith(headers: headers) ?? Options(headers: headers);

  final KRestApi _api;
  final String path;
  final bool usePrimary;

  /// It will replace the one in [Options.headers], don't provide if you wish to use the one in the Options
  final Map<String, String>? headers;
  final Object? data;
  final Options? options;
  final Map<String, dynamic>? queryParams;
  final CancelToken? cancelToken;
  final void Function(int, int)? onReceiveProgress;
  final ErrorOverrideCallback? errorOverride;

  final LogOptions? logOptions;

  /// Set to true by default. You can set to false if you don't want to append with the baseUrl from the parent [KRestApiBase] and want to provide a full URL in [path] instead.
  /// Doesn't have any effect if the [KRestApiBase] doesn't have a [baseUrl] configured, in which case the [path] is used as-is regardless of this flag.
  final bool useBaseUrl;

  /// Converts the raw Dio response payload into the client-facing output type.
  /// [data] == [Response.data]
  final DecodedCallback<TDecoded>? decoder;

  /// Selects the Dio instance that matches [usePrimary].
  Dio get _dio => usePrimary ? _api._parent._primaryDio : _api._parent._externalDio;

  KRestApiBase get _apiBase => _api._parent;

  /// Builds a fallback [RequestOptions] object for error handling and offline decodes.
  RequestOptions _requestOptionsFor(String method) => RequestOptions(
    path: path,
    headers: headers,
    data: data,
    queryParameters: queryParams,
    cancelToken: cancelToken,
    onReceiveProgress: onReceiveProgress,
    method: method,
  );

  /// For getting the final path after considering [useBaseUrl] and the parent's [baseUrl] joined.
  late final _transformedPath = (useBaseUrl && _apiBase._baseUrl.isNotEmpty) ? "${_apiBase._baseUrl}$path" : path;
  String get transformedPath => _transformedPath;

  Future<KResponse<Raw, TDecoded>> _runRequest<Raw>(String method, {required Future<Response<Raw>> response}) async {
    if (kDebugMode) _logRequest(logOptions ?? _apiBase._logOptions, method);
    final result = await response;
    if (kDebugMode) _logResponse(logOptions ?? _apiBase._logOptions, method, result);

    return KResponse<Raw, TDecoded>.fromDioResponse(
      result,
      decoder: decoder,
      error: errorOverride?.call(result.data) ?? _api._parent.globalErrorOverride(result.data),
    );
  }

  Future<KResponse<Raw, TDecoded>> _tryRunRequest<Raw>(String method, {required Future<Response<Raw>> response}) async {
    try {
      final result = await _runRequest(method, response: response);
      return result;
    } catch (e) {
      final response = KResponse<Raw, TDecoded>.fromDioResponse(
        Response(requestOptions: _requestOptionsFor(method)),
        decoder: decoder,
        error: errorOverride?.call(e) ?? _api._parent.globalErrorOverride(e),
      );
      if (kDebugMode) _logResponse(logOptions ?? _apiBase._logOptions, method, response);
      return response;
    }
  }

  KGetRequest<TDecoded> toGetRequest() => KGetRequest<TDecoded>.from(this);
  KPostRequest<TDecoded> toPostRequest() => KPostRequest<TDecoded>.from(this);
  KPutRequest<TDecoded> toPutRequest() => KPutRequest<TDecoded>.from(this);
  KPatchRequest<TDecoded> toPatchRequest() => KPatchRequest<TDecoded>.from(this);
  KDeleteRequest<TDecoded> toDeleteRequest() => KDeleteRequest<TDecoded>.from(this);
  KDownloadRequest<TDecoded> toDownloadRequest({required dynamic savePath}) =>
      KDownloadRequest<TDecoded>.from(this, savePath: savePath);
  KRequest<TDecoded> toRequest() => KRequest<TDecoded>.from(this);

  void _logRequest(LogOptions logOptions, String method) {
    if (logOptions.parts.isEmpty) return;

    final Map<String, dynamic> output = {};

    if (logOptions.parts.contains(LogPart.queryParams) && queryParams != null) {
      output['Query'] = queryParams;
    }
    if (logOptions.parts.contains(LogPart.requestBody) && data != null) {
      output['Body'] = data;
    }
    if (logOptions.parts.contains(LogPart.requestHeaders) && headers != null) {
      output['Headers'] = headers;
    }

    final title = 'Request($method): $_transformedPath';
    if (output.isNotEmpty) {
      final prettyJson = const JsonEncoder.withIndent('  ').convert(output);

      NetworkLog.request('$title\n$prettyJson');
    } else {
      NetworkLog.request(title);
    }
  }

  void _logResponse<Raw>(LogOptions logOptions, String method, dynamic result) {
    if (logOptions.parts.isEmpty) return;
    final bool isOk = result.statusCode != null && result.statusCode! >= 200 && result.statusCode! < 300;
    final Map<String, dynamic> output = {};

    if (logOptions.parts.contains(LogPart.responseBody) && result is Response && result.data != null) {
      String rawData = result.data.toString();

      if (rawData.length > logOptions.maxLogLength) {
        output['Data'] = '${rawData.substring(0, logOptions.maxLogLength)}... [TRUNCATED]';
      } else {
        output['Data'] = result.data;
      }
    }

    if (logOptions.parts.contains(LogPart.responseHeaders) && result is Response) {
      output['Headers'] = result.headers.map;
    }

    if (!isOk && logOptions.parts.contains(LogPart.errors) && result is KResponse && result.error != null) {
      output['Error Details'] = result.error.toString();
    }

    final title = 'Response(${result.statusCode ?? 'ERR'}): $_transformedPath';

    final prettyJson = output.isNotEmpty ? '\n${const JsonEncoder.withIndent('  ').convert(output)}' : '';

    if (isOk) {
      NetworkLog.success('$title$prettyJson');
    } else {
      NetworkLog.error('$title$prettyJson');
    }
  }

  @override
  String toString() {
    return 'KRestRequest(path: $path, usePrimary: $usePrimary, headers: $headers, data: $data, options: $options, queryParams: $queryParams, cancelToken: $cancelToken, onReceiveProgress: $onReceiveProgress, logOptions: $logOptions, useBaseUrl: $useBaseUrl)';
  }
}

/// GET request wrapper with an optional custom operation and response decoder.
class KGetRequest<TDecoded> extends KRestRequest<TDecoded> {
  KGetRequest(
    super._api, {
    required super.path,
    super.usePrimary,
    super.useBaseUrl,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  KGetRequest._(
    super._api, {
    required super.path,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,
    super.queryParams,
    super.cancelToken,
    super.onReceiveProgress,
    super.decoder,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  static const method = 'GET';

  Future<KResponse<Raw, TDecoded>> _getResponse<Raw>(bool tryRun) async {
    final response = _dio.get<Raw>(
      _transformedPath,
      options: options,
      data: data,
      queryParameters: queryParams,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return tryRun ? _tryRunRequest(method, response: response) : _runRequest<Raw>(method, response: response);
  }

  Future<KResponse<Raw, TDecoded>> getResponse<Raw>() => _getResponse(false);

  Future<KResponse<Raw, TDecoded>> tryGetResponse<Raw>() => _getResponse(true);

  Future<TDecoded?> get() => _getResponse(false).then((v) => v.value);
  Future<TDecoded?> tryGet<Raw>() => _getResponse(true).then((v) => v.value);

  Future<ApiResult<TDecoded?>> getResult() => _getResponse(false).then((v) => v.result);
  Future<ApiResult<TDecoded?>> tryGetResult() => _getResponse(true).then((v) => v.result);

  /// Returns a copy of this request with the supplied overrides.
  KGetRequest<TDecoded> copyWith({
    String? Function(String)? pathTransform,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Map<String, dynamic>? queryParams,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    bool? useBaseUrl,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KGetRequest<TDecoded>._(
    _api,
    path: pathTransform?.call(path) ?? path,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    queryParams: queryParams ?? this.queryParams,
    options: (options ?? this.options)?.copyWith(headers: headers ?? this.headers),
    cancelToken: cancelToken ?? this.cancelToken,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KGetRequest.from(KRestRequest<TDecoded> r) => KGetRequest<TDecoded>._(
    r._api,
    path: r.path,
    usePrimary: r.usePrimary,
    headers: r.headers,
    data: r.data,
    options: r.options,
    queryParams: r.queryParams,
    cancelToken: r.cancelToken,
    onReceiveProgress: r.onReceiveProgress,
    decoder: r.decoder,
    useBaseUrl: r.useBaseUrl,
    logOptions: r.logOptions,
    errorOverride: r.errorOverride,
  );
}

class KPostRequest<TDecoded> extends KRestRequest<TDecoded> {
  KPostRequest(
    super._api, {
    required super.path,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });
  KPostRequest._(
    super._api, {
    required super.path,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,
    super.queryParams,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  static const method = 'POST';

  final void Function(int, int)? onSendProgress;

  Future<KResponse<Raw, TDecoded>> _postResponse<Raw>(bool tryRun) async {
    final response = _dio.post<Raw>(
      _transformedPath,
      options: options,
      data: data,
      queryParameters: queryParams,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return tryRun ? _tryRunRequest(method, response: response) : _runRequest<Raw>(method, response: response);
  }

  Future<KResponse<Raw, TDecoded>> postResponse<Raw>() => _postResponse(false);
  Future<KResponse<Raw, TDecoded>> tryPostResponse<Raw>() => _postResponse(true);
  Future<TDecoded?> post() => _postResponse(false).then((v) => v.value);
  Future<TDecoded?> tryPost() => _postResponse(true).then((v) => v.value);
  Future<ApiResult<TDecoded?>> postResult() => _postResponse(false).then((v) => v.result);
  Future<ApiResult<TDecoded?>> tryPostResult() => _postResponse(true).then((v) => v.result);

  KPostRequest<TDecoded> copyWith({
    String? Function(String)? pathTransform,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    Map<String, dynamic>? queryParams,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    bool? useBaseUrl,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KPostRequest<TDecoded>._(
    _api,
    path: pathTransform?.call(path) ?? path,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    options: (options ?? this.options)?.copyWith(headers: headers ?? this.headers),
    cancelToken: cancelToken ?? this.cancelToken,
    queryParams: queryParams ?? this.queryParams,
    onSendProgress: onSendProgress ?? this.onSendProgress,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KPostRequest.from(KRestRequest<TDecoded> r) => KPostRequest<TDecoded>._(
    r._api,
    path: r.path,
    usePrimary: r.usePrimary,
    headers: r.headers,
    data: r.data,
    options: r.options,
    queryParams: r.queryParams,
    cancelToken: r.cancelToken,
    onReceiveProgress: r.onReceiveProgress,
    decoder: r.decoder,
    useBaseUrl: r.useBaseUrl,
    logOptions: r.logOptions,
    errorOverride: r.errorOverride,
  );
}

/// PUT request wrapper with send-progress support and optional response decoding.
class KPutRequest<TDecoded> extends KRestRequest<TDecoded> {
  KPutRequest(
    super._api, {
    required super.path,
    super.usePrimary,
    super.decoder,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });
  KPutRequest._(
    super._api, {
    required super.path,
    super.usePrimary,
    super.headers,
    super.data,
    super.decoder,
    super.options,
    super.queryParams,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  static const method = 'PUT';

  final void Function(int, int)? onSendProgress;

  Future<KResponse<Raw, TDecoded>> _putResponse<Raw>(bool tryRun) async {
    final response = _dio.put<Raw>(
      _transformedPath,
      options: options,
      data: data,
      queryParameters: queryParams,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return tryRun ? _tryRunRequest(method, response: response) : _runRequest<Raw>(method, response: response);
  }

  Future<KResponse<Raw, TDecoded>> putResponse<Raw>() => _putResponse(false);
  Future<KResponse<Raw, TDecoded>> tryPutResponse<Raw>() => _putResponse(true);
  Future<TDecoded?> put() => _putResponse(false).then((v) => v.value);
  Future<TDecoded?> tryPut() => _putResponse(true).then((v) => v.value);
  Future<ApiResult<TDecoded?>> putResult() => _putResponse(false).then((v) => v.result);
  Future<ApiResult<TDecoded?>> tryPutResult() => _putResponse(true).then((v) => v.result);

  KPutRequest<TDecoded> copyWith({
    String? Function(String)? pathTransform,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    Map<String, dynamic>? queryParams,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    bool? useBaseUrl,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KPutRequest<TDecoded>._(
    _api,
    path: pathTransform?.call(path) ?? path,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    options: (options ?? this.options)?.copyWith(headers: headers ?? this.headers),
    cancelToken: cancelToken ?? this.cancelToken,
    queryParams: queryParams ?? this.queryParams,
    onSendProgress: onSendProgress ?? this.onSendProgress,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KPutRequest.from(KRestRequest<TDecoded> r) => KPutRequest<TDecoded>._(
    r._api,
    path: r.path,
    usePrimary: r.usePrimary,
    headers: r.headers,
    data: r.data,
    options: r.options,
    queryParams: r.queryParams,
    cancelToken: r.cancelToken,
    onReceiveProgress: r.onReceiveProgress,
    decoder: r.decoder,
    useBaseUrl: r.useBaseUrl,
    logOptions: r.logOptions,
    errorOverride: r.errorOverride,
  );
}

/// PATCH request wrapper with send-progress support and optional response decoding.
class KPatchRequest<TDecoded> extends KRestRequest<TDecoded> {
  KPatchRequest._(
    super._api, {
    required super.path,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,
    super.queryParams,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });
  KPatchRequest(
    super._api, {
    required super.path,
    super.usePrimary,
    super.decoder,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  static const method = 'PATCH';

  final void Function(int, int)? onSendProgress;

  Future<KResponse<Raw, TDecoded>> _patchResponse<Raw>(bool tryRun) async {
    final response = _dio.patch<Raw>(
      _transformedPath,
      options: options,
      data: data,
      queryParameters: queryParams,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return tryRun ? _tryRunRequest(method, response: response) : _runRequest<Raw>(method, response: response);
  }

  Future<KResponse<Raw, TDecoded>> patchResponse<Raw>() => _patchResponse(false);
  Future<KResponse<Raw, TDecoded>> tryPatchResponse<Raw>() => _patchResponse(true);
  Future<TDecoded?> patch() => _patchResponse(false).then((v) => v.value);
  Future<TDecoded?> tryPatch() => _patchResponse(true).then((v) => v.value);
  Future<ApiResult<TDecoded?>> patchResult() => _patchResponse(false).then((v) => v.result);
  Future<ApiResult<TDecoded?>> tryPatchResult() => _patchResponse(true).then((v) => v.result);

  KPatchRequest<TDecoded> copyWith({
    String? Function(String)? pathTransform,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    Map<String, dynamic>? queryParams,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    bool? useBaseUrl,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KPatchRequest<TDecoded>._(
    _api,
    path: pathTransform?.call(path) ?? path,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    options: (options ?? this.options)?.copyWith(headers: headers ?? this.headers),
    cancelToken: cancelToken ?? this.cancelToken,
    queryParams: queryParams ?? this.queryParams,
    onSendProgress: onSendProgress ?? this.onSendProgress,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KPatchRequest.from(KRestRequest<TDecoded> r) => KPatchRequest<TDecoded>._(
    r._api,
    path: r.path,
    usePrimary: r.usePrimary,
    headers: r.headers,
    data: r.data,
    options: r.options,
    queryParams: r.queryParams,
    cancelToken: r.cancelToken,
    onReceiveProgress: r.onReceiveProgress,
    decoder: r.decoder,
    useBaseUrl: r.useBaseUrl,
    logOptions: r.logOptions,
    errorOverride: r.errorOverride,
  );
}

/// DELETE request wrapper with optional response decoding.
class KDeleteRequest<TDecoded> extends KRestRequest<TDecoded> {
  KDeleteRequest._(
    super._api, {
    required super.path,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,
    super.queryParams,
    super.cancelToken,
    super.onReceiveProgress,
    super.decoder,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  KDeleteRequest(
    super._api, {
    required super.path,
    super.usePrimary,
    super.decoder,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  static const method = 'DELETE';

  Future<KResponse<Raw, TDecoded>> _deleteResponse<Raw>(bool tryRun) async {
    final response = _dio.delete<Raw>(
      _transformedPath,
      options: options,
      data: data,
      queryParameters: queryParams,
      cancelToken: cancelToken,
    );
    return tryRun ? _tryRunRequest(method, response: response) : _runRequest<Raw>(method, response: response);
  }

  Future<KResponse<Raw, TDecoded>> deleteResponse<Raw>() => _deleteResponse(false);
  Future<KResponse<Raw, TDecoded>> tryDeleteResponse<Raw>() => _deleteResponse(true);
  Future<TDecoded?> delete() => _deleteResponse(false).then((v) => v.value);
  Future<TDecoded?> tryDelete() => _deleteResponse(true).then((v) => v.value);
  Future<ApiResult<TDecoded?>> deleteResult() => _deleteResponse(false).then((v) => v.result);
  Future<ApiResult<TDecoded?>> tryDeleteResult() => _deleteResponse(true).then((v) => v.result);

  KDeleteRequest<TDecoded> copyWith({
    String? Function(String)? pathTransform,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    Map<String, dynamic>? queryParams,
    LogOptions? logOptions,
    bool? useBaseUrl,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KDeleteRequest<TDecoded>._(
    _api,
    path: pathTransform?.call(path) ?? path,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    options: (options ?? this.options)?.copyWith(headers: headers ?? this.headers),
    cancelToken: cancelToken ?? this.cancelToken,
    queryParams: queryParams ?? this.queryParams,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KDeleteRequest.from(KRestRequest<TDecoded> r) => KDeleteRequest<TDecoded>._(
    r._api,
    path: r.path,
    usePrimary: r.usePrimary,
    headers: r.headers,
    data: r.data,
    options: r.options,
    queryParams: r.queryParams,
    cancelToken: r.cancelToken,
    onReceiveProgress: r.onReceiveProgress,
    decoder: r.decoder,
    useBaseUrl: r.useBaseUrl,
    logOptions: r.logOptions,
    errorOverride: r.errorOverride,
  );
}

class KDownloadRequest<TDecoded> extends KRestRequest<TDecoded> {
  KDownloadRequest(
    super._api, {
    required super.path,
    this.savePath,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.fileAccessMode = FileAccessMode.write,
    this.deleteOnError = true,
    this.lengthHeader = Headers.contentLengthHeader,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });
  KDownloadRequest._(
    super._api, {
    required super.path,
    required this.savePath,
    super.usePrimary,
    super.options,
    super.queryParams,
    super.cancelToken,
    super.onReceiveProgress,
    this.fileAccessMode = FileAccessMode.write,
    this.deleteOnError = true,
    this.lengthHeader = Headers.contentLengthHeader,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  static const method = 'DOWNLOAD';

  final dynamic savePath;
  final FileAccessMode fileAccessMode;
  final bool deleteOnError;
  final String lengthHeader;

  Future<KResponse<dynamic, TDecoded>> _downloadResponse(bool tryRun) async {
    final response = _dio.download(
      _transformedPath,
      savePath,
      options: options,
      data: data,
      fileAccessMode: fileAccessMode,
      queryParameters: queryParams,
      cancelToken: cancelToken,
      lengthHeader: lengthHeader,
      onReceiveProgress: onReceiveProgress,
      deleteOnError: deleteOnError,
    );
    return tryRun ? _tryRunRequest(method, response: response) : _runRequest(method, response: response);
  }

  Future<KResponse<dynamic, TDecoded>> downloadResponse() => _downloadResponse(false);
  Future<KResponse<dynamic, TDecoded>> tryDownloadResponse() => _downloadResponse(true);
  Future<void> download() => _downloadResponse(false).then((v) => v.value);
  Future<void> tryDownload() => _downloadResponse(true).then((v) => v.value);
  Future<ApiResult<void>> downloadResult() => _downloadResponse(false).then((v) => v.result);
  Future<ApiResult<void>> tryDownloadResult() => _downloadResponse(true).then((v) => v.result);

  KDownloadRequest<TDecoded> copyWith({
    String? Function(String)? pathTransform,
    bool? usePrimary,
    dynamic savePath,
    Options? options,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
    bool? deleteOnError,
    String? lengthHeader,
    FileAccessMode? fileAccessMode,
    LogOptions? logOptions,
    bool? useBaseUrl,
    ErrorOverrideCallback? errorOverride,
  }) => KDownloadRequest<TDecoded>._(
    _api,
    path: pathTransform?.call(path) ?? path,
    savePath: savePath ?? this.savePath,
    usePrimary: usePrimary ?? this.usePrimary,
    // options: (options ?? this.options)?.copyWith(headers: headers ?? this.headers),
    options: options ?? this.options,
    queryParams: queryParams ?? this.queryParams,
    cancelToken: cancelToken ?? this.cancelToken,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    deleteOnError: deleteOnError ?? this.deleteOnError,
    fileAccessMode: fileAccessMode ?? this.fileAccessMode,
    lengthHeader: lengthHeader ?? this.lengthHeader,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KDownloadRequest.from(
    KRestRequest<TDecoded> r, {
    required dynamic savePath,
    String lengthHeader = Headers.contentLengthHeader,
  }) => KDownloadRequest<TDecoded>._(
    r._api,
    path: r.path,
    usePrimary: r.usePrimary,
    savePath: savePath,
    options: r.options,
    queryParams: r.queryParams,
    cancelToken: r.cancelToken,
    onReceiveProgress: r.onReceiveProgress,
    lengthHeader: lengthHeader,
    useBaseUrl: r.useBaseUrl,
    logOptions: r.logOptions,
    errorOverride: r.errorOverride,
  );
}

class KRequest<TDecoded> extends KRestRequest<TDecoded> {
  KRequest(
    super._api, {
    required super.path,
    super.usePrimary,
    super.decoder,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  KRequest._(
    super._api, {
    required super.path,
    super.usePrimary,
    super.headers,
    super.data,
    super.decoder,
    super.options,
    super.queryParams,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  static const method = 'REQUEST';

  final void Function(int, int)? onSendProgress;

  Future<KResponse<Raw, TDecoded>> _request<Raw>(bool tryRun) async {
    final response = _dio.request<Raw>(
      _transformedPath,
      options: options,
      data: data,
      queryParameters: queryParams,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return tryRun ? _tryRunRequest(method, response: response) : _runRequest<Raw>(method, response: response);
  }

  Future<KResponse<Raw, TDecoded>> request<Raw>() => _request(false);
  Future<KResponse<Raw, TDecoded>> tryRequest<Raw>() => _request(true);
  Future<TDecoded?> get() => _request(false).then((v) => v.value);
  Future<TDecoded?> tryGet() => _request(true).then((v) => v.value);
  Future<ApiResult<TDecoded?>> getResult() => _request(false).then((v) => v.result);
  Future<ApiResult<TDecoded?>> tryGetResult() => _request(true).then((v) => v.result);

  KRequest<TDecoded> copyWith({
    String? Function(String)? pathTransform,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Map<String, dynamic>? queryParams,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    bool? useBaseUrl,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KRequest<TDecoded>._(
    _api,
    path: pathTransform?.call(path) ?? path,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    queryParams: queryParams ?? this.queryParams,
    options: (options ?? this.options)?.copyWith(headers: headers ?? this.headers),
    cancelToken: cancelToken ?? this.cancelToken,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KRequest.from(KRestRequest<TDecoded> r) => KRequest<TDecoded>._(
    r._api,
    path: r.path,
    usePrimary: r.usePrimary,
    headers: r.headers,
    data: r.data,
    options: r.options,
    queryParams: r.queryParams,
    cancelToken: r.cancelToken,
    onReceiveProgress: r.onReceiveProgress,
    decoder: r.decoder,
    useBaseUrl: r.useBaseUrl,
    logOptions: r.logOptions,
    errorOverride: r.errorOverride,
  );
}
