import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  static const _navy = Color(0xFF1A2238);
  static const _background = Color(0xFFF4F5F8);
  static const _gold = Color(0xFFF2B833);

  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  Stream<List<Map<String, dynamic>>>? _notesStream;
  String _searchQuery = "";
  bool _sortOldestFirst = false;
  final Map<String, Map<String, dynamic>> _pendingDeletes = {};
  Timer? _deleteTimer;
  Timer? _undoSnackBarTimer;

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

  @override
  void dispose() {
    _undoSnackBarTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToNoteEditor({Map<String, dynamic>? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(note: note, colors: _noteColors),
      ),
    );
  }

  Future<void> _togglePin(Map<String, dynamic> note) async {
    final currentStatus = note['is_pinned'] == true;
    try {
      await supabase
          .from('notes')
          .update({'is_pinned': !currentStatus})
          .eq('id', note['id']);
      if (mounted) {
        _showMessage(currentStatus ? 'أزيل التثبيت' : 'ثُبّتت الملاحظة');
      }
    } catch (error) {
      debugPrint('Pin note failed: $error');
      if (mounted) _showMessage('تعذر تحديث تثبيت الملاحظة. حاول مجدداً.');
    }
  }

  Future<bool> _confirmDelete(Map<String, dynamic> note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الملاحظة؟'),
        content: const Text('هل تريد حذف هذه الملاحظة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return shouldDelete == true && mounted;
  }

  void _scheduleDelete(Map<String, dynamic> note) {
    final id = note['id'].toString();
    _pendingDeletes[id] = Map<String, dynamic>.from(note);
    _deleteTimer?.cancel();
    _deleteTimer = Timer(const Duration(seconds: 5), _commitDeletes);
    _showUndoMessage('تم حذف الملاحظة');
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

  void _undoDeletes() {
    if (!mounted || _pendingDeletes.isEmpty) return;
    _deleteTimer?.cancel();
    _undoSnackBarTimer?.cancel();
    setState(_pendingDeletes.clear);
  }

  Future<void> _commitDeletes() async {
    final ids = _pendingDeletes.keys.toList();
    _pendingDeletes.clear();
    for (final id in ids) {
      try {
        final deleted = await supabase.from('notes').delete().eq('id', id).select('id');
        if (deleted.isEmpty) throw StateError('No note was deleted');
      } catch (error) {
        debugPrint('Delete note failed: $error');
        if (!mounted) return;
        setState(_initStream);
        _showMessage('تعذر إكمال حذف الملاحظة. تحقق من الاتصال.');
      }
    }
  }

  Future<void> _shareNote(Map<String, dynamic> note) async {
    final title = (note['title'] ?? '').toString().trim();
    final content = (note['content'] ?? '').toString().trim();
    final text = [if (title.isNotEmpty) title, if (content.isNotEmpty) content]
        .join('\n\n');
    try {
      await Share.share(text, subject: title.isEmpty ? 'ملاحظة من سند' : title);
    } catch (error) {
      debugPrint('Share note failed: $error');
      if (mounted) _showMessage('تعذرت مشاركة الملاحظة.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("يرجى تسجيل الدخول أولاً")));
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
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
        title: const Text(
          'ملاحظاتي',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(primaryColor),
          _buildSortControls(),
          Expanded(
            child: _notesStream == null 
              ? const Center(child: Text("يرجى التأكد من تسجيل الدخول"))
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _notesStream,
                  builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildLoadError();
                }
                
                // التأكد من وجود بيانات قبل إخفاء مؤشر التحميل
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _gold));
                }
                
                var notes = List<Map<String, dynamic>>.from(snapshot.data ?? const [])
                    .where((note) => !_pendingDeletes.containsKey(note['id'].toString()))
                    .toList();
                
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
                  return _sortOldestFirst
                      ? aDate.compareTo(bDate)
                      : bDate.compareTo(aDate);
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
                  return _buildEmptyState(isSearchResult: _searchQuery.isNotEmpty);
                }

                return _buildListView(notes, primaryColor);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToNoteEditor(),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        label: const Text('ملاحظة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }

  Widget _buildSearchBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _navy.withAlpha(10)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'ابحث في ملاحظاتك...',
            prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSortControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.sort_rounded, color: Color(0xFF7A8291), size: 18),
          const SizedBox(width: 6),
          const Text(
            'ترتيب',
            style: TextStyle(color: Color(0xFF7A8291), fontSize: 12),
          ),
          const Spacer(),
          _sortChip('الأحدث', selected: !_sortOldestFirst, onTap: () {
            setState(() => _sortOldestFirst = false);
          }),
          const SizedBox(width: 8),
          _sortChip('الأقدم', selected: _sortOldestFirst, onTap: () {
            setState(() => _sortOldestFirst = true);
          }),
        ],
      ),
    );
  }

  Widget _sortChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _navy,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: _navy,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? _navy : _navy.withAlpha(18)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFF9AA2B1), size: 42),
            const SizedBox(height: 10),
            const Text('تعذر تحميل الملاحظات'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(_initStream),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
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
          confirmDismiss: (_) => _confirmDelete(note),
          onDismissed: (_) {
            setState(() => _scheduleDelete(note));
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
    final rawColorIndex = note['color_index'];
    final colorIndex = (rawColorIndex is int
            ? rawColorIndex
            : int.tryParse(rawColorIndex?.toString() ?? '') ?? 0)
        .clamp(0, _noteColors.length - 1)
        .toInt();
    final isPinned = note['is_pinned'] == true;
    final title = (note['title'] ?? '').toString().trim();
    final content = (note['content'] ?? '').toString().trim();
    final createdAt = DateTime.tryParse(note['created_at']?.toString() ?? '')
        ?.toLocal();
    final dateLabel = createdAt == null
        ? 'غير معروف'
        : DateFormat('dd MMM yyyy').format(createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToNoteEditor(note: note),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _noteColors[colorIndex],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _navy.withAlpha(12)),
            boxShadow: [
              BoxShadow(
                color: _navy.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'بدون عنوان' : title,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPinned) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.push_pin_rounded, size: 17, color: primaryColor),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content.isEmpty ? 'لا يوجد نص' : content,
                style: TextStyle(color: _navy.withAlpha(180), fontSize: 13, height: 1.45),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: _navy.withAlpha(120)),
                  const SizedBox(width: 4),
                  Text(
                    dateLabel,
                    style: TextStyle(color: _navy.withAlpha(150), fontSize: 11),
                  ),
                  const Spacer(),
                  _noteAction(
                    tooltip: isPinned ? 'إلغاء التثبيت' : 'تثبيت',
                    icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    onPressed: () => _togglePin(note),
                    color: isPinned ? primaryColor : _navy.withAlpha(170),
                  ),
                  _noteAction(
                    tooltip: 'مشاركة',
                    icon: Icons.ios_share_rounded,
                    onPressed: () => _shareNote(note),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noteAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    Color color = _navy,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildEmptyState({bool isSearchResult = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearchResult ? Icons.search_off_rounded : Icons.note_alt_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isSearchResult ? 'لا توجد نتائج مطابقة' : 'لا توجد ملاحظات حالياً',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
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
  static const _navy = Color(0xFF1A2238);
  static const _background = Color(0xFFF4F5F8);

  final supabase = Supabase.instance.client;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  int _selectedColorIndex = 0;
  bool _isSaving = false;
  String _initialTitle = '';
  String _initialContent = '';
  int _initialColorIndex = 0;

  @override
  void initState() {
    super.initState();
    _initialTitle = (widget.note?['title'] ?? '').toString();
    _initialContent = (widget.note?['content'] ?? '').toString();
    final rawIndex = widget.note?['color_index'];
    _selectedColorIndex = (rawIndex is int
            ? rawIndex
            : int.tryParse(rawIndex?.toString() ?? '') ?? 0)
        .clamp(0, widget.colors.length - 1)
        .toInt();
    _initialColorIndex = _selectedColorIndex;
    _titleController = TextEditingController(text: _initialTitle);
    _contentController = TextEditingController(text: _initialContent);
    _titleController.addListener(_handleEditorChange);
    _contentController.addListener(_handleEditorChange);
  }

  bool get _hasUnsavedChanges =>
      _titleController.text != _initialTitle ||
      _contentController.text != _initialContent ||
      _selectedColorIndex != _initialColorIndex;

  void _handleEditorChange() {
    if (mounted) setState(() {});
  }

  Future<bool> _confirmLeave() async {
    if (_isSaving) return false;
    if (!_hasUnsavedChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('تغييرات غير محفوظة'),
            content: const Text('هل تريد الخروج دون حفظ التغييرات؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('متابعة التعديل'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('خروج دون حفظ'),
              ),
            ],
          ),
        ) ??
        false;
  }
@override
  void dispose() {
    _titleController.removeListener(_handleEditorChange);
    _contentController.removeListener(_handleEditorChange);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف عنواناً أو محتوى قبل الحفظ.')),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتهت الجلسة. سجّل الدخول ثم حاول مجدداً.')),
      );
      return;
    }

    setState(() => _isSaving = true);
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
    String dateStr = "";
    try {
      final date = widget.note != null 
          ? DateTime.parse(widget.note!['created_at']).toLocal()
          : DateTime.now();
      dateStr = DateFormat('dd MMMM yyyy  hh:mm a').format(date);
    } catch (e) {
      dateStr = DateFormat('dd MMMM yyyy  hh:mm a').format(DateTime.now());
    }

    return WillPopScope(
      onWillPop: _confirmLeave,
      child: Scaffold(
      backgroundColor: widget.colors[_selectedColorIndex],
      appBar: AppBar(
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
        title: Text(
          widget.note == null ? 'ملاحظة جديدة' : 'تعديل الملاحظة',
          style: const TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: _navy, strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'حفظ الملاحظة',
              icon: const Icon(Icons.check_rounded, size: 26, color: _navy),
              onPressed: _saveNote,
            ),
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
      ),
    );
  }

  Widget _buildColorPicker() {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _background,
        border: Border(top: BorderSide(color: _navy.withAlpha(12))),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 8, end: 4),
            child: Text(
              'اللون',
              style: TextStyle(color: _navy, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.colors.length,
              itemBuilder: (context, index) => Semantics(
                button: true,
                selected: _selectedColorIndex == index,
                label: 'لون ${index + 1}',
                child: GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.colors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColorIndex == index ? _navy : Colors.grey[300]!,
                        width: _selectedColorIndex == index ? 3 : 1,
                      ),
                      boxShadow: [
                        if (_selectedColorIndex == index)
                          BoxShadow(color: _navy.withAlpha(24), blurRadius: 6),
                      ],
                    ),
                    child: _selectedColorIndex == index
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: index == 0 ? _navy : _navy,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
