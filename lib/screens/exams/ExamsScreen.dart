import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart' as tex;

class ExamsScreen extends StatefulWidget {
  final String subjectName;
  final String category;

  const ExamsScreen({
    super.key,
    required this.subjectName,
    required this.category,
  });

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  static const _navy = Color(0xFF1A2238);
  static const _gold = Color(0xFFF2B833);

  String? selectedChapter;
  String? selectedTopic;
  String? selectedPart;
  bool isInitialLoading = true;
  bool _showSelectionBar = true;

  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isTestComplete = false;

  Map<String, dynamic> subjectData = {};
  List<dynamic> currentQuestions = [];

  List<dynamic> get _currentLessons => selectedChapter == null
      ? const []
      : (subjectData[selectedChapter!]?['lessons'] as List? ?? const []);

  List<String> get _availableParts {
    dynamic lessonData;
    if (selectedTopic != null) {
      for (final lesson in _currentLessons) {
        if (lesson['lesson_title'] == selectedTopic) {
          lessonData = lesson['data'];
          break;
        }
      }
    } else if (_currentLessons.length == 1) {
      lessonData = _currentLessons.first['data'];
    }

    if (lessonData is Map && lessonData['parts'] is List) {
      return (lessonData['parts'] as List)
          .map((part) => part['part']?.toString() ?? '')
          .where((part) => part.isNotEmpty)
          .toList();
    }
    return const [];
  }

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
        {
          'cat': 'Preparatory',
          'sub': 'Arabic',
          'file': 'rules/istifham_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Arabic',
          'file': 'rules/nafi_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Arabic',
          'file': 'rules/takdim_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Arabic',
          'file': 'rules/tawkid_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Arabic',
          'file': 'rules/nidaa_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Arabic',
          'file': 'rules/taajjub_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Arabic',
          'file': 'rules/madh_thamm_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Arabic',
          'file': 'literature/literature_ministerials.json',
        },
      ],
      'الإنكليزي': [
        {
          'cat': 'Preparatory',
          'sub': 'English',
          'file': 'unit1_ministerials.json',
        },
      ],
    };

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

          String categoryName = widget.subjectName;
          if (widget.subjectName == 'العربية') {
            if (path.contains('/rules/'))
              categoryName = "القواعد";
            else if (path.contains('/literature/'))
              categoryName = "الأدب";
            else if (path.contains('/criticism/'))
              categoryName = "النقد";
            else
              categoryName = "أخرى";
          } else {
            // تسمية القسم بناءً على اسم الملف (فصل أو وحدة)
            String fileName = fileInfo['file']!;
            if (fileName.contains('tajweed')) {
              categoryName = "أحكام التلاوة";
            } else if (fileName.contains('unit1')) {
              categoryName = widget.subjectName == 'الإنكليزي'
                  ? "Unit 1"
                  : "الوحدة الأولى";
            } else if (fileName.contains('chapter1')) {
              categoryName = "الفصل الأول";
            }
          }

          if (!subjectData.containsKey(categoryName)) {
            subjectData[categoryName] = {'lessons': []};
          }

          if (data is List) {
            for (var item in data) {
              (subjectData[categoryName]['lessons'] as List).add({
                'lesson_title':
                    item['subject'] ??
                    item['unit'] ??
                    item['topic'] ??
                    item['title'] ??
                    "بدون عنوان",
                'data': item,
              });
            }
          } else if (data is Map &&
              data.containsKey('lessons') &&
              data['lessons'] is List) {
            for (var subLesson in data['lessons']) {
              (subjectData[categoryName]['lessons'] as List).add({
                'lesson_title':
                    subLesson['lesson_title'] ??
                    subLesson['title'] ??
                    subLesson['subject'] ??
                    "بدون عنوان",
                'data': subLesson,
              });
            }
          } else {
            (subjectData[categoryName]['lessons'] as List).add({
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

      if (mounted) setState(() => isInitialLoading = false);
    } catch (e) {
      debugPrint("Error loading assets: $e");
      if (mounted) setState(() => isInitialLoading = false);
    }
  }

  void applyFilter() {
    if (selectedChapter == null) return;

    List<dynamic> questionsList = [];
    final lessons = subjectData[selectedChapter!]['lessons'] as List;

    // دالة مساعدة لاستخراج الأسئلة
    List<dynamic> extractQuestions(dynamic d) {
      if (d is! Map) return [];
      List<dynamic> list = [];
      if (d.containsKey('questions')) {
        list = List.from(d['questions']);
      } else if (d.containsKey('parts')) {
        for (var part in d['parts']) {
          if (selectedPart != null && part['part'] != selectedPart) continue;
          if (part['questions'] != null) {
            for (var q in part['questions']) {
              Map<String, dynamic> qWithTag = Map<String, dynamic>.from(q);
              qWithTag['section_tag'] = part['part'] ?? "";
              list.add(qWithTag);
            }
          }
        }
      } else if (d.containsKey('extracted_questions')) {
        list = List.from(d['extracted_questions']);
      } else if (d.containsKey('sections')) {
        for (var section in d['sections']) {
          if (section['questions'] != null) {
            list.addAll(List.from(section['questions']));
          }
        }
      }
      return list;
    }

    final selectedLessons = selectedTopic == null
        ? lessons
        : lessons
              .where((lesson) => lesson['lesson_title'] == selectedTopic)
              .toList();
    for (final lesson in selectedLessons) {
      final data = lesson['data'];
      if (data is Map && data['lessons'] is List) {
        for (final subLesson in data['lessons']) {
          questionsList.addAll(extractQuestions(subLesson));
        }
      } else {
        questionsList.addAll(extractQuestions(data));
      }
    }

    // خلط الأسئلة واختيار 10
    questionsList.shuffle();
    if (questionsList.length > 10) {
      questionsList = questionsList.take(10).toList();
    }

    setState(() {
      currentQuestions = questionsList;
      _currentIndex = 0;
      _showAnswer = false;
      _isTestComplete = false;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'اختبارات ${widget.subjectName}',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: _navy,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _navy,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        actions: [
          IconButton(
            tooltip: _showSelectionBar
                ? 'إخفاء الاختيارات'
                : 'إظهار الاختيارات',
            onPressed: () =>
                setState(() => _showSelectionBar = !_showSelectionBar),
            icon: Icon(
              _showSelectionBar
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.tune_rounded,
              color: _navy,
            ),
          ),
        ],
      ),
      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _showSelectionBar
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildChapterSelector(),
                            _buildSubsectionSelectors(),
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
                Expanded(
                  child: buildQuestionsList(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildChapterSelector() {
    final chapters = subjectData.keys.toList();
    if (chapters.isEmpty) return const SizedBox.shrink();

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
      child: SizedBox(
        height: 62,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            itemCount: chapters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              final selected = selectedChapter == chapter;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: selected ? _navy : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? _navy : const Color(0xFFE5E8EF),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _navy.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      selectedChapter = chapter;
                      selectedTopic = null;
                      selectedPart = null;
                    });
                    applyFilter();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(
                            Icons.check_rounded,
                            color: _gold,
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          chapter,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: selected ? Colors.white : _navy,
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

  Widget _buildSubsectionSelectors() {
    final lessons = _currentLessons;
    if (selectedChapter == null || lessons.isEmpty) {
      return const SizedBox.shrink();
    }

    final lessonTitles = lessons
        .map((lesson) => lesson['lesson_title'].toString())
        .toList();
    final showLessons = lessonTitles.length > 1;
    final parts = _availableParts;
    if (!showLessons && parts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLessons)
            _buildOptionStrip(
              title: 'الدروس',
              options: lessonTitles,
              selected: selectedTopic,
              onSelected: (value) {
                setState(() {
                  selectedTopic = value;
                  selectedPart = null;
                });
                applyFilter();
              },
            ),
          if (parts.isNotEmpty)
            _buildOptionStrip(
              title: 'الأجزاء',
              options: parts,
              selected: selectedPart,
              onSelected: (value) {
                setState(() => selectedPart = value);
                applyFilter();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOptionStrip({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          if (title != 'الدروس')
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
              child: Text(
                '$title:',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: Color(0xFF7B8495),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.only(start: 19, end: 12),
                children: [
                  _buildOptionChip(
                    title == 'الدروس' ? 'كل الدروس' : 'كل الأجزاء',
                    selected == null,
                    () => onSelected(null),
                  ),
                  ...options.map(
                    (option) => _buildOptionChip(
                      option,
                      selected == option,
                      () => onSelected(option),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 7),
      child: Material(
        color: selected ? _navy : const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: selected ? Colors.white : _navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildQuestionsList(Color primaryColor) {
    if (selectedChapter == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                size: 42,
                color: _navy,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "اختر الفصل للبدء",
              style: TextStyle(
                color: _navy,
                fontFamily: 'Tajawal',
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "اختر فصلاً من الشريط أعلاه لعرض الأسئلة والاختبارات",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7B8495),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    if (currentQuestions.isEmpty) {
      return const Center(
        child: Text("لا توجد أسئلة متاحة في هذا الفصل حالياً"),
      );
    }

    if (_isTestComplete) {
      return _buildCompletionScreen(primaryColor);
    }

    return Column(
      children: [
        // عرض الأسئلة (PageView)
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
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
                    final String questionText =
                        item['question'] ??
                        (item['word'] != null
                            ? "ما معنى كلمة: ${item['word']}"
                            : "");
                    final String answerText =
                        item['answer'] ??
                        item['meaning'] ??
                        "لا يوجد جواب متاح";
                    final TextDirection textDir =
                        widget.subjectName == 'الإنكليزي'
                        ? TextDirection.ltr
                        : TextDirection.rtl;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 86, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item['verse'] != null &&
                              item['verse'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.1),
                                  ),
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _navy.withValues(alpha: 0.055),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "السؤال",
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    color: _navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Directionality(
                                  textDirection: textDir,
                                  child: Container(
                                    width: double.infinity,
                                    alignment: textDir == TextDirection.ltr
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight,
                                    child: _buildMathContent(
                                      questionText,
                                      const TextStyle(
                                        fontSize: 18,
                                        height: 1.9,
                                        color: Color(0xFF334155),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_showAnswer) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F8F3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFDCEFE1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF318458),
                                        size: 19,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "الإجابة النموذجية",
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          color: Color(0xFF28734A),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Directionality(
                                    textDirection: textDir,
                                    child: Container(
                                      width: double.infinity,
                                      alignment: textDir == TextDirection.ltr
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                      child: Column(
                                        crossAxisAlignment:
                                            textDir == TextDirection.ltr
                                            ? CrossAxisAlignment.start
                                            : CrossAxisAlignment.end,
                                        children: [
                                          if (item['answers'] != null)
                                            buildTajweedTable(item['answers']),
                                          if (item['answers'] == null)
                                            _buildMathContent(
                                              answerText,
                                              const TextStyle(
                                                fontSize: 16,
                                                height: 1.9,
                                                color: Color(0xFF3F5E4C),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (item['note'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 15),
                                      child: Text(
                                        "ملاحظة: ${item['note']}",
                                        style: const TextStyle(
                                          color: Color(0xFFB45309),
                                          fontSize: 13,
                                          height: 1.6,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (item['extra_answer'] != null) ...[
                                    const Divider(height: 32),
                                    Directionality(
                                      textDirection: textDir,
                                      child: Container(
                                        width: double.infinity,
                                        alignment: textDir == TextDirection.ltr
                                            ? Alignment.centerLeft
                                            : Alignment.centerRight,
                                        child: Text(
                                          item['extra_answer']['definition'] ??
                                              item['extra_answer']['text'] ??
                                              "",
                                          textAlign:
                                              textDir == TextDirection.ltr
                                              ? TextAlign.left
                                              : TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.8,
                                            color: Color(0xFF3F5E4C),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: _buildFloatingProgress(primaryColor),
              ),
            ],
          ),
        ),

        // أزرار التحكم في الأسفل
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      setState(() => _isTestComplete = true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    !_showAnswer
                        ? "عرض الجواب"
                        : (_currentIndex < currentQuestions.length - 1
                              ? "السؤال التالي"
                              : "إنهاء الاختبار"),
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

  Widget _buildFloatingProgress(Color color) {
    final progress = (_currentIndex + 1) / currentQuestions.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: 0.5,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'السؤال ${_currentIndex + 1} من ${currentQuestions.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}٪',
                style: const TextStyle(
                  color: Color(0xFF7B8495),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE9ECF2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(Color primaryColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7DF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.celebration_rounded,
                color: _gold,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'أحسنت! أكملت الاختبار',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: _navy,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'أنهيت الإجابة عن ${currentQuestions.length} ${currentQuestions.length == 1 ? 'سؤال' : 'أسئلة'}، يمكنك إعادة الاختبار ومراجعة الأسئلة مرة أخرى.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF737B8C),
                fontSize: 15,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isTestComplete = false;
                    _currentIndex = 0;
                    _showAnswer = false;
                    currentQuestions.shuffle();
                  });
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(0);
                  }
                },
                icon: const Icon(Icons.replay_rounded),
                label: const Text('أعد الاختبار'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
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
                subjectData[tempChapter] != null &&
                subjectData[tempChapter]!.containsKey('lessons')) {
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
                  if (tempChapter != null &&
                      topics.isNotEmpty &&
                      ![
                        'الرياضيات',
                        'الإنكليزي',
                        'الأحياء',
                        'التاريخ',
                        'الجغرافية',
                        'الاقتصاد',
                      ].contains(widget.subjectName) &&
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
                      onPressed:
                          (tempChapter != null &&
                              (topics.isEmpty ||
                                  tempTopic != null ||
                                  [
                                    'الرياضيات',
                                    'الإنكليزي',
                                    'الأحياء',
                                    'التاريخ',
                                    'الجغرافية',
                                    'الاقتصاد',
                                  ].contains(widget.subjectName) ||
                                  tempChapter == "أحكام التلاوة"))
                          ? () {
                              setState(() {
                                selectedChapter = tempChapter;
                                selectedTopic = tempTopic;
                                selectedPart = null;
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
        textAlign: widget.subjectName == 'الإنكليزي'
            ? TextAlign.left
            : TextAlign.right,
      );
    }

    // في الرياضيات: السؤال (يبدأ بـ س/) لليمين، والحل (يبدأ بـ sol :) لليسار
    bool isAnswer =
        text.trim().startsWith('sol :') || text.trim().startsWith('ج/');
    Alignment alignment = isAnswer
        ? Alignment.centerLeft
        : Alignment.centerRight;
    TextAlign textAlign = isAnswer ? TextAlign.left : TextAlign.right;

    // منطق الرياضيات المتقدم
    if (!text.contains('\$')) {
      return Container(
        width: double.infinity,
        alignment: alignment,
        child: Text(text, style: style, textAlign: textAlign),
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
              child: Text(parts[i], style: style, textAlign: textAlign),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
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
