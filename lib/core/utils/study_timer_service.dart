import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudyTimerService {
  static final StudyTimerService _instance = StudyTimerService._internal();
  factory StudyTimerService() => _instance;
  StudyTimerService._internal();

  DateTime? _entryTime;
  Timer? _periodicTimer;
  Future<void>? _syncing;
  int _pendingSeconds = 0;
  bool _isTracking = false;

  void startTimer() {
    if (_isTracking) return;

    _isTracking = true;
    _entryTime = DateTime.now();
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _captureElapsedTime();
      unawaited(_flushPendingTime());
    });
    unawaited(_flushPendingTime());
  }

  void stopTimer() {
    if (!_isTracking) return;

    _isTracking = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _captureElapsedTime();
    unawaited(_flushPendingTime());
  }

  Future<void> syncTime() async {
    if (_isTracking) _captureElapsedTime();
    await _flushPendingTime();
  }

  void _captureElapsedTime() {
    final startedAt = _entryTime;
    if (startedAt == null) return;

    final now = DateTime.now();
    _entryTime = _isTracking ? now : null;
    final elapsedSeconds = now.difference(startedAt).inSeconds;
    if (elapsedSeconds > 0) _pendingSeconds += elapsedSeconds;
  }

  Future<void> _flushPendingTime() async {
    final activeSync = _syncing;
    if (activeSync != null) {
      await activeSync;
      return;
    }
    if (_pendingSeconds <= 0) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final secondsToAdd = _pendingSeconds;
    _pendingSeconds = 0;
    final sync = _sendTime(user.id, secondsToAdd);
    _syncing = sync;
    final synced = await sync;
    _syncing = null;

    // Include any time captured while the previous request was in flight.
    if (synced && _pendingSeconds > 0) await _flushPendingTime();
  }

  Future<bool> _sendTime(String userId, int secondsToAdd) async {
    try {
      await Supabase.instance.client.rpc(
        'increment_study_time',
        params: {'user_id': userId, 'seconds_to_add': secondsToAdd},
      );
      debugPrint('StudyTimerService: Synced $secondsToAdd seconds');
      return true;
    } catch (error) {
      // Keep failed time for the next foreground sync attempt.
      _pendingSeconds += secondsToAdd;
      debugPrint('StudyTimerService: Error syncing time: $error');
      return false;
    }
  }
}
