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

      if (kDebugMode && logOptions?.logAllError == true) {
        _logResponse(logOptions ?? _apiBase._logOptions, method, kResponse);
      }
      if (!tryRun) rethrow;
      return kResponse;
    }
  }

  void _logRequest(LogOptions logOptions, String method) {
    if (logOptions.parts.isEmpty) return;

    final Map<String, dynamic> output = {};

    if (logOptions.parts.contains(LogPart.queryParams) &&
        uri.queryParameters.isNotEmpty) {
      output['Query'] = uri.queryParameters;
    }
    if (logOptions.parts.contains(LogPart.requestBody) && data != null) {
      output['Body'] = data;
    }
    if (logOptions.parts.contains(LogPart.requestHeaders) && headers != null) {
      output['Headers'] = headers;
    }

    final title = 'Request($method): ${uri.toString()}';
    if (output.isNotEmpty) {
      final prettyJson = const JsonEncoder.withIndent('  ').convert(output);

      NetworkLog.request('$title\n$prettyJson');
    } else {
      NetworkLog.request(title);
    }
  }

  void _logResponse<Raw>(
    LogOptions logOptions,
    String method,
    dynamic result, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (logOptions.parts.isEmpty) return;
    final bool isOk =
        result.statusCode != null &&
        result.statusCode! >= 200 &&
        result.statusCode! < 300;
    final Map<String, dynamic> output = {};

    if (logOptions.parts.contains(LogPart.queryParams) &&
        uri.queryParameters.isNotEmpty) {
      output['Query'] = result is Response
          ? result.requestOptions.queryParameters
          : uri.queryParameters;
    }

    if (logOptions.parts.contains(LogPart.responseBody) &&
        result is Response &&
        result.data != null) {
      String rawData = result.data.toString();

      if (rawData.length > logOptions.maxLogLength) {
        output['Data'] =
            '${rawData.substring(0, logOptions.maxLogLength)}... [TRUNCATED]';
      } else {
        output['Data'] = result.data;
      }
    }

    if (logOptions.parts.contains(LogPart.responseHeaders) &&
        result is Response) {
      output['Headers'] = result.headers.map;
    }

    if (!isOk &&
        logOptions.parts.contains(LogPart.errors) &&
        result is KResponse &&
        result.error != null) {
      output['Error Details'] = result.error.toString();
    }

    final title = 'Response(${result.statusCode ?? 'ERR'}): ${uri.toString()}';

    final prettyJson = output.isNotEmpty
        ? '\n${const JsonEncoder.withIndent('  ').convert(output)}'
        : '';

    if (isOk) {
      NetworkLog.success('$title$prettyJson');
    } else {
      NetworkLog.error('$title$prettyJson', error, stackTrace);
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
