// ignore_for_file: overridden_fields, invalid_use_of_protected_member

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickin_network/kickin_network.dart';

// =============================================================================
// Test doubles
// =============================================================================

/// Minimal concrete API root with both mixins applied.
class _TestApi extends KRestApiBase with KInternetCheckerMixin {
  _TestApi();
  late final items = _ItemsApi(this);
}

/// A typed API client with a String cache.
class _ItemsApi extends KRestApi<String> {
  _ItemsApi(super.parent);
}

/// Second client of the same type — used to verify id scoping.
class _ItemsApi2 extends KRestApi<String> {
  _ItemsApi2(super.parent);

  @override
  late final id = '_ItemsApi2_override';
}

/// A client with a multipart upload, sent through [_RecordingAdapter].
class _UploadApi extends KRestApi<String> {
  _UploadApi(super.parent);

  late final upload = KPostRequest<bool>(
    this,
    path: '/uploads',
    decoder: (_, res) => res.statusCode == 200,
  );
}

class _UploadRoot extends KRestApiBase {
  late final uploads = _UploadApi(this);
}

/// Records what reaches the network and answers 200 `{"ok": true}`.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    return ResponseBody.fromString(
      '{"ok": true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

FormData _form() => FormData.fromMap({
  'title': 'Cover',
  'cover': MultipartFile.fromBytes(
    [1, 2, 3],
    filename: 'cover.png',
    contentType: DioMediaType('image', 'png'),
  ),
});

// =============================================================================
// Helpers
// =============================================================================

