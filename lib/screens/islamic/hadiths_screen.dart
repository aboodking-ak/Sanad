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
  bool _showSelectionBar = true;

  @override
  void initState() {
    super.initState();
    _loadHadithData();
  }

  Future<void> _loadHadithData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/jsons/Content/Preparatory/Islamic/hadiths_questions.json',
      );
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
        title: const Text(
          "الأحاديث النبوية الشريفة",
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
            tooltip: _showSelectionBar
                ? 'إخفاء اختيار الحديث'
                : 'إظهار اختيار الحديث',
            icon: Icon(
              _showSelectionBar
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.tune_rounded,
            ),
            onPressed: isInitialLoading
                ? null
                : () => setState(() => _showSelectionBar = !_showSelectionBar),
          ),
        ],
      ),
      body: isInitialLoading
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
          : (hadithData == null
                ? const Center(child: Text("تعذر تحميل البيانات"))
                : Stack(
                    children: [
                      Positioned.fill(
                        top: _showSelectionBar ? 62 : 0,
                        child: _buildHadithContent(primaryColor),
                      ),
                      if (_showSelectionBar)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildHadithSelector(),
                        ),
                    ],
                  )),
    );
  }

  Widget _buildHadithSelector() {
    final lessons = hadithData?['lessons'] as List? ?? [];
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
      child: SizedBox(
        height: 62,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            itemCount: lessons.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final lesson = lessons[index] as Map<String, dynamic>;
              final title = lesson['lesson_title'].toString();
              final selected = selectedLesson == lesson;
              return Material(
                color: selected ? const Color(0xFF1A2238) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => selectedLesson = lesson),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1A2238)
                            : const Color(0xFFE5E8EF),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(
                            Icons.check_rounded,
                            color: Color(0xFFF2B833),
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: selected
                                ? Colors.white
                                : const Color(0xFF1A2238),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
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
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.format_quote_rounded,
                size: 50,
                color: primaryColor.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار الحديث للعرض",
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

    final sections = selectedLesson!['sections'] as List? ?? [];
    final hasMeanings = sections.any(
      (s) => s['section_title'] == "معاني الكلمات",
    );
    final hasGuidance = sections.any(
      (s) => s['section_title'] == "أهم ما يرشد إليه الحديث",
    );

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
            _buildVocabularyCard(
              sections.firstWhere(
                (s) => s['section_title'] == "معاني الكلمات",
              )['questions'],
            ),
          ],

          if (hasGuidance) ...[
            const SizedBox(height: 10),
            _buildSectionHeader("أبرز ما ترشد إليه الحديث", primaryColor),
            _buildGuidanceCard(
              sections.firstWhere(
                (s) => s['section_title'] == "أهم ما يرشد إليه الحديث",
              ),
            ),
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
            child: Text(
              selectedLesson!['lesson_title'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedLesson!['unit_title'] ?? hadithData!['unit'] ?? "",
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontFamily: 'Tajawal',
            ),
          ),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
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
            decoration: BoxDecoration(
              color: color,
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

  Widget _buildHadithTextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text:
                  "قَالَ رَسُولُ اللَّهِ (صَلَّى اللَّهُ عَلَيْهِ وَآلِهِ وَسَلَّمَ):\n\n",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black,
                fontFamily: 'Tajawal',
              ),
            ),
            TextSpan(
              text: selectedLesson!['hadith_text'],
              style: const TextStyle(
                fontSize: 18,
                height: 2.0,
                fontWeight: FontWeight.w600,
                fontFamily: 'Amiri',
                color: Color(0xFF1E293B),
              ),
            ),
            const TextSpan(
              text: "\n\nصَدَقَ رَسُولُ اللَّهِ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.blueGrey,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      ),
    );
  }

  Widget _buildVocabularyCard(List questions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
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
      decoration: BoxDecoration(
        color: isGray ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              word,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              meaning,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontFamily: 'Tajawal',
              ),
            ),
          ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
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
                  Text(
                    "${index + 1}.",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      guidance[index],
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xFF334155),
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
