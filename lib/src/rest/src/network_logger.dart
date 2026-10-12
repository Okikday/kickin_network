part of '../rest_api_base.dart';

class _DevLogOutput extends LogOutput {
  final String name;

  _DevLogOutput({this.name = 'KApi'});

  @override
  void output(OutputEvent event) => log(event.lines.join('\n'), name: name);
}

class NetworkLog {
  static final Logger _logger = Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      printEmojis: true,
      colors: true,
      lineLength: 80,
      levelColors: const {
        Level.info: AnsiColor.fg(6), // Cyan for Requests
        Level.debug: AnsiColor.fg(2), // Green for Success Responses
        Level.error: AnsiColor.fg(1), // Red for Error Responses
      },
    ),
    output: _DevLogOutput(name: 'kickin.network'),
  );

  // Expose basic methods
  static void request(String message) => _logger.i(message);
  static void success(String message) => _logger.d(message);
  static void error(String message, [dynamic error, StackTrace? st]) =>
      _logger.e(message, error: error, stackTrace: st);

  /// Pretty JSON for the logs. Values JSON can't hold (multipart forms and
  /// their files, streams, dates, any other object) are described instead,
  /// so a log line never fails because of what a request carries.
  static final JsonEncoder _encoder = JsonEncoder.withIndent('  ', _describe);

  /// [value] as pretty JSON for a log line (non-JSON values described).
  @visibleForTesting
  static String encode(Object? value) => _encoder.convert(value);

  static Object? _describe(dynamic value) => switch (value) {
    FormData() => {
      if (value.fields.isNotEmpty)
        'fields': {for (final f in value.fields) f.key: f.value},
      if (value.files.isNotEmpty)
        'files': [
          for (final f in value.files) '${f.key}: ${_describeFile(f.value)}',
        ],
    },
    MultipartFile() => _describeFile(value),
    DateTime() => value.toIso8601String(),
    ResponseBody() => value.contentLength >= 0
        ? '<stream, ${value.contentLength} bytes>'
        : '<stream>',
    Stream() => '<stream>',
    Map() => {for (final e in value.entries) '${e.key}': e.value},
    Iterable() => value.toList(),
    _ => value.toString(),
  };

  // "photo.jpg (image/jpeg, 52310 bytes)".
  static String _describeFile(MultipartFile file) {
    final type = file.contentType?.mimeType;
    final about = [?type, '${file.length} bytes'].join(', ');
    return '${file.filename ?? 'file'} ($about)';
  }

  // A logging failure must never fail the request: fall back to [title] alone.
  static void _safely(
    String title,
    void Function() log,
    void Function(String) fallback,
  ) {
    try {
      log();
    } catch (e) {
      try {
        fallback('$title\n(log details unavailable: $e)');
      } catch (_) {}
    }
  }

  /// Centralized logging for network requests.
  static void logRequest({
    required LogOptions logOptions,
    required String method,
    required String pathOrUri,
    Map<String, dynamic>? queryParams,
    dynamic data,
    Map<String, dynamic>? headers,
  }) {
    if (logOptions.parts.isEmpty) return;

    final Map<String, dynamic> output = {};

    if (logOptions.parts.contains(LogPart.queryParams) &&
        queryParams != null &&
        queryParams.isNotEmpty) {
      output['Query'] = queryParams;
    }
    if (logOptions.parts.contains(LogPart.requestBody) && data != null) {
      output['Body'] = data;
    }
    if (logOptions.parts.contains(LogPart.requestHeaders) &&
        headers != null &&
        headers.isNotEmpty) {
      output['Headers'] = headers;
    }

    final title = 'Request($method): $pathOrUri';
    _safely(title, () {
      if (output.isNotEmpty) {
        request('$title\n${_encoder.convert(output)}');
      } else {
        request(title);
      }
    }, request);
  }

  /// Centralized logging for network responses.
  static void logResponse({
    required LogOptions logOptions,
    required String method,
    required String pathOrUri,
    required dynamic result,
    Map<String, dynamic>? queryParams,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (logOptions.parts.isEmpty) return;

    final bool isOk =
        result.statusCode != null &&
        result.statusCode! >= 200 &&
        result.statusCode! < 300;

    final Map<String, dynamic> output = {};

    if (logOptions.parts.contains(LogPart.queryParams)) {
      final qp = result is Response
          ? (result.requestOptions.queryParameters.isNotEmpty
              ? result.requestOptions.queryParameters
              : queryParams)
          : queryParams;
      if (qp != null && qp.isNotEmpty) {
        output['Query'] = qp;
      }
    }

    if (logOptions.parts.contains(LogPart.responseBody) &&
        result is Response &&
        result.data != null) {
      final String rawData = result.data.toString();
      if (rawData.length > logOptions.maxLogLength) {
        output['Data'] =
            '${rawData.substring(0, logOptions.maxLogLength)}... [TRUNCATED]';
      } else {
        output['Data'] = result.data;
      }
    }

    if (logOptions.parts.contains(LogPart.responseHeaders) &&
        result is Response &&
        result.headers.map.isNotEmpty) {
      output['Headers'] = result.headers.map;
    }

    if (!isOk &&
        logOptions.parts.contains(LogPart.errors) &&
        result is KResponse &&
        result.error != null) {
      output['Error Details'] = result.error.toString();
    }

    // No status: the request failed before (or without) a response — say why.
    if (!isOk &&
        logOptions.parts.contains(LogPart.errors) &&
        error != null &&
        !output.containsKey('Error Details')) {
      output['Exception'] = error is DioException
          ? '${error.type.name}: ${error.message ?? error.error ?? ''}'.trim()
          : error.toString();
    }

    final title = 'Response(${result.statusCode ?? 'ERR'}): $pathOrUri';

    String details() =>
        (output.isNotEmpty ? '\n${_encoder.convert(output)}' : '')
            .replaceAll('\\n', '\n')
            .replaceAll('\\t', '\t')
            .replaceAll('\\r', '');

    if (isOk) {
      _safely(title, () => success('$title${details()}'), success);
    } else {
      _safely(
        title,
        () => NetworkLog.error(
          '$title${details()}',
          logOptions.logAllError ? error : null,
          logOptions.logAllError ? stackTrace : null,
        ),
        NetworkLog.error,
      );
    }
  }
}
