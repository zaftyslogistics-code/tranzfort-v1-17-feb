import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Task 9.12: Managed Realtime Subscriptions.
/// Tracks all active Supabase Realtime channels to prevent leaks.
/// Enforces max concurrent channels (Supabase free tier limit = 10).
/// Provides lifecycle-aware pause/resume/cancel.
class SubscriptionManager with WidgetsBindingObserver {
  static final SubscriptionManager _instance = SubscriptionManager._();
  factory SubscriptionManager() => _instance;
  SubscriptionManager._();

  final Map<String, RealtimeChannel> _channels = {};
  static const int maxChannels = 10;
  bool _initialized = false;

  /// Initialize and register as app lifecycle observer.
  void init() {
    if (_initialized) return;
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
    debugPrint('SubscriptionManager: initialized');
  }

  /// Dispose and remove lifecycle observer.
  void dispose() {
    cancelAll();
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
  }

  /// Register a channel. If a channel with the same key exists, unsubscribe it first.
  /// Returns false if max channels exceeded (caller should handle).
  bool register(String key, RealtimeChannel channel) {
    // If key already exists, unsubscribe old one
    if (_channels.containsKey(key)) {
      debugPrint('SubscriptionManager: replacing channel "$key"');
      _channels[key]?.unsubscribe();
      _channels.remove(key);
    }

    if (_channels.length >= maxChannels) {
      debugPrint('SubscriptionManager: max channels ($maxChannels) reached, cannot register "$key"');
      // Evict oldest channel to make room
      final oldestKey = _channels.keys.first;
      debugPrint('SubscriptionManager: evicting oldest channel "$oldestKey"');
      _channels[oldestKey]?.unsubscribe();
      _channels.remove(oldestKey);
    }

    _channels[key] = channel;
    debugPrint('SubscriptionManager: registered "$key" (${_channels.length}/$maxChannels active)');
    return true;
  }

  /// Unsubscribe and remove a specific channel by key.
  void unregister(String key) {
    final channel = _channels.remove(key);
    if (channel != null) {
      channel.unsubscribe();
      debugPrint('SubscriptionManager: unregistered "$key" (${_channels.length}/$maxChannels active)');
    }
  }

  /// Check if a channel key is registered.
  bool has(String key) => _channels.containsKey(key);

  /// Get a registered channel by key.
  RealtimeChannel? get(String key) => _channels[key];

  /// Cancel all channels (e.g. on logout or app termination).
  void cancelAll() {
    for (final entry in _channels.entries) {
      entry.value.unsubscribe();
      debugPrint('SubscriptionManager: cancelled "${entry.key}"');
    }
    _channels.clear();
    debugPrint('SubscriptionManager: all channels cancelled');
  }

  /// Number of active channels.
  int get activeCount => _channels.length;

  /// List of active channel keys (for debugging).
  List<String> get activeKeys => _channels.keys.toList();

  // ─── App Lifecycle ───

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _pauseAll();
        break;
      case AppLifecycleState.resumed:
        _resumeAll();
        break;
      case AppLifecycleState.detached:
        cancelAll();
        break;
      default:
        break;
    }
  }

  void _pauseAll() {
    debugPrint('SubscriptionManager: pausing ${_channels.length} channels (app backgrounded)');
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
  }

  void _resumeAll() {
    debugPrint('SubscriptionManager: resuming ${_channels.length} channels (app foregrounded)');
    for (final channel in _channels.values) {
      channel.subscribe();
    }
  }
}
