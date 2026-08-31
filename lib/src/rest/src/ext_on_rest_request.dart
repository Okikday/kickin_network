part of '../rest_api_base.dart';

/// Contains methods for executing requests and handling their responses.
extension ExtOnRestRequest<TDecoded> on KRestRequest<TDecoded> {
  Future<KResponse<Raw, TDecoded>> _send<Raw>(bool tryRun) async {
    try {
      if (kDebugMode) _logRequest(logOptions ?? _apiBase._logOptions, method);
      final result = await _implResponse<Raw>();
      if (kDebugMode) {
        _logResponse(logOptions ?? _apiBase._logOptions, method, result);
      }
      return KResponse<Raw, TDecoded>.fromDioResponse(
        result,
        decoder: decoder,
        error:
            errorOverride?.call(result, null) ??
            _api._parent.globalErrorOverride(result, null),
      );
    } catch (e, st) {
      final errResponse = e is DioException && e.response != null
          ? e.response as Response<Raw>
          : Response<Raw>(requestOptions: _requestOptionsFor(method));
      final kResponse = KResponse<Raw, TDecoded>.fromDioResponse(
        errResponse,
        decoder: decoder,
        error:
            errorOverride?.call(errResponse, e, st) ??
            _api._parent.globalErrorOverride(errResponse, e, st),
      );

      if (kDebugMode) {
        _logResponse(
          logOptions ?? _apiBase._logOptions,
          method,
          kResponse,
          e,
          st,
        );
      }
      if (!tryRun) rethrow;
      return kResponse;
    }
  }

  /// Executes the request, throwing an exception on failure.
  Future<KResponse<Raw, TDecoded>> sendResponse<Raw>() => _send(false);
  
  /// Executes the request safely, returning errors in the [KResponse] rather than throwing.
  Future<KResponse<Raw, TDecoded>> catchErrorOnSendResponse<Raw>() =>
      _send(true);
      
  /// Executes the request and directly returns the decoded payload. Throws on failure.
  Future<TDecoded?> send() => _send(false).then((v) => v.value);
  
  /// Executes the request safely and directly returns the decoded payload, yielding null on failure.
  Future<TDecoded?> catchErrorOnSend() => _send(true).then((v) => v.value);
  
  /// Executes the request and returns an [ApiResult]. Throws on failure.
  Future<ApiResult<TDecoded?>> sendResult() =>
      _send(false).then((v) => v.result);
      
  /// Executes the request safely and returns an [ApiResult], capturing any error cleanly.
  Future<ApiResult<TDecoded?>> catchErrorOnSendResult() =>
      _send(true).then((v) => v.result);

  // /// Do not convert from Other Request types to another Request type unless it's a [KRequest], otherwise you might lose some of the properties that are only available in those specific request types. For example, converting from [KPostRequest] to [KGetRequest] would lose the body of the request, which is not available in [KGetRequest].
  // KGetRequest<TDecoded> toGet() => KGetRequest<TDecoded>.from(this);
  // KPostRequest<TDecoded> toPost() => KPostRequest<TDecoded>.from(this);
  // KPutRequest<TDecoded> toPut() => KPutRequest<TDecoded>.from(this);
  // KPatchRequest<TDecoded> toPatch() => KPatchRequest<TDecoded>.from(this);
  // KDeleteRequest<TDecoded> toDelete() => KDeleteRequest<TDecoded>.from(this);
  // KDownloadRequest<TDecoded> toDownload({required dynamic savePath}) =>
  //     KDownloadRequest<TDecoded>.from(this, savePath: savePath);
  // KRequest<TDecoded> toRequest() => KRequest<TDecoded>.from(this);
}

/// Extension for logging on KRestRequest
extension ExtraExtOnRestRequest<TDecoded> on KRestRequest<TDecoded> {
  void _logRequest(LogOptions logOptions, String method) {
    NetworkLog.logRequest(
      logOptions: logOptions,
      method: method,
      pathOrUri: _transformedPath,
      queryParams: queryParams,
      data: data,
      headers: headers,
    );
  }

  void _logResponse<Raw>(
    LogOptions logOptions,
    String method,
    dynamic result, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    NetworkLog.logResponse(
      logOptions: logOptions,
      method: method,
      pathOrUri: _transformedPath,
      result: result,
      queryParams: queryParams,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

