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
    if (output.isNotEmpty) {
      final prettyJson = const JsonEncoder.withIndent('  ').convert(output);
      request('$title\n$prettyJson');
    } else {
      request(title);
    }
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

    final title = 'Response(${result.statusCode ?? 'ERR'}): $pathOrUri';

    final prettyJson =
        (output.isNotEmpty
                ? '\n${const JsonEncoder.withIndent('  ').convert(output)}'
                : '')
            .replaceAll('\\n', '\n')
            .replaceAll('\\t', '\t')
            .replaceAll('\\r', '');

    if (isOk) {
      success('$title$prettyJson');
    } else {
      NetworkLog.error(
        '$title$prettyJson',
        logOptions.logAllError ? error : null,
        logOptions.logAllError ? stackTrace : null,
      );
    }
  }
}
