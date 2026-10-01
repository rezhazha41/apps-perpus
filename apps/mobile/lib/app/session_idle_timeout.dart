import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signs the local Supabase session out after a full day without user activity.
class SessionIdleTimeout with WidgetsBindingObserver {
  SessionIdleTimeout._();

  static const _key = 'perpus.last_user_activity_ms';
  static const timeout = Duration(hours: 24);
  static SessionIdleTimeout? _instance;

  late SharedPreferences _preferences;
  Timer? _timer;
  int? _lastActivityMs;

  static Future<void> initialize() async {
    if (_instance != null) return;
    final guard = SessionIdleTimeout._();
    guard._preferences = await SharedPreferences.getInstance();
    _instance = guard;
    WidgetsBinding.instance.addObserver(guard);
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        guard._recordActivity();
      } else if (state.event == AuthChangeEvent.signedOut) {
        guard._clearActivity();
      }
    });
    await guard._restoreAndCheck();
  }

  static void recordActivity() => _instance?._recordActivity();

  Future<void> _restoreAndCheck() async {
    _lastActivityMs = _preferences.getInt(_key);
    final session = Supabase.instance.client.auth.currentSession;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (session != null && _isExpired(now)) {
      await Supabase.instance.client.auth.signOut();
      await _clearActivity();
      return;
    }
    if (session == null) {
      await _clearActivity();
      return;
    }
    if (_lastActivityMs == null) {
      _lastActivityMs = now;
      await _preferences.setInt(_key, now);
    }
    _scheduleTimeout();
  }

  bool _isExpired(int now) {
    final last = _lastActivityMs;
    return last != null && now - last >= timeout.inMilliseconds;
  }

  void _recordActivity() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastActivityMs = now;
    unawaited(_preferences.setInt(_key, now));
    _scheduleTimeout();
  }

  Future<void> _clearActivity() async {
    _timer?.cancel();
    _lastActivityMs = null;
    await _preferences.remove(_key);
  }

  void _scheduleTimeout() {
    _timer?.cancel();
    if (Supabase.instance.client.auth.currentSession == null) return;
    final last = _lastActivityMs;
    if (last == null) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    final remaining = timeout - Duration(milliseconds: elapsed);
    if (remaining <= Duration.zero) {
      unawaited(_expireSession());
    } else {
      _timer = Timer(remaining, _expireSession);
    }
  }

  Future<void> _expireSession() async {
    if (Supabase.instance.client.auth.currentSession == null) return;
    if (!_isExpired(DateTime.now().millisecondsSinceEpoch)) {
      _scheduleTimeout();
      return;
    }
    await Supabase.instance.client.auth.signOut();
    await _clearActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreAndCheck());
    } else {
      _timer?.cancel();
    }
  }
}
