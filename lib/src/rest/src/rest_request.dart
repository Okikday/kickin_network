// ignore_for_file: public_member_api_docs, sort_constructors_first
part of '../rest_api_base.dart';

typedef ErrorOverrideCallback<Raw> =
    Object? Function(Response<Raw> data, Object? error, [StackTrace? st]);
typedef DecodedCallback<TDecoded> = TDecoded Function(dynamic data, Response _);

/// =================================================
/// KRestRequest
/// =================================================
/// Base class for all path-based request wrappers.
/// For Uri-based requests, see [KUriRequest] and its subclasses
/// (e.g. [KGetUriRequest], [KPostUriRequest], …).
class KRestRequest<TDecoded> {
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
  }) : options =
           options?.copyWith(headers: headers) ?? Options(headers: headers);

  final KRestApi _api;
  final String path;
  final bool usePrimary;

  /// Replaces [Options.headers]. Omit to keep what's in [options].
  final Map<String, Object?>? headers;
  final Object? data;
  final Options? options;
  final Map<String, dynamic>? queryParams;
  final CancelToken? cancelToken;
  final void Function(int, int)? onReceiveProgress;
  final ErrorOverrideCallback? errorOverride;
  final LogOptions? logOptions;

  /// Set to true by default. Set to false to use [path] as a full URL,
  /// bypassing the parent [KRestApiBase.baseUrl].
  /// Has no effect when the parent has no baseUrl configured.
  final bool useBaseUrl;

  /// Converts the raw Dio response payload into the client-facing output type.
  /// [data] == [Response.data]
  final DecodedCallback<TDecoded>? decoder;

  Dio get _dio =>
      usePrimary ? _api._parent._primaryDio : _api._parent._externalDio;

  KRestApiBase get _apiBase => _api._parent;

  /// Builds a fallback [RequestOptions] for error handling and offline decodes.
  RequestOptions _requestOptionsFor(String method) => RequestOptions(
    path: path,
    headers: headers,
    data: data,
    queryParameters: queryParams,
    cancelToken: cancelToken,
    onReceiveProgress: onReceiveProgress,
    method: method,
    sendTimeout: options?.sendTimeout,
    receiveTimeout: options?.receiveTimeout,
    connectTimeout: options?.connectTimeout,
    extra: options?.extra,
    baseUrl: _api._parent._baseUrl,
    responseType: options?.responseType,
    preserveHeaderCase: options?.preserveHeaderCase,
    contentType: options?.contentType,
    validateStatus: options?.validateStatus,
    receiveDataWhenStatusError: options?.receiveDataWhenStatusError,
    followRedirects: options?.followRedirects,
    maxRedirects: options?.maxRedirects,
    requestEncoder: options?.requestEncoder,
    responseDecoder: options?.responseDecoder,
    listFormat: options?.listFormat,
    sourceStackTrace: StackTrace.current,
  );

  late final _transformedPath = (useBaseUrl && _apiBase._baseUrl.isNotEmpty)
      ? '${_apiBase._baseUrl}$path'
      : path;

  String get transformedPath => _transformedPath;

  @internal
  String get method => 'UNKNOWN';

  Future<Response<Raw>> _implResponse<Raw>() =>
      throw 'You tried sending the request on base class KRestRequest. '
          'Try converting to those that extend it.';

  @override
  String toString() =>
      'KRestRequest(path: $path, usePrimary: $usePrimary, headers: $headers, '
      'data: $data, options: $options, queryParams: $queryParams, '
      'cancelToken: $cancelToken, onReceiveProgress: $onReceiveProgress, '
      'logOptions: $logOptions, useBaseUrl: $useBaseUrl)';
}

// =================================================
// GET
// =================================================

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

  @override
  String get method => 'GET';

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.get<Raw>(
    _transformedPath,
    options: options,
    data: data,
    queryParameters: queryParams,
    cancelToken: cancelToken,
    onReceiveProgress: onReceiveProgress,
  );

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
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
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

