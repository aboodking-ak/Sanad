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
  bool _showSelectionBar = true;

  @override
  void initState() {
    super.initState();
    _loadSurahData();
  }

  Future<void> _loadSurahData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/jsons/Content/Preparatory/Islamic/islamic_surah.json',
      );
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
        title: const Text(
          "سور الحفظ",
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
                ? 'إخفاء اختيار السورة'
                : 'إظهار اختيار السورة',
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
          : (islamicData == null
                ? const Center(child: Text("تعذر تحميل البيانات"))
                : Stack(
                    children: [
                      Positioned.fill(
                        top: _showSelectionBar ? 62 : 0,
                        child: _buildSurahContent(primaryColor),
                      ),
                      if (_showSelectionBar)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildSurahSelector(),
                        ),
                    ],
                  )),
    );
  }

  Widget _buildSurahSelector() {
    final units = islamicData?['units'] as List? ?? [];
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
            itemCount: units.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final unit = units[index] as Map<String, dynamic>;
              final title = unit['lesson']['subtitle'].toString();
              final selected = selectedUnit == unit;
              return Material(
                color: selected ? const Color(0xFF1A2238) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => selectedUnit = unit),
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
              "يرجى اختيار السورة للعرض",
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
          Text(
            lesson['subtitle'],
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedUnit!['title'],
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontFamily: 'Tajawal',
            ),
          ),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
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

  Widget _buildMergedSurahTextCard() {
    final verses = (selectedUnit!['verses'] as List? ?? [])
        .where((v) => v['is_memorization'] == true)
        .toList();

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
              text: "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ\n\n",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black,
              ),
            ),
            ...List.generate(verses.length, (index) {
              final v = verses[index];
              return TextSpan(text: "${v['text']} ﴿${v['number']}﴾ ");
            }),
            const TextSpan(
              text: "\n\nصَدَقَ اللَّهُ الْعَلِيُّ الْعَظِيمُ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontSize: 18,
          height: 2.3,
          fontWeight: FontWeight.w500,
          fontFamily: 'Tajawal',
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildVocabularyCard() {
    final vocab = selectedUnit!['word_meanings'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
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

  Widget _buildGeneralMeaningCard() {
    final meanings = selectedUnit!['general_meaning'] as List? ?? [];
    final verses = selectedUnit!['verses'] as List? ?? [];

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
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "الآيات ($verseRange)",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 14,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
                if (verseText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Text(
                      verseText,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                        height: 1.8,
                      ),
                    ),
                  ),
                Text(
                  item['text'],
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: Color(0xFF334155),
                    fontFamily: 'Tajawal',
                  ),
                ),
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
        return allVerses
            .where((v) => v['number'] >= start && v['number'] <= end)
            .map((v) => "${v['text']} ﴿${v['number']}﴾")
            .join(" ");
      } else {
        int num = int.parse(range.trim());
        var v = allVerses.firstWhere((v) => v['number'] == num);
        return "${v['text']} ﴿${v['number']}﴾";
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(guidance.length, (index) {
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
      ),
    );
  }
}
