import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pomodoro_timer_service.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  static const _navy = Color(0xFF1A2238);
  static const _gold = Color(0xFFF2B833);
  static const _background = Color(0xFFF6F7FA);

  final _timer = PomodoroTimerService.instance;

  final _studyController = TextEditingController();
  final _shortController = TextEditingController();
  final _longController = TextEditingController();
  final _roundsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncSettingsFields();
  }

  void _syncSettingsFields() {
    _studyController.text = '${_timer.modeDurations[PomodoroMode.study]! ~/ 60}';
    _shortController.text = '${_timer.modeDurations[PomodoroMode.shortBreak]! ~/ 60}';
    _longController.text = '${_timer.modeDurations[PomodoroMode.longBreak]! ~/ 60}';
    _roundsController.text = '${_timer.totalRounds}';
  }

  @override
  void dispose() {
    _studyController.dispose();
    _shortController.dispose();
    _longController.dispose();
    _roundsController.dispose();
    super.dispose();
  }

  Future<void> _showSetupDialog() async {
    _syncSettingsFields();

    final settings = await showModalBottomSheet<(int, int, int, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E5EB),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                const Text(
                  'إعداد جلسة الدراسة',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'خصص وقت التركيز والاستراحات قبل البدء',
                  style: TextStyle(color: Color(0xFF7D8594), fontSize: 13),
                ),
                const SizedBox(height: 18),
                _settingField(
                  'وقت الدراسة (دقائق)',
                  _studyController,
                  Icons.menu_book_rounded,
                ),
                _settingField(
                  'الاستراحة القصيرة (دقائق)',
                  _shortController,
                  Icons.coffee_rounded,
                ),
                _settingField(
                  'الاستراحة الطويلة (دقائق)',
                  _longController,
                  Icons.weekend_rounded,
                ),
                _settingField(
                  'جلسات التركيز قبل الطويلة',
                  _roundsController,
                  Icons.loop_rounded,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      final values = (
                        _bounded(_studyController.text, 25, 1, 180),
                        _bounded(_shortController.text, 5, 1, 60),
                        _bounded(_longController.text, 15, 1, 90),
                        _bounded(_roundsController.text, 4, 1, 12),
                      );
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext, values);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'حفظ الإعدادات',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (settings != null && mounted) {
      await _timer.saveSettings(
        study: settings.$1,
        short: settings.$2,
        long: settings.$3,
        rounds: settings.$4,
      );
    }
  }

  int _bounded(String value, int fallback, int min, int max) =>
      (int.tryParse(value) ?? fallback).clamp(min, max);

  Widget _settingField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF70798B)),
        prefixIcon: Icon(icon, color: _navy, size: 20),
        filled: true,
        fillColor: _background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
      ),
    ),
  );

  String _formatTime(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  String _modeTitle(PomodoroMode mode) => switch (mode) {
    PomodoroMode.study => 'وقت التركيز',
    PomodoroMode.shortBreak => 'استراحة قصيرة',
    PomodoroMode.longBreak => 'استراحة طويلة',
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _timer,
    builder: (context, _) {
      if (!_timer.isReady) {
        return const Scaffold(
          backgroundColor: _background,
          body: Center(child: CircularProgressIndicator(color: _gold)),
        );
      }

      final isStudy = _timer.currentMode == PomodoroMode.study;
      final accent = isStudy ? _gold : const Color(0xFF55A979);
      final duration = _timer.modeDurations[_timer.currentMode] ?? 1;
      final progress =
          (1 - (_timer.remainingSeconds / duration)).clamp(0.0, 1.0);
      final completedRounds = isStudy
          ? _timer.currentRound - 1
          : _timer.currentRound;

      return Scaffold(
        backgroundColor: _background,
        appBar: _timer.isRunning
            ? null
            : AppBar(
                backgroundColor: Colors.white,
                foregroundColor: _navy,
                centerTitle: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: const Text(
                  'مؤقت بومودورو',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                actions: [
                  IconButton(
                    tooltip: 'إعدادات المؤقت',
                    onPressed: _showSetupDialog,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: _navy,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
              ),
        body: SafeArea(
          top: _timer.isRunning,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _timer.isRunning
                            ? 'جلسة جارية'
                            : 'خطّط لوقتك وأنجز بهدوء',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_timer.isRunning) ...[
                      IconButton(
                        tooltip: 'تصغير المؤقّت ومتابعته',
                        onPressed: () {
                          _timer.enableFloating();
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.picture_in_picture_alt_rounded,
                          color: _navy,
                        ),
                      ),
                      IconButton(
                        onPressed: _timer.pause,
                        icon: const Icon(Icons.close_rounded, color: _navy),
                        tooltip: 'إيقاف المؤقت',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 13),
                _roundProgress(completedRounds),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: _navy.withValues(alpha: .06),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          _modeTitle(_timer.currentMode),
                          style: TextStyle(
                            color: isStudy ? _navy : const Color(0xFF347650),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: 254,
                        height: 254,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 10,
                                strokeCap: StrokeCap.round,
                                backgroundColor: const Color(0xFFE9ECF2),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(_timer.remainingSeconds),
                                  style: const TextStyle(
                                    color: _navy,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    letterSpacing: -2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _timer.isSessionComplete
                                      ? 'اكتملت الجلسات المحددة'
                                      : (_timer.isRunning
                                            ? 'متبقي من ${_modeTitle(_timer.currentMode)}'
                                            : 'جاهز للبدء'),
                                  style: const TextStyle(
                                    color: Color(0xFF7D8594),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: _timer.isSessionComplete
                              ? null
                              : (_timer.isRunning
                                    ? _timer.pause
                                    : _timer.start),
                          style: FilledButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _navy.withValues(alpha: .6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          icon: Icon(
                            _timer.isRunning
                                ? Icons.pause_rounded
                                : (_timer.isSessionComplete
                                      ? Icons.check_rounded
                                      : Icons.play_arrow_rounded),
                          ),
                          label: Text(
                            _timer.isRunning
                                ? 'إيقاف مؤقت'
                                : (_timer.isSessionComplete
                                      ? 'اكتملت الجلسات'
                                      : 'ابدأ الآن'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      child: IconButton(
                        tooltip: 'إعادة الجلسة',
                        onPressed: _timer.reset,
                        icon: const Icon(Icons.restart_alt_rounded),
                        color: _navy,
                        iconSize: 25,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _roundProgress(int completedRounds) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
    decoration: BoxDecoration(
      color: _navy,
      borderRadius: BorderRadius.circular(19),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              '${_timer.currentRound} من ${_timer.totalRounds}',
              style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            const Text(
              'الدورات المكتملة',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.flag_rounded, size: 17, color: _gold),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(_timer.totalRounds, (index) {
            final complete = index < completedRounds;
            final current = index + 1 == _timer.currentRound &&
                _timer.currentMode == PomodoroMode.study;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 7,
                margin: EdgeInsets.only(left: index == 0 ? 0 : 5),
                decoration: BoxDecoration(
                  color: complete || current
                      ? _gold
                      : Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 9),
        Text(
          'الاستراحة الطويلة بعد ${_timer.totalRounds} دورات تركيز',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .72),
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}
