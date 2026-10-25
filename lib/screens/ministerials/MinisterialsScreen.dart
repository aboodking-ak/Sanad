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
  static const _navy = Color(0xFF1A2238);
  static const _gold = Color(0xFFF2B833);

  String? selectedChapter;
  String? selectedTopic;
  String? selectedPart;
  bool _showSelectionBar = true;
  bool isInitialLoading = true;
  int _currentQuestionIndex = 0;
  final TextEditingController _questionInputController = TextEditingController(
    text: '1',
  );

  Map<String, dynamic> subjectData = {};
  List<dynamic> filteredQuestions = [];

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

  double get _selectionPanelHeight {
    if (!_showSelectionBar || subjectData.isEmpty) return 0;
    final selectorRows =
        (_currentLessons.length > 1 ? 1 : 0) +
        (_availableParts.isNotEmpty ? 1 : 0);
    return 62 + (selectorRows > 0 ? 8 : 0) + selectorRows * 45;
  }

  @override
  void dispose() {
    _questionInputController.dispose();
    super.dispose();
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
        {
          'cat': 'Preparatory',
          'sub': 'Islamic',
          'file': 'unit2_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Islamic',
          'file': 'unit3_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Islamic',
          'file': 'unit4_ministerials.json',
        },
        {
          'cat': 'Preparatory',
          'sub': 'Islamic',
          'file': 'unit5_ministerials.json',
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
            } else if (fileName.contains('unit5')) {
              mainCategory = "الوحدة الخامسة";
            } else if (fileName.contains('unit4')) {
              mainCategory = "الوحدة الرابعة";
            } else if (fileName.contains('unit3')) {
              mainCategory = "الوحدة الثالثة";
            } else if (fileName.contains('unit2')) {
              mainCategory = "الوحدة الثانية";
            } else if (fileName.contains('unit1')) {
              mainCategory = widget.subjectName == 'الإنكليزي'
                  ? "Unit 1"
                  : "الوحدة الأولى";
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
          } else if (data is Map &&
              data.containsKey('lessons') &&
              data['lessons'] is List) {
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
          if (selectedPart != null && partName != selectedPart) continue;
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

    final selectedLessons = selectedTopic == null
        ? lessons
        : lessons
              .where((lesson) => lesson['lesson_title'] == selectedTopic)
              .toList();

    for (final lesson in selectedLessons) {
      final lessonTitle = lesson['lesson_title'];
      final data = lesson['data'];
      if (data is Map && data['lessons'] is List) {
        for (final subLesson in data['lessons']) {
          final subTitle =
              subLesson['lesson_title'] ?? subLesson['title'] ?? lessonTitle;
          questionsList.addAll(getQuestionsFromData(subLesson, subTitle));
        }
      } else {
        questionsList.addAll(getQuestionsFromData(data, lessonTitle));
      }
    }

    setState(() {
      filteredQuestions = questionsList;
      _currentQuestionIndex = 0;
      _questionInputController.text = '1';
    });
  }

  void _changeQuestion(int delta) {
    final nextIndex = _currentQuestionIndex + delta;
    if (nextIndex < 0 || nextIndex >= filteredQuestions.length) return;
    setState(() {
      _currentQuestionIndex = nextIndex;
      _questionInputController.text = '${nextIndex + 1}';
    });
  }

  void _goToQuestionFromInput(String value) {
    final requested = int.tryParse(value);
    if (requested == null || filteredQuestions.isEmpty) {
      _questionInputController.text = '${_currentQuestionIndex + 1}';
      return;
    }
    final nextIndex = (requested - 1)
        .clamp(0, filteredQuestions.length - 1)
        .toInt();
    FocusScope.of(context).unfocus();
    setState(() {
      _currentQuestionIndex = nextIndex;
      _questionInputController.text = '${nextIndex + 1}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _navy,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Text(
          'وزاريات ${widget.subjectName}',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: _navy,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
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
          : Stack(
              children: [
                Positioned.fill(
                  top: _selectionPanelHeight,
                  child: ClipRect(child: buildQuestionsList()),
                ),
                // Paint the selector after the scrolling content so its shadow
                // remains visible above the question as it reaches the top.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildSelectionPanel(),
                ),
              ],
            ),
    );
  }

  Widget _buildChapterSelector() {
    final chapters = subjectData.keys.toList();
    if (chapters.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.13),
            blurRadius: 22,
            spreadRadius: 0,
            offset: const Offset(0, 8),
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

  Widget _buildSelectionPanel() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _showSelectionBar
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.1),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChapterSelector(),
                  _buildSubsectionSelectors(),
                ],
              ),
            )
          : const SizedBox.shrink(),
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
    final parts = _availableParts;
    if (lessonTitles.length < 2 && parts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lessonTitles.length > 1)
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

  Widget buildQuestionsList() {
    if (subjectData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_rounded, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "لا توجد وزاريات متوفرة حالياً لهذه المادة",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

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
              "اختر فصلاً من الشريط أعلاه لعرض الأسئلة الوزارية",
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

    if (filteredQuestions.isEmpty) {
      return const Center(
        child: Text("لا توجد أسئلة متاحة في هذا الفصل حالياً"),
      );
    }

    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              fit: StackFit.expand,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: SingleChildScrollView(
              key: ValueKey(_currentQuestionIndex),
              primary: false,
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: buildMinisterialItem(
                filteredQuestions[_currentQuestionIndex],
                _currentQuestionIndex,
              ),
            ),
          ),
        ),
        _buildQuestionNavigation(),
      ],
    );
  }

  Widget _buildQuestionNavigation() {
    final total = filteredQuestions.length;
    final hasPrevious = _currentQuestionIndex > 0;
    final hasNext = _currentQuestionIndex < total - 1;

    return SafeArea(
      top: false,
      child: Container(
        height: 50,
        margin: const EdgeInsets.fromLTRB(18, 2, 18, 8),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _navy.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'السؤال السابق',
              onPressed: hasPrevious ? () => _changeQuestion(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: _navy,
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 36),
                maximumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            SizedBox(
              width: 112,
              height: 32,
              child: TextField(
                controller: _questionInputController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.go,
                onSubmitted: _goToQuestionFromInput,
                decoration: InputDecoration(
                  hintText: 'رقم السؤال',
                  suffixText: '/ $total',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _gold, width: 1.5),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'السؤال التالي',
              onPressed: hasNext ? () => _changeQuestion(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
              color: _navy,
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 36),
                maximumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMinisterialItem(Map<String, dynamic> item, int index) {
    final dynamic rawYears = item['years'];
    final List<dynamic> years = (rawYears is List)
        ? rawYears
        : (rawYears != null ? [rawYears] : []);
    final String? tag = item['section_tag'];
    final bool isHeader = item['isHeader'] ?? false;

    final TextDirection textDir = widget.subjectName == 'الإنكليزي'
        ? TextDirection.ltr
        : TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.zero,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_edu_rounded,
                        size: 17,
                        color: _navy,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          tag ?? "سؤال وزاري ${index + 1}",
                          style: const TextStyle(
                            color: _navy,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (years.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.zero,
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
                                color: _gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                year.toString(),
                                style: TextStyle(
                                  color: const Color(0xFF8A6200),
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
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F8F3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD7E8D9)),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 17,
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'السؤال',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: _navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Directionality(
                textDirection: textDir,
                child: _buildMathContent(
                  item['question'] ??
                      (item['word'] != null
                          ? "ما معنى كلمة: ${item['word']}"
                          : ""),
                  TextStyle(
                    fontSize: 16,
                    fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
                    height: 1.8,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const Divider(height: 28, color: Color(0xFFE9ECF1)),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 17,
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: _gold,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'الإجابة النموذجية',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: _navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Directionality(
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
                          fontSize: 15,
                          height: 1.85,
                          color: Color(0xFF334155),
                        ),
                      ),
                    if (item['note'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          "ملاحظة: ${item['note']}",
                          style: const TextStyle(
                            color: Color(0xFF8A6200),
                            fontSize: 13,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (item['extra_answer'] != null) ...[
                      const Divider(height: 28, color: Color(0xFFE9ECF1)),
                      Text(
                        item['extra_answer']['definition'] ??
                            item['extra_answer']['text'] ??
                            "",
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.8,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
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
