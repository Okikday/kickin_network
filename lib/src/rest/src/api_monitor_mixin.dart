part of '../rest_api_base.dart';

mixin KApiMonitorMixin on KRestApiBase {
  final Map<void Function(InternetStatus), StreamSubscription<InternetStatus>> _subscriptions = {};
  StreamSubscription<InternetStatus>? _monitorSubscription;
  bool _isMonitoring = false;

  /// Adds a persistent listener for internet status changes.
  /// The listener will fire immediately with the current connection state,
  /// and continue receiving updates until [removeListener] is called.
  void addListener(void Function(InternetStatus status) listener) {
    if (_subscriptions.containsKey(listener)) return; // already registered

    final sub = internetCheckerStream.listen(listener);
    _subscriptions[listener] = sub;

    // Pause it immediately if monitoring is globally off
    if (!_isMonitoring) sub.pause();
  }

  /// Removes and cancels a previously registered listener.
  void removeListener(void Function(InternetStatus status) listener) {
    _subscriptions.remove(listener)?.cancel();
  }

  /// Starts forwarding internet status events to all registered listeners.
  /// Safe to call multiple times — no-ops if already monitoring.
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    for (final sub in _subscriptions.values) {
      if (sub.isPaused) sub.resume();
    }

    // Internal monitor subscription for any base-class logging / callbacks
    _monitorSubscription ??= internetCheckerStream.listen((status) {
      if (_enabledMonitoring) {
        log('[ApiMonitor] Internet status: $status', name: runtimeType.toString());
      }
    });
  }

  /// Pauses all listener subscriptions without cancelling them.
  /// Listeners resume from where they left off when [startMonitoring] is called again.
  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;

    for (final sub in _subscriptions.values) {
      if (!sub.isPaused) sub.pause();
    }

    _monitorSubscription?.cancel();
    _monitorSubscription = null;
  }

  /// Cancels all subscriptions. Call this when the API instance is being
  /// disposed to avoid leaks — e.g. from a dispose() override on the subclass.
  void disposeMonitor() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _monitorSubscription?.cancel();
    _monitorSubscription = null;
    _isMonitoring = false;
  }
}
