# kickin_network `#experimental`

Kickin is a modern modular toolkit designed to turbocharge your Flutter development and eliminate boilerplate. It provides curated utilities, elegant extensions, and standardized architectures for common tasks like networking, state management, and storage.

This is the **#network** part of it.

---

## ✨ What's in the box

| Feature | Description |
|---|---|
| `KRestApiBase` | Singleton-friendly API root with shared Dio, base URL, logging |
| `KApiCacheMixin` mixin | Opt-in in-memory cache with optional Hive persistence |
| `KApiMonitorMixin` mixin | Internet connectivity monitoring with listener management |
| `KRestApi<T>` | Typed API client module with scoped cache and base URL access |
| `KRestRequest` | Composable, cloneable HTTP request with full Dio feature coverage |
| `KResponse<T>` | Structured response wrapper with typed success and error paths |
| `LogOptions` | Configurable request/response logging for debug workflows |

---

## 🌐 Network

A unified layer for all remote communication, adaptable to different protocols.

### REST APIs

A robust and extensible wrapper over [Dio](https://pub.dev/packages/dio) for HTTP requests with structured error handling, caching, logging, and decoding.

**Key classes:** `KRestApiBase`, `KRestApi`, `KRestRequest`, `KResponse`

#### Request capabilities

- Choose between a **primary Dio client** and an **external Dio client** per request.
- Use `try…` request methods to capture failures as `KResponse` instead of throwing.
- Clone and transform requests with `copyWith`, `toGetRequest`, `toPostRequest`, `toPutRequest`, `toPatchRequest`, `toDeleteRequest`, `toDownloadRequest`, and `toRequest`.
- Prefix endpoints with a shared base URL, or opt out per request with `useBaseUrl: false`.
- Log requests and responses with configurable `LogOptions`.
- Download files with custom `savePath`, `fileAccessMode`, and `deleteOnError` behaviour.

#### Caching — `KApiCacheMixin` mixin

Cache is **opt-in** via a mixin. Apply `KApiCacheMixin` to your API root to unlock per-client in-memory caching, with optional persistence through `kickin_storage`.

```dart
class MyApi extends KRestApiBase with KApiCacheMixin {
  static final shared = MyApi._();
  MyApi._();
}
```

Each `KRestApi` client gets a **scoped cache key** (`parentType_clientType`) so there are zero conflicts across clients. Override `id` if you mount multiple instances of the same client type on the same root.

Cache is flushed to Hive in a **debounced batch** (300 ms) to keep write pressure low. On cold start, the stored key index is used to hydrate the in-memory map before any request fires.

```dart
// Inside a KRestApi subclass
setCache(someValue);      // write
cache;                    // read (typed via KRestApi<T>)
clearCache();             // scoped delete — only this client's entry
```

Enable persistence in `intialize`:

```dart
await MyApi.shared.intialize(
  syncCacheToStorage: true,
  cacheBoxName: 'my_app_cache', // optional, defaults to 'kickin_api_cache'
);
```

#### Connectivity monitoring — `KApiMonitorMixin` mixin

Apply `KApiMonitorMixin` to subscribe to internet status changes anywhere in the app via your API singleton.

```dart
class MyApi extends KRestApiBase with KApiCacheMixin, KApiMonitorMixin { ... }

// Start/stop globally
MyApi.shared.startMonitoring();
MyApi.shared.stopMonitoring();

// Register a typed listener
MyApi.shared.addListener((InternetStatus status) {
  if (status == InternetStatus.disconnected) showOfflineBanner();
});

// Remove it when done
MyApi.shared.removeListener(myListener);
```

Listeners are **paused** (not cancelled) by `stopMonitoring`, so they resume cleanly without re-registration. An internal debug subscription logs status changes when `monitorActivities` is enabled.

#### Disposal

```dart
@override
void dispose() {
  MyApi.shared.disposeCache();     // cancels pending flush timer
  MyApi.shared.disposeMonitor();   // cancels all subscriptions
}
```

---

### Usage

```dart
import 'package:kickin_network/kickin_network.dart';

class MyApi extends KRestApiBase with KApiCacheMixin, KApiMonitorMixin {
  MyApi._();
  static final shared = MyApi._();

  late final users = UsersApi(this);
  
  // @override
  // Object? globalErrorOverride(dynamic data, Object? error, [StackTrace? st]) {
  // if (error == null) return null;
  //  if (error is Map && error.containsKey("error")) return error;
  //  return null;
  // }
}

class UsersApi extends KRestApi<Map<String, dynamic>> {
  UsersApi(super.parent);

  late final getUser = KGetRequest<Map<String, dynamic>>(
    this,
    path: '/user',
    decoder: (data, _) => data as Map<String, dynamic>,
  );

  Future<Map<String, dynamic>?> fetchUser() async {
    // Return cached value if available
    if (cache != null) return cache;

    final result = await getUser.copyWith(
      headers: await loadAuthHeaders(),
    ).send();

    // OR
    // final apiResult = await getUser.copyWith(
    // headers: await loadAuthHeaders(),
    // ).sendResult()
    // We can then access apiResult.value or apiResult.error
    // errors can be overriden in KRestApiBase or set in the KRestRequest
    // e.g 
    

    if (result != null) setCache(result);
    return result;
  }
  
}

Future<void> main() async {
  await MyApi.shared.intialize(
    baseUrl: 'https://api.myapp.com',
    syncCacheToStorage: true,
    logOptions: LogOptions.debugAll(),
  );

  MyApi.shared.startMonitoring();
  MyApi.shared.primaryInterceptors.add((...){
    log("some interception");
  });

  final user = await MyApi.shared.users.fetchUser();
  print(user);
}
```

### Example requests

```dart
final api = MyApi.shared;

// Safe — returns null instead of throwing
final profile = await api.users.getUser.tryGet();

// Clone with a path transform
final updated = await api.users.getUser.copyWith(
  pathTransform: (path) => '$path/profile',
).get();
```

---

## 📱 Platform setup

Required only when using connectivity monitoring (`KApiMonitorMixin`).

### Android

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
  ...
```

### macOS

Add the network entitlement to `macos/Runner/DebugProfile.entitlements` **and** `macos/Runner/Release.entitlements`:

```xml
<plist version="1.0">
  <dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
  </dict>
</plist>
```

> **Note:** The correct entitlement for outbound HTTP is `network.client`, not `network.server`.

---

## 📦 Installation

```sh
flutter pub add kickin_network
```

Or add manually to `pubspec.yaml`:

```yaml
dependencies:
  kickin_network: 0.0.1-dev.18
```

**Dependencies:** [`dio`](https://pub.dev/packages/dio) · [`internet_connection_checker_plus`](https://pub.dev/packages/internet_connection_checker_plus) · [`kickin_storage`](https://pub.dev/packages/kickin_storage)

> Other network kinds (WebSocket, GraphQL) are on the way.