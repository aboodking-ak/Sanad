import 'package:flutter/material.dart';
import 'study_timer_service.dart';

class TimeTrackingWrapper extends StatefulWidget {
  final Widget child;

  const TimeTrackingWrapper({super.key, required this.child});

  @override
  State<TimeTrackingWrapper> createState() => _TimeTrackingWrapperState();
}

class _TimeTrackingWrapperState extends State<TimeTrackingWrapper> with WidgetsBindingObserver {
  final StudyTimerService _timerService = StudyTimerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerService.startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerService.syncTime();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      // إيقاف العد فوراً وحفظ الوقت الحالي في السيرفر
      _timerService.stopTimer();
      _timerService.syncTime();
      debugPrint("Study Timer: Paused (App in background)");
    } else if (state == AppLifecycleState.resumed) {
      // إعادة تشغيل العد بمجرد عودة المستخدم
      _timerService.startTimer();
      debugPrint("Study Timer: Resumed (App in foreground)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
