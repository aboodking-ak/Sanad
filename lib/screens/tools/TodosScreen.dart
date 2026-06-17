import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  final supabase = Supabase.instance.client;
  final _todoController = TextEditingController();

  // جلب البيانات من سوبابيس
  final _future = Supabase.instance.client
      .from('todos')
      .select()
      .order('id', ascending: false);

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "قائمة المهام",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final todos = snapshot.data as List<dynamic>;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  "${todos.length} مهمة",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              Expanded(
                child: todos.isEmpty
                    ? const Center(
                        child: Text("لا توجد مهام حالياً", style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        itemCount: todos.length,
                        itemBuilder: (context, index) {
                          final todo = todos[index];
                          return _buildTodoItem(todo);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoDialog(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildTodoItem(dynamic todo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              todo['name'] ?? 'بدون اسم',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مهمة جديدة'),
        content: TextField(
          controller: _todoController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم المهمة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _todoController.text.trim();
              if (name.isNotEmpty) {
                await supabase.from('todos').insert({'name': name});
                setState(() {
                  // تحديث الواجهة (يفضل استخدام Stream لمتابعة التغييرات فوراً)
                });
                if (mounted) Navigator.pop(context);
                _todoController.clear();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
