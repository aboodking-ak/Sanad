import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  final _todoController = TextEditingController();
  List<Map<String, dynamic>> _todos = [];
  bool _isLoading = true;
  String _selectedPriority = 'متوسطة';
  String _selectedCategory = 'دراسة';

  final List<String> _categories = ['دراسة', 'شخصي', 'صحة', 'أهداف'];
  final Map<String, Color> _priorityColors = {
    'عالية': Colors.redAccent,
    'متوسطة': Colors.orangeAccent,
    'منخفضة': Colors.blueAccent,
  };

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? todosString = prefs.getString('local_todos_pro');
    if (todosString != null) {
      setState(() {
        _todos = List<Map<String, dynamic>>.from(json.decode(todosString));
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_todos_pro', json.encode(_todos));
  }

  void _addTodo(String task) {
    setState(() {
      _todos.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'task': task,
        'is_completed': false,
        'priority': _selectedPriority,
        'category': _selectedCategory,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
    });
    _saveTodos();
  }

  void _toggleTodo(int index) {
    setState(() {
      _todos[index]['is_completed'] = !_todos[index]['is_completed'];
    });
    _saveTodos();
  }

  void _deleteTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
    _saveTodos();
  }

  double _getCompletionRate() {
    if (_todos.isEmpty) return 0;
    final completed = _todos.where((t) => t['is_completed'] == true).length;
    return completed / _todos.length;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text("مهامي اليومية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        systemOverlayStyle: SystemUiOverlayStyle.light, // جعل أيقونات شريط الحالة بيضاء لتناسب الخلفية الملونة
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // تعديل المسافات في الهيدر ليتناسب مع الأب بار الملون
                _buildHeaderCard(primaryColor),
                Expanded(
                  child: _todos.isEmpty ? _buildEmptyState() : _buildTodoList(primaryColor),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskSheet(primaryColor),
        backgroundColor: primaryColor,
        label: const Text("مهمة جديدة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildHeaderCard(Color primaryColor) {
    final completion = _getCompletionRate();
    final remaining = _todos.where((t) => t['is_completed'] == false).length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 5, offset: Offset.zero)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("إنجاز اليوم", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${(completion * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completion,
              backgroundColor: Colors.white.withAlpha(50),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            remaining == 0 ? "أنجزت جميع مهامك! 🌟" : "لديك $remaining مهام متبقية لليوم",
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList(Color primaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _todos.length,
      itemBuilder: (context, index) {
        final todo = _todos[index];
        return _buildTodoCard(todo, index, primaryColor);
      },
    );
  }

  Widget _buildTodoCard(Map<String, dynamic> todo, int index, Color primaryColor) {
    final bool isCompleted = todo['is_completed'] ?? false;
    final Color priorityColor = _priorityColors[todo['priority']] ?? Colors.grey;

    return Dismissible(
      key: Key(todo['id'].toString()),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) => _deleteTodo(index),
      background: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25),
        child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 30),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 4, offset: Offset.zero)],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          onTap: () => _toggleTodo(index),
          leading: GestureDetector(
            onTap: () => _toggleTodo(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isCompleted ? Colors.green : Colors.grey[300]!, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : const SizedBox(width: 16, height: 16),
              ),
            ),
          ),
          title: Text(
            todo['task'],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted ? Colors.grey : Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: priorityColor.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                  child: Text(todo['priority'], style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Icon(Icons.label_outline_rounded, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(todo['category'], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          trailing: Text(todo['date'] == DateFormat('yyyy-MM-dd').format(DateTime.now()) ? "اليوم" : todo['date'], 
            style: TextStyle(color: Colors.grey[400], fontSize: 10)),
        ),
      ),
    );
  }

  void _showAddTaskSheet(Color primaryColor) {
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
              const Text("ما هي خطتك القادمة؟", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _todoController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "اكتب مهمتك هنا...",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              const Text("الأولوية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _priorityColors.keys.map((p) => ChoiceChip(
                  label: Text(p),
                  selected: _selectedPriority == p,
                  onSelected: (val) => setModalState(() => _selectedPriority = p),
                  selectedColor: _priorityColors[p]!.withAlpha(50),
                  labelStyle: TextStyle(color: _selectedPriority == p ? _priorityColors[p] : Colors.grey, fontWeight: FontWeight.bold),
                )).toList(),
              ),
              const SizedBox(height: 20),
              const Text("التصنيف", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: _categories.map((c) => ChoiceChip(
                  label: Text(c),
                  selected: _selectedCategory == c,
                  onSelected: (val) => setModalState(() => _selectedCategory = c),
                  selectedColor: primaryColor.withAlpha(30),
                  labelStyle: TextStyle(color: _selectedCategory == c ? primaryColor : Colors.grey),
                )).toList(),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    final task = _todoController.text.trim();
                    if (task.isNotEmpty) {
                      _addTodo(task);
                      Navigator.pop(context);
                      _todoController.clear();
                    }
                  },
                  child: const Text("حفظ المهمة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/icons/logo/logo.png', height: 100, opacity: const AlwaysStoppedAnimation(0.2)),
          const SizedBox(height: 20),
          const Text("لا توجد خطط حالياً", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("ابدأ بكتابة أهدافك اليومية للنجاح", style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}
