import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EssaysScreen extends StatefulWidget {
  const EssaysScreen({super.key});

  @override
  State<EssaysScreen> createState() => _EssaysScreenState();
}

class _EssaysScreenState extends State<EssaysScreen> {
  Map<String, dynamic>? essaysData;
  Map<String, dynamic>? selectedEssayData;
  int? selectedUnit; // لتعقب الوحدة المختارة
  bool isInitialLoading = true;
  bool isShortened = false; // Toggle for short version

  @override
  void initState() {
    super.initState();
    _loadEssays();
  }

  Future<void> _loadEssays() async {
    try {
      final String response = await rootBundle.loadString('assets/jsons/subjects/english/essays.json');
      final Map<String, dynamic> data = json.decode(response);
      setState(() {
        essaysData = data;
        isInitialLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading essays data: $e");
      setState(() => isInitialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    const backgroundColor = Color(0xFFF1F5F9);

    if (isInitialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("الإنشاءات الإنجليزية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Tajawal')),
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
          if (selectedEssayData != null)
            IconButton(
              icon: Icon(isShortened ? Icons.compress_rounded : Icons.expand_rounded),
              tooltip: isShortened ? "عرض النص الكامل" : "اختصار النص",
              onPressed: () => setState(() => isShortened = !isShortened),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showSelectionBottomSheet(context, primaryColor),
          ),
        ],
      ),
      body: essaysData == null
          ? const Center(child: Text("تعذر تحميل البيانات"))
          : _buildEssayContent(primaryColor),
    );
  }

  void _showSelectionBottomSheet(BuildContext context, Color primaryColor) {
    final List<dynamic> unitsData = essaysData?['units'] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        // متغيرات مؤقتة للاختيار داخل الـ BottomSheet فقط
        int? tempUnit = selectedUnit;
        Map<String, dynamic>? tempEssay = selectedEssayData;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedUnitData = unitsData.firstWhere(
              (u) => u['number'] == tempUnit,
              orElse: () => null,
            );
            final filteredEssays = selectedUnitData?['essays'] as List? ?? [];

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "اختيار الوحدة والإنشاء",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 20),
                  _buildModalDropdown(
                    "اختر الوحدة (Unit)",
                    Icons.grid_view_rounded,
                    unitsData.map((u) => u['title'] as String).toList(),
                    selectedUnitData?['title'],
                    (val) {
                      final unit = unitsData.firstWhere((u) => u['title'] == val);
                      setModalState(() {
                        tempUnit = unit['number'];
                        tempEssay = null;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  _buildModalDropdown(
                    "اختر الإنشاء (Essay)",
                    Icons.edit_note_rounded,
                    filteredEssays.map((e) => e['title'] as String).toList(),
                    tempEssay?['title'],
                    (val) {
                      final essay = filteredEssays.firstWhere((e) => e['title'] == val);
                      setModalState(() => tempEssay = essay);
                    },
                    isEnabled: tempUnit != null,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (tempEssay != null)
                          ? () {
                              // تحديث الحالة الرئيسية فقط عند الضغط على زر التأكيد
                              setState(() {
                                selectedUnit = tempUnit;
                                selectedEssayData = tempEssay;
                                isShortened = false; // Reset shortening when new essay selected
                              });
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("تأكيد الاختيار", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalDropdown(String hint, IconData icon, List<String> items, String? value, ValueChanged<String?> onChanged, {bool isEnabled = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.grey[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 20, color: isEnabled ? Colors.grey[400] : Colors.grey[300]),
              const SizedBox(width: 12),
              Text(hint, style: TextStyle(color: isEnabled ? Colors.grey[400] : Colors.grey[300], fontFamily: 'Tajawal')),
            ],
          ),
          items: isEnabled
              ? items
                  .map((item) => DropdownMenuItem(
                      value: item,
                      child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(item, textAlign: TextAlign.left, style: const TextStyle(fontFamily: 'Tajawal')))))
                  .toList()
              : null,
          onChanged: isEnabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildEssayContent(Color primaryColor) {
    if (selectedEssayData == null) {
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
              child: Icon(Icons.edit_note_rounded, size: 50, color: primaryColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار الإنشاء للعرض",
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
          _buildSectionHeader("منطوق السؤال (Question)", primaryColor),
          _buildQuestionCard(primaryColor),

          const SizedBox(height: 10),
          _buildSectionHeader("نص الإنشاء (English)", primaryColor),
          _buildEssayTextCard(primaryColor),
          
          const SizedBox(height: 10),
          _buildSectionHeader("الترجمة (Translation)", primaryColor),
          _buildTranslationCard(primaryColor),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              selectedEssayData!['question'] ?? "",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), height: 1.5),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Text(
            selectedEssayData!['question_ar'] ?? "",
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF475569), height: 1.5, fontFamily: 'Tajawal'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'Tajawal'),
          ),
        ],
      ),
    );
  }

  Widget _buildEssayTextCard(Color primaryColor) {
    final String essayText = isShortened 
        ? (selectedEssayData!['short_answer'] ?? selectedEssayData!['answer']) 
        : selectedEssayData!['answer'];
    final int wordCount = essayText.split(' ').where((w) => w.isNotEmpty).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), offset: const Offset(0, 2), blurRadius: 5),
        ],
      ),
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.ltr, // Title in English
            child: Center(
              child: Text(selectedEssayData!['title'],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'Tajawal')),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
            ),
            child: Text(
              "$wordCount Words",
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Tajawal'),
            ),
          ),
          const Divider(height: 40, thickness: 1),
          Directionality(
            textDirection: TextDirection.ltr, // Content in English
            child: Text(
              essayText,
              textAlign: TextAlign.justify,
              style: const TextStyle(fontSize: 17, height: 1.8, fontWeight: FontWeight.w500, color: Color(0xFF334155), fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationCard(Color primaryColor) {
    final String translationText = isShortened 
        ? (selectedEssayData!['short_translation'] ?? selectedEssayData!['translation']) 
        : selectedEssayData!['translation'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Text(
        translationText,
        textAlign: TextAlign.justify,
        style: const TextStyle(fontSize: 17, height: 1.8, fontWeight: FontWeight.w500, color: Color(0xFF334155), fontFamily: 'Tajawal'),
      ),
    );
  }
}
