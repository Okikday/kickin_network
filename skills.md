# kickin_network — Skills & Patterns

A practical companion to the README. These are the conventions, patterns, and recipes that come up most often when working with this package — including how to wire it up for AI-powered features.

---

## Table of contents

1. [Core mental model](#1-core-mental-model)
2. [Project layout convention](#2-project-layout-convention)
3. [Declaring requests](#3-declaring-requests)
4. [Calling requests cleanly](#4-calling-requests-cleanly)
5. [Headers — auth, content-type, and helpers](#5-headers)
6. [Decoders — mapping raw JSON to models](#6-decoders)
7. [Dynamic paths and query params](#7-dynamic-paths-and-query-params)
8. [File uploads (multipart)](#8-file-uploads-multipart)
9. [File downloads](#9-file-downloads)
10. [Per-client caching](#10-per-client-caching)
11. [Token refresh interceptor pattern](#11-token-refresh-interceptor-pattern)
12. [Custom global error parsing](#12-custom-global-error-parsing)
13. [Internet connectivity monitoring](#13-internet-connectivity-monitoring)
14. [Using a secondary Dio client](#14-using-a-secondary-dio-client)
15. [URI-based requests](#15-uri-based-requests)
16. [AI / LLM integration patterns](#16-ai--llm-integration-patterns)
17. [Testing](#17-testing)
18. [Quick reference](#18-quick-reference)

---

## 1. Core mental model

```
KRestApiBase  (one per app)
  ├── KRestApi  (one per feature domain)
  │     ├── KGetRequest / KPostRequest / …  (one per endpoint, declared once)
  │     └── extension on KRestApi           (public call-site methods)
  └── KRestApi  (another feature domain)
        └── …
```

- **`KRestApiBase`** — holds the Dio clients, base URL, interceptors, in-memory cache, and log options. Create exactly **one** static singleton per backend root.
- **`KRestApi<CacheType>`** — a scoped client for one feature area (auth, users, products…). Gets its config from the parent hub via `_parent`.
- **Requests** — immutable value objects (`KGetRequest`, `KPostRequest`, …). Declare them as `late final` fields. At call time use `.copyWith()` to attach dynamic data, then execute with `.catchErrorOnSendResult()`.

---

## 2. Project layout convention

```
lib/
  network/
    api.dart          ← the hub (Api extends KRestApiBase)
    src/
      auth/
        auth_api.dart
      products/
        products_api.dart
      orders/
        orders_api.dart
    models/
      auth/
        sign_in_request.dart
        auth_response.dart
      products/
        product_model.dart
```

The hub `api.dart` imports and re-exports all feature clients and models so callers only need one import: `import 'package:myapp/network/api.dart';`.

---

## 3. Declaring requests

Keep all request declarations **private** inside the `KRestApi` subclass. Expose them only through extension methods.

```dart
class ProductsApi extends KRestApi<List<ProductModel>> {
  ProductsApi(super.parent);

  static const _base = '/products';

  // GET /products
  late final _list = KGetRequest<List<ProductModel>>(
    this,
    path: _base,
    decoder: (data, _) => (data['data'] as List)
        .map((e) => ProductModel.fromMap(e))
        .toList(),
  );

  // GET /products/:id
  late final _getById = KGetRequest<ProductModel>(
    this,
    path: _base, // path is mutated via copyWith at call time
    decoder: (data, _) => ProductModel.fromMap(data['data']),
  );

  // POST /products
  late final _create = KPostRequest<ProductModel>(
    this,
    path: _base,
    decoder: (data, _) => ProductModel.fromMap(data['data']),
  );

  // PATCH /products/:id
  late final _update = KPatchRequest<ProductModel>(
    this,
    path: _base,
    decoder: (data, _) => ProductModel.fromMap(data['data']),
  );

  // DELETE /products/:id
  late final _delete = KDeleteRequest<bool>(
    this,
    path: _base,
    decoder: (_, res) => res.statusCode == 200,
  );
}
```

---

## 4. Calling requests cleanly

Put all call-site logic in an **extension** on the API class. This keeps the class body clean and the extension focused on the public contract.

```dart
extension ProductsApiExt on ProductsApi {
  // ── private header helper ─────────────────────────────────────────────
  Map<String, String> _auth([Map<String, String>? h]) =>
      addAuthAndJsonTypeHeaders(h);

  // ── public methods ────────────────────────────────────────────────────
  Future<ApiResult<List<ProductModel>?>> fetchProducts({
    String? category,
    int page = 1,
  }) => _list
      .copyWith(
        headers: _auth(),
        queryParams: {
          if (category != null) 'category': category,
          'page': page,
        },
      )
      .catchErrorOnSendResult();

  Future<ApiResult<ProductModel?>> fetchProduct(String id) =>
      _getById
          .copyWith(
            headers: _auth(),
            pathTransform: (base) => '$base/$id',
          )
          .catchErrorOnSendResult();

  Future<ApiResult<ProductModel?>> createProduct(CreateProductRequest body) =>
      _create
          .copyWith(headers: _auth(), data: body.toMap())
          .catchErrorOnSendResult();

  Future<ApiResult<ProductModel?>> updateProduct(
    String id,
    UpdateProductRequest body,
  ) => _update
      .copyWith(
        headers: _auth(),
        pathTransform: (base) => '$base/$id',
        data: body.toMap(),
      )
      .catchErrorOnSendResult();

  Future<ApiResult<bool?>> deleteProduct(String id) =>
      _delete
          .copyWith(
            headers: _auth(),
            pathTransform: (base) => '$base/$id',
          )
          .catchErrorOnSendResult();
}
```

Callers then read like prose:

```dart
final result = await Api.instance.products.fetchProduct(id);
if (result.isSuccess) {
  showProduct(result.value!);
} else {
  showError(result.error);
}
```

---

## 5. Headers

### Auth + JSON content-type helper

`KRestApi` inherits `headerWithJsonContentType()`. In practice, extend your feature clients with helpers that compose common combinations:

```dart
// In your hub's extension on KRestApi
extension ApiHeaderHelpers on KRestApi {
  Map<String, String> addJsonTypeHeader([Map<String, String>? h]) =>
      (h ?? {})..['Content-Type'] = 'application/json';

  Map<String, String> addAuthHeader([Map<String, String>? h]) {
    final token = TokenStore.instance.accessToken;
    final base = h ?? {};
    return token == null ? base : base..['Authorization'] = 'Bearer $token';
  }

  Map<String, String> addAuthAndJsonTypeHeaders([Map<String, String>? h]) =>
      addAuthHeader(addJsonTypeHeader(h));
}
```

---

## 6. Decoders

The `decoder` callback receives `(dynamic data, Response _)`. `data` is the raw `Response.data` — whatever Dio parsed (usually a `Map`, `List`, or `String`).

### Typical patterns

```dart
// Unwrap an envelope: { "data": { ... } }
decoder: (raw, _) => MyModel.fromMap(raw['data']),

// Status code as bool
decoder: (_, res) => res.statusCode == 200,

// List inside envelope
decoder: (raw, _) => (raw['data'] as List)
    .map((e) => MyModel.fromMap(e))
    .toList(),

// Nullable — guard before parsing
decoder: (raw, _) {
  final map = raw is Map ? raw['data'] : null;
  return map != null ? MyModel.fromMap(map) : null;
},
```

### Reusable cast helper

If your backend always wraps in `{ "data": ... }`, add a shared helper on `KRestApi`:

```dart
extension on KRestApi {
  dynamic unwrap(dynamic raw, {bool useDataKey = true}) {
    if (raw is Map && useDataKey && raw.containsKey('data')) {
      return raw['data'];
    }
    return raw;
  }
}
```

Then decoders stay one-liners: `decoder: (raw, _) => MyModel.fromMap(unwrap(raw))`.

---

## 7. Dynamic paths and query params

### Path segments

```dart
// Declaration — static base path
late final _getComment = KGetRequest(this, path: '/comments');

// Call site — append the dynamic segment at call time
Future<ApiResult<Comment?>> fetchComment(String id) =>
    _getComment
        .copyWith(pathTransform: (base) => '$base/$id')
        .catchErrorOnSendResult();
```

### Query parameters

```dart
Future<ApiResult<List<Post>?>> searchPosts({
  required String query,
  String sort = 'recent',
  int limit = 20,
  int offset = 0,
}) =>
    _search
        .copyWith(
          queryParams: {
            'q': query,
            'sort': sort,
            'limit': limit,
            'offset': offset,
          },
        )
        .catchErrorOnSendResult();
```

---

## 8. File uploads (multipart)

Use Dio's `FormData` / `MultipartFile` directly in the `data` field. These are re-exported by `kickin_network`:

```dart
// Single file
Future<ApiResult<bool?>> uploadProfilePicture(String filePath) async {
  final form = FormData.fromMap({
    'avatar': await MultipartFile.fromFile(
      filePath,
      filename: filePath.split('/').last,
    ),
  });
  return _uploadAvatar
      .copyWith(headers: addAuthHeader(), data: form)
      .catchErrorOnSendResult();
}

// Multiple files + metadata
Future<ApiResult<bool?>> uploadAlbum(
  List<String> paths,
  String albumName,
) async {
  final files = await Future.wait(
    paths.map((p) => MultipartFile.fromFile(p, filename: p.split('/').last)),
  );
  final form = FormData.fromMap({
    'album': albumName,
    'files': files,
  });
  return _createAlbum
      .copyWith(headers: addAuthHeader(), data: form)
      .catchErrorOnSendResult();
}
```

Track upload progress by passing `onSendProgress` to the original `KPostRequest`:

```dart
late final _uploadAvatar = KPostRequest<bool>(
  this,
  path: '/users/me/avatar',
  onSendProgress: (sent, total) => uploadProgress.value = sent / total,
  decoder: (_, res) => res.statusCode == 200,
);
```

---

## 9. File downloads

```dart
late final _downloadReport = KDownloadRequest<dynamic>(
  this,
  path: '/reports/export',
);

Future<ApiResult<dynamic>> downloadReport(String savePath) =>
    _downloadReport
        .copyWith(
          savePath: savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) downloadProgress.value = received / total;
          },
        )
        .catchErrorOnSendResult();
```

---

## 10. Per-client caching

Each `KRestApi<CacheType>` gets a typed cache slot scoped to the client. Access it via `cache`, `setCache(value)`, and `clearCache()`:

```dart
class CategoriesApi extends KRestApi<List<CategoryModel>> {
  CategoriesApi(super.parent);

  late final _list = KGetRequest<List<CategoryModel>>(
    this,
    path: '/categories',
    decoder: (raw, _) =>
        (raw['data'] as List).map(CategoryModel.fromMap).toList(),
  );
}

extension CategoriesApiExt on CategoriesApi {
  Future<List<CategoryModel>?> getCategories() async {
    if (cache != null) return cache; // serve from memory
    final result = await _list.catchErrorOnSend();
    if (result != null) setCache(result);
    return result;
  }

  void invalidateCategories() => clearCache();
}
```

For multi-value caches (e.g. caching per user ID), use the parent directly:

```dart
extension on UsersApi {
  UserModel? cachedUser(String id) => _parent.getCache('user_$id');
  void cacheUser(String id, UserModel m) => _parent.setCache('user_$id', m);
}
```

---

## 11. Token refresh interceptor pattern

Add a Dio interceptor on the primary client that retries requests after refreshing the access token:

```dart
class TokenRefreshInterceptor extends Interceptor {
  final Future<void> Function() onSessionInvalid;
  TokenRefreshInterceptor({required this.onSessionInvalid});

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }
    final refreshed = await CoreApi.instance.refreshTokens();
    if (refreshed == true) {
      // Retry with updated token
      final opts = err.requestOptions
        ..headers['Authorization'] = 'Bearer ${TokenStore.instance.accessToken}';
      try {
        final resp = await Api.instance.primaryClone().fetch(opts);
        return handler.resolve(resp);
      } catch (e) {
        return handler.next(err);
      }
    }
    await onSessionInvalid();
    handler.next(err);
  }
}

// Wire it up during initialisation
Api.instance.primaryInterceptors.add(
  TokenRefreshInterceptor(onSessionInvalid: () async => router.go('/login')),
);
```

---

## 12. Custom global error parsing

Override `globalErrorOverride` on your hub to post-process the default error messages:

```dart
class Api extends KRestApiBase {
  @override
  String? globalErrorOverride(
    Response response,
    Object? error, [
    StackTrace? st,
  ]) {
    final result = super.globalErrorOverride(response, error, st);

    // 5xx — always show a generic message
    if (response.statusCode != null && response.statusCode! >= 500) {
      return 'Something went wrong on our end. Please try again.';
    }

    return switch (result) {
      // If the server returned a list of validation messages, join the first few
      List l => l.take(3).map((e) => e.toString()).join(', '),
      // Capitalise the first letter of string errors
      String s when s.isNotEmpty =>
        s.replaceFirst(s[0], s[0].toUpperCase()),
      _ => result?.toString(),
    };
  }
}
```

For per-request overrides, pass `errorOverride` directly to the request constructor or via `copyWith`:

```dart
final result = await _getProfile
    .copyWith(
      errorOverride: (res, err, [st]) =>
          res.statusCode == 404 ? 'Profile not found.' : null,
    )
    .catchErrorOnSendResult();
```

---

## 13. Internet connectivity monitoring

```dart
class Api extends KRestApiBase with KInternetCheckerMixin {
  static final instance = Api._();
  Api._();
}

// Somewhere in your app shell widget
@override
void initState() {
  super.initState();
  Api.instance.startMonitoring();
  Api.instance.addListener(_onConnectivityChange);
}

@override
void dispose() {
  Api.instance.removeListener(_onConnectivityChange);
  Api.instance.stopMonitoring();
  super.dispose();
}

void _onConnectivityChange(InternetStatus status) {
  final isOnline = status == InternetStatus.connected;
  ref.read(connectivityProvider.notifier).state = isOnline;
  if (!isOnline) showOfflineBanner();
}
```

Call `disposeMonitor()` when the app terminates to avoid leaks.

---

## 14. Using a secondary Dio client

Use `usePrimary: false` on requests that should bypass the primary interceptor chain (e.g. third-party APIs where your auth headers must not be sent):

```dart
// Configure the external Dio instance separately
Api.instance.setExternalDio(
  Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    responseType: ResponseType.bytes,
  )),
);

// Then use usePrimary: false on the relevant requests
late final _cdnDownload = KGetRequest<Uint8List>(
  this,
  path: '',        // full URL supplied via pathTransform at call time
  usePrimary: false,
  useBaseUrl: false,
);
```

---

## 15. URI-based requests

When you have a full `Uri` at hand (from a response `Location` header, deep-link, or external service):

```dart
late final _oauthCallback = KPostUriRequest<AuthResponse>(
  this,
  uri: Uri.parse('https://auth.external.com/oauth/token'),
  usePrimary: false,
  decoder: (data, _) => AuthResponse.fromMap(data),
);

Future<ApiResult<AuthResponse?>> exchangeCode(String code) =>
    _oauthCallback
        .copyWith(data: {'code': code, 'grant_type': 'authorization_code'})
        .trySendResult();
```

---

## 16. AI / LLM integration patterns

### 16.1 Dedicated AI hub

Give AI API calls their own `KRestApiBase` hub. This keeps interceptors, base URLs, and error handling completely separate from your app backend.

```dart
class AiApi extends KRestApiBase {
  static final instance = AiApi._();
  AiApi._();

  late final chat = ChatApi(this);
  late final embeddings = EmbeddingsApi(this);

  Future<void> init(String apiKey) async {
    await super.intialize(
      baseUrl: 'https://api.openai.com/v1',
      logOptions: LogOptions.debugAll(),
    );
    primaryInterceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer $apiKey';
          options.headers['Content-Type'] = 'application/json';
          handler.next(options);
        },
      ),
    );
  }
}
```

---

### 16.2 Chat completions (OpenAI-compatible)

```dart
// ── Models ─────────────────────────────────────────────────────────────
class ChatMessage {
  final String role;    // 'system' | 'user' | 'assistant'
  final String content;
  const ChatMessage({required this.role, required this.content});
  Map<String, dynamic> toMap() => {'role': role, 'content': content};
}

class ChatCompletion {
  final String id;
  final String content;
  final String model;
  final int totalTokens;

  const ChatCompletion({
    required this.id,
    required this.content,
    required this.model,
    required this.totalTokens,
  });

  factory ChatCompletion.fromMap(Map<String, dynamic> m) => ChatCompletion(
        id: m['id'],
        content: m['choices'][0]['message']['content'],
        model: m['model'],
        totalTokens: m['usage']['total_tokens'],
      );
}

// ── Feature client ──────────────────────────────────────────────────────
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
    required List<ChatMessage> messages,
    String model = 'gpt-4o',
    double temperature = 0.7,
    int maxTokens = 1024,
  }) =>
      _complete
          .copyWith(data: {
            'model': model,
            'messages': messages.map((m) => m.toMap()).toList(),
            'temperature': temperature,
            'max_tokens': maxTokens,
          })
          .catchErrorOnSendResult();
}

// ── Usage ──────────────────────────────────────────────────────────────
Future<void> main() async {
  await AiApi.instance.init(apiKey);

  final result = await AiApi.instance.chat.complete(
    messages: [
      const ChatMessage(role: 'system', content: 'You are a helpful assistant.'),
      const ChatMessage(role: 'user', content: "Summarise Newton's laws."),
    ],
  );

  if (result.isSuccess) {
    print(result.value!.content);
  } else {
    print('Error: ${result.error}');
  }
}
```

---

### 16.3 Embeddings

```dart
class EmbeddingResult {
  final List<double> vector;
  final int promptTokens;
  const EmbeddingResult({required this.vector, required this.promptTokens});

  factory EmbeddingResult.fromMap(Map<String, dynamic> m) => EmbeddingResult(
        vector: List<double>.from(m['data'][0]['embedding']),
        promptTokens: m['usage']['prompt_tokens'],
      );
}

class EmbeddingsApi extends KRestApi<EmbeddingResult> {
  EmbeddingsApi(super.parent);

  late final _embed = KPostRequest<EmbeddingResult>(
    this,
    path: '/embeddings',
    decoder: (data, _) => EmbeddingResult.fromMap(data),
  );
}

extension EmbeddingsApiExt on EmbeddingsApi {
  Future<ApiResult<EmbeddingResult?>> embed(
    String text, {
    String model = 'text-embedding-3-small',
  }) =>
      _embed
          .copyWith(data: {'model': model, 'input': text})
          .catchErrorOnSendResult();
}
```

**Caching embeddings per input key** — avoid re-embedding identical strings:

```dart
extension CachedEmbeddings on EmbeddingsApi {
  Future<List<double>?> embeddingFor(String text) async {
    final key = 'embed_${text.hashCode}';
    final cached = _parent.getCache<List<double>>(key);
    if (cached != null) return cached;
    final result = await embed(text);
    final vector = result.value?.vector;
    if (vector != null) _parent.setCache(key, vector);
    return vector;
  }
}
```

---

### 16.4 Streaming responses (SSE)

Dio supports streaming via `ResponseType.stream`. Set this in `Options` and consume the `ResponseBody`:

```dart
class StreamChatApi extends KRestApi<ResponseBody> {
  StreamChatApi(super.parent);

  late final _stream = KPostRequest<ResponseBody>(
    this,
    path: '/chat/completions',
    options: Options(responseType: ResponseType.stream),
    decoder: (data, _) => data as ResponseBody,
  );
}

extension StreamChatApiExt on StreamChatApi {
  Stream<String> streamCompletion(List<ChatMessage> messages) async* {
    final response = await _stream
        .copyWith(data: {
          'model': 'gpt-4o',
          'stream': true,
          'messages': messages.map((m) => m.toMap()).toList(),
        })
        .sendResponse<ResponseBody>();

    final body = response.data;
    if (body == null) return;

    await for (final chunk in body.stream) {
      final text = String.fromCharCodes(chunk);
      for (final line in text.split('\n')) {
        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload == '[DONE]') return;
        try {
          final decoded = jsonDecode(payload) as Map;
          final delta =
              decoded['choices']?[0]?['delta']?['content'] as String?;
          if (delta != null) yield delta;
        } catch (_) {}
      }
    }
  }
}
```

---

### 16.5 AI + your backend together

A common pattern is to call the AI hub and your app backend in the same service method:

```dart
class SummaryService {
  /// Summarises raw text via AI, then persists the result to your backend.
  Future<void> summariseAndSave({
    required String noteId,
    required String rawText,
  }) async {
    // 1. Get summary from the AI hub
    final aiResult = await AiApi.instance.chat.complete(
      messages: [
        const ChatMessage(
          role: 'system',
          content: 'Summarise the following in 3 concise bullet points.',
        ),
        ChatMessage(role: 'user', content: rawText),
      ],
    );
    if (!aiResult.isSuccess) return;

    // 2. Persist to your own backend
    await Api.instance.notes.updateSummary(
      id: noteId,
      summary: aiResult.value!.content,
    );
  }
}
```

---

### 16.6 Custom error parsing for AI APIs

AI providers often return errors in a different envelope format. Override `globalErrorOverride` on the AI hub:

```dart
class AiApi extends KRestApiBase {
  @override
  Object? globalErrorOverride(
    Response response,
    Object? error, [
    StackTrace? st,
  ]) {
    // OpenAI error format: { "error": { "message": "..." } }
    final data = response.data;
    if (data is Map && data['error'] is Map) {
      return data['error']['message'] ?? 'AI request failed.';
    }
    return super.globalErrorOverride(response, error, st);
  }
}
```

---

## 17. Testing

### Injecting a mock Dio instance

```dart
setUp(() {
  final mockDio = MockDio(); // using mocktail or mockito
  Api.instance.setPrimaryDio(mockDio);
});
```

### Forcing all status codes through without throwing

```dart
late final _login = KPostRequest<AuthResponse>(
  this,
  path: '/auth/login',
  options: Options(validateStatus: (_) => true),
  decoder: (data, _) => AuthResponse.fromMap(data),
);
```

This prevents Dio from throwing on 4xx/5xx, letting `KResponse.error` carry the parsed error instead of an exception.

---

## 18. Quick reference

### Execution methods

| Method | Returns | Throws? | Use when |
|---|---|---|---|
| `.send()` | `TDecoded?` | Yes | You handle exceptions upstream |
| `.catchErrorOnSend()` | `TDecoded?` | No | You only need the value |
| `.sendResponse()` | `KResponse<Raw, TDecoded>` | Yes | You need raw HTTP metadata |
| `.catchErrorOnSendResponse()` | `KResponse<Raw, TDecoded>` | No | You need both value and raw metadata |
| `.sendResult()` | `ApiResult<TDecoded?>` | Yes | Clean result type, handled upstream |
| `.catchErrorOnSendResult()` | `ApiResult<TDecoded?>` | **No** | **Default — use this everywhere** |

### URI request execution methods

`KUriRequest` variants use `trySend` / `trySendResult` / `trySendResponse` instead of `catchErrorOn*`:

| Method | Returns | Throws? |
|---|---|---|
| `.send()` | `TDecoded?` | Yes |
| `.trySend()` | `TDecoded?` | No |
| `.sendResult()` | `ApiResult<TDecoded?>` | Yes |
| `.trySendResult()` | `ApiResult<TDecoded?>` | No |
| `.sendResponse()` | `KResponse<Raw, TDecoded>` | Yes |
| `.trySendResponse()` | `KResponse<Raw, TDecoded>` | No |

### Request classes

| Class | HTTP verb | Notes |
|---|---|---|
| `KGetRequest` | GET | |
| `KPostRequest` | POST | Has `onSendProgress` |
| `KPutRequest` | PUT | Has `onSendProgress` |
| `KPatchRequest` | PATCH | Has `onSendProgress` |
| `KDeleteRequest` | DELETE | |
| `KDownloadRequest` | GET (stream to disk) | Has `savePath`, `fileAccessMode` |
| `KHeadRequest` | HEAD | |
| `KRequest` | Any (via `Options.method`) | Generic method |
| `KFetchRequest` | Any | Pass a full `RequestOptions` |
| `K*UriRequest` variants | Same verbs | Take `Uri` instead of path string |

### `ApiResult<T>` at a glance

```dart
result.isSuccess                       // true when value != null && error == null
result.value                           // T? — the decoded model
result.error                           // Object? — the human-readable error
result.transform((v) => v.id)          // map value → ApiResult<S>
result.copyWith(value: ..., error: ...) // produce a modified copy
```
