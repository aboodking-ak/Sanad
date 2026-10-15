import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  static const _navy = Color(0xFF1A2238);
  static const _gold = Color(0xFFF2B833);
  static const _background = Color(0xFFF6F7FA);
  static const _todayFilter = 'اليوم';
  static const _upcomingFilter = 'القادمة';
  static const _completedFilter = 'المكتملة';

  List<Map<String, dynamic>> _todos = [];
  final Map<String, (Map<String, dynamic>, int)> _pendingDeletes = {};
  Timer? _deleteTimer;
  Timer? _undoSnackBarTimer;
  bool _isLoading = true;
  bool _loadFailed = false;
  String _selectedFilter = _todayFilter;

  static const _categories = ['دراسة', 'شخصي', 'صحة', 'أهداف'];
  static const _priorities = ['عالية', 'متوسطة', 'منخفضة'];
  static const Map<String, Color> _priorityColors = {
    'عالية': Color(0xFFD95050),
    'متوسطة': Color(0xFFE5A928),
    'منخفضة': Color(0xFF5E83B5),
  };

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  String get _todayKey => DateFormat('yyyy-MM-dd').format(_today);

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void dispose() {
    _deleteTimer?.cancel();
    _undoSnackBarTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_todos_pro');
      final decoded = raw == null ? <dynamic>[] : jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Invalid tasks data');

      final loaded = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final task = Map<String, dynamic>.from(item);
        task['id'] ??= DateTime.now().microsecondsSinceEpoch.toString();
        task['task'] = task['task']?.toString() ?? '';
        task['is_completed'] = task['is_completed'] == true;
        task['priority'] = _priorities.contains(task['priority'])
            ? task['priority']
            : 'متوسطة';
        task['category'] = _categories.contains(task['category'])
            ? task['category']
            : 'دراسة';
        // Older tasks had only a creation date, so keep them in today's list.
        task['due_date'] ??= _todayKey;
        loaded.add(task);
      }

      if (!mounted) return;
      setState(() {
        _todos = loaded;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Could not load local tasks: $error');
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  Future<bool> _saveTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        'local_todos_pro',
        jsonEncode(_todos),
      );
      if (!saved) throw StateError('Local task save failed');
      return true;
    } catch (error) {
      debugPrint('Could not save local tasks: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ التغييرات على هذا الجهاز.')),
        );
      }
      return false;
    }
  }

  DateTime _dueDate(Map<String, dynamic> task) =>
      DateTime.tryParse(task['due_date']?.toString() ?? '') ?? _today;

  bool _isCompleted(Map<String, dynamic> task) => task['is_completed'] == true;

  List<Map<String, dynamic>> get _todayTasks => _todos.where((task) {
    final due = DateUtils.dateOnly(_dueDate(task));
    return due.isAtSameMomentAs(_today) ||
        (due.isBefore(_today) && !_isCompleted(task));
  }).toList();

  List<Map<String, dynamic>> get _upcomingTasks => _todos.where((task) {
    return !_isCompleted(task) &&
        DateUtils.dateOnly(_dueDate(task)).isAfter(_today);
  }).toList()..sort((a, b) => _dueDate(a).compareTo(_dueDate(b)));

  List<Map<String, dynamic>> get _completedTasks =>
      _todos.where(_isCompleted).toList();

  List<Map<String, dynamic>> get _visibleTasks => switch (_selectedFilter) {
    'القادمة' => _upcomingTasks,
    'المكتملة' => _completedTasks,
    _ => _todayTasks,
  };

  List<Map<String, dynamic>> get _todayProgressTasks => _todos.where((task) {
    return DateUtils.dateOnly(_dueDate(task)).isAtSameMomentAs(_today);
  }).toList();

  double get _completionRate {
    final todayTasks = _todayProgressTasks;
    if (todayTasks.isEmpty) return 0;
    return todayTasks.where(_isCompleted).length / todayTasks.length;
  }

  int get _remainingToday =>
      _todayProgressTasks.where((task) => !_isCompleted(task)).length;

  Future<void> _addTask(Map<String, dynamic> values) async {
    final previousTodos = _todos
        .map((task) => Map<String, dynamic>.from(task))
        .toList();
    final previousFilter = _selectedFilter;
    setState(() {
      _todos.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        ...values,
        'is_completed': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      _selectedFilter = values['due_date'].toString().compareTo(_todayKey) <= 0
          ? _todayFilter
          : _upcomingFilter;
    });
    if (!await _saveTodos() && mounted) {
      setState(() {
        _todos = previousTodos;
        _selectedFilter = previousFilter;
      });
    }
  }

  Future<void> _updateTask(String id, Map<String, dynamic> values) async {
    final index = _todos.indexWhere((task) => task['id'].toString() == id);
    if (index < 0) return;
    final previousTodos = _todos
        .map((task) => Map<String, dynamic>.from(task))
        .toList();
    setState(() => _todos[index] = {..._todos[index], ...values});
    if (!await _saveTodos() && mounted) {
      setState(() => _todos = previousTodos);
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final id = task['id'].toString();
    final index = _todos.indexWhere((item) => item['id'].toString() == id);
    if (index < 0) return;
    final previousTodos = _todos
        .map((task) => Map<String, dynamic>.from(task))
        .toList();
    setState(
      () => _todos[index]['is_completed'] = !_isCompleted(_todos[index]),
    );
    if (!await _saveTodos() && mounted) {
      setState(() => _todos = previousTodos);
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final id = task['id'].toString();
    final index = _todos.indexWhere((item) => item['id'].toString() == id);
    if (index < 0) return;
    final removed = Map<String, dynamic>.from(_todos[index]);
    setState(() => _todos.removeAt(index));
    if (!await _saveTodos()) {
      if (mounted) setState(() => _todos.insert(index, removed));
      return;
    }
    _pendingDeletes[id] = (removed, index);
    _deleteTimer?.cancel();
    _deleteTimer = Timer(const Duration(seconds: 5), _pendingDeletes.clear);
    _showUndoMessage('تم حذف المهمة');
  }

  void _showUndoMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
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
        _todos.insert(entry.$2.clamp(0, _todos.length).toInt(), entry.$1);
      }
    });
    await _saveTodos();
  }

  Future<void> _showTaskEditor({Map<String, dynamic>? task}) async {
    final controller = TextEditingController(
      text: task?['task']?.toString() ?? '',
    );
    var priority = task?['priority']?.toString() ?? 'متوسطة';
    var category = task?['category']?.toString() ?? 'دراسة';
    var dueDate = DateUtils.dateOnly(task == null ? _today : _dueDate(task));
    final values = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9DDE5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    task == null ? 'أضف مهمة جديدة' : 'تعديل المهمة',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'خطوة صغيرة اليوم تقرّبك من هدفك.',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Color(0xFF778094), fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textDirection: widgets.TextDirection.rtl,
                    maxLength: 120,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'مثال: مراجعة درس الأحياء',
                      filled: true,
                      fillColor: _background,
                      prefixIcon: const Icon(
                        Icons.edit_note_rounded,
                        color: _navy,
                      ),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _editorLabel('موعد المهمة'),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: _navy,
                              secondary: _gold,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (selected != null) {
                        setModalState(
                          () => dueDate = DateUtils.dateOnly(selected),
                        );
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(_dateLabel(dueDate)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      side: const BorderSide(color: Color(0xFFE4E7ED)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _editorLabel('الأولوية'),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _priorities.map((value) {
                      final selected = priority == value;
                      final color = _priorityColors[value]!;
                      return ChoiceChip(
                        label: Text(value),
                        selected: selected,
                        onSelected: (_) =>
                            setModalState(() => priority = value),
                        selectedColor: color.withValues(alpha: .14),
                        backgroundColor: _background,
                        checkmarkColor: color,
                        labelStyle: TextStyle(
                          color: selected ? color : const Color(0xFF70798B),
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: selected
                              ? color.withValues(alpha: .35)
                              : Colors.transparent,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 17),
                  _editorLabel('التصنيف'),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((value) {
                      final selected = category == value;
                      return ChoiceChip(
                        label: Text(value),
                        selected: selected,
                        onSelected: (_) =>
                            setModalState(() => category = value),
                        selectedColor: _gold.withValues(alpha: .2),
                        backgroundColor: _background,
                        checkmarkColor: _navy,
                        labelStyle: TextStyle(
                          color: selected ? _navy : const Color(0xFF70798B),
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: selected
                              ? _gold.withValues(alpha: .55)
                              : Colors.transparent,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        Navigator.pop(sheetContext, {
                          'task': text,
                          'priority': priority,
                          'category': category,
                          'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: Icon(
                        task == null ? Icons.add_rounded : Icons.check_rounded,
                      ),
                      label: Text(
                        task == null ? 'إضافة المهمة' : 'حفظ التعديلات',
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (values == null || !mounted) return;
    if (task == null) {
      await _addTask(values);
    } else {
      await _updateTask(task['id'].toString(), values);
    }
  }

  Widget _editorLabel(String text) => Text(
    text,
    textAlign: TextAlign.right,
    style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
  );

  String _dateLabel(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    if (normalized.isAtSameMomentAs(_today)) return 'اليوم';
    if (normalized.isAtSameMomentAs(_today.add(const Duration(days: 1)))) {
      return 'غداً';
    }
    return DateFormat('yyyy/MM/dd').format(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        centerTitle: true,
        title: const Text(
          'قائمة المهام',
          style: TextStyle(
            color: _navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _navy,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _loadFailed
          ? _buildLoadError()
          : Column(
              children: [
                _buildProgressCard(),
                _buildFilters(),
                Expanded(
                  child: _visibleTasks.isEmpty
                      ? _buildEmptyState()
                      : _buildTaskList(),
                ),
              ],
            ),
      floatingActionButton: _loadFailed
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showTaskEditor(),
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'مهمة جديدة',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }

  Widget _buildProgressCard() {
    final todayTasks = _todayProgressTasks;
    final completed = todayTasks.where(_isCompleted).length;
    final overdue = _todos.where((task) {
      return !_isCompleted(task) &&
          DateUtils.dateOnly(_dueDate(task)).isBefore(_today);
    }).length;
    final rate = _completionRate;

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 13),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_navy, Color(0xFF293653)],
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: .08),
            blurRadius: 5,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'إنجاز اليوم',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(rate * 100).round()}%',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .16),
              valueColor: const AlwaysStoppedAnimation<Color>(_gold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            todayTasks.isEmpty
                ? 'لا توجد مهام مجدولة لليوم'
                : _remainingToday == 0
                ? 'أحسنت! أنجزت مهام اليوم 🌟'
                : 'أنجزت $completed من ${todayTasks.length} مهام اليوم',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .83),
              fontSize: 13,
            ),
          ),
          if (overdue > 0) ...[
            const SizedBox(height: 5),
            Text(
              'لديك $overdue ${overdue == 1 ? 'مهمة' : 'مهام'} متأخرة',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFFFD27A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      (_todayFilter, _todayTasks.length, Icons.today_rounded),
      (_upcomingFilter, _upcomingTasks.length, Icons.event_rounded),
      (_completedFilter, _completedTasks.length, Icons.task_alt_rounded),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECF2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: filters.map((filter) {
          final selected = _selectedFilter == filter.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _navy.withValues(alpha: .06),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      filter.$3,
                      size: 16,
                      color: selected ? _navy : const Color(0xFF7F8797),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        filter.$1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? _navy : const Color(0xFF7F8797),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${filter.$2}',
                      style: TextStyle(
                        color: selected ? _navy : const Color(0xFF9299A6),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskList() {
    final tasks = _visibleTasks;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 100),
      itemCount: tasks.length,
      itemBuilder: (context, index) => _buildTaskCard(tasks[index]),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final completed = _isCompleted(task);
    final due = DateUtils.dateOnly(_dueDate(task));
    final overdue = !completed && due.isBefore(_today);
    final priority = task['priority']?.toString() ?? 'متوسطة';
    final category = task['category']?.toString() ?? 'دراسة';
    final priorityColor =
        _priorityColors[priority] ?? _priorityColors['متوسطة']!;

    return Dismissible(
      key: ValueKey('todo-${task['id']}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFD95050),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _deleteTask(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: .045),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => _showTaskEditor(task: task),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 13, 14),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _toggleTask(task),
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: completed
                            ? const Color(0xFF49A66C)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: completed
                              ? const Color(0xFF49A66C)
                              : const Color(0xFFC9CED8),
                          width: 1.8,
                        ),
                      ),
                      child: completed
                          ? const Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['task']?.toString() ?? '',
                          textDirection: widgets.TextDirection.rtl,
                          style: TextStyle(
                            color: completed ? const Color(0xFF9299A6) : _navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _metaChip(priority, priorityColor),
                            _metaChip(
                              category,
                              const Color(0xFF778094),
                              icon: Icons.sell_outlined,
                            ),
                            _metaChip(
                              overdue ? 'متأخرة' : _dateLabel(due),
                              overdue
                                  ? const Color(0xFFD95050)
                                  : const Color(0xFF778094),
                              icon: overdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.calendar_today_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: _navy.withValues(alpha: .38),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String text, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _buildEmptyState() {
    final (icon, title, subtitle) = switch (_selectedFilter) {
      'القادمة' => (
        Icons.event_available_rounded,
        'لا توجد مهام قادمة',
        'أضف موعداً لمهمة لتظهر هنا.',
      ),
      'المكتملة' => (
        Icons.emoji_events_outlined,
        'لم تنجز مهاماً بعد',
        'ستظهر هنا كل مهمة تكملها.',
      ),
      _ => (
        Icons.checklist_rounded,
        'ابدأ بخطة اليوم',
        'أضف أول مهمة دراسية وأنجزها خطوة بخطوة.',
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _navy, size: 35),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              style: const TextStyle(
                color: _navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7D8594), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: _navy, size: 42),
          const SizedBox(height: 12),
          const Text(
            'تعذر تحميل المهام المحفوظة',
            style: TextStyle(
              color: _navy,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'لم نحذف بياناتك. أعد المحاولة قبل إجراء أي تغييرات.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF7D8594)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loadTodos,
            style: FilledButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );
}
