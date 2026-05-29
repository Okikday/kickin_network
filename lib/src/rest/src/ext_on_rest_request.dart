part of '../rest_api_base.dart';

extension ExtOnRestRequest<TDecoded> on KRestRequest<TDecoded> {
  Future<KResponse<Raw, TDecoded>> _send<Raw>(bool tryRun) async {
    try {
      if (kDebugMode) _logRequest(logOptions ?? _apiBase._logOptions, method);
      final result = await _implResponse<Raw>();
      if (kDebugMode) _logResponse(logOptions ?? _apiBase._logOptions, method, result);
      return KResponse<Raw, TDecoded>.fromDioResponse(
        result,
        decoder: decoder,
        error: errorOverride?.call(result.data, null) ?? _api._parent.globalErrorOverride(result.data, null),
      );
    } catch (e, st) {
      if (!tryRun) {
        if (kDebugMode) {
          final response = KResponse<Raw, TDecoded>.fromDioResponse(
            Response(requestOptions: _requestOptionsFor(method)),
            decoder: decoder,
            error: errorOverride?.call(null, e, st) ?? _api._parent.globalErrorOverride(null, e, st),
          );
          _logResponse(logOptions ?? _apiBase._logOptions, method, response);
        }
        rethrow;
      }
      final response = KResponse<Raw, TDecoded>.fromDioResponse(
        Response(requestOptions: _requestOptionsFor(method)),
        decoder: decoder,
        error: errorOverride?.call(null, e, st) ?? _api._parent.globalErrorOverride(null, e, st),
      );
      if (kDebugMode) _logResponse(logOptions ?? _apiBase._logOptions, method, response);
      return response;
    }
  }

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

  void _logResponse<Raw>(
    LogOptions logOptions,
    String method,
    dynamic result, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
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
      NetworkLog.error('$title$prettyJson', error, stackTrace);
    }
  }

  Future<KResponse<Raw, TDecoded>> sendResponse<Raw>() => _send(false);
  Future<KResponse<Raw, TDecoded>> trySendResponse<Raw>() => _send(true);
  Future<TDecoded?> send() => _send(false).then((v) => v.value);
  Future<TDecoded?> trySend() => _send(true).then((v) => v.value);
  Future<ApiResult<TDecoded?>> sendResult() => _send(false).then((v) => v.result);
  Future<ApiResult<TDecoded?>> trySendResult() => _send(true).then((v) => v.result);

  /// Do not convert from Other Request types to another Request type unless it's a [KRequest], otherwise you might lose some of the properties that are only available in those specific request types. For example, converting from [KPostRequest] to [KGetRequest] would lose the body of the request, which is not available in [KGetRequest].
  KGetRequest<TDecoded> toGet() => KGetRequest<TDecoded>.from(this);
  KPostRequest<TDecoded> toPost() => KPostRequest<TDecoded>.from(this);
  KPutRequest<TDecoded> toPut() => KPutRequest<TDecoded>.from(this);
  KPatchRequest<TDecoded> toPatch() => KPatchRequest<TDecoded>.from(this);
  KDeleteRequest<TDecoded> toDelete() => KDeleteRequest<TDecoded>.from(this);
  KDownloadRequest<TDecoded> toDownload({required dynamic savePath}) =>
      KDownloadRequest<TDecoded>.from(this, savePath: savePath);
  KRequest<TDecoded> toRequest() => KRequest<TDecoded>.from(this);
}
