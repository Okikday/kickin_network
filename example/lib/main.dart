// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:kickin_network/kickin_network.dart';

// =============================================================================
// API root
// =============================================================================

/// Single shared instance for the entire app.
/// - [KApiCache]    → in-memory cache with optional Hive persistence
/// - [_ApiMonitor]  → internet connectivity monitoring
class AppApi extends KRestApiBase with KApiCacheMixin, KApiMonitorMixin {
  AppApi._();
  static final shared = AppApi._();

  late final posts = PostsApi(this);
  late final users = UsersApi(this);
}

// =============================================================================
// Posts API client
// =============================================================================

/// Cache type: list of post maps.
class PostsApi extends KRestApi<List<Map<String, dynamic>>> {
  PostsApi(super.parent);

  late final _list = KGetRequest<List<Map<String, dynamic>>>(
    this,
    path: '/posts',
    decoder: (data, _) => (data as List).cast<Map<String, dynamic>>(),
  );

  late final _single = KGetRequest<Map<String, dynamic>>(
    this,
    path: '/posts',
    decoder: (data, _) => data as Map<String, dynamic>,
  );

  /// Returns cached posts when available, fetches otherwise.
  Future<List<Map<String, dynamic>>?> fetchAll() async {
    if (cache != null) {
      print('[PostsApi] returning ${cache!.length} posts from cache');
      return cache;
    }
    final result = await _list.catchErrorOnSend();
    if (result != null) setCache(result);
    return result;
  }

  /// Always fetches a single post by [id] — no caching at this level.
  Future<Map<String, dynamic>?> fetchById(int id) {
    return _single.copyWith(pathTransform: (path) => '$path/$id').catchErrorOnSend();
  }

  /// Invalidates the cached post list.
  void invalidate() => clearCache();
}

// =============================================================================
// Users API client
// =============================================================================

/// Cache type: single user map.
class UsersApi extends KRestApi<Map<String, dynamic>> {
  UsersApi(super.parent);

  late final _me = KGetRequest<Map<String, dynamic>>(
    this,
    path: '/users/1',
    decoder: (data, _) => data as Map<String, dynamic>,
  );

  Future<Map<String, dynamic>?> fetchMe() async {
    if (cache != null) return cache;
    final result = await _me.catchErrorOnSend();
    if (result != null) setCache(result);
    return result;
  }
}

// =============================================================================
// App bootstrap
// =============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppApi.shared.intialize(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    monitorActivities: true,
    syncCacheToStorage: true,
    logOptions: const LogOptions.normal(),
  );

  // Start internet monitoring.
  AppApi.shared.startMonitoring();
  AppApi.shared.addListener((InternetStatus status) {
    print('[Connectivity] $status');
  });

  runApp(const KickinExample());
}

// =============================================================================
// UI
// =============================================================================

class KickinExample extends StatelessWidget {
  const KickinExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kickin_network example',
      theme: ThemeData.dark(useMaterial3: true),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final _api = AppApi.shared;
  List<Map<String, dynamic>>? _posts;
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _api.posts.fetchAll();
      final user = await _api.users.fetchMe();
      setState(() {
        _posts = posts;
        _user = user;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.disposeCache();
    _api.disposeMonitor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('kickin_network example'),
        actions: [
          IconButton(
            tooltip: 'Invalidate cache & reload',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _api.posts.invalidate();
              _load();
            },
          ),
        ],
      ),
      body: switch ((_loading, _error)) {
        (true, _) => const Center(child: CircularProgressIndicator()),
        (_, String e) => Center(child: Text('Error: $e')),
        _ => _Body(posts: _posts ?? [], user: _user),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.posts, required this.user});

  final List<Map<String, dynamic>> posts;
  final Map<String, dynamic>? user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Signed in as ${user!['name']}', style: Theme.of(context).textTheme.titleMedium),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: posts.length,
            itemBuilder: (_, i) {
              final post = posts[i];
              return ListTile(
                title: Text(post['title'] as String? ?? ''),
                subtitle: Text(post['body'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                leading: CircleAvatar(child: Text('${post['id']}')),
              );
            },
          ),
        ),
      ],
    );
  }
}