_TestApi _makeApi() => _TestApi();

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // KApiCacheMixin
  // ---------------------------------------------------------------------------

  group('KApiCacheMixin', () {
    late _TestApi api;

    setUp(() => api = _makeApi());
    tearDown(() => api.disposeCache());

    test('getCache returns null for a missing key', () {
      expect(api.getCache<String>('missing'), isNull);
    });

    test('setCache and getCache round-trip', () {
      api.setCache('hello', 'world');
      expect(api.getCache<String>('hello'), 'world');
    });

    test('removeCache deletes the entry', () {
      api.setCache('k', 'v');
      api.removeCache('k');
      expect(api.getCache<String>('k'), isNull);
    });

    test('hasCache returns true after setCache', () {
      api.setCache('x', 1);
      expect(api.hasCache('x'), isTrue);
    });

    test('hasCache returns false after removeCache', () {
      api.setCache('x', 1);
      api.removeCache('x');
      expect(api.hasCache('x'), isFalse);
    });

    test('clearCache removes all entries', () {
      api.setCache('a', 1);
      api.setCache('b', 2);
      api.clearCache();
      expect(api.hasCache('a'), isFalse);
      expect(api.hasCache('b'), isFalse);
    });

    test('disposeCache cancels the pending flush timer without throwing', () {
      api.setCache('flush_me', 'value'); // schedules timer
      expect(() => api.disposeCache(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // KRestApi cache delegation
  // ---------------------------------------------------------------------------

  group('KRestApi — scoped cache', () {
    late _TestApi api;

    setUp(() => api = _makeApi());
    tearDown(() => api.disposeCache());

    test('cache is null before any write', () {
      expect(api.items.cache, isNull);
    });

    test('setCache / cache round-trip via client', () {
      api.items.setCache('hello');
      expect(api.items.cache, 'hello');
    });

    test('clearCache via client removes the entry', () {
      api.items.setCache('hello');
      api.items.clearCache();
      expect(api.items.cache, isNull);
    });

    test('id is scoped to parent + client type', () {
      expect(api.items.id, contains('_TestApi'));
      expect(api.items.id, contains('_ItemsApi'));
    });

    test(
      'two clients of the same type do not share cache when id is overridden',
      () {
        final items2 = _ItemsApi2(api);
        api.items.setCache('for_items');
        items2.setCache('for_items2');

        expect(api.items.cache, 'for_items');
        expect(items2.cache, 'for_items2');
      },
    );

    test('headerWithJsonContentType includes Content-Type', () {
      final headers = api.items.headerWithJsonContentType();
      expect(headers['Content-Type'], 'application/json');
    });

    test('headerWithJsonContentType merges with existing headers', () {
      final headers = api.items.headerWithJsonContentType({
        'Authorization': 'Bearer tok',
      });
      expect(headers['Authorization'], 'Bearer tok');
      expect(headers['Content-Type'], 'application/json');
    });
  });

  // ---------------------------------------------------------------------------
  // KRestApiBase — baseUrl
  // ---------------------------------------------------------------------------

  group('KRestApiBase — initialize', () {
    late _TestApi api;

    setUp(() => api = _makeApi());

    test('baseUrl is empty before initialize', () {
      expect(api.items.baseUrl, '');
    });

    test('baseUrl is set after initialize', () async {
      await api.initialize(baseUrl: 'https://api.example.com');
      expect(api.items.baseUrl, 'https://api.example.com');
    });

    test('joinWithBaseUrl concatenates correctly', () async {
      await api.initialize(baseUrl: 'https://api.example.com');
      expect(
        api.items.joinWithBaseUrl('/users'),
        'https://api.example.com/users',
      );
    });

    test('initialize without baseUrl leaves it empty', () async {
      await api.initialize();
      expect(api.items.baseUrl, '');
    });
  });

  // ---------------------------------------------------------------------------
  // KApiMonitorMixin
  // ---------------------------------------------------------------------------

  group('KApiMonitorMixin', () {
    late _TestApi api;

    setUp(() => api = _makeApi());
    tearDown(() => api.disposeMonitor());

    test('startMonitoring is idempotent', () {
      expect(() {
        api.startMonitoring();
        api.startMonitoring();
      }, returnsNormally);
    });

    test('stopMonitoring is idempotent', () {
      api.startMonitoring();
      expect(() {
        api.stopMonitoring();
        api.stopMonitoring();
      }, returnsNormally);
    });

    test('addListener registers without throwing', () {
      void listener(InternetStatus _) {}
      expect(() => api.addListener(listener), returnsNormally);
    });

    test('removeListener on unregistered listener does not throw', () {
      void listener(InternetStatus _) {}
      expect(() => api.removeListener(listener), returnsNormally);
    });

    test('addListener is idempotent — same listener registered twice', () {
      int callCount = 0;
      void listener(InternetStatus _) => callCount++;
      api.addListener(listener);
      api.addListener(listener); // second call should be no-op
      // Subscriptions map should hold exactly one entry for this listener.
      // We verify indirectly: removeListener once should clean it up cleanly.
      expect(() => api.removeListener(listener), returnsNormally);
    });

    test('disposeMonitor cancels all subscriptions without throwing', () {
      void l1(InternetStatus _) {}
      void l2(InternetStatus _) {}
      api.addListener(l1);
      api.addListener(l2);
      api.startMonitoring();
      expect(() => api.disposeMonitor(), returnsNormally);
    });

    test('listeners paused when monitoring is stopped', () async {
      final received = <InternetStatus>[];
      void listener(InternetStatus s) => received.add(s);

      api.addListener(listener);
      api.startMonitoring();
      api.stopMonitoring();

      // Give the stream a moment — nothing should arrive while paused.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(received, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // NetworkLog
  // ---------------------------------------------------------------------------

  group('NetworkLog', () {
    test('describes multipart bodies instead of failing to encode them', () {
      final json = NetworkLog.encode({'Body': _form()});
      expect(json, contains('"title": "Cover"'));
      expect(json, contains('cover: cover.png (image/png, 3 bytes)'));
    });

    test('describes other non-JSON values (dates, sets, streams)', () {
      final json = NetworkLog.encode({
        'at': DateTime.utc(2026, 1, 2),
        'tags': {'a', 'b'},
        'body': Stream<int>.empty(),
        1: 'non-string key',
      });
      expect(json, contains('2026-01-02T00:00:00.000Z'));
      expect(json, contains('"a"'));
      expect(json, contains('<stream>'));
      expect(json, contains('"1": "non-string key"'));
    });

    test('logging a request or a failed response never throws', () {
      expect(
        () => NetworkLog.logRequest(
          logOptions: LogOptions.debugAll(),
          method: 'POST',
          pathOrUri: '/uploads',
          data: _form(),
          headers: {'Authorization': 'Bearer x'},
        ),
        returnsNormally,
      );
      expect(
        () => NetworkLog.logResponse(
          logOptions: LogOptions.debugAll(),
          method: 'POST',
          pathOrUri: '/uploads',
          result: Response<dynamic>(
            requestOptions: RequestOptions(path: '/uploads'),
            data: ResponseBody.fromString('', 200),
          ),
          error: StateError('offline'),
        ),
        returnsNormally,
      );
    });

    test('a multipart request is sent (and decoded) with full logging on', () async {
      final root = _UploadRoot();
      await root.initialize(
        baseUrl: 'https://example.test',
        logOptions: LogOptions.debugAll(),
      );
      final adapter = _RecordingAdapter();
      root.setPrimaryDio(Dio()..httpClientAdapter = adapter);

      final result = await root.uploads.upload
          .copyWith(data: _form())
          .catchErrorOnSendResult();

      expect(adapter.requests, hasLength(1), reason: 'the upload reached the network');
      expect(adapter.requests.single.data, isA<FormData>());
      expect(result.value, isTrue);
    });
  });
}
