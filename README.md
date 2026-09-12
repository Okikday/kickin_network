# kickin_network

A Flutter package for making HTTP requests cleanly and reliably. It is built on top of [Dio](https://pub.dev/packages/dio), with typed responses, optional caching, and internet connectivity monitoring baked in.

Part of the **Kickin** toolkit for Flutter.

> 🤖 **AI Agent & LLM Cookbook:** For architecture patterns, conventions, code snippets, and AI recipes, see [`skills.md`](skills.md).

---

## Installation

```sh
flutter pub add kickin_network
```

Or add it manually to your `pubspec.yaml`:

```yaml
dependencies:
  kickin_network: ^0.0.32
```

---

## How it works

The package gives you three things to work with:

1. **An API hub** (`KRestApiBase`): one class per app that holds your base URL, Dio config, and interceptors.
2. **Feature API clients** (`KRestApi`): one class per area of your app (e.g. `UsersApi`, `ChatsApi`). Each client is owned by the hub.
3. **Requests** (`KGetRequest`, `KPostRequest`, etc.): declared once on your client, then called with `.send()` or `.catchErrorOnSend()` wherever you need them.

Every response comes back as `ApiResult<T>`, which holds either a typed `value` or an `error` ending with no uncaught exceptions.

---

## Quick start

### Step 1 — Create your API hub

```dart
import 'package:kickin_network/kickin_network.dart';

class Api extends KRestApiBase {
  Api._();
  static final instance = Api._();

  // Feature clients live here
  late final users = UsersApi(this);

  Future<void> init() async {
    await super.intialize(
      baseUrl: 'https://api.yourapp.com',
    );
  }
}
```

### Step 2 — Create a feature client

```dart
class UsersApi extends KRestApi {
  UsersApi(super.parent);

  // Declare your requests once
  late final getProfile = KGetRequest(
    this,
    path: '/users/me',
    decoder: (data, _) => UserModel.fromMap(data),
  );
}
```

### Step 3 — Call it anywhere

```dart
await Api.instance.init();

final result = await Api.instance.users.getProfile.catchErrorOnSendResult();

if (result.isSuccess) {
  print(result.value); // UserModel
} else {
  print(result.error); // human-readable error string
}
```

That's the core loop. Everything else is opt-in.

---

## Sending requests

Each request type has a few ways to execute it. Pick the one that fits your use case:

| Method | Returns | Throws on error? |
|---|---|---|
| `.send()` | `TDecoded?` | Yes |
| `.catchErrorOnSend()` | `TDecoded?` | No, returns `null` |
| `.sendResponse()` | `KResponse<Raw, TDecoded>` | Yes |
| `.catchErrorOnSendResponse()` | `KResponse<Raw, TDecoded>` | No |
| `.sendResult()` | `ApiResult<TDecoded>` | Yes |
| `.catchErrorOnSendResult()` | `ApiResult<TDecoded>` | No, **recommended** |

**Recommendation:** Use `catchErrorOnSendResult()` in most cases. It never throws and gives you both value and error in one object.

---

## Request types

| Class | HTTP method | Notes |
|---|---|---|
| `KGetRequest` | GET | |
| `KPostRequest` | POST | Has `onSendProgress` |
| `KPutRequest` | PUT | Has `onSendProgress` |
| `KPatchRequest` | PATCH | Has `onSendProgress` |
| `KDeleteRequest` | DELETE | |
| `KDownloadRequest` | GET (stream to disk) | Has `savePath`, `fileAccessMode` |
| `KHeadRequest` | HEAD | |
| `KRequest` | Any | HTTP method set via `Options.method` |
| `KFetchRequest` | Any | Takes a full `RequestOptions` object |

Each class also has a `K*UriRequest` mirror (e.g. `KGetUriRequest`, `KPostUriRequest`) that accepts a `Uri` instead of a path string — useful when you have a fully-qualified URI from a redirect, deep-link, or external service. URI variants use `.trySend()` / `.trySendResult()` / `.trySendResponse()` instead of `catchErrorOn*`.

### Cloning requests for dynamic paths

Use `.copyWith()` to create a modified copy of any request; useful for dynamic routes:

```dart
// Base request defined on the client
late final getUserById = KGetRequest(this, path: '/users/me', ...);

// Clone it with a different path at call time
final result = await getUserById
    .copyWith(pathTransform: (p) => '/users/$userId')
    .catchErrorOnSendResult();
```

### Sending data (POST / PATCH / PUT)

```dart
late final updateBio = KPatchRequest(
  this,
  path: '/users/me',
  decoder: (_, res) => res.statusCode == 200,
);

// At call time, attach the body
final result = await updateBio
    .copyWith(data: {'bio': 'Hello!'}, headers: addAuthHeader())
    .catchErrorOnSendResult();
```

---

## Responses

### `ApiResult<T>`

The cleanest response type (check `isSuccess` to see if it was successful):

```dart
final result = await api.users.getProfile.catchErrorOnSendResult();

if (result.isSuccess) {
  print(result.value); // your decoded model
} else {
  print(result.error); // error message string
}
```

### `KResponse<Raw, Formatted>`

Extends Dio's `Response`, so you can access raw HTTP details too:

```dart
final response = await api.users.getProfile.catchErrorOnSendResponse();

print(response.statusCode);
print(response.raw);     // raw payload
print(response.value);   // decoded model
print(response.error);   // error if any
```

---

## Interceptors & global error handling

Add global interceptors (e.g. token refresh) on your hub:

```dart
Api.instance.primaryInterceptors.add(
  TokenRefreshInterceptor(onSessionInvalid: () async { /* logout */ }),
);
```

Override `globalErrorOverride` to customise how errors are parsed:

```dart
class Api extends KRestApiBase {
  @override
  String? globalErrorOverride(Response response, Object? error, [StackTrace? st]) {
    final result = super.globalErrorOverride(response, error, st);
    if (result is List) return result.take(3).join(', ');
    return result?.toString();
  }
}
```

The default implementation already handles common HTTP status codes (400, 401, 403, 404, 500, etc.) with readable messages.

---

## Logging

Control what gets logged during development via `LogOptions`:

```dart
await super.intialize(
  baseUrl: '...',
  logOptions: LogOptions(
    parts: {LogPart.requestBody, LogPart.responseBody, LogPart.errors},
    maxLogLength: 2000,
  ),
);
```

**Preset shortcuts:**

| Preset | What it logs |
|---|---|
| `LogOptions.debugAll()` | Everything |
| `LogOptions.debugRequest()` | Request only (query, headers, body) |
| `LogOptions.debugResponse()` | Response only (headers, body, errors) |
| `LogOptions.normal()` | Query, request headers/body, response body |
| `LogOptions.none()` | Nothing |

> Logging only runs in debug mode.

---

## Built-in Caching

Every `KRestApiBase` includes a built-in in-memory cache. No mixin required.

Use cache inside a feature client:

```dart
class UsersApi extends KRestApi<UserModel> {
  UsersApi(super.parent);

  Future<UserModel?> getCachedProfile() async {
    if (cache != null) return cache; // return cached value
    final result = await getProfile.catchErrorOnSend();
    if (result != null) setCache(result);
    return result;
  }
}
```

- Each client gets its own cache slot meaning no conflicts between clients.
- For disk persistence, read from / write to the cache in your own code using
  whatever storage solution you prefer.

**Clean up:**

```dart
Api.instance.disposeCache(); // clears the in-memory cache
```

---

## Optional: Internet monitoring — `KApiMonitorMixin`

> Requires platform setup: see [Platform setup](#platform-setup) below.

Add real-time connectivity monitoring to your hub:

```dart
class Api extends KRestApiBase with KInternetCheckerMixin {
  static final instance = Api._();
  Api._();
}
```

```dart
// Start/stop monitoring globally
Api.instance.startMonitoring();
Api.instance.stopMonitoring();

// React to connectivity changes
void _onStatusChange(InternetStatus status) {
  if (status == InternetStatus.disconnected) showOfflineBanner();
}

Api.instance.addListener(_onStatusChange);

// Remove when done (e.g. in dispose)
Api.instance.removeListener(_onStatusChange);
```

- Listeners are **paused** (not cancelled) when `stopMonitoring()` is called so they resume cleanly.
- Call `disposeMonitor()` to clean up all subscriptions when the app shuts down.

```dart
@override
void dispose() {
  Api.instance.disposeCache();
  Api.instance.disposeMonitor();
}
```

---

## Platform setup

Required **only** when using `KApiMonitorMixin`.

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### macOS

Add to both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

---

## Full example

```dart
import 'package:kickin_network/kickin_network.dart';

// ── Hub ──────────────────────────────────────────────────────────────────
class Api extends KRestApiBase {
  Api._();
  static final instance = Api._();

  late final users = UsersApi(this);

  Future<void> init() async {
    await super.intialize(
      baseUrl: 'https://api.myapp.com',
      logOptions: LogOptions.debugAll(),
    );

    primaryInterceptors.add(
      TokenRefreshInterceptor(onSessionInvalid: () async {}),
    );
  }
}

// ── Feature client ───────────────────────────────────────────────────
class UsersApi extends KRestApi<UserModel> {
  UsersApi(super.parent);

  late final getProfile = KGetRequest(
    this,
    path: '/users/me',
    decoder: (data, _) => UserModel.fromMap(data['data']),
  );

  late final updateFcmToken = KPatchRequest(
    this,
    path: '/users/me/fcm-token',
    decoder: (_, res) => res.statusCode == 200,
  );
}

// ── Extensions (keep call sites clean) ───────────────────────────────
extension UsersApiExt on UsersApi {
  Map<String, String> _authHeader() => {'Authorization': 'Bearer $yourToken'};

  Future<ApiResult<UserModel?>> fetchProfile() =>
      getProfile.copyWith(headers: _authHeader()).catchErrorOnSendResult();

  Future<ApiResult<bool?>> pushFcmToken(String token) =>
      updateFcmToken
          .copyWith(headers: _authHeader(), data: {'fcmToken': token})
          .catchErrorOnSendResult();
}

// ── Usage ─────────────────────────────────────────────────────────────
Future<void> main() async {
  await Api.instance.init();

  final result = await Api.instance.users.fetchProfile();

  if (result.isSuccess) {
    print('Hello, ${result.value!.name}');
  } else {
    print('Error: ${result.error}');
  }
}
```

---

## AI / LLM integration

`kickin_network` is a good fit for AI APIs because they are just REST endpoints. Give your AI backend its own `KRestApiBase` hub so its interceptors, base URL, and error format stay isolated from your app's backend.

```dart
class AiApi extends KRestApiBase {
  static final instance = AiApi._();
  AiApi._();

  late final chat = ChatApi(this);

  Future<void> init(String apiKey) async {
    await super.intialize(baseUrl: 'https://api.openai.com/v1');
    primaryInterceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) {
          opts.headers['Authorization'] = 'Bearer $apiKey';
          opts.headers['Content-Type'] = 'application/json';
          handler.next(opts);
        },
      ),
    );
  }
}

class ChatApi extends KRestApi<ChatCompletion> {
  ChatApi(super.parent);

  late final _complete = KPostRequest<ChatCompletion>(
    this,
    path: '/chat/completions',
    decoder: (data, _) => ChatCompletion.fromMap(data),
  );
}

extension ChatApiExt on ChatApi {
  Future<ApiResult<ChatCompletion?>> complete({
    required List<Map<String, String>> messages,
    String model = 'gpt-4o',
  }) =>
      _complete
          .copyWith(data: {'model': model, 'messages': messages})
          .catchErrorOnSendResult();
}

// Usage
final result = await AiApi.instance.chat.complete(
  messages: [
    {'role': 'system', 'content': 'You are a helpful assistant.'},
    {'role': 'user', 'content': 'Summarise Flutter in one sentence.'},
  ],
);
```

For streaming (SSE), set `options: Options(responseType: ResponseType.stream)` on your request and consume `response.data` as a `ResponseBody` stream.

See [`skills.md`](skills.md) for full recipes: embeddings, SSE streaming, embedding caching, combining AI calls with your backend, and AI-specific error parsing.

---

## API reference summary

| Class / Mixin | Purpose |
|---|---|
| `KRestApiBase` | Base class for your app's API hub (includes in-memory cache) |
| `KInternetCheckerMixin` | Adds internet connectivity monitoring to the hub |
| `KRestApi<T>` | Base class for feature API clients |
| `KRestRequest<T>` | Base class for all path-based request wrappers |
| `KGetRequest` | HTTP GET |
| `KPostRequest` | HTTP POST |
| `KPutRequest` | HTTP PUT |
| `KPatchRequest` | HTTP PATCH |
| `KDeleteRequest` | HTTP DELETE |
| `KDownloadRequest` | File download (streams to disk) |
| `KHeadRequest` | HTTP HEAD |
| `KRequest` | Any HTTP method (set via `Options.method`) |
| `KFetchRequest` | Any HTTP method (pass a raw `RequestOptions`) |
| `KUriRequest` + `K*UriRequest` | URI-based mirrors of all path-based types |
| `KResponse<Raw, Formatted>` | Full Dio response + typed decoded value |
| `ApiResult<T>` | Lightweight result type: value or error |
| `LogOptions` | Configure what gets logged and how |

---

> WebSocket and GraphQL support are planned for future releases.
>
> For patterns, conventions, and AI integration recipes see [`skills.md`](skills.md).
