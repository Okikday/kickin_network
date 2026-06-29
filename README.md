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

A typical real-world setup involves defining a central `Api` hub extending `KRestApiBase`, feature-specific modules extending `KRestApi`, and utilizing extensions to keep your API definitions declarative and execution methods clean.

```dart
import 'package:kickin_network/kickin_network.dart';

// 1. Define your main API Hub
class Api extends KRestApiBase {
  Api._();
  static final instance = Api._();

  // Feature specific APIs
  late final users = UsersApi(this);

  Future<void> init() async {
    await super.intialize(
      baseUrl: 'https://api.myapp.com',
      logOptions: const LogOptions(
        logAllError: false,
        parts: {LogPart.queryParams, LogPart.requestHeaders, LogPart.requestBody, LogPart.responseBody, LogPart.errors},
      ),
    );

    // Add global interceptors like token refresh
    primaryInterceptors.add(
      TokenRefreshInterceptor(onSessionInvalid: () async { /* handle logout */ }),
    );
  }

  // Optional: Global error parser
  @override
  String? globalErrorOverride(Response response, Object? error, [StackTrace? st]) {
    final result = super.globalErrorOverride(response, error, st);
    if (result == null) return null;
    
    // Parse global API error response format
    if (result is String) return result;
    if (result is List) return result.take(3).map((e) => e.toString()).join(', ');
    return result.toString();
  }
}

// 2. Define global extensions for common parsing and headers
extension KApiExtension on KRestApi {
  Map<String, String> addAuthAccessTokenHeader([Map<String, String>? headers]) {
    final h = headers ?? {};
    final accessToken = "YOUR_TOKEN"; // Load your token securely
    return accessToken.isEmpty ? h : h..['Authorization'] = 'Bearer $accessToken';
  }

  // Utility to extract data from a standard { "data": ... } response
  dynamic castDataFromRaw(dynamic data) {
    if (data is Map && data.containsKey("data")) {
      return data["data"];
    }
    return data;
  }
}

// 3. Define feature APIs (e.g., Users)
class UsersApi extends KRestApi {
  UsersApi(super.parent);

  static const _usersMe = "/users/me";

  // Declare request definitions declaratively
  late final getProfileRequest = KGetRequest(
    this,
    path: _usersMe,
    decoder: (data, _) => UserModel.fromMap(castDataFromRaw(data)),
  );

  late final updateFcmTokenRequest = KPatchRequest(
    this,
    path: '$_usersMe/fcm-token',
    decoder: (_, response) => response.statusCode == 200,
  );
}

// 4. Use extensions on Feature APIs to keep request execution methods clean
extension UsersApiExt on UsersApi {
  Future<ApiResult<UserModel?>> getProfile() =>
      getProfileRequest.copyWith(headers: addAuthAccessTokenHeader()).catchErrorOnSendResult();

  Future<KResponse<dynamic, bool>> updateFcmToken(String fcmToken) =>
      updateFcmTokenRequest
          .copyWith(headers: addAuthAccessTokenHeader(), data: {"fcmToken": fcmToken})
          .catchErrorOnSendResponse();
}

// 5. Initialize and use anywhere
Future<void> main() async {
  await Api.instance.init();

  // Fetching data safely, catching errors without throwing exceptions
  final profileResult = await Api.instance.users.getProfile();
  
  if (profileResult.value != null) {
    print("User: ${profileResult.value}");
  } else {
    print("Error: ${profileResult.error}");
  }
}
```

### Example Requests & Request Cloning

You can easily clone and transform requests for different scenarios using `copyWith`.

```dart
final api = Api.instance;

// Safe — returns null instead of throwing on HTTP errors
final profile = await api.users.getProfileRequest.tryGet();

// Clone with a path transform for dynamic routes
final specificUser = await api.users.getProfileRequest.copyWith(
  pathTransform: (path) => '/users/$userId', // e.g. from /users/me -> /users/123
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
  kickin_network: 0.0.1
```

**Dependencies:** [`dio`](https://pub.dev/packages/dio) · [`internet_connection_checker_plus`](https://pub.dev/packages/internet_connection_checker_plus) · [`kickin_storage`](https://pub.dev/packages/kickin_storage)

> Other network kinds (WebSocket, GraphQL) are on the way.