// =================================================
// POST
// =================================================

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

  @override
  String get method => 'POST';

  final void Function(int, int)? onSendProgress;

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.post<Raw>(
    _transformedPath,
    options: options,
    data: data,
    queryParameters: queryParams,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

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
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,
    queryParams: queryParams ?? this.queryParams,
    onSendProgress: onSendProgress ?? this.onSendProgress,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KPostRequest.from(KRestRequest<TDecoded> r) =>
      KPostRequest<TDecoded>._(
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

// =================================================
// PUT
// =================================================

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

  @override
  String get method => 'PUT';

  final void Function(int, int)? onSendProgress;

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.put<Raw>(
    _transformedPath,
    options: options,
    data: data,
    queryParameters: queryParams,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

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
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
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

// =================================================
// PATCH
// =================================================

class KPatchRequest<TDecoded> extends KRestRequest<TDecoded> {
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

  @override
  String get method => 'PATCH';

  final void Function(int, int)? onSendProgress;

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.patch<Raw>(
    _transformedPath,
    options: options,
    data: data,
    queryParameters: queryParams,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

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
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,
    queryParams: queryParams ?? this.queryParams,
    onSendProgress: onSendProgress ?? this.onSendProgress,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KPatchRequest.from(KRestRequest<TDecoded> r) =>
      KPatchRequest<TDecoded>._(
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

// =================================================
// DELETE
// =================================================

class KDeleteRequest<TDecoded> extends KRestRequest<TDecoded> {
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

  @override
  String get method => 'DELETE';

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.delete<Raw>(
    _transformedPath,
    options: options,
    data: data,
    queryParameters: queryParams,
    cancelToken: cancelToken,
  );

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
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,
    queryParams: queryParams ?? this.queryParams,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KDeleteRequest.from(KRestRequest<TDecoded> r) =>
      KDeleteRequest<TDecoded>._(
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

// =================================================
// DOWNLOAD (path variant)
// =================================================

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

  @override
  String get method => 'DOWNLOAD';

  final dynamic savePath;
  final FileAccessMode fileAccessMode;
  final bool deleteOnError;
  final String lengthHeader;

  /// Do not add the generic type parameter [Raw] (excluding dynamic) when
  /// calling this method, otherwise it will cause a type error.
  @override
  Future<Response<Raw>> _implResponse<Raw>() =>
      _dio.download(
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
          )
          as Future<Response<Raw>>;

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

// =================================================
// HEAD
// =================================================

class KHeadRequest<TDecoded> extends KRestRequest<TDecoded> {
  KHeadRequest(
    super._api, {
    required super.path,
    super.usePrimary,
    super.decoder,
    super.options,
    super.cancelToken,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  KHeadRequest._(
    super._api, {
    required super.path,
    super.usePrimary,
    super.headers,
    super.data,
    super.decoder,
    super.options,
    super.queryParams,
    super.cancelToken,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  });

  @override
  String get method => 'HEAD';

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.head<Raw>(
    _transformedPath,
    options: options,
    data: data,
    queryParameters: queryParams,
    cancelToken: cancelToken,
  );

  KHeadRequest<TDecoded> copyWith({
    String? Function(String)? pathTransform,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Map<String, dynamic>? queryParams,
    Options? options,
    CancelToken? cancelToken,
    LogOptions? logOptions,
    bool? useBaseUrl,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KHeadRequest<TDecoded>._(
    _api,
    path: pathTransform?.call(path) ?? path,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    queryParams: queryParams ?? this.queryParams,
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KHeadRequest.from(KRestRequest<TDecoded> r) =>
      KHeadRequest<TDecoded>._(
        r._api,
        path: r.path,
        usePrimary: r.usePrimary,
        headers: r.headers,
        data: r.data,
        options: r.options,
        queryParams: r.queryParams,
        cancelToken: r.cancelToken,
        decoder: r.decoder,
        useBaseUrl: r.useBaseUrl,
        logOptions: r.logOptions,
        errorOverride: r.errorOverride,
      );
}

// =================================================
// REQUEST (generic method via options)
// =================================================

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

  @override
  String get method => 'REQUEST';

  final void Function(int, int)? onSendProgress;

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.request<Raw>(
    _transformedPath,
    options: options,
    data: data,
    queryParameters: queryParams,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

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
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
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

// =================================================
// FETCH (RequestOptions passthrough — uri-agnostic)
// =================================================

class KFetchRequest<TDecoded> extends KRestRequest<TDecoded> {
  KFetchRequest(
    super._api, {
    required this.requestOptions,
    super.usePrimary,
    super.decoder,
    super.logOptions,
    super.useBaseUrl,
    super.errorOverride,
  }) : super(
         path: requestOptions.path,
         headers: requestOptions.headers,
         data: requestOptions.data,
         queryParams: requestOptions.queryParameters,
         cancelToken: requestOptions.cancelToken,
       );

  final RequestOptions requestOptions;

  @override
  String get method => 'FETCH';

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.fetch<Raw>(requestOptions);

  KFetchRequest<TDecoded> copyWith({
    RequestOptions? requestOptions,
    bool? usePrimary,
    LogOptions? logOptions,
    bool? useBaseUrl,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KFetchRequest<TDecoded>(
    _api,
    requestOptions: requestOptions ?? this.requestOptions,
    usePrimary: usePrimary ?? this.usePrimary,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    useBaseUrl: useBaseUrl ?? this.useBaseUrl,
    errorOverride: errorOverride ?? this.errorOverride,
  );

  factory KFetchRequest.from(
    KRestRequest<TDecoded> r,
    RequestOptions requestOptions,
  ) => KFetchRequest<TDecoded>(
    r._api,
    requestOptions: requestOptions,
    usePrimary: r.usePrimary,
    decoder: r.decoder,
    logOptions: r.logOptions,
    useBaseUrl: r.useBaseUrl,
    errorOverride: r.errorOverride,
  );
}
