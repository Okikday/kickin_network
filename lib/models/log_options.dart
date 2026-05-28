part of '../src/rest/rest_api_base.dart';

enum LogPart { queryParams, requestHeaders, requestBody, responseHeaders, responseBody, errors }

class LogOptions {
  final Set<LogPart> parts;
  final int maxLogLength;

  const LogOptions.none() : this(parts: const {}, maxLogLength: 0);

  const LogOptions({this.parts = const {LogPart.queryParams}, this.maxLogLength = 1024});

  factory LogOptions.debugAll() => LogOptions(parts: LogPart.values.toSet());

  factory LogOptions.debugRequest() =>
      const LogOptions(parts: {LogPart.queryParams, LogPart.requestHeaders, LogPart.requestBody});

  factory LogOptions.debugResponse() =>
      const LogOptions(parts: {LogPart.responseHeaders, LogPart.responseBody, LogPart.errors});

  const LogOptions.normal()
    : this(parts: const {LogPart.queryParams, LogPart.requestHeaders, LogPart.requestBody, LogPart.responseBody});
}
