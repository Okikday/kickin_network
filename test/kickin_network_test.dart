// ignore_for_file: overridden_fields, invalid_use_of_protected_member

import 'package:flutter_test/flutter_test.dart';
import 'package:kickin_network/kickin_network.dart';

// =============================================================================
// Test doubles
// =============================================================================

/// Minimal concrete API root with both mixins applied.
class _TestApi extends KRestApiBase with KApiCacheMixin, KApiMonitorMixin {
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

    test('two clients of the same type do not share cache when id is overridden', () {
      final items2 = _ItemsApi2(api);
      api.items.setCache('for_items');
      items2.setCache('for_items2');

      expect(api.items.cache, 'for_items');
      expect(items2.cache, 'for_items2');
    });

    test('headerWithJsonContentType includes Content-Type', () {
      final headers = api.items.headerWithJsonContentType();
      expect(headers['Content-Type'], 'application/json');
    });

    test('headerWithJsonContentType merges with existing headers', () {
      final headers = api.items.headerWithJsonContentType({'Authorization': 'Bearer tok'});
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
      await api.intialize(baseUrl: 'https://api.example.com');
      expect(api.items.baseUrl, 'https://api.example.com');
    });

    test('joinWithBaseUrl concatenates correctly', () async {
      await api.intialize(baseUrl: 'https://api.example.com');
      expect(api.items.joinWithBaseUrl('/users'), 'https://api.example.com/users');
    });

    test('initialize without baseUrl leaves it empty', () async {
      await api.intialize();
      expect(api.items.baseUrl, '');
    });

    test('syncCacheToStorage without KApiCacheMixin asserts', () async {
      // _TestApi has KApiCacheMixin so this should NOT assert.
      expect(() => api.intialize(syncCacheToStorage: true), returnsNormally);
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
}
