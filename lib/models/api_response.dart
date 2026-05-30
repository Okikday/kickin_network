// ignore_for_file: public_member_api_docs, sort_constructors_first
part of '../src/rest/rest_api_base.dart';

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

  /// Don't call this if you didn't provide a [decoder] function, otherwise it would return null.
  Formatted? get value {
    final data = this.data;
    if (data == null) return null;
    try {
      if (decoder == null) return (data as Formatted);
      return decoder!(data, this);
    } catch (e, stackTrace) {
      log(
        'Decoding failed for ${requestOptions.method} ${requestOptions.uri}\n'
        '$e',
        name: 'KResponse<$Formatted> <== ${data.runtimeType}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  ApiResult<Formatted> get result => ApiResult(value: value, error: error);
}

class ApiResult<Formatted> {
  final Formatted? value;
  final Object? error;

  const ApiResult({this.value, this.error});

  /// Could contain value, error, or both. [isSuccess] is used to check it contains a value without an error.
  bool get isSuccess => value != null && error == null;

  /// v for value
  ApiResult<T> transform<T>(T Function(Formatted v) transformer) =>
      value != null ? ApiResult<T>(value: transformer(value as Formatted), error: error) : ApiResult<T>(error: error);

  ApiResult<Formatted> copyWith({Formatted? value, Object? error}) =>
      ApiResult<Formatted>(value: value ?? this.value, error: error ?? this.error);
}
