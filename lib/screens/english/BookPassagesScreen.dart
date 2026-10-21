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
  bool _showSelectionBar = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/jsons/Content/Preparatory/English/book_passages.json',
      );
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
        title: const Text(
          "قطع الكتاب",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            fontFamily: 'Tajawal',
            color: Color(0xFF1A2238),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A2238),
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        actions: [
          IconButton(
            tooltip: _showSelectionBar ? 'Hide selections' : 'Show selections',
            icon: Icon(
              _showSelectionBar
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.tune_rounded,
            ),
            onPressed: isLoading
                ? null
                : () => setState(() => _showSelectionBar = !_showSelectionBar),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: primaryColor,
                ),
              ),
            )
          : (bookData == null
                ? const Center(child: Text("تعذر تحميل البيانات"))
                : Stack(
                    children: [
                      Positioned.fill(
                        top: _showSelectionBar
                            ? (selectedUnit == null ? 62 : 107)
                            : 0,
                        child: _buildPassageContent(primaryColor),
                      ),
                      if (_showSelectionBar)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildPassageSelector(),
                        ),
                    ],
                  )),
    );
  }

  Widget _buildPassageSelector() {
    final units = bookData?['units'] as List? ?? [];
    final selectedUnitData = units.cast<Map<String, dynamic>?>().firstWhere(
      (unit) => unit?['number'] == selectedUnit,
      orElse: () => null,
    );
    final passages = selectedUnitData?['passages'] as List? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2238).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEnglishChoiceRow(
            height: 62,
            items: units,
            selectedTitle: selectedUnitData?['title']?.toString(),
            titleOf: (unit) => unit['title'].toString(),
            onSelected: (unit) => setState(() {
              selectedUnit = unit['number'] as int;
              selectedPassageData = null;
            }),
          ),
          if (selectedUnitData != null)
            _buildEnglishChoiceRow(
              height: 45,
              items: passages,
              selectedTitle: selectedPassageData?['title']?.toString(),
              titleOf: (passage) => passage['title'].toString(),
              onSelected: (passage) =>
                  setState(() => selectedPassageData = passage),
            ),
        ],
      ),
    );
  }

  Widget _buildEnglishChoiceRow({
    required double height,
    required List items,
    required String? selectedTitle,
    required String Function(dynamic item) titleOf,
    required ValueChanged<dynamic> onSelected,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 19, 7),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 9),
          itemBuilder: (context, index) {
            final item = items[index];
            final title = titleOf(item);
            final selected = selectedTitle == title;
            return Material(
              color: selected ? const Color(0xFF1A2238) : Colors.white,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => onSelected(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF1A2238)
                          : const Color(0xFFE5E8EF),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      title,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: selected
                            ? Colors.white
                            : const Color(0xFF1A2238),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 50,
                color: primaryColor.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار الوحدة والقطعة للعرض",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Tajawal',
              ),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedPassageData!['title_ar'] ?? "",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    fontFamily: 'Tajawal',
                  ),
                ),
                if (selectedPassageData!['note'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedPassageData!['note'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                              fontFamily: 'Tajawal',
                            ),
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
            ...segments.map(
              (segment) => _buildSegmentCard(segment, primaryColor),
            ),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Tajawal',
            ),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              segment['en'] ?? "",
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),
          Text(
            segment['ar'] ?? "",
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, Color primaryColor) {
    final bool isFillInBlank =
        (q['a_en'] == null || q['a_en'].toString().trim().isEmpty) &&
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
              Icon(
                isFillInBlank
                    ? Icons.edit_note_rounded
                    : Icons.help_outline_rounded,
                size: 20,
                color: primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                isFillInBlank ? "أكمل الفراغ" : "السؤال",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                  color: Colors.grey,
                ),
              ),
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
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 20,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                const Text(
                  "الجواب",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                q['a_en'] ?? "",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              q['a_ar'] ?? "",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
                fontFamily: 'Tajawal',
              ),
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
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: TextStyle(
              fontSize: isArabic ? 14 : 15,
              fontWeight: isArabic ? FontWeight.w600 : FontWeight.bold,
              color: isArabic
                  ? const Color(0xFF475569)
                  : const Color(0xFF1E293B),
              fontFamily: isArabic ? 'Tajawal' : null,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontSize: isArabic ? 14 : 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
            fontFamily: isArabic ? 'Tajawal' : null,
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(
            fontSize: isArabic ? 14 : 15,
            fontWeight: isArabic ? FontWeight.w600 : FontWeight.bold,
            color: isArabic ? const Color(0xFF475569) : const Color(0xFF1E293B),
            fontFamily: isArabic ? 'Tajawal' : null,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
    );
  }
}
