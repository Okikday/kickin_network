// ignore_for_file: unintended_html_in_doc_comment, public_member_api_docs, sort_constructors_first
part of '../rest_api_base.dart';

/// =================================================
/// URI-based request variants
/// =================================================
/// Parallel classes to the path-based request classes, but take a [Uri]
/// directly instead of a path string. No [useBaseUrl], no [pathTransform] —
/// the Uri is the full destination.
///
/// Use these when you have a fully-qualified Uri at hand (e.g. from a
/// previous response's Location header, a deep-link, or an external service).
///
/// Naming convention: K<Verb>UriRequest mirrors K<Verb>Request exactly,
/// minus path-specific members.

// =================================================
// Abstract base for all URI requests
// =================================================

abstract class KUriRequest<TDecoded> {
  KUriRequest(
    this._api, {
    required this.uri,
    this.usePrimary = true,
    this.headers,
    this.data,
    Options? options,
    this.cancelToken,
    this.onReceiveProgress,
    this.decoder,
    this.logOptions,
    this.errorOverride,
  }) : options =
           options?.copyWith(headers: headers) ?? Options(headers: headers);

  final KRestApi _api;
  final Uri uri;
  final bool usePrimary;

  /// Replaces [Options.headers]. Omit to keep what's in [options].
  final Map<String, Object?>? headers;
  final Object? data;
  final Options? options;
  final CancelToken? cancelToken;
  final void Function(int, int)? onReceiveProgress;
  final ErrorOverrideCallback? errorOverride;
  final LogOptions? logOptions;
  final DecodedCallback<TDecoded>? decoder;

  Dio get _dio =>
      usePrimary ? _api._parent._primaryDio : _api._parent._externalDio;

  KRestApiBase get _apiBase => _api._parent;

  /// Builds a fallback [RequestOptions] for error handling.
  RequestOptions _requestOptionsFor(String method) => RequestOptions(
    path: uri.path,
    headers: headers,
    data: data,
    queryParameters: uri.queryParameters,
    cancelToken: cancelToken,
    onReceiveProgress: onReceiveProgress,
    method: method,
  );

  @internal
  String get method => 'UNKNOWN';

  Future<Response<Raw>> _implResponse<Raw>();

  @override
  String toString() =>
      '$runtimeType(uri: $uri, usePrimary: $usePrimary, headers: $headers, '
      'data: $data, options: $options, queryParams: ${uri.queryParameters}, '
      'cancelToken: $cancelToken, logOptions: $logOptions)';
}

// =================================================
// GET
// =================================================

