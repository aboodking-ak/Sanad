import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BookPassagesScreen extends StatefulWidget {
  const BookPassagesScreen({super.key});

  @override
  State<BookPassagesScreen> createState() => _BookPassagesScreenState();
}

class _BookPassagesScreenState extends State<BookPassagesScreen> {
  Map<String, dynamic>? bookData;
  Map<String, dynamic>? selectedPassageData;
  int? selectedUnit;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final String response = await rootBundle.loadString('assets/jsons/Content/Preparatory/English/book_passages.json');
      final Map<String, dynamic> data = json.decode(response);
      setState(() {
        bookData = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading book passages data: $e");
      setState(() => isLoading = false);
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
        title: const Text("قطع الكتاب", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Tajawal')),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: isLoading ? null : () => _showSelectionBottomSheet(context, primaryColor),
          ),
        ],
      ),
      body: isLoading 
          ? Center(child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: primaryColor)))
          : (bookData == null
              ? const Center(child: Text("تعذر تحميل البيانات"))
              : _buildPassageContent(primaryColor)),
    );
  }

  void _showSelectionBottomSheet(BuildContext context, Color primaryColor) {
    final List<dynamic> unitsData = bookData?['units'] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        int? tempUnit = selectedUnit;
        Map<String, dynamic>? tempPassage = selectedPassageData;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedUnitData = unitsData.firstWhere(
              (u) => u['number'] == tempUnit,
              orElse: () => null,
            );
            final filteredPassages = selectedUnitData?['passages'] as List? ?? [];

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "اختيار الوحدة والقطعة",
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
                        tempPassage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  _buildModalDropdown(
                    "اختر القطعة (Passage)",
                    Icons.menu_book_rounded,
                    filteredPassages.map((p) => p['title'] as String).toList(),
                    tempPassage?['title'],
                    (val) {
                      final passage = filteredPassages.firstWhere((p) => p['title'] == val);
                      setModalState(() => tempPassage = passage);
                    },
                    isEnabled: tempUnit != null,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (tempPassage != null)
                          ? () {
                              setState(() {
                                selectedUnit = tempUnit;
                                selectedPassageData = tempPassage;
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

  Widget _buildPassageContent(Color primaryColor) {
    if (selectedPassageData == null) {
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
              "يرجى اختيار الوحدة والقطعة للعرض",
              style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'),
            ),
          ],
        ),
      );
    }

    final segments = selectedPassageData!['segments'] as List? ?? [];
    final questions = selectedPassageData!['questions'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    selectedPassageData!['title'],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'Tajawal'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedPassageData!['title_ar'] ?? "",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey, fontFamily: 'Tajawal'),
                ),
                if (selectedPassageData!['note'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedPassageData!['note'],
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber, fontFamily: 'Tajawal'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(),
              ],
            ),
          ),
          
          if (segments.isNotEmpty) ...[
            _buildSectionHeader("نص القطعة (Passage Text)", primaryColor),
            ...segments.map((segment) => _buildSegmentCard(segment, primaryColor)),
          ],

          if (questions.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionHeader("الأسئلة والأجوبة (Q&A)", primaryColor),
            ...questions.map((q) => _buildQuestionCard(q, primaryColor)),
          ],
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

  Widget _buildSegmentCard(Map<String, dynamic> segment, Color primaryColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), offset: const Offset(0, 2), blurRadius: 5),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              segment['en'] ?? "",
              style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF334155), fontWeight: FontWeight.w500),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),
          Text(
            segment['ar'] ?? "",
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF475569), fontWeight: FontWeight.w600, fontFamily: 'Tajawal'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, Color primaryColor) {
    final bool isFillInBlank = (q['a_en'] == null || q['a_en'].toString().trim().isEmpty) &&
        (q['a_ar'] == null || q['a_ar'].toString().trim().isEmpty);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Section
          Row(
            children: [
              Icon(isFillInBlank ? Icons.edit_note_rounded : Icons.help_outline_rounded, size: 20, color: primaryColor),
              const SizedBox(width: 8),
              Text(isFillInBlank ? "أكمل الفراغ" : "السؤال",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: _buildRichText(q['q_en'] ?? ""),
          ),
          const SizedBox(height: 5),
          _buildRichText(q['q_ar'] ?? "", isArabic: true),

          if (!isFillInBlank) ...[
            const Divider(height: 30),
            // Answer Section
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                const Text("الجواب", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal', color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                q['a_en'] ?? "",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              q['a_ar'] ?? "",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569), fontFamily: 'Tajawal'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRichText(String text, {bool isArabic = false}) {
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'<u>(.*?)</u>');
    int lastMatchEnd = 0;

    final Iterable<RegExpMatch> matches = regExp.allMatches(text);

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(
            fontSize: isArabic ? 14 : 15,
            fontWeight: isArabic ? FontWeight.w600 : FontWeight.bold,
            color: isArabic ? const Color(0xFF475569) : const Color(0xFF1E293B),
            fontFamily: isArabic ? 'Tajawal' : null,
          ),
        ));
      }

      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontSize: isArabic ? 14 : 15,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          fontFamily: isArabic ? 'Tajawal' : null,
        ),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(
          fontSize: isArabic ? 14 : 15,
          fontWeight: isArabic ? FontWeight.w600 : FontWeight.bold,
          color: isArabic ? const Color(0xFF475569) : const Color(0xFF1E293B),
          fontFamily: isArabic ? 'Tajawal' : null,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
    );
  }
}
