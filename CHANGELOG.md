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