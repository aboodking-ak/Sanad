import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  static const _navy = Color(0xFF1A2238);
  static const _gold = Color(0xFFF2B833);
  static const _background = Color(0xFFF4F5F8);

  List<Map<String, dynamic>> _countdowns = [];
  final Map<String, (Map<String, dynamic>, int)> _pendingDeletes = {};
  Timer? _deleteTimer;
  Timer? _undoSnackBarTimer;
  late Timer _timer;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadCountdowns();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _checkCompletions();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _deleteTimer?.cancel();
    _undoSnackBarTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCountdowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_countdowns');
      final decoded = raw == null ? <dynamic>[] : jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Invalid countdown data');

      final loaded = <Map<String, dynamic>>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        final item = Map<String, dynamic>.from(value);
        if (DateTime.tryParse(item['target']?.toString() ?? '') == null) continue;
        item['id'] ??= DateTime.now().microsecondsSinceEpoch.toString();
        item['name'] = item['name']?.toString() ?? '';
        item['notified'] = item['notified'] == true;
        loaded.add(item);
      }

      if (!mounted) return;
      setState(() {
        _countdowns = loaded;
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (error) {
      debugPrint('Could not load countdowns: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<bool> _saveCountdowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString('local_countdowns', jsonEncode(_countdowns));
      if (!saved) throw StateError('Countdown save failed');
      return true;
    } catch (error) {
      debugPrint('Could not save countdowns: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ العد التنازلي على هذا الجهاز.')),
        );
      }
      return false;
    }
  }

  Future<void> _deleteCountdown(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    final currentIndex = _countdowns.indexWhere((entry) => entry['id'].toString() == id);
    if (currentIndex < 0) return;
    final removed = Map<String, dynamic>.from(_countdowns[currentIndex]);
    setState(() => _countdowns.removeAt(currentIndex));
    if (!await _saveCountdowns()) {
      if (mounted) setState(() => _countdowns.insert(currentIndex, removed));
      return;
    }
    _pendingDeletes[id] = (removed, currentIndex);
    _deleteTimer?.cancel();
    _deleteTimer = Timer(const Duration(seconds: 5), _pendingDeletes.clear);
    _showUndoMessage();
  }

  void _showUndoMessage() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('تم حذف الموعد'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'تراجع',
          textColor: _gold,
          onPressed: _undoDeletes,
        ),
      ));
    _undoSnackBarTimer?.cancel();
    _undoSnackBarTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) messenger.hideCurrentSnackBar();
    });
  }

  Future<void> _undoDeletes() async {
    if (!mounted || _pendingDeletes.isEmpty) return;
    _deleteTimer?.cancel();
    _undoSnackBarTimer?.cancel();
    final pending = _pendingDeletes.values.toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    _pendingDeletes.clear();
    setState(() {
      for (final entry in pending) {
        _countdowns.insert(
          entry.$2.clamp(0, _countdowns.length).toInt(),
          entry.$1,
        );
      }
    });
    await _saveCountdowns();
  }

  void _checkCompletions() async {
    final now = DateTime.now();
    bool changed = false;

    for (final item in _countdowns) {
      final target = DateTime.tryParse(item['target']?.toString() ?? '');
      if (target != null && !target.isAfter(now) && item['notified'] != true) {
        item['notified'] = true;
        changed = true;
        _sendInAppNotification(item['name']);
      }
    }

    if (changed) {
      _saveCountdowns();
    }
  }

  Future<void> _sendInAppNotification(String taskName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('notifications').insert({
          'user_id': user.id,
          'title': 'انتهى العد التنازلي! ⏰',
          'body': 'لقد وصل موعد: $taskName. نتمنى لك كل التوفيق!',
        });
      } catch (e) {
        debugPrint("Error sending notification: $e");
      }
    }
  }

  void _addCountdown() {
    final nameController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    const primaryColor = _navy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          padding: EdgeInsets.fromLTRB(25, 20, 25, MediaQuery.of(context).viewInsets.bottom + 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 25),
              const Text("إضافة هدف جديد", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "مثلاً: موعد امتحان اللغة العربية",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildPickerTile(
                      label: "التاريخ",
                      value: DateFormat('yyyy/MM/dd').format(selectedDate),
                      icon: Icons.calendar_today_rounded,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setModalState(() => selectedDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildPickerTile(
                      label: "الوقت",
                      value: selectedTime.format(context),
                      icon: Icons.access_time_rounded,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) setModalState(() => selectedTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('اكتب اسماً للموعد أولاً.')),
                      );
                      return;
                    }
                    final target = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    if (!target.isAfter(DateTime.now())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('اختر وقتاً مستقبلياً للعد التنازلي.')),
                      );
                      return;
                    }
                    final id = DateTime.now().microsecondsSinceEpoch.toString();
                    setState(() {
                      _countdowns.insert(0, {
                        'id': id,
                        'name': name,
                        'target': target.toIso8601String(),
                        'notified': false,
                      });
                    });
                    if (await _saveCountdowns()) {
                      if (context.mounted) Navigator.pop(context);
                    } else if (mounted) {
                      setState(() => _countdowns.removeWhere((item) => item['id'] == id));
                    }
                  },
                  child: const Text('حفظ الموعد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerTile({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = _navy;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'العد التنازلي',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 19),
        ),
        backgroundColor: _background,
        foregroundColor: _navy,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _navy,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: Column(
        children: [
          _buildOverview(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _loadFailed
                    ? _buildLoadError()
                    : _countdowns.isEmpty
                        ? _buildEmptyState(primaryColor)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                            itemCount: _countdowns.length,
                            itemBuilder: (context, index) {
                              final item = _countdowns[index];
                              return _buildCountdownCard(item, primaryColor);
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCountdown,
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        label: const Text('إضافة موعد', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildOverview() {
    final activeCount = _countdowns.where((item) {
      final target = DateTime.tryParse(item['target']?.toString() ?? '');
      return target != null && target.isAfter(DateTime.now());
    }).length;
    final completedCount = _countdowns.length - activeCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _navy.withAlpha(30), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: _gold.withAlpha(30), shape: BoxShape.circle),
            child: const Icon(Icons.event_available_rounded, color: _gold, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مواعيدك المهمة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '$activeCount قيد الانتظار  •  $completedCount مكتمل',
                  style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 42),
            const SizedBox(height: 10),
            const Text('تعذر تحميل المواعيد المحفوظة'),
            TextButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadCountdowns();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, size: 100, color: primaryColor.withAlpha(30)),
          const SizedBox(height: 20),
          const Text("لا يوجد عداد نشط", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("سجل مواعيد امتحاناتك وأهدافك الهامة", style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatTarget(DateTime value) {
    const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final date = value.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'ص' : 'م';
    return '${weekdays[date.weekday - 1]}، ${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute $period';
  }
  Widget _buildCountdownCard(Map<String, dynamic> item, Color primaryColor) {
    final target = DateTime.tryParse(item['target']?.toString() ?? '') ?? DateTime.now();
    final diff = target.difference(DateTime.now());
    final isExpired = !target.isAfter(DateTime.now());
    final name = item['name']?.toString().trim() ?? '';

    return Dismissible(
      key: Key(item['id'].toString()),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) => _deleteCountdown(item),
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(22)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _navy.withAlpha(8)),
          boxShadow: [
            BoxShadow(color: _navy.withAlpha(12), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isExpired ? const Color(0xFFE8F5E9) : _gold.withAlpha(28),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExpired ? Icons.task_alt_rounded : Icons.event_rounded,
                      color: isExpired ? const Color(0xFF43A66A) : _navy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'موعد بدون عنوان' : name,
                          style: const TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTarget(target),
                          style: const TextStyle(color: Color(0xFF858B98), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                      child: const Text('انتهى', style: TextStyle(color: Color(0xFF348653), fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: isExpired ? const Color(0xFFF0F8F2) : const Color(0xFFF5F6F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: isExpired
                  ? const Center(
                      child: Text('حان موعدك المحدد 🌟', style: TextStyle(color: Color(0xFF348653), fontWeight: FontWeight.w700, fontSize: 14)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTimePart(diff.inDays, 'يوم'),
                        _buildTimePart(diff.inHours % 24, 'ساعة'),
                        _buildTimePart(diff.inMinutes % 60, 'دقيقة'),
                        _buildTimePart(diff.inSeconds % 60, 'ثانية'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePart(int value, String unit) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _navy),
        ),
        Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }
}
