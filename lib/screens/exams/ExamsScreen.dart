import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamsScreen extends StatefulWidget {
  final String subjectName;
  const ExamsScreen({super.key, required this.subjectName});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  String? selectedChapter;
  String? selectedTopic;
  bool isInitialLoading = true;

  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _showAnswer = false;

  Map<String, dynamic> subjectData = {};
  List<dynamic> currentQuestions = [];

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    try {
      if (!mounted) return;
      setState(() {
        subjectData = {}; // تصفير البيانات لضمان النظافة
        isInitialLoading = true;
      });

      String dbSubject = 'islamic';
      final String sName = widget.subjectName;
      if (sName.contains('عرب')) dbSubject = 'arabic';
      if (sName.contains('نكليز')) dbSubject = 'english';

      // جلب كافة البيانات الخاصة بهذا القسم من السيرفر
      final response = await Supabase.instance.client
          .from('app_contents')
          .select('title, data')
          .eq('subject', dbSubject)
          .eq('type', 'ministerials');

      final Set<String> addedTitles = {};

      for (var item in response) {
        if (item['data'] == null) continue;
        final data = item['data'] as Map<String, dynamic>;
        String chapterTitle = item['title']?.toString().trim() ?? "قسم غير مسمى";
        
        if (dbSubject == 'arabic') {
          // تصنيف تلقائي ذكي بناءً على العنوان اليدوي
          bool isLiterature = chapterTitle.contains('الوحدة') || chapterTitle.contains('وحدة');
          String category = isLiterature ? "الأدب" : "القواعد";
          
          if (!subjectData.containsKey(category)) {
            subjectData[category] = {'lessons': []};
          }
          
          List lessonsList = subjectData[category]['lessons'];

          // إضافة الوحدة أو موضوع القواعد كخيار واحد فقط بدون تفكيك
          if (!addedTitles.contains(chapterTitle)) {
            lessonsList.add({'lesson_title': chapterTitle, 'data': data});
            addedTitles.add(chapterTitle);
          }
        } else if (dbSubject == 'english') {
          // هيكلية الإنكليزي (وحدات مدمجة أو منفصلة)
          final List<dynamic> units = data['units'] ?? [];
          if (units.isNotEmpty) {
            for (var unit in units) {
              String unitTitle = unit['title'] ?? chapterTitle;
              if (!addedTitles.contains(unitTitle)) {
                subjectData[unitTitle] = {'unit': unitTitle, 'questions': unit['essays']};
                addedTitles.add(unitTitle);
              }
            }
          } else {
            if (!addedTitles.contains(chapterTitle)) {
              subjectData[chapterTitle] = data;
              addedTitles.add(chapterTitle);
            }
          }
        } else {
          if (!addedTitles.contains(chapterTitle)) {
            subjectData[chapterTitle] = data;
            addedTitles.add(chapterTitle);
          }
        }
      }
      if (mounted) setState(() => isInitialLoading = false);
    } catch (e) {
      debugPrint("Error initializing data: $e");
      if (mounted) setState(() => isInitialLoading = false);
    }
  }

  void applyFilter() {
    if (selectedChapter == null) return;

    final chapterData = subjectData[selectedChapter];
    List<dynamic> questionsList = [];

    if (chapterData.containsKey('questions')) {
      questionsList = List.from(chapterData['questions']);
    } else if (chapterData.containsKey('lessons')) {
      final lessons = chapterData['lessons'] as List;
      final lesson = lessons.firstWhere((l) => l['lesson_title'] == selectedTopic, orElse: () => null);

      if (lesson != null) {
        if (widget.subjectName == 'العربية') {
          final data = lesson['data'];
          if (data.containsKey('extracted_questions')) {
            questionsList.addAll(List.from(data['extracted_questions']));
          } else if (data.containsKey('parts')) {
            for (var part in data['parts']) {
              if (part['questions'] != null) {
                questionsList.addAll(List.from(part['questions']));
              }
            }
          } else if (data.containsKey('questions')) {
            questionsList.addAll(List.from(data['questions']));
          }
        } else {
          if (lesson['sections'] != null) {
            for (var section in lesson['sections']) {
              if (section['questions'] != null) {
                questionsList.addAll(List.from(section['questions']));
              }
              if (section['discussion_questions'] != null) {
                questionsList.addAll(List.from(section['discussion_questions']));
              }
              if (section['story_groups'] != null) {
                for (var group in section['story_groups']) {
                  if (group['questions'] != null) {
                    questionsList.addAll(List.from(group['questions']));
                  }
                  if (group['discussion_questions'] != null) {
                    questionsList.addAll(List.from(group['discussion_questions']));
                  }
                }
              }
            }
          }
        }
      }
    }

    // خلط الأسئلة عشوائياً واختيار 10 فقط
    questionsList.shuffle();
    if (questionsList.length > 10) {
      questionsList = questionsList.take(10).toList();
    }

    setState(() {
      currentQuestions = questionsList;
      _currentIndex = 0;
      _showAnswer = false;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
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
        title: Text("اختبار ${widget.subjectName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            onPressed: isInitialLoading ? null : () => showSelectionSheet(context, primaryColor),
          ),
        ],
      ),
      body: isInitialLoading 
          ? Center(
              child: SizedBox(
                width: 40, 
                height: 40, 
                child: CircularProgressIndicator(strokeWidth: 3, color: primaryColor)
              ),
            )
          : buildQuestionsList(primaryColor),
    );
  }

  void showSelectionSheet(BuildContext context, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        String? tempChapter = selectedChapter;
        String? tempTopic = selectedTopic;

        return StatefulBuilder(
          builder: (context, setModalState) {
            List<String> chapters = subjectData.keys.toList();
            List<String> topics = [];
            if (tempChapter != null && subjectData[tempChapter] != null && subjectData[tempChapter]!.containsKey('lessons')) {
              topics = (subjectData[tempChapter]['lessons'] as List).map((l) => l['lesson_title'].toString()).toList();
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "اختيار مادة الاختبار",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  buildDropdown(
                    "الوحدة / القسم",
                    Icons.folder_open_rounded,
                    chapters,
                    tempChapter,
                    (val) {
                      setModalState(() {
                        tempChapter = val;
                        tempTopic = null;
                      });
                    },
                  ),
                  if (topics.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    buildDropdown(
                      "الموضوع",
                      Icons.topic_outlined,
                      topics,
                      tempTopic,
                      (val) {
                        setModalState(() => tempTopic = val);
                      },
                      isEnabled: tempChapter != null,
                    ),
                  ],
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (tempChapter != null && (topics.isEmpty || tempTopic != null))
                          ? () {
                              setState(() {
                                selectedChapter = tempChapter;
                                selectedTopic = tempTopic;
                              });
                              Navigator.pop(context);
                              applyFilter();
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

  Widget buildDropdown(String hint, IconData icon, List<String> items, String? value, ValueChanged<String?> onChanged, {bool isEnabled = true}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.grey[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: (value != null && items.contains(value)) ? value : null,
            hint: Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Text(items.isEmpty && isEnabled ? "جاري تحميل الوحدات..." : hint, 
                     style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              ],
            ),
            items: isEnabled && items.isNotEmpty
                ? items.map((item) => DropdownMenuItem(
                    value: item, 
                    child: Text(item, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))
                  )).toList()
                : null,
            onChanged: isEnabled ? onChanged : null,
          ),
        ),
      ),
    );
  }

  Widget buildQuestionsList(Color primaryColor) {
    if (currentQuestions.isEmpty) {
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
              child: Icon(Icons.assignment_outlined, size: 50, color: primaryColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار المادة لبدء الاختبار",
              style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // شريط التقدم
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "السؤال ${_currentIndex + 1} من ${currentQuestions.length}",
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    "${((_currentIndex + 1) / currentQuestions.length * 100).toInt()}%",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / currentQuestions.length,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
            ],
          ),
        ),

        // عرض الأسئلة (PageView)
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _showAnswer = false;
              });
            },
            itemCount: currentQuestions.length,
            itemBuilder: (context, index) {
              final item = currentQuestions[index];
              final String questionText = item['question'] ?? (item['word'] != null ? "ما معنى كلمة: ${item['word']}" : "");
              final String answerText = item['answer'] ?? item['meaning'] ?? "لا يوجد جواب متاح";

              return SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item['verse'] != null && item['verse'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Container(
                          width: double.infinity, padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            item['verse'], textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF15803D), fontFamily: 'Amiri', height: 1.8),
                          ),
                        ),
                      ),
                    Text(
                      questionText,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.8,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_showAnswer) ...[
                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 20),
                      const Text(
                        "الإجابة النموذجية:",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (item['answers'] != null) buildTajweedTable(item['answers']),
                      if (item['answers'] == null)
                        Text(
                          answerText,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      if (item['note'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text("• ملاحظة: ${item['note']}", style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      if (item['extra_answer'] != null) ...[
                        const Divider(height: 35),
                        Text(item['extra_answer']['definition'] ?? item['extra_answer']['text'] ?? "", style: const TextStyle(fontSize: 15, height: 1.7)),
                      ]
                    ],
                  ],
                ),
              );
            },
          ),
        ),

        // أزرار التحكم في الأسفل
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
            ],
          ),
          child: Row(
            children: [
              if (_currentIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("السابق"),
                  ),
                ),
              if (_currentIndex > 0) const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_showAnswer) {
                      setState(() => _showAnswer = true);
                    } else if (_currentIndex < currentQuestions.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    !_showAnswer 
                        ? "عرض الجواب" 
                        : (_currentIndex < currentQuestions.length - 1 ? "السؤال التالي" : "إنهاء الاختبار"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildTajweedTable(List<dynamic> answers) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 15, headingRowHeight: 35,
        columns: const [DataColumn(label: Text("الكلمة")), DataColumn(label: Text("الحكم")), DataColumn(label: Text("السبب"))],
        rows: answers.map((a) => DataRow(cells: [
          DataCell(Text(a['word']??"", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
          DataCell(Text(a['ruling']??"")),
          DataCell(Text(a['reason']??"", style: const TextStyle(fontSize: 11))),
        ])).toList(),
      ),
    );
  }
}
