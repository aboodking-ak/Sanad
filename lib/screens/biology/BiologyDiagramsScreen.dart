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
        title: const Text("رسومات الأحياء", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Tajawal')),
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
            onPressed: isLoading ? null : () => _showSelectionBottomSheet(context, primaryColor),
          ),
        ],
      ),
      body: isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _buildContent(primaryColor),
    );
  }

  void _showSelectionBottomSheet(BuildContext context, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        String? tempChapter = selectedChapter;
        Map<String, dynamic>? tempDiagram = selectedDiagram;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredDiagrams = tempChapter == null 
                ? <Map<String, dynamic>>[] 
                : List<Map<String, dynamic>>.from(
                    (biologyData?['chapters'] as List).firstWhere((c) => c['title'] == tempChapter)['diagrams']
                  );

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "اختيار الرسمة",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
                  ),
                  const SizedBox(height: 20),
                  _buildModalDropdown(
                    "الفصل",
                    Icons.folder_open_rounded,
                    chapters,
                    tempChapter,
                    (val) {
                      setModalState(() {
                        tempChapter = val;
                        tempDiagram = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildModalDropdown(
                    "الرسمة",
                    Icons.image_outlined,
                    filteredDiagrams.map((d) => d['title'] as String).toList(),
                    tempDiagram?['title'],
                    (val) {
                      setModalState(() {
                        tempDiagram = filteredDiagrams.firstWhere((d) => d['title'] == val);
                      });
                    },
                    isEnabled: tempChapter != null,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (tempChapter != null && tempDiagram != null)
                          ? () {
                              setState(() {
                                selectedChapter = tempChapter;
                                selectedDiagram = tempDiagram;
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
              Icon(icon, size: 20, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Text(hint, style: TextStyle(color: Colors.grey[400], fontFamily: 'Tajawal')),
            ],
          ),
          items: isEnabled ? items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontFamily: 'Tajawal')))).toList() : null,
          onChanged: isEnabled ? onChanged : null,
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20),
                ],
              ),
              child: Icon(Icons.image_search_rounded, size: 50, color: primaryColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار الرسمة للعرض",
              style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'),
            ),
          ],
        ),
      );
    }

    final bool isHifth = selectedDiagram!['type'] == 'حفظ';

    return Column(
      children: [
        _buildSectionHeader(selectedChapter!, primaryColor),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedDiagram!['title'],
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'Tajawal'),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isHifth ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isHifth ? Colors.red : Colors.blue, width: 1),
                    ),
                    child: Text(
                      selectedDiagram!['type'],
                      style: TextStyle(
                        color: isHifth ? Colors.red : Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'Tajawal'
                      ),
                    ),
                  ),
                ],
              ),
              if (selectedDiagram!['years'] != null && (selectedDiagram!['years'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  "السنوات الوزارية:",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Tajawal'),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (selectedDiagram!['years'] as List).map((year) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        year.toString(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange, fontFamily: 'Tajawal'),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.white,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 5.0,
              clipBehavior: Clip.none,
              child: Center(
                child: Image.asset(
                  selectedDiagram!['imagePath'],
                  width: MediaQuery.of(context).size.width,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("لم يتم العثور على ملف الصورة", style: TextStyle(color: Colors.grey, fontFamily: 'Tajawal')),
                        Text(selectedDiagram!['imagePath'].split('/').last, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
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
