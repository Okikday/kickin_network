## 0.0.35
- fix: prevent network logging failures from crashing non-JSON requests and add body descriptors

## 0.0.34
- Fixed: in debug mode, requests whose body isn't plain JSON (`FormData` / `MultipartFile` uploads, streams, dates)
  were never sent. Logging the request threw inside `_send`, so the call failed with `Response(ERR)` and no request
  log. Logging can no longer fail a request or turn a successful response into an error.
- Request / response logs now describe such bodies: form fields as-is, each file as `key: name (type, N bytes)`,
  streams as `<stream>`, dates as ISO 8601, non-string map keys stringified.
- Failed requests without a response now log the reason (`Exception`) under `LogPart.errors`.

## 0.0.33
- add warning for trailing slash in baseUrl to prevent unexpected behavior

## 0.0.32
- fixed a typo in method: (KRestApiBase.initialize) -> (breaking change)

## 0.0.31
- Added skill.md for AI

## 0.0.3
### ⚠️ Breaking Changes
- **Removed `KApiCacheMixin`** — in-memory caching is now built directly into `KRestApiBase`. Remove `KApiCacheMixin` from your `with` clause.
- **Removed `syncCacheToStorage` and `cacheBoxName` parameters** from `KRestApiBase.intialize()`. Disk persistence is no longer handled by this package — use your own storage solution if needed.
- **Removed `kickin_storage` dependency** — the package no longer depends on `kickin_storage`/Hive.
- **Removed `kApiCacheBoxName` constant.**

### Added
- `getCache`, `setCache`, `removeCache`, `hasCache`, `clearCache`, `disposeCache` are now available directly on `KRestApiBase`.

### Migration
```dart
// Before
class Api extends KRestApiBase with KApiCacheMixin { ... }
await api.intialize(syncCacheToStorage: true, cacheBoxName: 'my_cache');

// After
class Api extends KRestApiBase { ... }
await api.intialize();
```

## 0.0.2+1
- Updated docs to be clearer

## 0.0.2
- Update dependencies to support latest versions

## 0.0.1
- Official release of version 1.