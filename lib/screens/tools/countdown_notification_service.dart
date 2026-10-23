import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Watches locally stored countdowns independently from the countdown screen.
/// This keeps completion notifications working while the user visits other
/// pages in the foreground app.
class CountdownNotificationService with WidgetsBindingObserver {
  CountdownNotificationService._();

  static final CountdownNotificationService instance =
      CountdownNotificationService._();

  Timer? _timer;
  bool _isChecking = false;

  void initialize() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(checkCompletions());
    });
    unawaited(checkCompletions());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkCompletions());
    }
  }

  Future<void> checkCompletions() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_countdowns');
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final now = DateTime.now();
      final completedKeys = <String>{};
      for (final value in decoded) {
        if (value is! Map) continue;
        final item = Map<String, dynamic>.from(value);
        final target = DateTime.tryParse(item['target']?.toString() ?? '');
        if (target == null || target.isAfter(now) || item['notified'] == true) {
          continue;
        }
        final itemKey =
            item['id']?.toString() ?? '${item['target']}|${item['name'] ?? ''}';

        try {
          await Supabase.instance.client.from('notifications').insert({
            'user_id': user.id,
            'title': 'انتهى العد التنازلي! ⏰',
            'body': 'لقد وصل موعد: ${item['name'] ?? ''}. نتمنى لك كل التوفيق!',
          });
          completedKeys.add(itemKey);
        } catch (error) {
          // Keep it pending so the next check can retry if the network returns.
          debugPrint('Could not create countdown notification: $error');
        }
      }

      if (completedKeys.isNotEmpty) {
        // Reload before writing so an edit made in the countdown screen while
        // the database request was in flight is never overwritten.
        final latestRaw = prefs.getString('local_countdowns');
        if (latestRaw == null) return;
        final latest = jsonDecode(latestRaw);
        if (latest is! List) return;
        for (final value in latest) {
          if (value is! Map) continue;
          final itemKey =
              value['id']?.toString() ??
              '${value['target']}|${value['name'] ?? ''}';
          if (completedKeys.contains(itemKey)) value['notified'] = true;
        }
        await prefs.setString('local_countdowns', jsonEncode(latest));
      }
    } catch (error) {
      debugPrint('Could not check countdown completions: $error');
    } finally {
      _isChecking = false;
    }
  }
}
