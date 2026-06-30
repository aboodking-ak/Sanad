import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  List<Map<String, dynamic>> _countdowns = [];
  late Timer _timer;
  bool _isLoading = true;

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
    super.dispose();
  }

  Future<void> _loadCountdowns() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('local_countdowns');
    if (data != null) {
      setState(() {
        _countdowns = List<Map<String, dynamic>>.from(json.decode(data));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCountdowns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_countdowns', json.encode(_countdowns));
  }

  void _checkCompletions() async {
    final now = DateTime.now();
    bool changed = false;

    for (var item in _countdowns) {
      final target = DateTime.parse(item['target']);
      if (target.isBefore(now) && item['notified'] != true) {
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
    final primaryColor = Theme.of(context).colorScheme.primary;

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
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      final target = DateTime(
                        selectedDate.year, selectedDate.month, selectedDate.day,
                        selectedTime.hour, selectedTime.minute,
                      );
                      setState(() {
                        _countdowns.insert(0, {
                          'id': DateTime.now().millisecondsSinceEpoch,
                          'name': nameController.text.trim(),
                          'target': target.toIso8601String(),
                          'notified': false,
                        });
                      });
                      _saveCountdowns();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("بدء العد التنازلي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("العد التنازلي", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _countdowns.isEmpty
              ? _buildEmptyState(primaryColor)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _countdowns.length,
                  itemBuilder: (context, index) {
                    final item = _countdowns[index];
                    return _buildCountdownCard(item, index, primaryColor);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCountdown,
        backgroundColor: primaryColor,
        label: const Text("إضافة عداد", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
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

  Widget _buildCountdownCard(Map<String, dynamic> item, int index, Color primaryColor) {
    final target = DateTime.parse(item['target']);
    final diff = target.difference(DateTime.now());
    final bool isExpired = diff.isNegative;

    return Dismissible(
      key: Key(item['id'].toString()),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) {
        setState(() => _countdowns.removeAt(index));
        _saveCountdowns();
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(25)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25),
        child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 30),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 6, offset: Offset.zero)],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: primaryColor.withAlpha(20), shape: BoxShape.circle),
                    child: Icon(Icons.event_note_rounded, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      item['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isExpired)
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              decoration: BoxDecoration(
                color: isExpired ? Colors.green.withAlpha(10) : primaryColor.withAlpha(5),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
              ),
              child: isExpired
                  ? const Center(child: Text("تم الوصول للموعد المحدّد 🌟", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTimePart(diff.inDays, "يوم"),
                        _buildTimePart(diff.inHours % 24, "ساعة"),
                        _buildTimePart(diff.inMinutes % 60, "دقيقة"),
                        _buildTimePart(diff.inSeconds % 60, "ثانية"),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePart(int value, String unit) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }
}
