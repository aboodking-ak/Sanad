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
  bool _showSelectionBar = true;

  @override
  void initState() {
    super.initState();
    _loadEssays();
  }

  Future<void> _loadEssays() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/jsons/Content/Preparatory/English/essays.json',
      );
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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "الإنشاءات الإنجليزية",
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
          : (essaysData == null
                ? const Center(child: Text("تعذر تحميل البيانات"))
                : Stack(
                    children: [
                      Positioned.fill(
                        top: _showSelectionBar
                            ? (selectedUnit == null ? 62 : 107)
                            : 0,
                        child: _buildEssayContent(primaryColor),
                      ),
                      if (_showSelectionBar)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildEssaySelector(),
                        ),
                    ],
                  )),
    );
  }

  Widget _buildEssaySelector() {
    final units = essaysData?['units'] as List? ?? [];
    final selectedUnitData = units.cast<Map<String, dynamic>?>().firstWhere(
      (unit) => unit?['number'] == selectedUnit,
      orElse: () => null,
    );
    final essays = selectedUnitData?['essays'] as List? ?? [];

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
              selectedEssayData = null;
            }),
          ),
          if (selectedUnitData != null)
            _buildEnglishChoiceRow(
              height: 45,
              items: essays,
              selectedTitle: selectedEssayData?['title']?.toString(),
              titleOf: (essay) => essay['title'].toString(),
              onSelected: (essay) => setState(() => selectedEssayData = essay),
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
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 50,
                color: primaryColor.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار الإنشاء للعرض",
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                height: 1.5,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Text(
            selectedEssayData!['question_ar'] ?? "",
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              height: 1.5,
              fontFamily: 'Tajawal',
            ),
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

  Widget _buildEssayTextCard(Color primaryColor) {
    final String essayText = selectedEssayData!['answer'];
    final int wordCount = essayText
        .split(' ')
        .where((w) => w.isNotEmpty)
        .length;

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
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.ltr, // Title in English
            child: Center(
              child: Text(
                selectedEssayData!['title'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontFamily: 'Tajawal',
                ),
              ),
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
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          const Divider(height: 40, thickness: 1),
          Directionality(
            textDirection: TextDirection.ltr, // Content in English
            child: Text(
              essayText,
              textAlign: TextAlign.justify,
              style: const TextStyle(
                fontSize: 17,
                height: 1.8,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationCard(Color primaryColor) {
    final String translationText = selectedEssayData!['translation'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(color: Colors.white),
      child: Text(
        translationText,
        textAlign: TextAlign.justify,
        style: const TextStyle(
          fontSize: 17,
          height: 1.8,
          fontWeight: FontWeight.w500,
          color: Color(0xFF334155),
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }
}
