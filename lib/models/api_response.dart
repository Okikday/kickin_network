part of '../src/rest/rest_api_base.dart';

typedef ApiResult<Formatted> = ({Formatted? value, Object? error});

class KResponse<Raw, Formatted> extends Response<Raw> {
  final Formatted Function(Raw data, Response<Raw> _)? decoder;
  final Object? error;
  KResponse._({
    required super.data,
    this.decoder,
    this.error,
    required super.headers,
    required super.statusCode,
    required super.statusMessage,
    required super.extra,
    required super.redirects,
    required super.isRedirect,
    required super.requestOptions,
  });

  factory KResponse.fromDioResponse(
    Response<Raw> response, {
    Formatted Function(Raw data, Response<Raw> _)? decoder,
    Object? error,
  }) {
    return KResponse<Raw, Formatted>._(
      decoder: decoder,
      error: error,
      requestOptions: response.requestOptions,
      data: response.data,
      headers: response.headers,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      extra: response.extra,
      redirects: response.redirects,
      isRedirect: response.isRedirect,
    );
  }

  bool get isSuccess => data != null;
  Raw? get raw => data;

  Formatted? get decoded => value;

  /// Don't call this if you didn't provide a [decoder] function, otherwise it would return null;
  Formatted? get value {
    final data = this.data;
    if (data == null) return null;
    try {
      if (decoder == null) return (data as Formatted);
      final decoded = decoder!(data, this);
      return decoded;
    } catch (e) {
      log("Decoding failed for request: ${requestOptions.uri}");
      rethrow;
    }
  }

  ApiResult<Formatted> get result => (value: value, error: error);
}
