import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HadithsScreen extends StatefulWidget {
  const HadithsScreen({super.key});

  @override
  State<HadithsScreen> createState() => _HadithsScreenState();
}

class _HadithsScreenState extends State<HadithsScreen> {
  Map<String, dynamic>? hadithData;
  Map<String, dynamic>? selectedLesson;
  bool isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHadithData();
  }

  Future<void> _loadHadithData() async {
    try {
      final String response = await rootBundle.loadString('assets/jsons/islamic/hadiths_questions.json');
      final data = json.decode(response);
      setState(() {
        hadithData = data;
        isInitialLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading hadith data: $e");
      setState(() => isInitialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    const backgroundColor = Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("الأحاديث النبوية الشريفة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Tajawal')),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: isInitialLoading ? null : () => _showSelectionBottomSheet(context, primaryColor),
          ),
        ],
      ),
      body: isInitialLoading 
          ? Center(child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: primaryColor)))
          : (hadithData == null
              ? const Center(child: Text("تعذر تحميل البيانات"))
              : _buildHadithContent(primaryColor)),
    );
  }

  void _showSelectionBottomSheet(BuildContext context, Color primaryColor) {
    final lessons = hadithData?['lessons'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        Map<String, dynamic>? tempLesson = selectedLesson;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "اختيار الحديث",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 20),
                  _buildModalDropdown(
                    "الحديث",
                    Icons.menu_book_rounded,
                    lessons.map((l) => l['lesson_title'].toString()).toList(),
                    tempLesson?['lesson_title'],
                    (val) {
                      final newLesson = lessons.firstWhere((l) => l['lesson_title'] == val);
                      setModalState(() => tempLesson = newLesson);
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => selectedLesson = tempLesson);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("تأكيد الاختيار", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalDropdown(String hint, IconData icon, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Text(hint, style: TextStyle(color: Colors.grey[400], fontFamily: 'Tajawal')),
            ],
          ),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontFamily: 'Tajawal')))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildHadithContent(Color primaryColor) {
    if (selectedLesson == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20),
                ],
              ),
              child: Icon(Icons.format_quote_rounded, size: 50, color: primaryColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار الحديث للعرض",
              style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'),
            ),
          ],
        ),
      );
    }

    final sections = selectedLesson!['sections'] as List? ?? [];
    final hasMeanings = sections.any((s) => s['section_title'] == "معاني الكلمات");
    final hasGuidance = sections.any((s) => s['section_title'] == "أهم ما يرشد إليه الحديث");

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          _buildHadithTitleHeader(primaryColor),
          
          _buildSectionHeader("نص الحديث الشريف", primaryColor),
          _buildHadithTextCard(),

          if (hasMeanings) ...[
            const SizedBox(height: 10),
            _buildSectionHeader("معاني الكلمات", primaryColor),
            _buildVocabularyCard(sections.firstWhere((s) => s['section_title'] == "معاني الكلمات")['questions']),
          ],
          
          if (hasGuidance) ...[
            const SizedBox(height: 10),
            _buildSectionHeader("أبرز ما ترشد إليه الحديث", primaryColor),
            _buildGuidanceCard(sections.firstWhere((s) => s['section_title'] == "أهم ما يرشد إليه الحديث")),
          ],
        ],
      ),
    );
  }

  Widget _buildHadithTitleHeader(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(selectedLesson!['lesson_title'],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'Tajawal')),
          ),
          const SizedBox(height: 6),
          Text(selectedLesson!['unit_title'] ?? hadithData!['unit'] ?? "",
              style: const TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Tajawal')),
          if (selectedLesson!['note'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
              ),
              child: Text(
                selectedLesson!['note'],
                style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  Widget _buildHadithTextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), offset: const Offset(0, 2), blurRadius: 5)],
      ),
      child: Text(
        selectedLesson!['hadith_text'],
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 17, height: 2.0, fontWeight: FontWeight.w600, fontFamily: 'Amiri', color: Color(0xFF1E293B)),
      ),
    );
  }

  Widget _buildVocabularyCard(List questions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: questions.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildVocabRow(item['word'], item['meaning'], index % 2 == 0);
        }).toList(),
      ),
    );
  }

  Widget _buildVocabRow(String word, String meaning, bool isGray) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(color: isGray ? Colors.grey[50] : Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(word, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontFamily: 'Tajawal'))),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: Text(meaning, style: const TextStyle(color: Color(0xFF475569), fontFamily: 'Tajawal'))),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(Map<String, dynamic> section) {
    final guidance = section['guidance'] as List? ?? [];
    final note = section['note'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null) ...[
            Text(
              note,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 15),
          ],
          ...List.generate(guidance.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${index + 1}.", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(guidance[index], style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF334155), fontFamily: 'Tajawal'))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
