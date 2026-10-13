import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PomodoroMode { study, shortBreak, longBreak }

class PomodoroTimerService extends ChangeNotifier with WidgetsBindingObserver {
  PomodoroTimerService._();

  static final PomodoroTimerService instance = PomodoroTimerService._();
  static const _stateKey = 'pomodoro_timer_state_v2';

  final Map<PomodoroMode, int> modeDurations = {
    PomodoroMode.study: 25 * 60,
    PomodoroMode.shortBreak: 5 * 60,
    PomodoroMode.longBreak: 15 * 60,
  };

  Timer? _ticker;
  int remainingSeconds = 25 * 60;
  bool isRunning = false;
  bool isFloatingEnabled = false;
  bool isReady = false;
  PomodoroMode currentMode = PomodoroMode.study;
  PomodoroMode? nextMode;
  int totalRounds = 4;
  int currentRound = 1;
  int? _endTimeMs;
  bool _initialized = false;

  bool get isSessionComplete =>
      !isRunning &&
      currentMode == PomodoroMode.longBreak &&
      remainingSeconds == 0 &&
      currentRound >= totalRounds;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    modeDurations[PomodoroMode.study] =
        (prefs.getInt('pomodoro_study') ?? 25) * 60;
    modeDurations[PomodoroMode.shortBreak] =
        (prefs.getInt('pomodoro_short') ?? 5) * 60;
    modeDurations[PomodoroMode.longBreak] =
        (prefs.getInt('pomodoro_long') ?? 15) * 60;
    totalRounds = prefs.getInt('pomodoro_rounds') ?? 4;

    final values = prefs.getString(_stateKey)?.split('|');
    if (values != null && values.length == 6) {
      currentMode = PomodoroMode.values[
        (int.tryParse(values[0]) ?? 0).clamp(0, PomodoroMode.values.length - 1)
      ];
      currentRound = (int.tryParse(values[1]) ?? 1).clamp(1, totalRounds);
      remainingSeconds =
          int.tryParse(values[2]) ?? modeDurations[currentMode]!;
      final nextIndex = int.tryParse(values[3]);
      nextMode = nextIndex == null
          ? null
          : PomodoroMode.values[
              nextIndex.clamp(0, PomodoroMode.values.length - 1)];
      isRunning = values[4] == '1';
      _endTimeMs = int.tryParse(values[5]);
    }

    if (isRunning && _endTimeMs != null) {
      remainingSeconds = ((_endTimeMs! - DateTime.now().millisecondsSinceEpoch) /
              1000)
          .ceil()
          .clamp(0, modeDurations[currentMode]!);
    }
    isReady = true;
    notifyListeners();
    if (isRunning) {
      if (remainingSeconds == 0) {
        await _finishCurrentMode();
      } else {
        _startTicker();
      }
    }
    await _persist();
  }

  Future<void> saveSettings({
    required int study,
    required int short,
    required int long,
    required int rounds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomodoro_study', study);
    await prefs.setInt('pomodoro_short', short);
    await prefs.setInt('pomodoro_long', long);
    await prefs.setInt('pomodoro_rounds', rounds);
    _ticker?.cancel();
    modeDurations[PomodoroMode.study] = study * 60;
    modeDurations[PomodoroMode.shortBreak] = short * 60;
    modeDurations[PomodoroMode.longBreak] = long * 60;
    totalRounds = rounds;
    currentRound = 1;
    currentMode = PomodoroMode.study;
    nextMode = null;
    isRunning = false;
    isFloatingEnabled = false;
    _endTimeMs = null;
    remainingSeconds = study * 60;
    notifyListeners();
    await _persist();
  }

  Future<void> start() async {
    if (!isReady || isRunning || isSessionComplete) return;
    if (nextMode != null) {
      final next = nextMode!;
      if (next == PomodoroMode.study) {
        currentRound = currentMode == PomodoroMode.shortBreak
            ? (currentRound + 1).clamp(1, totalRounds)
            : 1;
      }
      currentMode = next;
      nextMode = null;
      remainingSeconds = modeDurations[next]!;
    }
    _beginCurrentMode();
    notifyListeners();
    await _persist();
  }

  void _beginCurrentMode() {
    isRunning = true;
    _endTimeMs = DateTime.now().millisecondsSinceEpoch +
        (remainingSeconds * 1000);
    _startTicker();
  }

  void enableFloating() {
    if (!isRunning || isFloatingEnabled) return;
    isFloatingEnabled = true;
    notifyListeners();
  }

  void disableFloating() {
    if (!isFloatingEnabled) return;
    isFloatingEnabled = false;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isRunning || _endTimeMs == null) return;
      final remaining = ((_endTimeMs! - DateTime.now().millisecondsSinceEpoch) /
              1000)
          .ceil();
      if (remaining <= 0) {
        _finishCurrentMode();
      } else {
        remainingSeconds = remaining;
        notifyListeners();
        _persist();
      }
    });
  }

  PomodoroMode _followingMode() {
    if (currentMode == PomodoroMode.study) {
      return currentRound >= totalRounds
          ? PomodoroMode.longBreak
          : PomodoroMode.shortBreak;
    }
    return PomodoroMode.study;
  }

  Future<void> _finishCurrentMode() async {
    if (!isRunning) return;
    _ticker?.cancel();
    final completedMode = currentMode;
    final next = _followingMode();
    final finishedCycle = completedMode == PomodoroMode.longBreak;
    remainingSeconds = 0;
    _endTimeMs = null;
    if (completedMode == PomodoroMode.shortBreak) {
      currentRound = (currentRound + 1).clamp(1, totalRounds);
    }
    if (finishedCycle) {
      isRunning = false;
      isFloatingEnabled = false;
      nextMode = null;
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    } else {
      currentMode = next;
      nextMode = null;
      remainingSeconds = modeDurations[next]!;
      _beginCurrentMode();
    }
    notifyListeners();
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
    await _persist();
  }

  Future<void> pause() async {
    if (!isRunning) return;
    if (_endTimeMs != null) {
      remainingSeconds = ((_endTimeMs! - DateTime.now().millisecondsSinceEpoch) /
              1000)
          .ceil()
          .clamp(0, modeDurations[currentMode]!);
    }
    _ticker?.cancel();
    isRunning = false;
    isFloatingEnabled = false;
    _endTimeMs = null;
    notifyListeners();
    await _persist();
  }

  Future<void> reset() async {
    _ticker?.cancel();
    isRunning = false;
    isFloatingEnabled = false;
    _endTimeMs = null;
    nextMode = null;
    currentRound = 1;
    currentMode = PomodoroMode.study;
    remainingSeconds = modeDurations[PomodoroMode.study]!;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stateKey,
      '${currentMode.index}|$currentRound|$remainingSeconds|'
      '${nextMode?.index ?? ''}|${isRunning ? 1 : 0}|${_endTimeMs ?? ''}',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isReady && isRunning) {
      final endAt = _endTimeMs;
      if (endAt != null && endAt <= DateTime.now().millisecondsSinceEpoch) {
        _finishCurrentMode();
      } else if (endAt != null) {
        remainingSeconds = ((endAt - DateTime.now().millisecondsSinceEpoch) /
                1000)
            .ceil()
            .clamp(0, modeDurations[currentMode]!);
        notifyListeners();
        _startTicker();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persist();
    }
  }
}
