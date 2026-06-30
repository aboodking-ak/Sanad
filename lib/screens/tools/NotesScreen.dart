import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final supabase = Supabase.instance.client;
  Stream<List<Map<String, dynamic>>>? _notesStream;
  String _searchQuery = "";

  // قائمة ألوان الملاحظات
  final List<Color> _noteColors = [
    Colors.white,
    const Color(0xFFFFE082), // Amber
    const Color(0xFFA5D6A7), // Green
    const Color(0xFF90CAF9), // Blue
    const Color(0xFFF48FB1), // Pink
    const Color(0xFFCE93D8), // Purple
    const Color(0xFFFFAB91), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      _notesStream = supabase
          .from('notes')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('is_pinned', ascending: false) // ترتيب المثبت أولاً
          .order('created_at', ascending: false); // ثم الأحدث تاريخاً
    }
  }

  void _navigateToNoteEditor({Map<String, dynamic>? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(note: note, colors: _noteColors),
      ),
    );
  }

  Future<void> _deleteNote(String id) async {
    await supabase.from('notes').delete().eq('id', id);
  }

  Future<void> _togglePin(Map<String, dynamic> note) async {
    final bool currentStatus = note['is_pinned'] ?? false;
    await supabase.from('notes').update({'is_pinned': !currentStatus}).eq('id', note['id']);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("يرجى تسجيل الدخول أولاً")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text("ملاحظاتي", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(primaryColor),
          Expanded(
            child: _notesStream == null 
              ? const Center(child: Text("يرجى التأكد من تسجيل الدخول"))
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _notesStream,
                  builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                
                // التأكد من وجود بيانات قبل إخفاء مؤشر التحميل
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var notes = snapshot.data ?? [];
                
                // ترتيب يدوي لضمان ظهور المثبت في الأعلى دائماً
                notes.sort((a, b) {
                  final bool aPinned = a['is_pinned'] ?? false;
                  final bool bPinned = b['is_pinned'] ?? false;
                  if (aPinned != bPinned) {
                    return aPinned ? -1 : 1; // المثبت أولاً
                  }
                  // إذا كان كلاهما مثبت أو كلاهما غير مثبت، نرتب حسب التاريخ الأحدث
                  final DateTime aDate = DateTime.tryParse(a['created_at'] ?? "") ?? DateTime(2000);
                  final DateTime bDate = DateTime.tryParse(b['created_at'] ?? "") ?? DateTime(2000);
                  return bDate.compareTo(aDate);
                });
                
                // فلترة البحث
                if (_searchQuery.isNotEmpty) {
                  notes = notes.where((n) {
                    final title = (n['title'] ?? "").toString().toLowerCase();
                    final content = (n['content'] ?? "").toString().toLowerCase();
                    final query = _searchQuery.toLowerCase();
                    return title.contains(query) || content.contains(query);
                  }).toList();
                }

                if (notes.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildListView(notes, primaryColor);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToNoteEditor(),
        backgroundColor: primaryColor,
        label: const Text("ملاحظة جديدة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildSearchBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 5, offset: Offset.zero)],
        ),
        child: TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: "ابحث في ملاحظاتك...",
            prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> notes, Color primaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final String id = note['id'].toString();

        return Dismissible(
          key: Key(id),
          direction: DismissDirection.startToEnd,
          onDismissed: (direction) {
            _deleteNote(id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("تم حذف الملاحظة"),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 25),
            child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildNoteCard(note, primaryColor),
          ),
        );
      },
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, Color primaryColor) {
    final int colorIndex = note['color_index'] ?? 0;
    final bool isPinned = note['is_pinned'] ?? false;
    
    // معالجة التاريخ بشكل آمن
    String dateStr = "غير معروف";
    String timeStr = "";
    try {
      if (note['created_at'] != null) {
        final date = DateTime.parse(note['created_at']).toLocal();
        dateStr = DateFormat('dd MMM yyyy').format(date);
        timeStr = DateFormat('hh:mm a').format(date);
      }
    } catch (e) {
      debugPrint("Error parsing date: $e");
    }

    return GestureDetector(
      onTap: () => _navigateToNoteEditor(note: note),
      onLongPress: () => _showOptions(note),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _noteColors[colorIndex],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withAlpha(10)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 4, offset: Offset.zero)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // يمنع تمدد الملاحظة بشكل لا نهائي
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (note['title'] ?? "").isEmpty ? "بدون عنوان" : note['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPinned) Icon(Icons.push_pin_rounded, size: 16, color: primaryColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (note['content'] ?? "").isEmpty ? "لا يوجد نص" : note['content'],
              style: TextStyle(color: Colors.black.withAlpha(150), fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: Icon(note['is_pinned'] == true ? Icons.push_pin_outlined : Icons.push_pin_rounded),
            title: Text(note['is_pinned'] == true ? "إلغاء التثبيت" : "تثبيت الملاحظة"),
            onTap: () {
              Navigator.pop(context);
              _togglePin(note);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            title: const Text("حذف الملاحظة", style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _deleteNote(note['id']);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_alt_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("لا توجد ملاحضات حالياً", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? note;
  final List<Color> colors;
  const NoteEditorScreen({super.key, this.note, required this.colors});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final supabase = Supabase.instance.client;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  int _selectedColorIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?['title'] ?? "");
    _contentController = TextEditingController(text: widget.note?['content'] ?? "");
    _selectedColorIndex = widget.note?['color_index'] ?? 0;
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = {
        'user_id': user.id,
        'title': title,
        'content': content,
        'color_index': _selectedColorIndex,
      };

      if (widget.note == null) {
        await supabase.from('notes').insert(data);
      } else {
        await supabase.from('notes').update(data).eq('id', widget.note!['id']);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الحفظ: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    String dateStr = "";
    try {
      final date = widget.note != null 
          ? DateTime.parse(widget.note!['created_at']).toLocal()
          : DateTime.now();
      dateStr = DateFormat('dd MMMM yyyy  hh:mm a').format(date);
    } catch (e) {
      dateStr = DateFormat('dd MMMM yyyy  hh:mm a').format(DateTime.now());
    }

    return Scaffold(
      backgroundColor: widget.colors[_selectedColorIndex],
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(widget.note == null ? "ملاحظة جديدة" : "تعديل الملاحظة", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isSaving 
            ? const Center(child: Padding(padding: EdgeInsets.all(15), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))))
            : IconButton(icon: const Icon(Icons.check_rounded, size: 28), onPressed: _saveNote),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: "العنوان", border: InputBorder.none),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(color: Colors.black.withAlpha(100), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    style: const TextStyle(fontSize: 18, height: 1.5),
                    decoration: const InputDecoration(hintText: "اكتب ملاحظاتك هنا...", border: InputBorder.none),
                  ),
                ],
              ),
            ),
          ),
          _buildColorPicker(),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.colors.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => setState(() => _selectedColorIndex = index),
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.colors[index],
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedColorIndex == index ? Colors.blue : Colors.grey[300]!,
                width: _selectedColorIndex == index ? 3 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
