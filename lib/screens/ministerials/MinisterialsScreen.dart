import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart' as tex;

class MinisterialsScreen extends StatefulWidget {
  final String subjectName;
  final String category;

  const MinisterialsScreen({
    super.key,
    required this.subjectName,
    required this.category,
  });

  @override
  State<MinisterialsScreen> createState() => _MinisterialsScreenState();
}

class _MinisterialsScreenState extends State<MinisterialsScreen> {
  String? selectedChapter;
  String? selectedTopic;
  bool isInitialLoading = true;

  Map<String, dynamic> subjectData = {};
  List<dynamic> filteredQuestions = [];

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  String _getSubjectEnglishName(String label) {
    switch (label) {
      case 'الإسلامية':
        return 'Islamic';
      case 'العربية':
        return 'Arabic';
      case 'الإنكليزي':
        return 'English';
      case 'الأحياء':
        return 'Biology';
      case 'الرياضيات':
        return 'Mathematics';
      case 'الكيمياء':
        return 'Chemistry';
      case 'الفيزياء':
        return 'Physics';
      case 'التاريخ':
        return 'History';
      case 'الجغرافية':
        return 'Geography';
      case 'الاقتصاد':
        return 'Economics';
      case 'الفرنسية':
        return 'French';
      default:
        return label;
    }
  }

  Future<void> initializeData() async {
    final Map<String, List<Map<String, String>>> subjectFiles = {
      'الإسلامية': [
        {
          'cat': 'Preparatory',
          'sub': 'Islamic',
          'file': 'tajweed_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Islamic',
          'file': 'unit1_ministerials.json',
        },
      ],
      'العربية': [
        {'cat': 'Preparatory', 'sub': 'Arabic', 'file': 'rules/istifham_ministerials.json'},
        {'cat': 'Preparatory', 'sub': 'Arabic', 'file': 'rules/nafi_ministerials.json'},
        {'cat': 'Preparatory', 'sub': 'Arabic', 'file': 'rules/takdim_ministerials.json'},
        {'cat': 'Preparatory', 'sub': 'Arabic', 'file': 'rules/tawkid_ministerials.json'},
        {'cat': 'Preparatory', 'sub': 'Arabic', 'file': 'rules/nidaa_ministerials.json'},
        {'cat': 'Preparatory', 'sub': 'Arabic', 'file': 'rules/taajjub_ministerials.json'},
        {'cat': 'Preparatory', 'sub': 'Arabic', 'file': 'rules/madh_thamm_ministerials.json'},
        {'cat': 'Preparatory', 'sub': 'Arabic', 'file': 'literature/literature_ministerials.json'},
        {'cat': 'Preparatory', 'sub': 'Arabic', 'file': 'criticism/criticism_ministerials.json'},
      ],
      'الإنكليزي': [
        {
          'cat': 'Preparatory',
          'sub': 'English',
          'file': 'unit1_ministerials.json',
        },
      ],
    };

    // إضافة النقد إذا كانت المادة عربية والقسم أدبي (أصبح داخل مجلد العربية أيضاً)
    if (widget.subjectName == 'العربية' && widget.category == 'Literary') {
      subjectFiles['العربية']?.add({
        'cat': 'Preparatory',
        'sub': 'Arabic',
        'file': 'criticism/criticism_ministerials.json',
      });
    }

    try {
      if (!mounted) return;
      setState(() {
        subjectData = {};
        isInitialLoading = true;
      });

      List<Map<String, String>> files = [];

      if (subjectFiles.containsKey(widget.subjectName)) {
        files = subjectFiles[widget.subjectName]!;
      } else {
        String engSub = _getSubjectEnglishName(widget.subjectName);
        files = [
          {
            'cat': widget.category,
            'sub': engSub,
            'file': 'chapter1_ministerials.json',
          },
        ];
      }

      for (var fileInfo in files) {
        String path =
            'assets/jsons/Content/${fileInfo['cat']}/${fileInfo['sub']}/Ministerial/${fileInfo['file']}';

        try {
          final String response = await rootBundle.loadString(path);
          final data = json.decode(response);

          String mainCategory = widget.subjectName;
          if (widget.subjectName == 'العربية') {
            if (path.contains('/rules/')) {
              mainCategory = "القواعد";
            } else if (path.contains('/literature/')) {
              mainCategory = "الأدب";
            } else if (path.contains('/criticism/')) {
              mainCategory = "النقد";
            } else {
              mainCategory = "أخرى";
            }
          } else {
            // تسمية القسم بناءً على اسم الملف (فصل أو وحدة)
            String fileName = fileInfo['file']!;
            if (fileName.contains('tajweed')) {
              mainCategory = "أحكام التلاوة";
            } else if (fileName.contains('unit1')) {
              mainCategory = widget.subjectName == 'الإنكليزي' ? "Unit 1" : "الوحدة الأولى";
            } else if (fileName.contains('chapter1')) {
              mainCategory = "الفصل الأول";
            }
          }

          if (!subjectData.containsKey(mainCategory)) {
            subjectData[mainCategory] = {'lessons': []};
          }

          if (data is List) {
            for (var item in data) {
              (subjectData[mainCategory]['lessons'] as List).add({
                'lesson_title':
                    item['subject'] ??
                    item['unit'] ??
                    item['topic'] ??
                    item['title'] ??
                    "بدون عنوان",
                'data': item,
              });
            }
          } else if (data is Map && data.containsKey('lessons') && data['lessons'] is List) {
            // التعامل مع هيكل ملفات الإسلامية التي تحتوي على دروس بداخلها
            for (var subLesson in data['lessons']) {
              (subjectData[mainCategory]['lessons'] as List).add({
                'lesson_title':
                    subLesson['lesson_title'] ??
                    subLesson['title'] ??
                    subLesson['subject'] ??
                    "بدون عنوان",
                'data': subLesson,
              });
            }
          } else {
            (subjectData[mainCategory]['lessons'] as List).add({
              'lesson_title':
                  data['subject'] ??
                  data['unit'] ??
                  data['topic'] ??
                  data['title'] ??
                  "بدون عنوان",
              'data': data,
            });
          }
        } catch (e) {
          debugPrint("Could not load file: $path");
        }
      }

      if (mounted) {
        setState(() {
          isInitialLoading = false;
          // تم إلغاء الاختيار التلقائي بناءً على طلبك
        });
      }
    } catch (e) {
      debugPrint("Error loading assets: $e");
      if (mounted) setState(() => isInitialLoading = false);
    }
  }

