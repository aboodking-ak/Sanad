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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _timerService.syncTime();
    } else if (state == AppLifecycleState.resumed) {
      _timerService.startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
