part of '../rest_api_base.dart';

extension ExtOnRestUriRequest<TDecoded> on KUriRequest<TDecoded> {
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

  Future<KResponse<Raw, TDecoded>> sendResponse<Raw>() => _send(false);
  Future<KResponse<Raw, TDecoded>> trySendResponse<Raw>() => _send(true);
  Future<TDecoded?> send() => _send(false).then((v) => v.value);
  Future<TDecoded?> trySend() => _send(true).then((v) => v.value);
  Future<ApiResult<TDecoded?>> sendResult() =>
      _send(false).then((v) => v.result);
  Future<ApiResult<TDecoded?>> trySendResult() =>
      _send(true).then((v) => v.result);

  // /// Do not convert from Other Request types to another Request type unless it's a [KRequest], otherwise you might lose some of the properties that are only available in those specific request types. For example, converting from [KPostRequest] to [KGetRequest] would lose the body of the request, which is not available in [KGetRequest].
  // KGetUriRequest<TDecoded> toGet() => KGetUriRequest<TDecoded>.from(this);
  // KPostUriRequest<TDecoded> toPost() => KPostUriRequest<TDecoded>.from(this);
  // KPutUriRequest<TDecoded> toPut() => KPutUriRequest<TDecoded>.from(this);
  // KPatchUriRequest<TDecoded> toPatch() => KPatchUriRequest<TDecoded>.from(this);
  // KDeleteUriRequest<TDecoded> toDelete() => KDeleteUriRequest<TDecoded>.from(this);
  // KDownloadUriRequest<TDecoded> toDownload({required dynamic savePath}) =>
  //     KDownloadUriRequest<TDecoded>.from(this, savePath: savePath);
  // KUriRequest<TDecoded> toUriRequest() => KRequest<TDecoded>.from(this);
}

/// Extension for logging and sending requests on KUriRequest.
extension ExtraExtOnRestUriRequest<TDecoded> on KUriRequest<TDecoded> {
  void _logRequest(LogOptions logOptions, String method) {
    NetworkLog.logRequest(
      logOptions: logOptions,
      method: method,
      pathOrUri: uri.toString(),
      queryParams: uri.queryParameters.isNotEmpty ? uri.queryParameters : null,
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
      pathOrUri: uri.toString(),
      result: result,
      queryParams: uri.queryParameters.isNotEmpty ? uri.queryParameters : null,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

