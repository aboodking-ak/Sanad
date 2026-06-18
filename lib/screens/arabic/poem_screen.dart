import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PoemScreen extends StatefulWidget {
  const PoemScreen({super.key});

  @override
  State<PoemScreen> createState() => _PoemScreenState();
}

class _PoemScreenState extends State<PoemScreen> {
  List<dynamic> allPoems = [];
  Map<String, dynamic>? selectedPoemData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoemsData();
  }

  Future<void> _loadPoemsData() async {
    try {
      final String response = await rootBundle.loadString('assets/jsons/arabic/literature/poems.json');
      final data = json.decode(response);
      setState(() {
        allPoems = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading poems: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    const backgroundColor = Color(0xFFF8FAFC);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text("قصائد الأدب", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          backgroundColor: primaryColor,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              onPressed: isLoading ? null : () => _showSelectionBottomSheet(context, primaryColor),
            ),
          ],
        ),
        body: isLoading 
            ? Center(child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: primaryColor)))
            : _buildPoemContent(primaryColor),
      ),
    );
  }

  void _showSelectionBottomSheet(BuildContext context, Color primaryColor) {
    Map<String, dynamic>? localSelectedPoem = selectedPoemData;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "اختيار القصيدة",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildModalDropdown(
                    "القصيدة",
                    Icons.auto_stories_rounded,
                    allPoems.map((p) => p['poem_name'].toString()).toList(),
                    localSelectedPoem?['poem_name'],
                    (val) {
                      final poem = allPoems.firstWhere((p) => p['poem_name'] == val);
                      setModalState(() => localSelectedPoem = poem);
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (localSelectedPoem != null)
                          ? () {
                              setState(() => selectedPoemData = localSelectedPoem);
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("تأكيد الاختيار", style: TextStyle(fontWeight: FontWeight.bold)),
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
              Text(hint, style: TextStyle(color: Colors.grey[400])),
            ],
          ),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPoemContent(Color primaryColor) {
    if (selectedPoemData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار قصيدة للعرض",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPoemHeader(primaryColor),
          const SizedBox(height: 25),
          _buildPoetInfoCard(primaryColor),
          const SizedBox(height: 30),
          _buildVersesSection(primaryColor),
          if (selectedPoemData!['meanings'] != null && (selectedPoemData!['meanings'] as List).isNotEmpty) ...[
            const SizedBox(height: 40),
            _buildMeaningsSection(primaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildPoemHeader(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: primaryColor.withAlpha(50), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Text(
            selectedPoemData!['poem_name'],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "للشاعر: ${selectedPoemData!['poet_name']}",
              style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoetInfoCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.person_pin_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 10),
              const Text("عن الشاعر", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          _buildInfoRow(Icons.cake_rounded, "الولادة", "${selectedPoemData!['birth_date']} - ${selectedPoemData!['birth_place']}"),
          const Divider(height: 20),
          _buildInfoRow(Icons.event_busy_rounded, "الوفاة", "${selectedPoemData!['death_date'] ?? 'غير محدد'} - ${selectedPoemData!['death_place'] ?? 'غير محدد'}"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildVersesSection(Color primaryColor) {
    final List verses = selectedPoemData!['verses'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("أبيات القصيدة", primaryColor),
        const SizedBox(height: 20),
        ...verses.map((v) => _buildVerseItem(v['sadr'] ?? "", v['ajuz'] ?? "", primaryColor)),
      ],
    );
  }

  Widget _buildVerseItem(String sadr, String ajuz, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(sadr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(ajuz, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeaningsSection(Color primaryColor) {
    final List meanings = selectedPoemData!['meanings'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("معاني الكلمات", primaryColor),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: List.generate(meanings.length, (index) {
              final m = meanings[index];
              return _buildMeaningRow(m['word'] ?? "", m['meaning'] ?? "", index % 2 == 0);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMeaningRow(String word, String meaning, bool isGray) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        color: isGray ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(child: Text(word, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
          const Icon(Icons.arrow_left_rounded, size: 24, color: Colors.grey),
          const SizedBox(width: 15),
          Expanded(child: Text(meaning, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color primaryColor) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
