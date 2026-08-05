import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SurahScreen extends StatefulWidget {
  const SurahScreen({super.key});

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  Map<String, dynamic>? islamicData;
  Map<String, dynamic>? selectedUnit;
  bool isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSurahData();
  }

  Future<void> _loadSurahData() async {
    try {
      final String response = await rootBundle.loadString('assets/jsons/Content/Preparatory/Islamic/islamic_surah.json');
      final data = json.decode(response);
      setState(() {
        islamicData = data;
        isInitialLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading surah data: $e");
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
        title: const Text("سور الحفظ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Tajawal')),
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
          : (islamicData == null
              ? const Center(child: Text("تعذر تحميل البيانات"))
              : _buildSurahContent(primaryColor)),
    );
  }

  void _showSelectionBottomSheet(BuildContext context, Color primaryColor) {
    final units = islamicData?['units'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        Map<String, dynamic>? tempUnit = selectedUnit;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "اختيار السورة",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 20),
                  _buildModalDropdown(
                    "السورة",
                    Icons.menu_book_rounded,
                    units.map((u) => u['lesson']['subtitle'].toString()).toList(),
                    tempUnit?['lesson']['subtitle'],
                    (val) {
                      final newUnit = units.firstWhere((u) => u['lesson']['subtitle'] == val);
                      setModalState(() => tempUnit = newUnit);
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => selectedUnit = tempUnit);
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

  Widget _buildSurahContent(Color primaryColor) {
    if (selectedUnit == null) {
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
              child: Icon(Icons.menu_book_rounded, size: 50, color: primaryColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار السورة للعرض",
              style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          _buildSurahTitleHeader(primaryColor),
          
          _buildSectionHeader("النص القرآني", primaryColor),
          _buildMergedSurahTextCard(),

          const SizedBox(height: 10),
          _buildSectionHeader("الكلمة ومعناها", primaryColor),
          if (selectedUnit!['meanings_note'] != null)
            _buildNoteCard(selectedUnit!['meanings_note'], Colors.orange),
          _buildVocabularyCard(),
          
          const SizedBox(height: 10),
          _buildSectionHeader("المعنى العام", primaryColor),
          _buildGeneralMeaningCard(),

          const SizedBox(height: 10),
          _buildSectionHeader("أبرز ما ترشد إليه السورة", primaryColor),
          _buildGuidanceCard(),
        ],
      ),
    );
  }

  Widget _buildSurahTitleHeader(Color primaryColor) {
    final lesson = selectedUnit!['lesson'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      child: Column(
        children: [
          Text(lesson['subtitle'],
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'Tajawal')),
          const SizedBox(height: 6),
          Text(selectedUnit!['title'],
              style: const TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Tajawal')),
          if (lesson['memorization_range'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
              ),
              child: Text(
                "آيات الحفظ: من ${lesson['memorization_range'].toString().split('-').first} إلى ${lesson['memorization_range'].toString().split('-').last}",
                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
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

  Widget _buildMergedSurahTextCard() {
    final verses = selectedUnit!['verses'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), offset: const Offset(0, 2), blurRadius: 5)],
      ),
      child: Text.rich(
        TextSpan(
          children: List.generate(verses.length, (index) {
            final v = verses[index];
            return TextSpan(text: "${v['text']} ﴿${v['number']}﴾ ");
          }),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 18, height: 2.3, fontWeight: FontWeight.w500, fontFamily: 'Tajawal', color: Color(0xFF1E293B)),
      ),
    );
  }

  Widget _buildVocabularyCard() {
    final vocab = selectedUnit!['word_meanings'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: vocab.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildVocabRow(item['word'], item['meaning'], index % 2 == 0);
        }).toList(),
      ),
    );
  }

  Widget _buildNoteCard(String note, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ],
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

  Widget _buildGeneralMeaningCard() {
    final meanings = selectedUnit!['general_meaning'] as List? ?? [];
    final verses = selectedUnit!['verses'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: meanings.map((item) {
          // محاولة جلب نص الآية بناءً على الأرقام المذكورة في الشرح
          String verseRange = item['verses'].toString();
          String verseText = _extractVerseText(verses, verseRange);

          return Padding(
            padding: const EdgeInsets.only(bottom: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text("الآيات ($verseRange)", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14, fontFamily: 'Tajawal')),
                  ],
                ),
                if (verseText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withValues(alpha: 0.05))),
                    child: Text(verseText, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blueGrey, height: 1.8)),
                  ),
                Text(item['text'], style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF334155), fontFamily: 'Tajawal')),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _extractVerseText(List allVerses, String range) {
    try {
      if (range.contains('-')) {
        var parts = range.split('-');
        int start = int.parse(parts[0].trim());
        int end = int.parse(parts[1].trim());
        return allVerses.where((v) => v['number'] >= start && v['number'] <= end).map((v) => v['text']).join(" ");
      } else {
        int num = int.parse(range.trim());
        return allVerses.firstWhere((v) => v['number'] == num)['text'];
      }
    } catch (e) {
      return "";
    }
  }

  Widget _buildGuidanceCard() {
    final guidance = selectedUnit!['guidance'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(guidance.length, (index) {
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
      ),
    );
  }
}