  void applyFilter() {
    if (selectedChapter == null) return;

    List<dynamic> questionsList = [];
    final lessons = subjectData[selectedChapter!]['lessons'] as List;

    // دالة مساعدة لاستخراج الأسئلة من كائن بيانات معين
    List<dynamic> getQuestionsFromData(dynamic d, String title) {
      if (d is! Map) return [];
      List<dynamic> qList = [];

      if (d.containsKey('questions')) {
        qList = List.from(d['questions']);
      } else if (d.containsKey('parts')) {
        for (var part in d['parts']) {
          String partName = part['part'] ?? "";
          if (part['questions'] != null) {
            for (var q in part['questions']) {
              Map<String, dynamic> qWithTag = Map<String, dynamic>.from(q);
              qWithTag['section_tag'] = partName;
              qList.add(qWithTag);
            }
          }
        }
      } else if (d.containsKey('extracted_questions')) {
        qList = List.from(d['extracted_questions']);
      } else if (d.containsKey('sections')) {
        for (var section in d['sections']) {
          if (section['questions'] != null) {
            qList.addAll(List.from(section['questions']));
          }
        }
      }

      return qList.map((q) {
        Map<String, dynamic> qWithTopic = Map<String, dynamic>.from(q);
        qWithTopic['topic_header'] = title;
        return qWithTopic;
      }).toList();
    }

    bool isSimpleSubject = ['الرياضيات', 'الإنكليزي', 'الأحياء', 'التاريخ', 'الجغرافية', 'الاقتصاد'].contains(widget.subjectName);

    if (isSimpleSubject || selectedTopic == null || selectedChapter == "أحكام التلاوة") {
      // عرض كافة المواضيع في هذا القسم (تلقائياً للإنكليزي والأحياء، أو إذا لم يتم اختيار موضوع)
      for (var lesson in lessons) {
        final lessonTitle = lesson['lesson_title'];
        final data = lesson['data'];

        if (data is Map && data.containsKey('lessons') && data['lessons'] is List) {
          for (var subLesson in data['lessons']) {
            final subTitle = subLesson['lesson_title'] ?? subLesson['title'] ?? lessonTitle;
            questionsList.addAll(getQuestionsFromData(subLesson, subTitle));
          }
        } else {
          questionsList.addAll(getQuestionsFromData(data, lessonTitle));
        }
      }
    } else {
      // عرض موضوع محدد فقط (للعربية والإسلامية)
      final lesson = lessons.firstWhere((l) => l['lesson_title'] == selectedTopic, orElse: () => lessons.first);
      final data = lesson['data'];

      if (data is Map && data.containsKey('lessons') && data['lessons'] is List) {
        for (var subLesson in data['lessons']) {
          final subTitle = subLesson['lesson_title'] ?? subLesson['title'] ?? selectedTopic!;
          questionsList.addAll(getQuestionsFromData(subLesson, subTitle));
        }
      } else {
        questionsList.addAll(getQuestionsFromData(data, selectedTopic!));
      }
    }

    setState(() => filteredQuestions = questionsList);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          "وزاريات ${widget.subjectName}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: isInitialLoading
                ? null
                : () => showSelectionSheet(context, primaryColor),
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
          : buildQuestionsList(primaryColor, secondaryColor),
    );
  }

  Widget buildQuestionsList(Color primaryColor, Color secondaryColor) {
    if (subjectData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_rounded, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "لا توجد وزاريات متوفرة حالياً لهذه المادة",
              style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (filteredQuestions.isEmpty) {
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.history_edu_rounded,
                size: 50,
                color: primaryColor.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "يرجى اختيار القسم لعرض الوزاريات",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: filteredQuestions.length,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.blueGrey.withOpacity(0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      itemBuilder: (context, index) => buildMinisterialItem(
        filteredQuestions[index],
        index,
        primaryColor,
        secondaryColor,
      ),
    );
  }

  Widget buildMinisterialItem(
    Map<String, dynamic> item,
    int index,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final dynamic rawYears = item['years'];
    final List<dynamic> years = (rawYears is List) ? rawYears : (rawYears != null ? [rawYears] : []);
    final String? tag = item['section_tag'];
    final String? topicHeader = item['topic_header'];
    final bool isHeader = item['isHeader'] ?? false;

    // التحقق إذا كان هذا أول سؤال في موضوع جديد لعرض العنوان
    bool showTopicHeader = false;
    if (topicHeader != null) {
      if (index == 0) {
        showTopicHeader = true;
      } else {
        final prevItem = filteredQuestions[index - 1];
        if (prevItem['topic_header'] != topicHeader) {
          showTopicHeader = true;
        }
      }
    }

    final TextDirection textDir = widget.subjectName == 'الإنكليزي' ? TextDirection.ltr : TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTopicHeader)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            color: primaryColor.withValues(alpha: 0.05),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: secondaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      topicHeader!,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    children: [
                      Icon(Icons.history_edu_rounded, size: 18, color: primaryColor),
                      const SizedBox(width: 10),
                      Text(
                        tag ?? "سؤال وزاري ${index + 1}",
                        style: TextStyle(
                          color: Colors.blueGrey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (years.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: years
                          .map(
                            (year) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: secondaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                year.toString(),
                                style: TextStyle(
                                  color: secondaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
              if (item['verse'] != null && item['verse'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      item['verse'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                        fontFamily: 'Amiri',
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                child: Directionality(
                  textDirection: textDir,
                  child: _buildMathContent(
                    item['question'] ??
                        (item['word'] != null ? "ما معنى كلمة: ${item['word']}" : ""),
                    TextStyle(
                      fontSize: 16,
                      fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
                      height: 1.6,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      "عرض الجواب النموذجي",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                  iconColor: secondaryColor,
                  collapsedIconColor: secondaryColor,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                        ),
                        child: Directionality(
                          textDirection: textDir,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item['answers'] != null)
                                buildTajweedTable(item['answers']),
                              if (item['answer'] != null || item['meaning'] != null)
                                _buildMathContent(
                                  item['answer'] ?? item['meaning'],
                                  const TextStyle(
                                    fontSize: 14,
                                    height: 1.7,
                                    color: Colors.black87,
                                  ),
                                ),
                              if (item['note'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    "• ملاحظة: ${item['note']}",
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (item['extra_answer'] != null) ...[
                                const Divider(height: 25),
                                Text(
                                  item['extra_answer']['definition'] ??
                                      item['extra_answer']['text'] ??
                                      "",
                                  style: const TextStyle(fontSize: 14, height: 1.7),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
            if (tempChapter != null &&
                subjectData[tempChapter] is Map &&
                subjectData[tempChapter].containsKey('lessons')) {
              topics = (subjectData[tempChapter]['lessons'] as List)
                  .map((l) => l['lesson_title'].toString())
                  .toList();
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "اختيار مادة الوزاريات",
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
                  if (tempChapter != null && 
                      topics.isNotEmpty && 
                      !['الرياضيات', 'الإنكليزي', 'الأحياء', 'التاريخ', 'الجغرافية', 'الاقتصاد'].contains(widget.subjectName) &&
                      tempChapter != "أحكام التلاوة") ...[
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
                      onPressed: (tempChapter != null && 
                                 (topics.isEmpty || 
                                  tempTopic != null || 
                                  ['الرياضيات', 'الإنكليزي', 'الأحياء', 'التاريخ', 'الجغرافية', 'الاقتصاد'].contains(widget.subjectName) ||
                                  tempChapter == "أحكام التلاوة"))
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "تأكيد الاختيار",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  Widget buildDropdown(
    String hint,
    IconData icon,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged, {
    bool isEnabled = true,
  }) {
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
                Text(
                  items.isEmpty && isEnabled ? "جاري تحميل الوحدات..." : hint,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
            items: isEnabled && items.isNotEmpty
                ? items
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList()
                : null,
            onChanged: isEnabled ? onChanged : null,
          ),
        ),
      ),
    );
  }

  Widget buildTajweedTable(List<dynamic> answers) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 15,
        headingRowHeight: 35,
        columns: const [
          DataColumn(label: Text("الكلمة")),
          DataColumn(label: Text("الحكم")),
          DataColumn(label: Text("السبب")),
        ],
        rows: answers
            .map(
              (a) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      a['word'] ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  DataCell(Text(a['ruling'] ?? "")),
                  DataCell(
                    Text(
                      a['reason'] ?? "",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMathContent(String text, TextStyle style) {
    // إذا لم تكن المادة هي الرياضيات، نعيد النص بشكل بسيط جداً لضمان عدم تأثر بقية المواد
    if (widget.subjectName != 'الرياضيات') {
      return Text(
        text,
        style: style,
        textAlign: widget.subjectName == 'الإنكليزي' ? TextAlign.left : TextAlign.right,
      );
    }

    // في الرياضيات: السؤال (يبدأ بـ س/) لليمين، والحل (يبدأ بـ sol :) لليسار
    bool isAnswer = text.trim().startsWith('sol :') || text.trim().startsWith('ج/');
    Alignment alignment = isAnswer ? Alignment.centerLeft : Alignment.centerRight;
    TextAlign textAlign = isAnswer ? TextAlign.left : TextAlign.right;

    // منطق الرياضيات المتقدم
    if (!text.contains('\$')) {
      return Container(
        width: double.infinity,
        alignment: alignment,
        child: Text(
          text,
          style: style,
          textAlign: textAlign,
        ),
      );
    }

    List<Widget> contentWidgets = [];
    final parts = text.split('\$');

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // نص عادي
        if (parts[i].trim().isNotEmpty) {
          contentWidgets.add(
            Container(
              width: double.infinity,
              alignment: alignment,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                parts[i],
                style: style,
                textAlign: textAlign,
              ),
            ),
          );
        }
      } else {
        // نص رياضي (LaTeX)
        if (parts[i].isNotEmpty) {
          contentWidgets.add(
            Container(
              width: double.infinity,
              alignment: alignment,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: tex.Math.tex(
                      "\u200E ${parts[i]} \u200E",
                      textStyle: style.copyWith(
                        fontSize: (style.fontSize ?? 14) + 2,
                        fontFamily: 'Tajawal',
                        color: style.color,
                      ),
                      onErrorFallback: (err) => Text(
                        parts[i],
                        style: style.copyWith(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }
}