class KGetUriRequest<TDecoded> extends KUriRequest<TDecoded> {
  KGetUriRequest(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  KGetUriRequest._(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,

    super.cancelToken,
    super.onReceiveProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  @override
  String get method => 'GET';

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.getUri<Raw>(
    uri,
    options: options,
    cancelToken: cancelToken,
    onReceiveProgress: onReceiveProgress,
  );

  KGetUriRequest<TDecoded> copyWith({
    Uri? uri,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KGetUriRequest<TDecoded>._(
    _api,
    uri: uri ?? this.uri,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    errorOverride: errorOverride ?? this.errorOverride,
  );
}

// =================================================
// POST
// =================================================

class KPostUriRequest<TDecoded> extends KUriRequest<TDecoded> {
  KPostUriRequest(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  KPostUriRequest._(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,

    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  @override
  String get method => 'POST';

  final void Function(int, int)? onSendProgress;

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.postUri<Raw>(
    uri,
    options: options,
    data: data,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  KPostUriRequest<TDecoded> copyWith({
    Uri? uri,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Options? options,
    CancelToken? cancelToken,

    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KPostUriRequest<TDecoded>._(
    _api,
    uri: uri ?? this.uri,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,

    onSendProgress: onSendProgress ?? this.onSendProgress,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    errorOverride: errorOverride ?? this.errorOverride,
  );
}

// =================================================
// PUT
// =================================================

class KPutUriRequest<TDecoded> extends KUriRequest<TDecoded> {
  KPutUriRequest(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  KPutUriRequest._(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,

    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  @override
  String get method => 'PUT';

  final void Function(int, int)? onSendProgress;

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.putUri<Raw>(
    uri,
    options: options,
    data: data,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  KPutUriRequest<TDecoded> copyWith({
    Uri? uri,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Options? options,
    CancelToken? cancelToken,

    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KPutUriRequest<TDecoded>._(
    _api,
    uri: uri ?? this.uri,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,

    onSendProgress: onSendProgress ?? this.onSendProgress,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    errorOverride: errorOverride ?? this.errorOverride,
  );
}

// =================================================
// PATCH
// =================================================

class KPatchUriRequest<TDecoded> extends KUriRequest<TDecoded> {
  KPatchUriRequest(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  KPatchUriRequest._(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,

    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  @override
  String get method => 'PATCH';

  final void Function(int, int)? onSendProgress;

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.patchUri<Raw>(
    uri,
    options: options,
    data: data,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  KPatchUriRequest<TDecoded> copyWith({
    Uri? uri,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Options? options,
    CancelToken? cancelToken,

    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KPatchUriRequest<TDecoded>._(
    _api,
    uri: uri ?? this.uri,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,

    onSendProgress: onSendProgress ?? this.onSendProgress,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    errorOverride: errorOverride ?? this.errorOverride,
  );
}

// =================================================
// DELETE
// =================================================

class KDeleteUriRequest<TDecoded> extends KUriRequest<TDecoded> {
  KDeleteUriRequest(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  KDeleteUriRequest._(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,

    super.cancelToken,
    super.onReceiveProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  @override
  String get method => 'DELETE';

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.deleteUri<Raw>(
    uri,
    options: options,
    data: data,
    cancelToken: cancelToken,
  );

  KDeleteUriRequest<TDecoded> copyWith({
    Uri? uri,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,
    Options? options,
    CancelToken? cancelToken,

    LogOptions? logOptions,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KDeleteUriRequest<TDecoded>._(
    _api,
    uri: uri ?? this.uri,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,
    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,

    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    errorOverride: errorOverride ?? this.errorOverride,
  );
}

// =================================================
// HEAD
// =================================================

class KHeadUriRequest<TDecoded> extends KUriRequest<TDecoded> {
  KHeadUriRequest(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  KHeadUriRequest._(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,

    super.cancelToken,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  @override
  String get method => 'HEAD';

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.headUri<Raw>(
    uri,
    options: options,
    data: data,
    cancelToken: cancelToken,
  );

  KHeadUriRequest<TDecoded> copyWith({
    Uri? uri,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,

    Options? options,
    CancelToken? cancelToken,
    LogOptions? logOptions,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KHeadUriRequest<TDecoded>._(
    _api,
    uri: uri ?? this.uri,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,

    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    errorOverride: errorOverride ?? this.errorOverride,
  );
}

// =================================================
// REQUEST (generic method via options)
// =================================================

class KRequestUri<TDecoded> extends KUriRequest<TDecoded> {
  KRequestUri(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  KRequestUri._(
    super._api, {
    required super.uri,
    super.usePrimary,
    super.headers,
    super.data,
    super.options,

    super.cancelToken,
    super.onReceiveProgress,
    this.onSendProgress,
    super.decoder,
    super.logOptions,
    super.errorOverride,
  });

  @override
  String get method => 'REQUEST';

  final void Function(int, int)? onSendProgress;

  @override
  Future<Response<Raw>> _implResponse<Raw>() => _dio.requestUri<Raw>(
    uri,
    options: options,
    data: data,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
    onReceiveProgress: onReceiveProgress,
  );

  KRequestUri<TDecoded> copyWith({
    Uri? uri,
    bool? usePrimary,
    Map<String, String>? headers,
    Object? data,

    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    LogOptions? logOptions,
    DecodedCallback<TDecoded>? decoder,
    ErrorOverrideCallback? errorOverride,
  }) => KRequestUri<TDecoded>._(
    _api,
    uri: uri ?? this.uri,
    usePrimary: usePrimary ?? this.usePrimary,
    headers: headers ?? this.headers,
    data: data ?? this.data,

    options: (options ?? this.options)?.copyWith(
      headers: headers ?? this.headers,
    ),
    cancelToken: cancelToken ?? this.cancelToken,
    onSendProgress: onSendProgress ?? this.onSendProgress,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    decoder: decoder ?? this.decoder,
    logOptions: logOptions ?? this.logOptions,
    errorOverride: errorOverride ?? this.errorOverride,
  );
}

// =================================================
// DOWNLOAD (URI variant)
// =================================================

class KDownloadUriRequest<TDecoded> extends KUriRequest<TDecoded> {
  KDownloadUriRequest(
    super._api, {
    required super.uri,
    this.savePath,
    super.usePrimary,
    super.options,
    super.cancelToken,
    super.onReceiveProgress,
    this.fileAccessMode = FileAccessMode.write,
    this.deleteOnError = true,
    this.lengthHeader = Headers.contentLengthHeader,
    super.logOptions,
    super.errorOverride,
  });

  KDownloadUriRequest._(
    super._api, {
    required super.uri,
    required this.savePath,
    super.usePrimary,
    super.options,

    super.cancelToken,
    super.onReceiveProgress,
    this.fileAccessMode = FileAccessMode.write,
    this.deleteOnError = true,
    this.lengthHeader = Headers.contentLengthHeader,
    super.logOptions,
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
      _dio.downloadUri(
            uri,
            savePath,
            options: options,
            data: data,
            fileAccessMode: fileAccessMode,
            cancelToken: cancelToken,
            lengthHeader: lengthHeader,
            onReceiveProgress: onReceiveProgress,
            deleteOnError: deleteOnError,
          )
          as Future<Response<Raw>>;

  KDownloadUriRequest<TDecoded> copyWith({
    Uri? uri,
    bool? usePrimary,
    dynamic savePath,
    Options? options,

    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
    bool? deleteOnError,
    String? lengthHeader,
    FileAccessMode? fileAccessMode,
    LogOptions? logOptions,
    ErrorOverrideCallback? errorOverride,
  }) => KDownloadUriRequest<TDecoded>._(
    _api,
    uri: uri ?? this.uri,
    savePath: savePath ?? this.savePath,
    usePrimary: usePrimary ?? this.usePrimary,
    options: options ?? this.options,

    cancelToken: cancelToken ?? this.cancelToken,
    onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
    deleteOnError: deleteOnError ?? this.deleteOnError,
    fileAccessMode: fileAccessMode ?? this.fileAccessMode,
    lengthHeader: lengthHeader ?? this.lengthHeader,
    logOptions: logOptions ?? this.logOptions,
    errorOverride: errorOverride ?? this.errorOverride,
  );
}
