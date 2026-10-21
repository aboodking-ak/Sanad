import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TajweedRulesScreen extends StatelessWidget {
  const TajweedRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "أحكام التلاوة",
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2238),
              fontSize: 19,
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
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(primaryColor, secondaryColor),
              const SizedBox(height: 25),
              _buildDefinitionSection(primaryColor),
              const SizedBox(height: 25),
              _buildComparisonTable(primaryColor),
              const SizedBox(height: 30),
              _buildRuleSection(
                title: "أولاً: حكم الإظهار",
                definition:
                    "وهو أن تخرج النون الساكنة أو التنوين من مخرجها من غير غنة فيقرعه اللسان إذا جاء بعدهما أحد حروف الحلق الستة (ء - هـ - ح - خ - ع - غ) والمجموعة في أوائل كلمات: (أخي هاك علماً حازه غير خاسر). ويقع الإظهار في كلمة أو كلمتين.",
                extraContent: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildSubRuleBox(
                      "علامة الإظهار:",
                      "رأس خاء (حـ) صغيرة فوق النون مثل: عَنْهُمْ، أَنْعَمْتَ",
                      primaryColor,
                    ),
                  ],
                ),
                examples: [
                  {
                    'word': 'أَنْ أَتَاكُم',
                    'rule': 'إظهار',
                    'reason': 'جاء بعد النون الساكنة حرف الإظهار (أ)',
                  },
                  {
                    'word': 'بَيَاتاً أَوْ',
                    'rule': 'إظهار',
                    'reason': 'جاء بعد التنوين حرف الإظهار (أ)',
                  },
                  {
                    'word': 'مِنْ هَادٍ',
                    'rule': 'إظهار',
                    'reason': 'جاء بعد النون الساكنة حرف الإظهار (هـ)',
                  },
                ],
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
              ),
              const SizedBox(height: 25),
              _buildRuleSection(
                title: "ثانياً: حكم الإقلاب",
                definition:
                    "هو قلب النون الساكنة أو التنوين ميماً مخفاة مع الغنة إذا جاء بعدها حرف الباء ويقع في كلمة واحدة أو كلمتين.",
                extraContent: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildSubRuleBox(
                      "علامة الإقلاب:",
                      "وضع حرف ميم (م) فوق النون أو بدلاً من الحركة الثانية في التنوين",
                      primaryColor,
                    ),
                  ],
                ),
                examples: [
                  {
                    'word': 'أَنبِيَاء',
                    'rule': 'إقلاب',
                    'reason': 'جاء بعد النون الساكنة حرف الباء',
                  },
                  {
                    'word': 'مِن بَعْدِ',
                    'rule': 'إقلاب',
                    'reason': 'جاء بعد النون الساكنة حرف الباء',
                  },
                  {
                    'word': 'سَمِيعٌ بَصِيرٌ',
                    'rule': 'إقلاب',
                    'reason': 'جاء بعد التنوين حرف الباء',
                  },
                ],
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
              ),
              const SizedBox(height: 25),
              _buildRuleSection(
                title: "ثالثاً: حكم الإدغام",
                definition:
                    "هو قلب النون الساكنة أو التنوين في آخر الكلمة الأولى إلى أحد حروف (يرملون) في بداية الكلمة الثانية ليصبحا حرفاً واحداً مشدداً. وهو على قسمين:",
                extraContent: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 15),
                    _buildSubRuleBox(
                      "1. الإدغام بغنة",
                      "حروفه: (ي، ن، م، و) مجموعة في كلمة (ينمو)",
                      primaryColor,
                    ),
                    const SizedBox(height: 10),
                    _buildSubRuleBox(
                      "2. الإدغام بدون غنة",
                      "حروفه: (ل، ر)",
                      primaryColor,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "ملاحظات هامة:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "• يجب أن يكون الإدغام في كلمتين، فإذا التقيا في كلمة واحدة وجب الإظهار (إظهار مطلق) مثل: (دنيا، صنوان، قنوان، بنيان).",
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
                examples: [
                  {
                    'word': 'مَن يَعْمَلْ',
                    'rule': 'إدغام بغنة',
                    'reason': 'جاء بعد النون الساكنة حرف الياء',
                  },
                  {
                    'word': 'مِن مَّاءٍ',
                    'rule': 'إدغام بغنة',
                    'reason': 'جاء بعد النون الساكنة حرف الميم',
                  },
                  {
                    'word': 'مِن رَّبِّهِمْ',
                    'rule': 'إدغام بدون غنة',
                    'reason': 'جاء بعد النون الساكنة حرف الراء',
                  },
                  {
                    'word': 'هُدًى لِّلْمُتَّقِينَ',
                    'rule': 'إدغام بدون غنة',
                    'reason': 'جاء بعد التنوين حرف اللام',
                  },
                ],
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
              ),
              const SizedBox(height: 25),
              _buildRuleSection(
                title: "رابعاً: حكم الإخفاء",
                definition:
                    "هو النطق بالنون الساكنة أو التنوين خالية من التشديد وسطاً بين الإظهار والإدغام مع الغنة، إذا جاء بعدها أحد الحروف الخمسة عشر المجموعة في أوائل كلمات بيت الشعر:\n(صف ذا ثنا كم جاد شخص قد سما ... دم طيباً زد في تقى ضع ظالماً)",
                examples: [
                  {
                    'word': 'مَنصُوراً',
                    'rule': 'إخفاء',
                    'reason': 'جاء بعد النون الساكنة حرف الصاد',
                  },
                  {
                    'word': 'مِن طِينٍ',
                    'rule': 'إخفاء',
                    'reason': 'جاء بعد النون الساكنة حرف الطاء',
                  },
                  {
                    'word': 'قَوْماً جَبَّارِينَ',
                    'rule': 'إخفاء',
                    'reason': 'جاء بعد التنوين حرف الجيم',
                  },
                ],
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color primaryColor, Color secondaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withAlpha(204)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 50),
          const SizedBox(height: 15),
          const Text(
            "أحكام النون الساكنة والتنوين",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "أساسيات قواعد التلاوة",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefinitionSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("التعريفات الأساسية", primaryColor),
        const SizedBox(height: 15),
        _buildInfoBox(
          "النون الساكنة:",
          "هي حرف خالٍ من الحركات يقع في وسط الكلمة أو آخرها يلفظ ساكناً في الوصل والوقف، وتكون في الأسماء والأفعال والحروف.",
          primaryColor,
        ),
        const SizedBox(height: 12),
        _buildInfoBox(
          "التنوين:",
          "هو النطق بالحركة المضعفة (ً  ٍ  ٌ) نوناً ساكنة زائدة تلحق آخر الاسم، تلفظ نوناً ولا تكتب.",
          primaryColor,
        ),
      ],
    );
  }

  Widget _buildInfoBox(String title, String content, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("الفرق بين النون الساكنة والتنوين", primaryColor),
        const SizedBox(height: 15),
        Table(
          border: TableBorder.all(
            color: Colors.grey[300]!,
            borderRadius: BorderRadius.circular(10),
          ),
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: primaryColor.withAlpha(25)),
              children: [
                _buildTableCell(
                  "النون الساكنة",
                  isHeader: true,
                  primaryColor: primaryColor,
                ),
                _buildTableCell(
                  "التنوين",
                  isHeader: true,
                  primaryColor: primaryColor,
                ),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell("تأتي وسط الكلمة وآخرها"),
                _buildTableCell("يأتي في آخر الكلمة فقط"),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell("تأتي في الاسم والحرف والفعل"),
                _buildTableCell("يأتي مع الأسماء فقط"),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell("تلفظ وصلاً ووقفاً"),
                _buildTableCell("يلفظ وصلاً فقط"),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    Color? primaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? primaryColor : Colors.black87,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildRuleSection({
    required String title,
    required String definition,
    required List<Map<String, String>> examples,
    required Color primaryColor,
    required Color secondaryColor,
    Widget? extraContent,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 25,
                decoration: BoxDecoration(
                  color: secondaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            definition,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
          if (extraContent != null) extraContent,
          const SizedBox(height: 20),
          const Text(
            "أمثلة من القرآن الكريم:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ...examples.map(
            (ex) => _buildExampleRow(ex, primaryColor, secondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleRow(
    Map<String, String> ex,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              ex['word']!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "الحكم: ${ex['rule']}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: secondaryColor,
                  ),
                ),
                Text(
                  "السبب: ${ex['reason']}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color primaryColor) {
    return Row(
      children: [
        Icon(Icons.label_important_rounded, color: primaryColor, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSubRuleBox(String title, String content, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withAlpha(30)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
