import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../core/models/subject_model.dart';
import '../../core/utils/study_timer_service.dart';

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  // منطق العد التنازلي
  late Timer _timer;
  Duration _timeLeft = const Duration(days: 45, hours: 12, minutes: 30);
  
  int _currentTipIndex = 0;
  List<Map<String, String>> _tips = [];
  
  String userName = "الطالب";
  String userEmail = "user@email.com";
  String? _profileImagePath;
  String? selectedStage;
  bool isAdsRemoved = false;
  bool isAiSubscribed = false;
  int _aiMessagesCount = 0;
  List<SubjectModel> _supabaseSubjects = [];
  bool _isLoadingSubjects = false; // حالة تحميل المواد

  // متغيرات تتبع الوقت والمتصدرين
  List<Map<String, dynamic>> _leaderboardUsers = [];
  bool _isLoadingLeaderboard = false;

  String _getInitials(String name) {
    if (name.isEmpty) return "S";
    return name.trim().substring(0, 1).toUpperCase();
  }

  // Gemini AI & Search Variables
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isTipVisible = false;
  final List<Map<String, dynamic>> _chatMessages = [];
  bool _isTyping = false;
  late GenerativeModel _model;
  late ChatSession _chat;

  @override
  void initState() {
    super.initState();
    // تصفير القيم عند الدخول لأول مرة فقط (للتجربة)
    isAdsRemoved = false;
    isAiSubscribed = false;
    _aiMessagesCount = 0;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    _loadUserData();
    _loadTips();
    _startCountdown();
    _initGemini();
    _fetchSupabaseData();
    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _syncTimeOnRefresh() async {
    // هذه الدالة ستقوم فقط بمزامنة الوقت الحالي مع السيرفر
    // منطق الحساب موجود في TimeTrackingWrapper
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // نحن نعتمد الآن على الـ Global Wrapper ولكن للريفريش نحتاج التأكد من الحفظ
      // سنقوم بعمل تحديث بسيط لتحفيز السيرفر
    }
  }

  Future<void> _updateStudyTime() async {
    // تم نقل هذا المنطق إلى TimeTrackingWrapper
    // سنتركه فارغاً أو نقوم باستدعاء المزامنة من الـ Wrapper إذا لزم الأمر
  }

  Future<void> _fetchLeaderboard() async {
    if (!mounted) return;
    setState(() => _isLoadingLeaderboard = true);
    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, profile_image, stage, weekly_study_time')
          .order('weekly_study_time', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _leaderboardUsers = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Error fetching leaderboard: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLeaderboard = false);
    }
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return "$hours س $minutes د";
    return "$minutes دقيقة";
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "صباح الخير";
    return "مساء الخير";
  }

  final List<Map<String, String>> _notifications = [
    {
      'title': 'مرحباً بك في سند',
      'body': 'نتمنى لك رحلة تعليمية ممتعة ومفيدة.',
      'time': 'منذ ساعة'
    },
    {
      'title': 'تحديث جديد',
      'body': 'تم إضافة مواد دراسية جديدة للمرحلة السادسة العلمي.',
      'time': 'منذ ساعتين'
    },
  ];

  Future<void> _loadTips() async {
    try {
      final String response = await rootBundle.loadString('assets/jsons/tips.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _tips = data.map((item) => Map<String, String>.from(item)).toList();
      });
    } catch (e) {
      debugPrint("Error loading tips: $e");
      // Fallback if file not found
      setState(() {
        _tips = [
          {'type': 'نصيحة', 'text': 'ابدأ يومك بنية صادقة، فالتوفيق يبدأ بصدق العمل والاجتهاد المستمر للوصول إلى هدفك.'}
        ];
      });
    }
  }

  Future<void> _fetchSupabaseData() async {
    setState(() => _isLoadingSubjects = true);
    try {
      final subjects = await SubjectModel.fetchFromSupabase();
      if (mounted) {
        setState(() {
          _supabaseSubjects = subjects;
        });
      }
    } catch (e) {
      debugPrint("Error fetching Supabase data: $e");
    } finally {
      if (mounted) setState(() => _isLoadingSubjects = false);
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. جلب الصورة المخزنة محلياً فوراً
    final savedImagePath = prefs.getString('profile_image_path');
    final savedName = prefs.getString('user_name');
    final savedEmail = prefs.getString('user_email');
    final savedStage = prefs.getString('user_stage');
    
    if (mounted) {
      setState(() {
        if (savedName != null && savedName.isNotEmpty) userName = savedName;
        userEmail = savedEmail ?? "user@email.com";
        _profileImagePath = savedImagePath;
        if (savedStage != null) selectedStage = savedStage;
      });
    }

    // 2. تحديث البيانات من Supabase في الخلفية لضمان الدقة
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      final latestImageUrl = user.userMetadata?['profile_image'];
      final latestName = user.userMetadata?['full_name'];
      
      if (latestImageUrl != null && latestImageUrl != _profileImagePath) {
        await prefs.setString('profile_image_path', latestImageUrl);
        if (mounted) {
          setState(() {
            _profileImagePath = latestImageUrl;
          });
        }
      }
      if (latestName != null && latestName != userName) {
        await prefs.setString('user_name', latestName);
        if (mounted) setState(() => userName = latestName);
      }
    }
  }

  Future<void> _editNameDialog() async {
    final TextEditingController nameController = TextEditingController(text: userName);
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit_note_rounded, size: 40, color: primaryColor),
              ),
              const SizedBox(height: 20),
              const Text(
                "تعديل الاسم",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "أدخل اسمك الجديد",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = nameController.text.trim();
                        if (newName.isNotEmpty) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('user_name', newName);
                          setState(() {
                            userName = newName;
                          });
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initGemini() {
    // ملاحظة: يجب وضع API Key صالح هنا ليعمل الذكاء الاصطناعي
    const apiKey = 'AIzaSyAc-fKE-o9DfoYciB0o2_UqaKUUFKuG2w0';
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
    _chat = _model.startChat();
    
    // رسالة الترحيب
    _chatMessages.add({
      'text': 'مرحباً بك في سند! أنا مساعدك الذكي، كيف يمكنني مساعدتك في دراستك اليوم؟',
      'isMe': false,
    });
  }

  Future<void> _sendMessage() async {
    if (!isAiSubscribed && _aiMessagesCount >= 3) {
      _showSubscriptionSheet();
      return;
    }

    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _chatMessages.add({'text': message, 'isMe': true});
      _chatController.clear();
      if (!isAiSubscribed) {
        _aiMessagesCount++; // زيادة العداد عند الإرسال
      }
      _isTyping = true;
    });

    try {
      final response = await _chat.sendMessage(Content.text(message));
      
      setState(() {
        _chatMessages.add({
          'text': response.text ?? 'عذراً، لم أستطع فهم ذلك.',
          'isMe': false,
        });
      });
    } catch (e) {
      debugPrint("Gemini Error: $e");
      setState(() {
        _chatMessages.add({
          'text': 'حدث خطأ في الاتصال. يرجى التأكد من مفتاح API أو جودة الإنترنت. الخطأ: ${e.toString().split(':').first}',
          'isMe': false,
        });
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_timeLeft.inMinutes > 0) {
        setState(() {
          _timeLeft = _timeLeft - const Duration(minutes: 1);
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is String) {
      selectedStage = args;
    } else if (args is Map<String, dynamic>) {
      // استقبال البيانات من شاشة البداية لضمان الظهور الفوري
      if (args['userName'] != null) userName = args['userName'];
      if (args['profileImage'] != null) _profileImagePath = args['profileImage'];
      if (args['selectedStage'] != null) selectedStage = args['selectedStage'];
    }
  }

  List<Map<String, dynamic>> _getSubjectPdfs(String label, List<Map<String, String>> defaultPdfs) {
    List<String> supabaseKeys = [];
    bool isScientific = selectedStage?.contains('علمي') ?? true;

    switch (label) {
      case 'الإسلامية': supabaseKeys = ['islamic']; break;
      case 'العربية': supabaseKeys = ['arabic_p1', 'arabic_p2']; break;
      case 'الإنكليزي': supabaseKeys = ['english_student', 'english_activity']; break;
      case 'الرياضيات': supabaseKeys = [isScientific ? 'math_scientific' : 'math_literary']; break;
      case 'الأحياء': supabaseKeys = ['biology']; break;
      case 'الكيمياء': supabaseKeys = ['chemistry']; break;
      case 'الفيزياء': supabaseKeys = ['physics']; break;
      case 'التاريخ': supabaseKeys = ['history']; break;
      case 'الجغرافية': supabaseKeys = ['geography']; break;
      case 'الاقتصاد': supabaseKeys = ['economics']; break;
    }

    List<Map<String, dynamic>> supabasePdfs = [];
    for (var key in supabaseKeys) {
      final subject = _supabaseSubjects.firstWhere(
        (s) => s.label == key,
        orElse: () => SubjectModel(label: '', icon: Icons.book, pdfs: []),
      );
      for (var pdf in subject.pdfs) {
        supabasePdfs.add({'title': pdf.title, 'path': pdf.url});
      }
    }

    if (supabasePdfs.isNotEmpty) {
      return supabasePdfs;
    }
    return defaultPdfs;
  }

  List<Map<String, dynamic>> get filteredSubjects {
    bool isScientific = selectedStage?.contains('علمي') ?? true;

    final List<Map<String, dynamic>> sharedSubjects = [
      {
        'label': 'الإسلامية',
        'icon': Icons.menu_book_rounded,
        'pdfs': _getSubjectPdfs('الإسلامية', [
          {'title': 'الكتاب', 'path': AppAssets.islamicPdf}
        ]),
        'exams': [
          {'title': 'اختبار شامل - الفصل الأول'},
          {'title': 'اختبار شامل - الفصل الثاني'},
        ]
      },
      {
        'label': 'العربية',
        'icon': Icons.auto_stories_rounded,
        'pdfs': _getSubjectPdfs('العربية', [
          {'title': 'الكتاب - الجزء الأول', 'path': AppAssets.arabicP1Pdf},
          {'title': 'الكتاب - الجزء الثاني', 'path': AppAssets.arabicP2Pdf},
        ]),
        'exams': [
          {'title': 'اختبار الأدب - الفصل الأول'},
          {'title': 'اختبار القواعد - الفصل الأول'},
        ]
      },
      {
        'label': 'الإنكليزي',
        'icon': Icons.language_rounded,
        'pdfs': _getSubjectPdfs('الإنكليزي', [
          {'title': 'الكتاب - كتاب الطالب', 'path': AppAssets.englishStudentPdf},
          {'title': 'الكتاب - كتاب النشاط', 'path': AppAssets.englishActivityPdf},
        ]),
        'exams': [
          {'title': 'اختبار مفردات - Unit 1'},
          {'title': 'اختبار قواعد - Unit 1'},
        ]
      },
    ];

    final List<Map<String, dynamic>> scientificSubjects = [
      {
        'label': 'الرياضيات',
        'icon': Icons.functions_rounded,
        'pdfs': _getSubjectPdfs('الرياضيات', [
          {'title': 'الكتاب', 'path': AppAssets.mathScientificPdf}
        ]),
        'exams': [
          {'title': 'اختبار الأعداد المركبة'},
          {'title': 'اختبار القطوع المخروطية'},
        ]
      },
      {
        'label': 'الأحياء',
        'icon': Icons.biotech_rounded,
        'pdfs': _getSubjectPdfs('الأحياء', [
          {'title': 'الكتاب', 'path': AppAssets.biologyPdf}
        ]),
        'exams': [
          {'title': 'اختبار الخلية'},
          {'title': 'اختبار الأنسجة'},
        ]
      },
      {
        'label': 'الكيمياء',
        'icon': Icons.science_rounded,
        'pdfs': _getSubjectPdfs('الكيمياء', [
          {'title': 'الكتاب', 'path': AppAssets.chemistryPdf}
        ]),
        'exams': [
          {'title': 'اختبار الثرموداينمك'},
          {'title': 'اختبار الاتزان الكيميائي'},
        ]
      },
      {
        'label': 'الفيزياء',
        'icon': Icons.bolt_rounded,
        'pdfs': _getSubjectPdfs('الفيزياء', [
          {'title': 'الكتاب', 'path': AppAssets.physicsPdf}
        ]),
        'exams': [
          {'title': 'اختبار المتسعات'},
          {'title': 'اختبار الحث الكهرومغناطيسي'},
        ]
      },
    ];

    final List<Map<String, dynamic>> literarySubjects = [
      {
        'label': 'الرياضيات',
        'icon': Icons.functions_rounded,
        'pdfs': _getSubjectPdfs('الرياضيات', [
          {'title': 'الكتاب', 'path': AppAssets.mathLiteraryPdf}
        ]),
        'exams': []
      },
      {
        'label': 'التاريخ',
        'icon': Icons.history_edu_rounded,
        'pdfs': _getSubjectPdfs('التاريخ', [
          {'title': 'الكتاب', 'path': AppAssets.historyPdf}
        ]),
        'exams': []
      },
      {
        'label': 'الجغرافية',
        'icon': Icons.public_rounded,
        'pdfs': _getSubjectPdfs('الجغرافية', [
          {'title': 'الكتاب', 'path': AppAssets.geographyPdf}
        ]),
        'exams': []
      },
      {
        'label': 'الاقتصاد',
        'icon': Icons.pie_chart_rounded,
        'pdfs': _getSubjectPdfs('الاقتصاد', [
          {'title': 'الكتاب', 'path': AppAssets.economicsPdf}
        ]),
        'exams': []
      },
    ];

    return [...sharedSubjects, ...(isScientific ? scientificSubjects : literarySubjects)];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return DefaultTabController(
      length: 5,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false, // الحل الاحترافي: منع الشاشة من الانضغاط
          drawer: _buildDrawer(context, primaryColor, secondaryColor),
          appBar: AppBar(
            toolbarHeight: 80,
            backgroundColor: primaryColor,
            elevation: 4,
            shadowColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
            titleSpacing: 0, // إزالة المسافة التلقائية ليكون النص قريباً من الأيقونة
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            title: _buildGreetingText(secondaryColor),
            actions: [
              Padding(
                padding: const EdgeInsets.only(left: 15),
                child: _buildUserAvatar(),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Container(
                margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(50), width: 1.5), // حواف بيضاء خفيفة وواضحة
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorColor: secondaryColor,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 4,
                  labelColor: secondaryColor,
                  unselectedLabelColor: Colors.white70,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(width: 4.0, color: secondaryColor),
                    insets: const EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.home_rounded, size: 26)),
                    Tab(icon: Icon(Icons.auto_awesome_rounded, size: 26)),
                    Tab(icon: Icon(Icons.handyman_rounded, size: 26)),
                    Tab(icon: Icon(Icons.notifications_none_rounded, size: 26)),
                    Tab(icon: Icon(Icons.emoji_events_rounded, size: 26)),
                  ],
                ),
              ),
            ),
          ),
          body: SafeArea(
            bottom: true, // يضمن عدم تداخل المحتوى مع أزرار النظام في الأسفل
            child: TabBarView(
              // تم ترك خاصية physics افتراضية للسماح بالسحب بين التبويبات
              children: [
                _buildHomeView(primaryColor, secondaryColor),
                _buildAiChatView(primaryColor),
                _buildToolsView(primaryColor, secondaryColor),
                _buildNotificationsView(primaryColor, secondaryColor),
                _buildLeaderboardView(primaryColor, secondaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSubscriptionSheet() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
        ),
        padding: const EdgeInsets.fromLTRB(25, 15, 25, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            const Text("باقات سند بلس", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("اختر خطة التوفير وابدأ رحلة التفوق", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 35),
            _buildPremiumCard(
              title: "باقة الهدوء",
              subtitle: "إزالة الإعلانات بالكامل",
              price: "10,000 د.ع",
              period: "شهرياً",
              icon: Icons.block_rounded,
              gradient: const [Color(0xFFFF5252), Color(0xFFFF1744)],
              isSubscribed: isAdsRemoved,
              onTap: () => _processPayment('ads'),
            ),
            const SizedBox(height: 20),
            _buildPremiumCard(
              title: "باقة الذكاء",
              subtitle: "وصول غير محدود لـ AI سند",
              price: "5,000 د.ع",
              period: "شهرياً",
              icon: Icons.auto_awesome_rounded,
              gradient: const [Color(0xFF2979FF), Color(0xFF2962FF)],
              isSubscribed: isAiSubscribed,
              onTap: () => _processPayment('ai'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard({required String title, required String subtitle, required String price, required String period, required IconData icon, required List<Color> gradient, required bool isSubscribed, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: isSubscribed ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: gradient.first.withAlpha(80), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isSubscribed)
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 30)
                else ...[
                  Text(price, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(period, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiPaywall(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.blueAccent.withAlpha(20), shape: BoxShape.circle),
              child: const Icon(Icons.lock_person_rounded, size: 80, color: Colors.blueAccent),
            ),
            const SizedBox(height: 25),
            const Text("استنفدت الرسائل المجانية", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("لقد استخدمت 3 رسائل، اشترك الآن للحصول على وصول غير محدود للمساعد الذكي طوال الشهر.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _showSubscriptionSheet,
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text("اشترك الآن بـ 5,000 د.ع"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(String type) async {
    // محاكاة عملية الدفع - هنا يتم ربط ZainCash أو أي بوابة دفع لاحقاً
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await Future.delayed(const Duration(seconds: 2)); // محاكاة وقت الاتصال بالسيرفر
    
    if (type == 'ads') {
      setState(() => isAdsRemoved = true);
    } else {
      setState(() => isAiSubscribed = true);
    }
    // ملاحظة: تم إزالة الكود الخاص بحفظ الحالة في SharedPreferences لجعلها تجريبية فقط

    if (mounted) {
      Navigator.pop(context); // إغلاق الـ Loading
      Navigator.pop(context); // إغلاق الـ BottomSheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تفعيل الاشتراك بنجاح! استمتع بالمميزات الجديدة"), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildUserAvatar() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/profile').then((_) => _loadUserData());
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              spreadRadius: 1,
              offset: Offset.zero, // موزعة في كل الاتجاهات
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white.withAlpha(40),
          backgroundImage: _profileImagePath != null 
              ? (_profileImagePath!.startsWith('http') 
                  ? NetworkImage(_profileImagePath!) as ImageProvider
                  : FileImage(File(_profileImagePath!)))
              : null,
          child: _profileImagePath == null
              ? Text(
                  _getInitials(userName),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, Color primaryColor, Color secondaryColor) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // رأس الدراور ملون وجذاب
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
            decoration: BoxDecoration(
              color: primaryColor,
              boxShadow: [
                BoxShadow(color: primaryColor.withAlpha(40), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(AppAssets.logo, height: 70),
                ),
                const SizedBox(height: 20),
                const Text(
                  "سـنـد",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  "رفيقك في طريق النجاح",
                  style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          // زر الترقية الذهبي
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFA500).withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showSubscriptionSheet();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 15),
                        Text(
                          "سند بلس (الاشتراكات)",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildDrawerItem(
            icon: Icons.share_rounded,
            title: "مشاركة التطبيق",
            color: primaryColor,
            onTap: () {},
          ),
          _buildDrawerItem(
            icon: Icons.star_rate_rounded,
            title: "تقييم التطبيق",
            color: primaryColor,
            onTap: () {},
          ),
          _buildDrawerItem(
            icon: Icons.report_problem_rounded,
            title: "إبلاغ عن مشكلة",
            color: primaryColor,
            onTap: () {},
          ),
          const Divider(indent: 25, endIndent: 25, height: 40),
          _buildDrawerItem(
            icon: Icons.info_rounded,
            title: "عن التطبيق",
            color: primaryColor,
            onTap: () {},
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: Text(
              "الإصدار 1.0.0",
              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      onTap: onTap,
    );
  }

  Widget _buildGreetingText(Color secondaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_getGreeting(),
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                  text: "مرحباً، ",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              TextSpan(
                  text: userName,
                  style: TextStyle(
                      color: secondaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          selectedStage ?? "لم يتم تحديد المرحلة",
          style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAppBarLogo(Color secondaryColor) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
              text: "سـنـد",
              style: TextStyle(
                  color: secondaryColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHomeView(Color primaryColor, Color secondaryColor) {
    if (_tips.isEmpty) return const Center(child: CircularProgressIndicator());
    final currentTip = _tips[_currentTipIndex];
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              _buildSearchBar(),
              if (_searchQuery.trim().isEmpty) ...[
                _buildSectionHeader("المواد الدراسية", "${filteredSubjects.length} مواد"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        clipBehavior: Clip.none,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.4,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: filteredSubjects.length,
                        itemBuilder: (context, index) {
                          return _buildSubjectCard(filteredSubjects[index]);
                        },
                      ),
                ),
              ] else
                _buildSearchResults(primaryColor, secondaryColor),
              const SizedBox(height: 100),
            ],
          ),
        ),
        // فقاعة النصيحة - تظهر فوق الزر
        if (_isTipVisible)
          Positioned(
            bottom: 90,
            left: 20,
            child: GestureDetector(
              onTap: () => setState(() => _isTipVisible = false),
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withAlpha(40),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: primaryColor.withAlpha(30), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: secondaryColor.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getTipIcon(currentTip['type']!),
                            color: secondaryColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${currentTip['type']} اليوم",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentTip['text']!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // الزر العائم - موقعه ثابت تماماً
        Positioned(
          bottom: 20,
          left: 20,
          child: FloatingActionButton(
            onPressed: () {
              setState(() {
                if (!_isTipVisible) {
                  _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
                }
                _isTipVisible = !_isTipVisible;
              });
            },
            backgroundColor: primaryColor,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isTipVisible ? Icons.close_rounded : Icons.lightbulb_rounded,
                key: ValueKey<bool>(_isTipVisible),
                color: secondaryColor,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase()
        .trim();
  }

  Widget _buildSearchResults(Color primaryColor, Color secondaryColor) {
    final query = _normalizeArabic(_searchQuery);
    final List<Map<String, dynamic>> results = [];
    final currentSubjects = filteredSubjects;

    void navigateAndClear(String route, {Object? arguments}) {
      Navigator.pushNamed(context, route, arguments: arguments).then((_) {
        if (mounted) {
          setState(() {
            _searchQuery = "";
            _searchController.clear();
          });
        }
      });
    }

    for (var subject in currentSubjects) {
      final subjectLabel = subject['label'].toString();
      final normalizedLabel = _normalizeArabic(subjectLabel);
      
      // 1. البحث في الكتب (PDFs)
      final pdfs = subject['pdfs'] as List;
      for (var pdf in pdfs) {
        final pdfData = pdf as Map<String, dynamic>;
        final title = pdfData['title'].toString();
        final normalizedTitle = _normalizeArabic(title);
        
        if (normalizedTitle.contains(query) || normalizedLabel.contains(query)) {
          results.add({
            'title': "كتاب $subjectLabel - $title",
            'type': 'كتاب',
            'icon': Icons.menu_book_rounded,
            'onTap': () => navigateAndClear('/pdf_viewer', arguments: {'title': title, 'pdfPath': pdfData['path']}),
          });
        }
      }

      // 2. البحث في الاختبارات والوزاريات (فقط لمواد معينة)
      if (subjectLabel == 'الإسلامية' || subjectLabel == 'العربية') {
        if (_normalizeArabic("اختبارات $subjectLabel").contains(query) || _normalizeArabic("الاختبارات").contains(query)) {
          results.add({
            'title': "اختبارات $subjectLabel",
            'type': 'اختبارات',
            'icon': Icons.assignment_turned_in_rounded,
            'onTap': () => navigateAndClear('/exams', arguments: {'subjectName': subjectLabel}),
          });
        }
        if (_normalizeArabic("وزاريات $subjectLabel").contains(query) || _normalizeArabic("الوزاريات").contains(query)) {
          results.add({
            'title': "وزاريات $subjectLabel",
            'type': 'وزاريات',
            'icon': Icons.account_balance_rounded,
            'onTap': () => navigateAndClear('/ministerials', arguments: {'subjectName': subjectLabel}),
          });
        }
      }

      // 3. الأقسام الخاصة
      if (subjectLabel == 'الإسلامية') {
        if (_normalizeArabic("أحكام التلاوة").contains(query)) {
          results.add({
            'title': "أحكام التلاوة - الإسلامية",
            'type': 'قسم',
            'icon': Icons.menu_book_rounded,
            'onTap': () => navigateAndClear('/tajweed_rules'),
          });
        }
        if (_normalizeArabic("سور الحفظ").contains(query)) {
          results.add({
            'title': "سور الحفظ - الإسلامية",
            'type': 'قسم',
            'icon': Icons.menu_book_outlined,
            'onTap': () => navigateAndClear('/surahs'),
          });
        }
      }
      if (subjectLabel == 'العربية' && _normalizeArabic("قصائد الأدب").contains(query)) {
        results.add({
          'title': "قصائد الأدب - العربية",
          'type': 'قسم',
          'icon': Icons.auto_stories_rounded,
          'onTap': () => navigateAndClear('/poems'),
        });
      }
      if (subjectLabel == 'الإنكليزي') {
        if (_normalizeArabic("الإنشاءات").contains(query)) {
          results.add({
            'title': "الإنشاءات - الإنكليزي",
            'type': 'قسم',
            'icon': Icons.edit_note_rounded,
            'onTap': () => navigateAndClear('/essays'),
          });
        }
        if (_normalizeArabic("قطع الكتاب").contains(query)) {
          results.add({
            'title': "قطع الكتاب - الإنكليزي",
            'type': 'قسم',
            'icon': Icons.book_rounded,
            'onTap': () => navigateAndClear('/book_passages'),
          });
        }
      }
    }

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("لا توجد نتائج بحث مطابقة", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("نتائج البحث", "${results.length} نتيجة"),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4))],
                border: Border.all(color: Colors.grey[100]!),
              ),
              child: ListTile(
                onTap: item['onTap'],
                leading: CircleAvatar(backgroundColor: primaryColor.withAlpha(20), child: Icon(item['icon'], color: primaryColor, size: 22)),
                title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(item['type'], style: TextStyle(color: secondaryColor, fontSize: 12, fontWeight: FontWeight.w500)),
                trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: const InputDecoration(
            hintText: "ابحث داخل المواد...",
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  IconData _getTipIcon(String type) {
    switch (type) {
      case 'دعاء': return Icons.star_rounded;
      case 'تحفيز': return Icons.bolt_rounded;
      case 'حلم': return Icons.auto_awesome_rounded;
      default: return Icons.lightbulb_rounded;
    }
  }

  Widget _buildAiChatView(Color primaryColor) {
    // إظهار واجهة الاشتراك فقط بعد استهلاك الـ 3 رسائل بالكامل (أي عند محاولة الرابعة)
    if (!isAiSubscribed && _aiMessagesCount > 3) {
      return _buildAiPaywall(primaryColor);
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _chatMessages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _chatMessages.length) {
                return _buildChatBubble("جاري الكتابة...", false, primaryColor);
              }
              final msg = _chatMessages[index];
              return _buildChatBubble(msg['text'], msg['isMe'], primaryColor);
            },
          ),
        ),
        _buildChatInput(primaryColor),
      ],
    );
  }

  Widget _buildChatInput(Color primaryColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // يرتفع يدوياً مع الكيبورد
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, -5)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25)),
                child: TextField(
                  controller: _chatController,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                      hintText: "اكتب رسالتك هنا...",
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontSize: 14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: CircleAvatar(
                backgroundColor: primaryColor,
                child: _isTyping 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String message, bool isMe, Color primaryColor) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isMe ? 15 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 15),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(
              color: isMe ? Colors.white : Colors.black87, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildToolsView(Color primaryColor, Color secondaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("الأدوات التعليمية", "3 أدوات"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildToolListItem(
                    label: 'قائمة المهام',
                    icon: Icons.checklist_rounded,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor),
                _buildToolListItem(
                    label: 'بومودورو',
                    icon: Icons.timer_outlined,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor),
                _buildToolListItem(
                    label: 'ملاحظات',
                    icon: Icons.note_alt_rounded,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor),
                _buildToolListItem(
                    label: 'العد التنازلي',
                    icon: Icons.timer_rounded,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsView(Color primaryColor, Color secondaryColor) {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("لا توجد إشعارات حالياً",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        return Dismissible(
          key: Key(_notifications[index]['title']! + _notifications[index]['time']!),
          direction: DismissDirection.startToEnd,
          onDismissed: (direction) {
            setState(() {
              _notifications.removeAt(index);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("تم حذف الإشعار"),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 10,
                    offset: const Offset(0, 0)),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: CircleAvatar(
                backgroundColor: secondaryColor.withAlpha(25),
                child: Icon(Icons.notifications_active_outlined,
                    color: secondaryColor),
              ),
              title: Text(_notifications[index]['title']!,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(_notifications[index]['body']!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(_notifications[index]['time']!,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardView(Color primaryColor, Color secondaryColor) {
    if (_isLoadingLeaderboard) return const Center(child: CircularProgressIndicator());
    if (_leaderboardUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text("لا توجد بيانات حالياً", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    // إيجاد رتبة المستخدم الحالي
    final currentUser = Supabase.instance.client.auth.currentUser;
    int userRank = -1;
    Map<String, dynamic>? userData;
    
    if (currentUser != null) {
      for (int i = 0; i < _leaderboardUsers.length; i++) {
        if (_leaderboardUsers[i]['id'] == currentUser.id) {
          userRank = i + 1;
          userData = _leaderboardUsers[i];
          break;
        }
      }
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await StudyTimerService().syncTime();
            await _fetchLeaderboard();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildSectionHeader("المتصدرين", "أفضل 50 طالب"),
                const SizedBox(height: 40),
                // منصة التتويج (أول 3)
                if (_leaderboardUsers.length >= 3)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPodiumUser(
                            user: _leaderboardUsers[1],
                            rank: 2,
                            height: 140,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor),
                        const SizedBox(width: 15),
                        _buildPodiumUser(
                            user: _leaderboardUsers[0],
                            rank: 1,
                            height: 180,
                            hasCrown: true,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor),
                        const SizedBox(width: 15),
                        _buildPodiumUser(
                            user: _leaderboardUsers[2],
                            rank: 3,
                            height: 110,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor),
                      ],
                    ),
                  )
                else if (_leaderboardUsers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_leaderboardUsers.length > 1)
                          _buildPodiumUser(
                              user: _leaderboardUsers[1],
                              rank: 2,
                              height: 140,
                              primaryColor: primaryColor,
                              secondaryColor: secondaryColor),
                        if (_leaderboardUsers.length > 1) const SizedBox(width: 15),
                        _buildPodiumUser(
                            user: _leaderboardUsers[0],
                            rank: 1,
                            height: 180,
                            hasCrown: true,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor),
                        if (_leaderboardUsers.length > 2) const SizedBox(width: 15),
                        if (_leaderboardUsers.length > 2)
                          _buildPodiumUser(
                              user: _leaderboardUsers[2],
                              rank: 3,
                              height: 110,
                              primaryColor: primaryColor,
                              secondaryColor: secondaryColor),
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
                _buildLeaderList(primaryColor),
                const SizedBox(height: 120), // مساحة إضافية للبار العائم
              ],
            ),
          ),
        ),
        if (userData != null)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // تصغير البادينج العمودي
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    "#$userRank",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 15),
                  _buildUserCircle(userData['profile_image'], userData['full_name'] ?? "أنت", 20, Colors.white), // تصغير قطر الدائرة
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['full_name'] ?? "أنت",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userData['stage'] ?? "طالب",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatDuration(userData['weekly_study_time'] ?? 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showFullImageDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black87,
              ),
            ),
            Hero(
              tag: 'profile_pic',
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: _profileImagePath != null
                    ? (_profileImagePath!.startsWith('http') 
                        ? DecorationImage(image: NetworkImage(_profileImagePath!), fit: BoxFit.cover)
                        : DecorationImage(image: FileImage(File(_profileImagePath!)), fit: BoxFit.cover))
                    : null,
                  color: Theme.of(context).colorScheme.primary.withAlpha(25),
                ),
                child: _profileImagePath == null
                    ? Center(
                        child: Text(
                          _getInitials(userName),
                          style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 35),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (_profileImagePath != null)
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 35),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('profile_image_path');
                    setState(() {
                      _profileImagePath = null;
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("تم حذف الصورة الشخصية")),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, size: 50, color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              const Text(
                "تسجيل الخروج",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "هل أنت متأكد من رغبتك في تسجيل الخروج؟",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // منطق تسجيل الخروج
                        Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text("خروج", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, size: 50, color: Colors.red),
              ),
              const SizedBox(height: 20),
              const Text(
                "حذف الحساب نهائياً",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 12),
              const Text(
                "سيؤدي هذا الإجراء إلى حذف كافة بياناتك وملاحظاتك ولا يمكن التراجع عنه. هل أنت متأكد؟",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("تراجع", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // منطق حذف الحساب
                        Navigator.pushNamedAndRemoveUntil(context, '/signup', (route) => false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text("حذف الآن", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountActions() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 5,
                    offset: const Offset(0, 0)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showLogoutDialog(context),
                borderRadius: BorderRadius.circular(15),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Center(
                    child: Text("تسجيل الخروج",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                            fontSize: 16)),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        _buildDeleteAccountButton(),
      ],
    );
  }

  Widget _buildDeleteAccountButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 5,
              offset: const Offset(0, 0)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDeleteAccountDialog(context),
          borderRadius: BorderRadius.circular(15),
          child: const Padding(
            padding: EdgeInsets.all(15),
            child: Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String trailing) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                      color: secondaryColor,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
            ],
          ),
          Text(trailing,
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showSubjectDetails(BuildContext context, Map<String, dynamic> subject) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final List pdfs = subject['pdfs'] as List;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30), topRight: Radius.circular(30))),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subject['label']!,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  Icon(
                    subject['icon'] as IconData,
                    size: 40,
                    color: secondaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // عرض الكتب (سواء كتاب واحد أو أجزاء)
              ...pdfs.map((pdf) {
                final pdfData = pdf as Map<String, dynamic>;
                return _buildBottomSheetItem(
                  pdfData['title']!.toString(),
                  Icons.menu_book_rounded,
                  primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/pdf_viewer',
                      arguments: {
                        'title': pdfData['title'],
                        'pdfPath': pdfData['path'],
                      },
                    );
                  },
                );
              }),
              // زر الاختبارات الثابت (فقط لمواد معينة)
              if (subject['label'] == 'الإسلامية' || subject['label'] == 'العربية')
                _buildBottomSheetItem(
                  "الاختبارات",
                  Icons.assignment_turned_in_rounded,
                  primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/exams',
                      arguments: {
                        'subjectName': subject['label'],
                      },
                    );
                  },
                ),
              // زر الوزاريات الثابت (فقط لمواد معينة)
              if (subject['label'] == 'الإسلامية' || subject['label'] == 'العربية')
                _buildBottomSheetItem(
                  "الوزاريات",
                  Icons.account_balance_rounded,
                  primaryColor, // جعل لونه نفس لون الكتاب (primary)
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/ministerials',
                      arguments: {
                        'subjectName': subject['label'],
                      },
                    );
                  },
                ),
              // قسم أحكام التلاوة (فقط لمادة الإسلامية)
              if (subject['label'] == 'الإسلامية')
                _buildBottomSheetItem(
                  "أحكام التلاوة",
                  Icons.menu_book_rounded,
                  primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/tajweed_rules');
                  },
                ),
              // قسم سور الحفظ (فقط لمادة الإسلامية)
              if (subject['label'] == 'الإسلامية')
                _buildBottomSheetItem(
                  "سور الحفظ",
                  Icons.menu_book_outlined,
                  primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/surahs');
                  },
              ),
              // قسم الأحاديث النبوية الشريفة (فقط لمادة الإسلامية)
              if (subject['label'] == 'الإسلامية')
                _buildBottomSheetItem(
                  "الأحاديث النبوية الشريفة",
                  Icons.menu_book_rounded,
                  primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/hadiths');
                  },
                ),
              // قسم قصائد الأدب (فقط لمادة العربية)
              if (subject['label'] == 'العربية')
                _buildBottomSheetItem(
                  "قصائد الأدب",
                  Icons.auto_stories_rounded,
                  primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/poems');
                  },
                ),
              // قسم الإنشاءات (فقط لمادة الإنكليزي)
              if (subject['label'] == 'الإنكليزي')
                _buildBottomSheetItem(
                  "الإنشاءات",
                  Icons.edit_note_rounded,
                  primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/essays');
                  },
                ),
              // قسم قطع الكتاب (فقط لمادة الإنكليزي)
              if (subject['label'] == 'الإنكليزي')
                _buildBottomSheetItem(
                  "قطع الكتاب",
                  Icons.book_rounded,
                  primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/book_passages');
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetItem(String title, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[100]!)),
      child: ListTile(
        onTap: onTap ?? () => Navigator.pop(context),
        leading: CircleAvatar(
            backgroundColor: color.withAlpha(20),
            child: Icon(icon, color: color, size: 24)),
        title: Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color.withAlpha(200))),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }

  Widget _buildPodiumUser({required Map<String, dynamic> user, required int rank, required double height, bool hasCrown = false, required Color primaryColor, required Color secondaryColor}) {
    final String name = user['full_name'] ?? "طالب";
    final String? imageUrl = user['profile_image'];
    final String? stage = user['stage'];
    final int studyTime = user['weekly_study_time'] ?? 0;

    return Column(
      children: [
        if (hasCrown) const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 35),
        const SizedBox(height: 5),
        _buildUserCircle(imageUrl, name, 30, primaryColor),
        const SizedBox(height: 10),
        Text(name, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.visible,
        ),
        if (stage != null && stage.isNotEmpty)
          Text(stage, 
            style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 4),
        Text(_formatDuration(studyTime), 
          style: TextStyle(color: secondaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          width: 80, height: height,
          decoration: BoxDecoration(color: primaryColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15))),
          child: Center(child: Text("$rank", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
        ),
      ],
    );
  }

  Widget _buildUserCircle(String? imageUrl, String name, double radius, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: primaryColor.withAlpha(50), width: 2),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: primaryColor.withAlpha(20),
        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) 
            ? (imageUrl.startsWith('http') ? NetworkImage(imageUrl) : FileImage(File(imageUrl)) as ImageProvider)
            : null,
        child: (imageUrl == null || imageUrl.isEmpty)
            ? Text(
                _getInitials(name), 
                style: TextStyle(
                  color: primaryColor, 
                  fontWeight: FontWeight.bold, 
                  fontSize: radius * 0.8
                )
              )
            : null,
      ),
    );
  }

  Widget _buildLeaderList(Color primaryColor) {
    if (_leaderboardUsers.length <= 3) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _leaderboardUsers.length - 3,
        itemBuilder: (context, index) {
          final user = _leaderboardUsers[index + 3];
          final String name = user['full_name'] ?? "طالب";
          final String? imageUrl = user['profile_image'];
          final String? stage = user['stage'];
          final int studyTime = user['weekly_study_time'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Text("${index + 4}", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 15),
                _buildUserCircle(imageUrl, name, 22, primaryColor),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (stage != null)
                        Text(stage, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ),
                Text(_formatDuration(studyTime), 
                  style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolListItem({required String label, required IconData icon, required Color primaryColor, required Color secondaryColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15), // يجعل تأثير الضغط دائرياً بنفس حواف الحاوية
          onTap: () {
            if (label == 'العد التنازلي') {
              Navigator.pushNamed(context, '/countdown');
            } else if (label == 'ملاحظات') {
              Navigator.pushNamed(context, '/notes');
            } else if (label == 'بومودورو') {
              Navigator.pushNamed(context, '/pomodoro');
            } else if (label == 'قائمة المهام') {
              Navigator.pushNamed(context, '/todos');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.white.withAlpha(30),
                  child: Icon(icon, color: secondaryColor, size: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    int sectionCount = 0;
    if (subject['pdfs'] != null) {
      sectionCount += (subject['pdfs'] as List).length;
    }
    if (subject['label'] == 'الإسلامية' || subject['label'] == 'العربية') {
      sectionCount += 2; // الاختبارات + الوزاريات
    }
    
    if (subject['label'] == 'الإسلامية') {
      sectionCount += 3;
    } else if (subject['label'] == 'العربية') {
      sectionCount += 1;
    } else if (subject['label'] == 'الإنكليزي') {
      sectionCount += 2; // الإنشاءات + قطع الكتاب
    } else if (subject['label'] == 'الأحياء') {
      // لا توجد أقسام إضافية حالياً
    }

    return GestureDetector(
      onTap: () => _showSubjectDetails(context, subject),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject['label']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$sectionCount أقسام",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Icon(
                subject['icon'] as IconData,
                size: 35,
                color: secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
