import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BiologyDiagramsScreen extends StatefulWidget {
  const BiologyDiagramsScreen({super.key});

  @override
  State<BiologyDiagramsScreen> createState() => _BiologyDiagramsScreenState();
}

class _BiologyDiagramsScreenState extends State<BiologyDiagramsScreen> {
  Map<String, dynamic>? biologyData;
  String? selectedChapter;
  Map<String, dynamic>? selectedDiagram;
  bool isLoading = true;
  bool _showSelectionBar = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final String response = await rootBundle.loadString('assets/jsons/Content/Scientific/Biology/biology_diagrams.json');
      final data = json.decode(response);
      setState(() {
        biologyData = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading biology diagrams: $e");
      setState(() => isLoading = false);
    }
  }

  List<String> get chapters {
    final chaptersList = biologyData?['chapters'] as List? ?? [];
    return chaptersList.map((c) => c['title'] as String).toList();
  }

  List<Map<String, dynamic>> get currentDiagrams {
    if (selectedChapter == null) return [];
    final chaptersList = biologyData?['chapters'] as List? ?? [];
    final chapter = chaptersList.firstWhere((c) => c['title'] == selectedChapter, orElse: () => null);
    return List<Map<String, dynamic>>.from(chapter?['diagrams'] ?? []);
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
          'رسومات الأحياء',
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
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        actions: [
          IconButton(
            tooltip: _showSelectionBar ? 'إخفاء الاختيارات' : 'إظهار الاختيارات',
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
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _showSelectionBar
                      ? _buildDiagramSelector()
                      : const SizedBox(width: double.infinity),
                ),
                Expanded(child: _buildContent(primaryColor)),
              ],
            ),
    );
  }

  Widget _buildDiagramSelector() {
    final chaptersData = biologyData?['chapters'] as List? ?? [];
    final selectedChapterData = chaptersData.cast<Map<String, dynamic>?>().firstWhere(
      (chapter) => chapter?['title'] == selectedChapter,
      orElse: () => null,
    );
    final diagrams = List<Map<String, dynamic>>.from(
      selectedChapterData?['diagrams'] ?? const [],
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChoiceRow(
            items: chapters,
            selectedTitle: selectedChapter,
            icon: Icons.menu_book_rounded,
            onSelected: (chapter) => setState(() {
              selectedChapter = chapter;
              selectedDiagram = null;
            }),
          ),
          if (selectedChapter != null && diagrams.isNotEmpty)
            _buildChoiceRow(
              items: diagrams.map((diagram) => diagram['title'].toString()).toList(),
              selectedTitle: selectedDiagram?['title']?.toString(),
              icon: Icons.image_outlined,
              compact: true,
              onSelected: (title) => setState(() {
                selectedDiagram = diagrams.firstWhere(
                  (diagram) => diagram['title'].toString() == title,
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildChoiceRow({
    required List<String> items,
    required String? selectedTitle,
    required IconData icon,
    required ValueChanged<String> onSelected,
    bool compact = false,
  }) {
    const navy = Color(0xFF1A2238);

    return SizedBox(
      height: compact ? 48 : 62,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 5 : 9),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 9),
          itemBuilder: (context, index) {
            final title = items[index];
            final selected = selectedTitle == title;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: selected ? navy : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? navy : const Color(0xFFE5E8EF),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: navy.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(title),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 15),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        const Icon(Icons.check_rounded, color: Color(0xFFF2BC3B), size: 17),
                        const SizedBox(width: 6),
                      ] else if (!compact) ...[
                        Icon(icon, color: const Color(0xFF7B8495), size: 17),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: selected ? Colors.white : navy,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 13 : 14,
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
    );
  }
  Widget _buildContent(Color primaryColor) {
    if (selectedChapter == null || selectedDiagram == null) {
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
                Icons.image_search_rounded,
                size: 50,
                color: primaryColor.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'يرجى اختيار الرسمة للعرض',
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

    final diagram = selectedDiagram!;
    final bool isHifth = diagram['type'] == 'حفظ';
    final years = diagram['years'] as List? ?? [];
    final imageWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(selectedChapter!, primaryColor),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        diagram['title'].toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isHifth
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isHifth ? Colors.red : Colors.blue),
                      ),
                      child: Text(
                        diagram['type'].toString(),
                        style: TextStyle(
                          color: isHifth ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ],
                ),
                if (years.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'السنوات الوزارية:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: years.map((year) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          year.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Container(
            width: double.infinity,
            color: Colors.white,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 5.0,
              clipBehavior: Clip.none,
              child: Image.asset(
                diagram['imagePath'].toString(),
                width: imageWidth,
                fit: BoxFit.fitWidth,
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(
                    width: imageWidth,
                    height: 300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text(
                          'لم يتم العثور على ملف الصورة',
                          style: TextStyle(color: Colors.grey, fontFamily: 'Tajawal'),
                        ),
                        Text(
                          diagram['imagePath'].toString().split('/').last,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'Tajawal'),
          ),
        ],
      ),
    );
  }
}
