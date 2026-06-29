part of '../rest/rest_api_base.dart';

/// Defines which parts of an HTTP request or response should be logged.
enum LogPart {
  queryParams,
  requestHeaders,
  requestBody,
  responseHeaders,
  responseBody,
  errors,
}

/// Configuration for controlling the verbosity and format of network logs.
class LogOptions {
  /// Parts of the request/response to log.
  final Set<LogPart> parts;

  /// Maximum length for the body logs before they get truncated.
  final int maxLogLength;

  /// Only Request and Responses bypass this option. All other errors from other parts of the API will be logged when this is set to true, regardless of the [parts] option.
  final bool logAllError;

  const LogOptions.none() : this(parts: const {}, maxLogLength: 0);

  const LogOptions({
    this.parts = const {LogPart.queryParams},
    this.maxLogLength = 4096,
    this.logAllError = true,
  });

  /// Logs all available parts of the request and response.
  factory LogOptions.debugAll() => LogOptions(parts: LogPart.values.toSet());

  /// Logs only request-related parts (query, headers, body).
  factory LogOptions.debugRequest() => const LogOptions(
    parts: {LogPart.queryParams, LogPart.requestHeaders, LogPart.requestBody},
  );

  /// Logs only response-related parts (headers, body, errors).
  factory LogOptions.debugResponse() => const LogOptions(
    parts: {LogPart.responseHeaders, LogPart.responseBody, LogPart.errors},
  );

  const LogOptions.normal()
    : this(
        parts: const {
          LogPart.queryParams,
          LogPart.requestHeaders,
          LogPart.requestBody,
          LogPart.responseBody,
        },
      );
}
