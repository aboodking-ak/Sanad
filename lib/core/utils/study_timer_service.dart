import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudyTimerService {
  static final StudyTimerService _instance = StudyTimerService._internal();
  factory StudyTimerService() => _instance;
  StudyTimerService._internal();

  DateTime? _entryTime;
  bool _isUpdating = false;
  Timer? _periodicTimer;

  void startTimer() {
    _entryTime = DateTime.now();
    debugPrint("StudyTimerService: Timer Started at $_entryTime");
    
    // بدء مزامنة تلقائية كل 60 ثانية لضمان رفع الوقت أولاً بأول
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      syncTime();
    });
  }

  void stopTimer() {
    _periodicTimer?.cancel();
    syncTime(); // مزامنة أخيرة عند التوقف
  }

  Future<void> syncTime() async {
    if (_entryTime == null || _isUpdating) return;
    
    final now = DateTime.now();
    final secondsSpent = now.difference(_entryTime!).inSeconds;
    
    if (secondsSpent <= 0) return;

    _isUpdating = true;
    _entryTime = now; // Reset entry time immediately to avoid double counting

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        debugPrint("StudyTimerService: Syncing +$secondsSpent seconds for user ${user.id}");
        
        // استخدام RPC لضمان عملية إضافة ذرية (Atomic) ومنع التضارب
        await Supabase.instance.client.rpc('increment_study_time', params: {
          'user_id': user.id,
          'seconds_to_add': secondsSpent,
        });
        
        debugPrint("StudyTimerService: Sync Successful");
      } catch (e) {
        debugPrint("StudyTimerService: Error syncing time: $e");
        // في حال الخطأ، نعيد الثواني لوقت الدخول للمحاولة لاحقاً
        _entryTime = now.subtract(Duration(seconds: secondsSpent));
      } finally {
        _isUpdating = false;
      }
    } else {
      _isUpdating = false;
    }
  }
}
