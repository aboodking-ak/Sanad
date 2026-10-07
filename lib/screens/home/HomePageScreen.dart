import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_assets.dart';
import '../../core/models/subject_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/ad_helper.dart';

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _AiUsageBorderPainter extends CustomPainter {
  const _AiUsageBorderPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 1.5;
    const radius = 25.0;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final borderRect = Rect.fromLTRB(left, top, right, bottom);
    // Start at the lower-right edge, travel upward, then continue
    // counterclockwise around the dialog.
    final path = Path()
      ..moveTo(right, bottom - radius)
      ..lineTo(right, top + radius)
      ..quadraticBezierTo(right, top, right - radius, top)
      ..lineTo(left + radius, top)
      ..quadraticBezierTo(left, top, left, top + radius)
      ..lineTo(left, bottom - radius)
      ..quadraticBezierTo(left, bottom, left + radius, bottom)
      ..lineTo(right - radius, bottom)
      ..quadraticBezierTo(right, bottom, right, bottom - radius);
    final trackPaint = Paint()
      ..color = const Color(0xFFE3E7EF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, trackPaint);

    if (progress <= 0) return;
    final metric = path.computeMetrics().first;
    final progressPath = metric.extractPath(0, metric.length * progress);
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD66B), Color(0xFFE7A91F)],
      ).createShader(borderRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(progressPath, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _AiUsageBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _HomePageScreenState extends State<HomePageScreen>
    with TickerProviderStateMixin {
  final AdHelper _adHelper = AdHelper();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  static const String _noAdsId =
      'sanad_premium_monthly'; // نفس المعرف في جوجل بلاي

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
  int _aiMessagesCount = 0;
  int _aiRemaining = 50;
  DateTime? _aiResetAt;
  bool _aiQuotaLoaded = false;
  List<SubjectModel> _supabaseSubjects = [];
  bool _isLoadingSubjects = false; // حالة تحميل المواد

  // متغيرات تتبع الوقت والمتصدرين
  List<Map<String, dynamic>> _leaderboardUsers = [];
  bool _isLoadingLeaderboard = false;
  StreamSubscription? _leaderboardSubscription;

  // متغيرات الإشعارات
  List<Map<String, dynamic>> _liveNotifications = [];
  bool _isLoadingNotifications = false;
  int _unreadCount = 0;
  StreamSubscription? _notificationsSubscription;

  String _getCategoryForSubject(String label) {
    bool isLiterary = selectedStage?.contains('أدبي') ?? false;
    if (['الإسلامية', 'العربية', 'الإنكليزي'].contains(label)) {
      if (label == 'العربية' && isLiterary) return 'Literary';
      return 'Preparatory';
    }
    bool isScientific = selectedStage?.contains('علمي') ?? true;
    if (['الأحياء', 'الكيمياء', 'الفيزياء', 'الفرنسية'].contains(label)) {
      return 'Scientific';
    }
    if (['التاريخ', 'الجغرافية', 'الاقتصاد'].contains(label)) {
      return 'Literary';
    }
    if (label == 'الرياضيات') {
      return isScientific ? 'Scientific' : 'Literary';
    }
    return isScientific ? 'Scientific' : 'Literary';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "S";
    return name.trim().substring(0, 1).toUpperCase();
  }

  // Gemini AI & Search Variables
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  late final AnimationController _sendDotsController;
  late final AnimationController _chatHistoryPulseController;
  late final Animation<double> _chatHistoryPulseScale;
  XFile? _pendingChatImage;
  final ScrollController _chatScrollController = ScrollController();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isTipVisible = false;
  final List<Map<String, dynamic>> _chatMessages = [];
  final List<Map<String, dynamic>> _aiConversations = [];
  static const int _chatPageSize = 30;
  Map<String, dynamic>? _oldestChatMessageCursor;
  int _chatLoadGeneration = 0;
  bool _hasMoreChatMessages = false;
  bool _isLoadingOlderMessages = false;
  String? _currentConversationId;
  bool _isTyping = false;
  bool _isAiInitialized = false;
  bool _didPulseChatHistory = false;
  bool _isHistoryButtonPressed = false;

  String _appVersion = "1.1.0";

  @override
  void initState() {
    super.initState();
    _sendDotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _chatHistoryPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _chatHistoryPulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.07,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.07,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_chatHistoryPulseController);
    _chatFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    // تصفير القيم عند الدخول لأول مرة فقط (للتجربة)
    isAdsRemoved = false;
    _aiMessagesCount = 0;

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _loadUserData();
    _loadTips();
    _startCountdown();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        if (!_didPulseChatHistory) {
          _didPulseChatHistory = true;
          _chatHistoryPulseController.forward(from: 0);
        }
        _loadAiLimit();
        // Keep the newest messages anchored at the bottom when returning to chat.
        if (_chatScrollController.hasClients) {
          _chatScrollController.jumpTo(
            _chatScrollController.position.maxScrollExtent,
          );
        }
      }
    });
    _initAi();
    _loadAiLimit();
    _fetchSupabaseData();
    _fetchLeaderboard();
    _fetchNotifications();
    _loadAppVersion();
    _initializeInAppPurchase();

    // التأكد من تحميل إعلان المكافأة للأقسام
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adHelper.loadRewardedAd();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchController.dispose();
    _chatController.dispose();
    _chatFocusNode.dispose();
    _sendDotsController.dispose();
    _chatHistoryPulseController.dispose();
    _chatScrollController.dispose();
    _tabController.dispose();
    _notificationsSubscription?.cancel();
    _leaderboardSubscription?.cancel();
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

  Future<void> _loadAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint("Error loading app version: $e");
    }
  }

  Future<void> _fetchLeaderboard() async {
    if (!mounted) return;

    _leaderboardSubscription?.cancel();
    setState(() => _isLoadingLeaderboard = true);

    // البدء بالاستماع المباشر للتغييرات في جدول البروفايلات لترتيب المتصدرين
    _leaderboardSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .listen(
          (data) {
            if (mounted) {
              setState(() {
                // تحويل البيانات وترتيبها وأخذ أفضل 50
                var sortedUsers = List<Map<String, dynamic>>.from(data);
                sortedUsers.sort(
                  (a, b) => (b['weekly_study_time'] ?? 0).compareTo(
                    a['weekly_study_time'] ?? 0,
                  ),
                );

                _leaderboardUsers = sortedUsers.take(50).toList();
                _isLoadingLeaderboard = false;
              });
            }
          },
          onError: (error) {
            debugPrint("Leaderboard Realtime Error: $error");
            if (mounted) setState(() => _isLoadingLeaderboard = false);
          },
        );
  }

  Future<void> _fetchNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // إلغاء أي اشتراك قديم لتجنب التكرار
    _notificationsSubscription?.cancel();

    if (mounted) setState(() => _isLoadingNotifications = true);

    // بدء الاستماع الفوري للتغييرات في جدول الإشعارات
    _notificationsSubscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .listen(
          (data) {
            if (mounted) {
              setState(() {
                _liveNotifications = List<Map<String, dynamic>>.from(data);
                _unreadCount = _liveNotifications
                    .where((n) => n['is_read'] != true)
                    .length;
                _isLoadingNotifications = false;
              });
            }
          },
          onError: (error) {
            debugPrint("Realtime Error: $error");
            if (mounted) setState(() => _isLoadingNotifications = false);
          },
        );
  }

  Future<void> _markAllAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _unreadCount == 0) return;

    try {
      await Supabase.instance.client.rpc(
        'mark_notifications_as_read',
        params: {'target_user_id': user.id},
      );
      if (mounted) {
        setState(() {
          _unreadCount = 0;
          // تحديث الحالة محلياً أيضاً لضمان استجابة الواجهة فوراً
          for (var n in _liveNotifications) {
            n['is_read'] = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint("Error deleting notification: $e");
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

  Future<void> _loadTips() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/jsons/tips.json',
      );
      final List<dynamic> data = json.decode(response);
      setState(() {
        _tips = data.map((item) => Map<String, String>.from(item)).toList();
      });
    } catch (e) {
      debugPrint("Error loading tips: $e");
      // Fallback if file not found
      setState(() {
        _tips = [
          {
            'type': 'نصيحة',
            'text':
                'ابدأ يومك بنية صادقة، فالتوفيق يبدأ بصدق العمل والاجتهاد المستمر للوصول إلى هدفك.',
          },
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
    if (!mounted) return;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    // 1. قراءة البيانات المباشرة من كائن المستخدم والجلسة الحالية
    if (user != null) {
      final userMetadata = user.userMetadata;
      if (mounted) {
        setState(() {
          userEmail = user.email ?? "user@email.com";
          userName = userMetadata?['full_name'] ?? userName;
          _profileImagePath = userMetadata?['profile_image'];
          selectedStage = userMetadata?['user_stage'] ?? selectedStage;
        });
      }
    }

    // بيانات الحساب من Auth؛ لا تعِد تطبيق بيانات فتح الصفحة القديمة.
    // جدول profiles مخصص هنا لحالة الحظر والاشتراك فقط.
    if (user != null) {
      try {
        final profileData = await supabase
            .from('profiles')
            .select('is_blocked, ads_removed_until')
            .eq('id', user.id)
            .maybeSingle();

        if (!mounted || supabase.auth.currentUser?.id != user.id) return;
        if (profileData != null) {
          // التحقق من الحظر فوراً
          if (profileData['is_blocked'] == true) {
            if (mounted) _showBlockedDialog();
            return;
          }

          // فحص حالة الاشتراك وتاريخ الانتهاء
          bool adsStillRemoved = false;
          if (profileData['ads_removed_until'] != null) {
            final expiryDate = DateTime.parse(profileData['ads_removed_until']);
            if (expiryDate.isAfter(DateTime.now())) {
              adsStillRemoved = true;
            }
          }

          if (mounted) {
            setState(() {
              isAdsRemoved = adsStillRemoved;
            });
          }
        }
      } catch (e) {
        debugPrint("Error checking profile data from Supabase: $e");
      }
    }
  }

  void _showBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // لا يمكن إغلاقه بالضغط خارجاً
      builder: (context) => PopScope(
        canPop: false, // يمنع زر الرجوع في الهاتف
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gavel_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 25),
                const Text(
                  "تم حظر حسابك",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "عذراً، لقد تم حظر وصولك إلى تطبيق سند بسبب مخالفة شروط الاستخدام. يرجى التواصل مع الإدارة إذا كنت تعتقد أن هذا خطأ.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87, height: 1.6),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    // تسجيل الخروج والعودة لشاشة البداية
                    await AuthService().signOut();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/signin',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "تسجيل الخروج",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editNameDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: userName,
    );
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
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 40,
                  color: primaryColor,
                ),
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
                      child: const Text(
                        "إلغاء",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "حفظ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  void _applyAiUsage(dynamic usage) {
    if (!mounted || usage is! Map) return;
    final used = usage['used'];
    final remaining = usage['remaining'];
    if (used is! num || remaining is! num) return;
    setState(() {
      _aiMessagesCount = used.toInt();
      _aiRemaining = remaining.toInt();
      _aiResetAt = DateTime.tryParse(usage['reset_at']?.toString() ?? '');
      _aiQuotaLoaded = true;
    });
  }

  Future<void> _loadAiLimit() async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'sanad-ai',
        body: {'action': 'usage'},
      );
      if (response.status == 200 && response.data is Map) {
        _applyAiUsage(response.data['usage']);
      }
    } catch (_) {
      if (mounted) setState(() => _aiQuotaLoaded = false);
    }
  }

  Future<void> _initAi() async {
    try {
      if (Supabase.instance.client.auth.currentUser == null) return;
      await _loadConversations();
      if (mounted) setState(() => _isAiInitialized = true);
    } catch (_) {
      if (mounted) setState(() => _isAiInitialized = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_isTyping) return;

    if (!_isAiInitialized) {
      _showErrorMessage(
        'عذراً، لم يتم تهيئة المساعد الذكي بعد. يرجى المحاولة لاحقاً.',
      );
      return;
    }

    final typedMessage = _chatController.text.trim();
    final selectedImage = _pendingChatImage;
    if (typedMessage.isEmpty && selectedImage == null) return;
    final message = typedMessage.isEmpty
        ? 'اشرح محتوى هذه الصورة.'
        : typedMessage;

    // إخفاء لوحة المفاتيح عند الإرسال
    FocusScope.of(context).unfocus();

    setState(() {
      _chatMessages.add({
        'text': message,
        'isMe': true,
        if (selectedImage != null) 'localImagePath': selectedImage.path,
      });
      _chatController.clear();
      _pendingChatImage = null;
      _isTyping = true;
    });

    _scrollToBottom();

    String? uploadedImagePath;
    String? imageMimeType;
    if (selectedImage != null) {
      try {
        final uploaded = await _uploadChatImage(selectedImage);
        uploadedImagePath = uploaded['path'];
        imageMimeType = uploaded['mimeType'];
        if (mounted) {
          setState(() {
            _chatMessages.last['imagePath'] = uploadedImagePath;
            _chatMessages.last['imageMimeType'] = imageMimeType;
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _chatMessages.removeLast();
          _chatController.text = typedMessage;
          _pendingChatImage = selectedImage;
          _isTyping = false;
        });
        final error = e is FormatException ? e.message : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error ?? 'تعذر رفع الصورة. تحقق من الاتصال وحاول مجدداً.',
            ),
          ),
        );
        return;
      }
    }

    final messageSaved = await _saveMessageToDB(
      message,
      true,
      imagePath: uploadedImagePath,
      imageMimeType: imageMimeType,
    );
    if (!messageSaved) {
      if (!mounted) return;
      setState(() {
        _chatMessages.removeLast();
        _chatController.text = typedMessage;
        _pendingChatImage = selectedImage;
        _isTyping = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر حفظ المحادثة. تحقق من الاتصال ثم حاول مجدداً.'),
        ),
      );
      return;
    }

    Map<String, dynamic>? liveReply;
    try {
      String? responseText = await _getGroqResponse(
        message,
        imagePath: uploadedImagePath,
        onToken: (text) {
          if (!mounted) return;
          setState(() {
            if (liveReply == null) {
              liveReply = {'text': text, 'isMe': false};
              _chatMessages.add(liveReply!);
            } else {
              liveReply!['text'] = text;
            }
          });
        },
      );

      if (responseText == null || responseText.trim().isEmpty) {
        throw const FormatException('empty_response');
      }

      if (!mounted) return;
      setState(() {
        if (liveReply == null) {
          _chatMessages.add({'text': responseText, 'isMe': false});
        } else {
          liveReply!['text'] = responseText;
        }
      });
      await _saveMessageToDB(responseText!, false);
    } catch (e) {
      if (!mounted) return;
      if (liveReply != null) {
        setState(() => _chatMessages.remove(liveReply));
      }
      if (e is FunctionException &&
          e.details is Map &&
          e.details['error'] == 'daily_limit') {
        _showLimitReachedSheet();
      } else {
        final timedOut = e is TimeoutException;
        final error = e is FunctionException && e.details is Map
            ? e.details['error']?.toString()
            : null;
        final message = timedOut
            ? 'استغرق الرد وقتاً طويلاً. تحقق من الاتصال ثم أعد المحاولة.'
            : switch (error) {
                'requests_busy' =>
                  'هناك طلب آخر قيد المعالجة. انتظر قليلاً ثم أعد المحاولة.',
                'provider_unavailable' || 'service_unavailable' =>
                  'المساعد مشغول حالياً. حاول مرة أخرى بعد قليل.',
                'authentication_failed' || 'unauthorized' =>
                  'انتهت جلسة الدخول. سجّل الدخول مجدداً ثم أعد المحاولة.',
                _ => 'تعذر الاتصال بالمساعد. تحقق من الإنترنت ثم أعد المحاولة.',
              };
        _showErrorMessage(
          message,
          retryText: message,
          retryImagePath: uploadedImagePath,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        await _loadAiLimit();
      }
    }
  }

  Future<Map<String, String>> _uploadChatImage(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('حجم الصورة يجب ألا يتجاوز 5 ميغابايت.');
    }
    final path = image.path.toLowerCase();
    final mimeType =
        image.mimeType ??
        (path.endsWith('.png')
            ? 'image/png'
            : path.endsWith('.webp')
            ? 'image/webp'
            : path.endsWith('.jpg') || path.endsWith('.jpeg')
            ? 'image/jpeg'
            : null);
    const allowedTypes = {'image/jpeg', 'image/png', 'image/webp'};
    if (mimeType == null || !allowedTypes.contains(mimeType)) {
      throw const FormatException('اختر صورة بصيغة JPG أو PNG أو WebP.');
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw const FormatException('سجّل الدخول لإرسال صورة.');
    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final storagePath =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await Supabase.instance.client.storage
        .from('sanad-ai-chat-images')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    return {'path': storagePath, 'mimeType': mimeType};
  }

  Future<String?> _signedChatImageUrl(String? path) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || path == null || !path.startsWith('${user.id}/'))
      return null;
    try {
      return await Supabase.instance.client.storage
          .from('sanad-ai-chat-images')
          .createSignedUrl(path, 3600);
    } catch (e) {
      debugPrint('Could not create signed chat image URL: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _mapChatMessage(dynamic msg) async {
    final imagePath = msg['image_path']?.toString();
    return {
      'id': msg['id'],
      'text': msg['text'] ?? '',
      'isMe': msg['is_me'] ?? false,
      'createdAt': msg['created_at'],
      if (imagePath != null) 'imagePath': imagePath,
      if (msg['image_mime_type'] != null)
        'imageMimeType': msg['image_mime_type'],
      if (imagePath != null) 'imageUrl': await _signedChatImageUrl(imagePath),
    };
  }

  Future<String?> _getGroqResponse(
    String userMessage, {
    String? imagePath,
    required ValueChanged<String> onToken,
  }) async {
    final messages = <Map<String, dynamic>>[];
    for (final message
        in _chatMessages
            .where(_isUsableAiContextMessage)
            .toList()
            .reversed
            .take(10)
            .toList()
            .reversed) {
      final content = message['text']?.toString() ?? '';
      if (content.trim().isEmpty) continue;
      final requestMessage = <String, dynamic>{
        'role': message['isMe'] == true ? 'user' : 'assistant',
        'content': content,
      };
      final previousImagePath = message['imagePath']?.toString();
      if (previousImagePath != null && previousImagePath.isNotEmpty) {
        requestMessage['image_path'] = previousImagePath;
      }
      messages.add(requestMessage);
    }
    final imageMessageIndices = messages
        .asMap()
        .entries
        .where((entry) => entry.value['image_path'] != null)
        .map((entry) => entry.key)
        .toList();
    final olderImageCount = imageMessageIndices.length - 3;
    if (olderImageCount > 0) {
      for (final index in imageMessageIndices.take(olderImageCount)) {
        messages[index].remove('image_path');
      }
    }
    if (messages.isEmpty ||
        messages.last['role'] != 'user' ||
        messages.last['content'] != userMessage) {
      messages.add({
        'role': 'user',
        'content': userMessage,
        if (imagePath != null) 'image_path': imagePath,
      });
    }

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw const FunctionException(
        status: 401,
        details: {'error': 'unauthorized'},
      );
    }
    final endpoint = Uri.parse(
      supabase.rest.url.replaceFirst('/rest/v1', '/functions/v1/sanad-ai'),
    );
    final request = http.Request('POST', endpoint)
      ..headers.addAll(supabase.functions.headers)
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'messages': messages});

    final client = http.Client();
    try {
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 70));
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        dynamic details;
        try {
          details = jsonDecode(body);
          if (details is Map) _applyAiUsage(details['usage']);
        } catch (_) {
          details = body;
        }
        throw FunctionException(
          status: response.statusCode,
          details: details,
          reasonPhrase: response.reasonPhrase,
        );
      }

      final answer = StringBuffer();
      var receivedUsage = false;
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        final event = jsonDecode(payload);
        if (event is! Map) continue;
        if (event['delta'] is String) {
          answer.write(event['delta']);
          onToken(answer.toString());
          await Future<void>.delayed(const Duration(milliseconds: 20));
        } else if (event['usage'] != null) {
          _applyAiUsage(event['usage']);
          receivedUsage = true;
        } else if (event['error'] != null) {
          throw FunctionException(
            status: 503,
            details: {'error': event['error']},
          );
        }
      }
      if (answer.isEmpty || !receivedUsage) {
        throw const FunctionException(
          status: 503,
          details: {'error': 'incomplete_stream'},
        );
      }
      return answer.toString().trim();
    } finally {
      client.close();
    }
  }

  bool _isUsableAiContextMessage(Map<String, dynamic> message) {
    if (message['isError'] == true || message['retryText'] != null)
      return false;

    final text = message['text']?.toString().trim() ?? '';
    if (text.isEmpty) return false;

    // Ignore fallback failures saved by older versions as assistant replies.
    const legacyFailureReplies = {
      'عذراً، المساعد الذكي غير متاح حالياً.',
      'عذراً، لم يتم تهيئة المساعد الذكي بعد. يرجى المحاولة لاحقاً.',
    };
    if (message['isMe'] != true && legacyFailureReplies.contains(text)) {
      return false;
    }

    return message['isMe'] is bool;
  }

  void _showErrorMessage(
    String msg, {
    String? retryText,
    String? retryImagePath,
  }) {
    if (mounted) {
      setState(() {
        _chatMessages.add({
          'text': msg,
          'isMe': false,
          'isError': true,
          'retryText': retryText,
          'retryImagePath': retryImagePath,
        });
      });
    }
  }

  Future<void> _retryAiMessage(String message, {String? imagePath}) async {
    if (_isTyping || message.trim().isEmpty) return;
    setState(() {
      _chatMessages.removeWhere((item) => item['isError'] == true);
      _isTyping = true;
    });
    _scrollToBottom();
    Map<String, dynamic>? liveReply;
    try {
      final response = await _getGroqResponse(
        message,
        imagePath: imagePath,
        onToken: (text) {
          if (!mounted) return;
          setState(() {
            if (liveReply == null) {
              liveReply = {'text': text, 'isMe': false};
              _chatMessages.add(liveReply!);
            } else {
              liveReply!['text'] = text;
            }
          });
        },
      );
      if (response == null || response.isEmpty) {
        throw const FormatException('empty_response');
      }
      if (!mounted) return;
      setState(() {
        if (liveReply == null) {
          _chatMessages.add({'text': response, 'isMe': false});
        } else {
          liveReply!['text'] = response;
        }
      });
      await _saveMessageToDB(response, false);
    } catch (_) {
      if (!mounted) return;
      if (liveReply != null) {
        setState(() => _chatMessages.remove(liveReply));
      }
      _showErrorMessage(
        'تعذر الاتصال بالمساعد. تحقق من الإنترنت ثم أعد المحاولة.',
        retryText: message,
        retryImagePath: imagePath,
      );
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        await _loadAiLimit();
      }
    }
  }

  Future<void> _loadChatMessages() async {
    final user = Supabase.instance.client.auth.currentUser;
    final conversationId = _currentConversationId;
    final generation = ++_chatLoadGeneration;
    if (user == null || conversationId == null) {
      if (mounted) {
        setState(() {
          _chatMessages.clear();
          _oldestChatMessageCursor = null;
          _hasMoreChatMessages = false;
          _isLoadingOlderMessages = false;
        });
      }
      return;
    }

    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('chat_messages')
          .select('id, text, is_me, created_at, image_path, image_mime_type')
          .eq('user_id', user.id)
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(0, _chatPageSize - 1);

      if (mounted && generation == _chatLoadGeneration) {
        final messages = await Future.wait(data.reversed.map(_mapChatMessage));
        if (!mounted || generation != _chatLoadGeneration) return;
        setState(() {
          _chatMessages.clear();
          _chatMessages.addAll(messages);
          _oldestChatMessageCursor = data.isEmpty
              ? null
              : Map<String, dynamic>.from(data.last as Map);
          _hasMoreChatMessages = data.length == _chatPageSize;
          _isLoadingOlderMessages = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _chatLoadGeneration) {
            _scrollToBottom(isInstant: true);
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading chat messages: $e");
    }
  }

  Future<void> _loadOlderChatMessages() async {
    final user = Supabase.instance.client.auth.currentUser;
    final conversationId = _currentConversationId;
    final generation = _chatLoadGeneration;
    if (user == null ||
        conversationId == null ||
        !_hasMoreChatMessages ||
        _isLoadingOlderMessages)
      return;
    final cursor = _oldestChatMessageCursor;
    if (cursor == null) return;

    final oldPixels = _chatScrollController.hasClients
        ? _chatScrollController.position.pixels
        : 0.0;
    final oldExtent = _chatScrollController.hasClients
        ? _chatScrollController.position.maxScrollExtent
        : 0.0;
    setState(() => _isLoadingOlderMessages = true);
    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('chat_messages')
          .select('id, text, is_me, created_at, image_path, image_mime_type')
          .eq('user_id', user.id)
          .eq('conversation_id', conversationId)
          .or(
            'created_at.lt.${cursor['created_at']},and(created_at.eq.${cursor['created_at']},id.lt.${cursor['id']})',
          )
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(0, _chatPageSize - 1);

      if (!mounted || generation != _chatLoadGeneration) return;
      final knownIds = _chatMessages
          .map((message) => message['id']?.toString())
          .whereType<String>()
          .toSet();
      final olderMessages = await Future.wait(
        data
            .where((message) => !knownIds.contains(message['id']?.toString()))
            .map(_mapChatMessage),
      );
      if (!mounted || generation != _chatLoadGeneration) return;
      setState(() {
        _chatMessages.insertAll(0, olderMessages.reversed.toList());
        if (data.isNotEmpty) {
          _oldestChatMessageCursor = Map<String, dynamic>.from(
            data.last as Map,
          );
        }
        _hasMoreChatMessages = data.length == _chatPageSize;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            generation != _chatLoadGeneration ||
            !_chatScrollController.hasClients)
          return;
        final position = _chatScrollController.position;
        final newPixels = oldPixels + (position.maxScrollExtent - oldExtent);
        position.jumpTo(newPixels.clamp(0.0, position.maxScrollExtent));
      });
    } catch (e) {
      debugPrint('Error loading older chat messages: $e');
    } finally {
      if (mounted && generation == _chatLoadGeneration) {
        setState(() => _isLoadingOlderMessages = false);
      }
    }
  }

  Future<void> _loadConversations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('ai_conversations')
        .select('id, title, created_at, updated_at')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);
    if (!mounted) return;
    final conversations = data.cast<Map<String, dynamic>>();
    setState(() {
      _aiConversations
        ..clear()
        ..addAll(conversations);
      _currentConversationId = conversations.isEmpty
          ? null
          : conversations.first['id']?.toString();
      _chatMessages.clear();
    });
    if (_currentConversationId != null) await _loadChatMessages();
  }

  Future<void> _selectConversation(Map<String, dynamic> conversation) async {
    Navigator.of(context).pop();
    if (_chatScrollController.hasClients) {
      _chatScrollController.jumpTo(
        _chatScrollController.position.maxScrollExtent,
      );
    }
    setState(() {
      _chatLoadGeneration++;
      _currentConversationId = conversation['id']?.toString();
      _chatMessages.clear();
    });
    await _loadChatMessages();
  }

  void _startNewConversation() {
    if (_isTyping) return;
    if (_chatScrollController.hasClients) {
      _chatScrollController.jumpTo(
        _chatScrollController.position.maxScrollExtent,
      );
    }
    setState(() {
      _chatLoadGeneration++;
      _currentConversationId = null;
      _chatMessages.clear();
      _oldestChatMessageCursor = null;
      _hasMoreChatMessages = false;
      _isLoadingOlderMessages = false;
      _chatController.clear();
    });
  }

  Future<void> _renameConversation(
    Map<String, dynamic> conversation, {
    void Function()? onDialogRefresh,
  }) async {
    if (_isTyping) return;
    final id = conversation['id']?.toString();
    if (id == null) return;
    final controller = TextEditingController(
      text: conversation['title']?.toString() ?? '',
    );
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة تسمية المحادثة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          textDirection: widgets.TextDirection.rtl,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          decoration: const InputDecoration(
            hintText: 'اكتب اسماً للمحادثة',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    final title = newTitle?.trim();
    if (title == null || title.isEmpty || !mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final updatedAt = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client
          .from('ai_conversations')
          .update({'title': title, 'updated_at': updatedAt})
          .eq('id', id)
          .eq('user_id', user.id)
          .select('id');
      if (!mounted) return;
      setState(() {
        final index = _aiConversations.indexWhere(
          (item) => item['id']?.toString() == id,
        );
        if (index >= 0) {
          _aiConversations[index]['title'] = title;
          _aiConversations[index]['updated_at'] = updatedAt;
          final renamed = _aiConversations.removeAt(index);
          _aiConversations.insert(0, renamed);
        }
      });
      onDialogRefresh?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إعادة تسمية المحادثة.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذرت إعادة تسمية المحادثة.')),
      );
    }
  }

  Future<void> _deleteConversation(
    Map<String, dynamic> conversation, {
    void Function()? onDialogRefresh,
  }) async {
    if (_isTyping) return;
    final id = conversation['id']?.toString();
    if (id == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المحادثة؟'),
        content: const Text(
          'سيتم حذف المحادثة وجميع رسائلها نهائياً.',
          textDirection: widgets.TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final client = Supabase.instance.client;
    try {
      await client
          .from('chat_messages')
          .delete()
          .eq('user_id', user.id)
          .eq('conversation_id', id);
      final deleted = await client
          .from('ai_conversations')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id)
          .select('id');
      if (deleted.isEmpty) {
        throw StateError('Conversation was not deleted');
      }

      if (!mounted) return;
      setState(() {
        _aiConversations.removeWhere((item) => item['id']?.toString() == id);
        if (_currentConversationId == id) {
          _currentConversationId = null;
          _chatLoadGeneration++;
          _chatMessages.clear();
          _oldestChatMessageCursor = null;
          _hasMoreChatMessages = false;
          _isLoadingOlderMessages = false;
        }
      });
      onDialogRefresh?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المحادثة ورسائلها.')),
      );
    } catch (error) {
      debugPrint('Error deleting AI conversation and messages: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف المحادثة ورسائلها.')),
      );
    }
  }

  void _showConversationPicker() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: SafeArea(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SizedBox(
                    height: MediaQuery.of(dialogContext).size.height * 0.74,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Color(0xFFF7F8FC)),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'محادثاتي',
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1D2433),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_aiConversations.length} محادثة محفوظة',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF778198),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'سجل المحادثات',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF35415A),
                                    ),
                                  ),
                                ),
                                Text(
                                  'الأحدث أولاً',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: primaryColor.withAlpha(180),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _aiConversations.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 62,
                                          height: 62,
                                          decoration: BoxDecoration(
                                            color: primaryColor.withAlpha(14),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.forum_outlined,
                                            size: 27,
                                            color: primaryColor.withAlpha(170),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'لا توجد محادثات بعد',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'ابدأ محادثة جديدة وسيظهر سجلّك هنا',
                                          style: TextStyle(
                                            color: Color(0xFF8992A4),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      2,
                                      16,
                                      20,
                                    ),
                                    itemCount: _aiConversations.length,
                                    itemBuilder: (context, index) {
                                      final conversation =
                                          _aiConversations[index];
                                      final id = conversation['id']?.toString();
                                      final isSelected =
                                          id == _currentConversationId;
                                      final updatedAt =
                                          DateTime.tryParse(
                                            conversation['updated_at']
                                                    ?.toString() ??
                                                '',
                                          )?.toLocal() ??
                                          DateTime.now();
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 9,
                                        ),
                                        child: Material(
                                          color: isSelected
                                              ? primaryColor.withAlpha(13)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            17,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              17,
                                            ),
                                            onTap: () => _selectConversation(
                                              conversation,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 13,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(17),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? primaryColor.withAlpha(
                                                          70,
                                                        )
                                                      : const Color(0xFFE9ECF2),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? primaryColor
                                                          : const Color(
                                                              0xFFF0F2F7,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            13,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.forum_outlined,
                                                      size: 18,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF657087,
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          conversation['title']
                                                                  ?.toString() ??
                                                              'محادثة جديدة',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          _getRelativeTime(
                                                            updatedAt,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                                color: Color(
                                                                  0xFF8992A4,
                                                                ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuButton<String>(
                                                    tooltip: 'خيارات المحادثة',
                                                    enabled: !_isTyping,
                                                    icon: Icon(
                                                      Icons.more_vert_rounded,
                                                      size: 20,
                                                      color: isSelected
                                                          ? primaryColor
                                                          : const Color(
                                                              0xFFABB2C0,
                                                            ),
                                                    ),
                                                    onSelected: (action) {
                                                      if (action == 'rename') {
                                                        _renameConversation(
                                                          conversation,
                                                          onDialogRefresh: () =>
                                                              setDialogState(
                                                                () {},
                                                              ),
                                                        );
                                                      } else if (action ==
                                                          'delete') {
                                                        _deleteConversation(
                                                          conversation,
                                                          onDialogRefresh: () =>
                                                              setDialogState(
                                                                () {},
                                                              ),
                                                        );
                                                      }
                                                    },
                                                    itemBuilder: (_) => [
                                                      const PopupMenuItem(
                                                        value: 'rename',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              size: 18,
                                                            ),
                                                            SizedBox(width: 10),
                                                            Text(
                                                              'إعادة التسمية',
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              size: 18,
                                                              color: Color(
                                                                0xFFB42318,
                                                              ),
                                                            ),
                                                            SizedBox(width: 10),
                                                            Text(
                                                              'حذف المحادثة',
                                                              style: TextStyle(
                                                                color: Color(
                                                                  0xFFB42318,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFFE9ECF2)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: const Text(
                                      'إلغاء',
                                      style: TextStyle(
                                        color: Color(0xFF657087),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      _startNewConversation();
                                    },
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('محادثة جديدة'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
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
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _AiUsageBorderPainter(
                        progress: _aiQuotaLoaded
                            ? (_aiMessagesCount / 50).clamp(0.0, 1.0).toDouble()
                            : 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _createConversation(String firstMessage) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final title = firstMessage.replaceAll('\n', ' ').trim();
    final row = await Supabase.instance.client
        .from('ai_conversations')
        .insert({
          'user_id': user.id,
          'title': title.length > 48 ? '${title.substring(0, 48)}…' : title,
        })
        .select('id, title, created_at, updated_at')
        .single();
    final conversationId = row['id'].toString();
    if (!mounted) return null;
    setState(() {
      _currentConversationId = conversationId;
      _aiConversations.insert(0, Map<String, dynamic>.from(row));
    });
    return conversationId;
  }

  void _scrollToBottom({bool isInstant = false}) {
    if (_chatScrollController.hasClients) {
      if (isInstant) {
        _chatScrollController.jumpTo(
          _chatScrollController.position.maxScrollExtent,
        );
      } else {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      // إذا لم يكن جاهزاً بعد، ننتظر الإطار القادم
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToBottom(isInstant: isInstant),
      );
    }
  }

  Future<bool> _saveMessageToDB(
    String text,
    bool isMe, {
    String? imagePath,
    String? imageMimeType,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      var conversationId = _currentConversationId;
      if (conversationId == null && isMe) {
        conversationId = await _createConversation(text);
      }
      if (conversationId == null) return false;
      await Supabase.instance.client.from('chat_messages').insert({
        'user_id': user.id,
        'conversation_id': conversationId,
        'text': text,
        'is_me': isMe,
        if (imagePath != null) 'image_path': imagePath,
        if (imageMimeType != null) 'image_mime_type': imageMimeType,
      });
      final updatedAt = DateTime.now().toUtc().toIso8601String();
      try {
        await Supabase.instance.client
            .from('ai_conversations')
            .update({'updated_at': updatedAt})
            .eq('id', conversationId)
            .eq('user_id', user.id);
      } catch (e) {
        debugPrint('Error updating conversation time: $e');
      }
      if (mounted) {
        setState(() {
          final index = _aiConversations.indexWhere(
            (item) => item['id'].toString() == conversationId,
          );
          if (index >= 0) {
            _aiConversations[index]['updated_at'] = updatedAt;
            final updated = _aiConversations.removeAt(index);
            _aiConversations.insert(0, updated);
          }
        });
      }
      return true;
    } catch (e) {
      debugPrint("Error saving message to DB: $e");
      return false;
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
    // بيانات الحساب المحفوظة أحدث من بيانات فتح الصفحة.
    if (Supabase.instance.client.auth.currentUser != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is String) {
      selectedStage = args;
    } else if (args is Map<String, dynamic>) {
      // استقبال البيانات من شاشة البداية لضمان الظهور الفوري
      if (args['userName'] != null) userName = args['userName'];
      if (args['profileImage'] != null)
        _profileImagePath = args['profileImage'];
      if (args['selectedStage'] != null) selectedStage = args['selectedStage'];
    }
  }

  List<Map<String, dynamic>> _getSubjectPdfs(
    String label,
    List<Map<String, String>> defaultPdfs,
  ) {
    List<String> supabaseKeys = [];
    bool isScientific = selectedStage?.contains('علمي') ?? true;

    switch (label) {
      case 'الإسلامية':
        supabaseKeys = ['islamic'];
        break;
      case 'العربية':
        supabaseKeys = ['arabic_p1', 'arabic_p2'];
        break;
      case 'الإنكليزي':
        supabaseKeys = ['english_student', 'english_activity'];
        break;
      case 'الرياضيات':
        supabaseKeys = [isScientific ? 'math_scientific' : 'math_literary'];
        break;
      case 'الأحياء':
        supabaseKeys = ['biology'];
        break;
      case 'الكيمياء':
        supabaseKeys = ['chemistry'];
        break;
      case 'الفيزياء':
        supabaseKeys = ['physics'];
        break;
      case 'التاريخ':
        supabaseKeys = ['history'];
        break;
      case 'الجغرافية':
        supabaseKeys = ['geography'];
        break;
      case 'الاقتصاد':
        supabaseKeys = ['economics'];
        break;
      case 'الأدب والنقد':
        supabaseKeys = ['literature_literary'];
        break;
      case 'الفرنسية':
        supabaseKeys = ['french'];
        break;
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
          {'title': 'الكتاب', 'path': AppAssets.islamicPdf},
        ]),
        'exams': [
          {'title': 'اختبار شامل - الفصل الأول'},
          {'title': 'اختبار شامل - الفصل الثاني'},
        ],
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
        ],
      },
      {
        'label': 'الإنكليزي',
        'icon': Icons.language_rounded,
        'pdfs': _getSubjectPdfs('الإنكليزي', [
          {
            'title': 'الكتاب - كتاب الطالب',
            'path': AppAssets.englishStudentPdf,
          },
          {
            'title': 'الكتاب - كتاب النشاط',
            'path': AppAssets.englishActivityPdf,
          },
        ]),
        'exams': [
          {'title': 'اختبار مفردات - Unit 1'},
          {'title': 'اختبار قواعد - Unit 1'},
        ],
      },
    ];

    final List<Map<String, dynamic>> scientificSubjects = [
      {
        'label': 'الأحياء',
        'icon': Icons.biotech_rounded,
        'pdfs': _getSubjectPdfs('الأحياء', [
          {'title': 'الكتاب', 'path': AppAssets.biologyPdf},
        ]),
        'exams': [
          {'title': 'اختبار الخلية'},
          {'title': 'اختبار الأنسجة'},
        ],
      },
      {
        'label': 'الرياضيات',
        'icon': Icons.functions_rounded,
        'pdfs': _getSubjectPdfs('الرياضيات', [
          {'title': 'الكتاب', 'path': AppAssets.mathScientificPdf},
        ]),
        'exams': [
          {'title': 'اختبار الأعداد المركبة'},
          {'title': 'اختبار القطوع المخروطية'},
        ],
      },
      {
        'label': 'الكيمياء',
        'icon': Icons.science_rounded,
        'pdfs': _getSubjectPdfs('الكيمياء', [
          {'title': 'الكتاب', 'path': AppAssets.chemistryPdf},
        ]),
        'exams': [
          {'title': 'اختبار الثرموداينمك'},
          {'title': 'اختبار الاتزان الكيميائي'},
        ],
      },
      {
        'label': 'الفيزياء',
        'icon': Icons.bolt_rounded,
        'pdfs': _getSubjectPdfs('الفيزياء', [
          {'title': 'الكتاب', 'path': AppAssets.physicsPdf},
        ]),
        'exams': [
          {'title': 'اختبار المتسعات'},
          {'title': 'اختبار الحث الكهرومغناطيسي'},
        ],
      },
      {
        'label': 'الفرنسية',
        'icon': Icons.translate_rounded,
        'pdfs': _getSubjectPdfs('الفرنسية', []),
        'exams': [],
      },
    ];

    final List<Map<String, dynamic>> literarySubjects = [
      {
        'label': 'التاريخ',
        'icon': Icons.history_edu_rounded,
        'pdfs': _getSubjectPdfs('التاريخ', [
          {'title': 'الكتاب', 'path': AppAssets.historyPdf},
        ]),
        'exams': [],
      },
      {
        'label': 'الرياضيات',
        'icon': Icons.functions_rounded,
        'pdfs': _getSubjectPdfs('الرياضيات', [
          {'title': 'الكتاب', 'path': AppAssets.mathLiteraryPdf},
        ]),
        'exams': [],
      },
      {
        'label': 'الجغرافية',
        'icon': Icons.public_rounded,
        'pdfs': _getSubjectPdfs('الجغرافية', [
          {'title': 'الكتاب', 'path': AppAssets.geographyPdf},
        ]),
        'exams': [],
      },
      {
        'label': 'الاقتصاد',
        'icon': Icons.pie_chart_rounded,
        'pdfs': _getSubjectPdfs('الاقتصاد', [
          {'title': 'الكتاب', 'path': AppAssets.economicsPdf},
        ]),
        'exams': [],
      },
    ];

    return [
      ...sharedSubjects,
      ...(isScientific ? scientificSubjects : literarySubjects),
    ];
  }

  Future<bool> _showExitDialog() async {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return await showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.exit_to_app_rounded,
                      size: 45,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "مغادرة التطبيق",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "هل أنت متأكد من رغبتك في إغلاق التطبيق؟ سيتم حفظ وقت دراستك تلقائياً.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            "البقاء",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: const Text(
                            "خروج",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  void _showLimitReachedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_clock_rounded,
              size: 50,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 15),
            const Text(
              "عذراً، وصلت للحد اليومي",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _aiResetAt == null
                  ? 'وصلت للحد اليومي. يتجدد عند منتصف الليل بتوقيت بغداد.'
                  : 'وصلت للحد اليومي. يتجدد في ${DateFormat('d/M HH:mm').format(_aiResetAt!.toLocal())} بتوقيت جهازك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, height: 1.5),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("حسناً"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitDialog();
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Directionality(
        textDirection: widgets.TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false,
          // الحل الاحترافي: منع الشاشة من الانضغاط
          drawer: _buildDrawer(context, primaryColor, secondaryColor),
          appBar: AppBar(
            toolbarHeight: 80,
            backgroundColor: primaryColor,
            elevation: 4,
            shadowColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
            titleSpacing: 0,
            // إزالة المسافة التلقائية ليكون النص قريباً من الأيقونة
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
                  border: Border.all(
                    color: Colors.white.withAlpha(50),
                    width: 1.5,
                  ), // حواف بيضاء خفيفة وواضحة
                ),
                child: TabBar(
                  controller: _tabController,
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
                  tabs: [
                    const Tab(icon: Icon(Icons.home_rounded, size: 26)),
                    const Tab(icon: Icon(Icons.auto_awesome_rounded, size: 26)),
                    const Tab(icon: Icon(Icons.handyman_rounded, size: 26)),
                    Tab(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 26,
                          ),
                          if (_unreadCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 10,
                                  minHeight: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Tab(icon: Icon(Icons.emoji_events_rounded, size: 26)),
                  ],
                ),
              ),
            ),
          ),
          body: SafeArea(
            bottom: true,
            // يضمن عدم تداخل المحتوى مع أزرار النظام في الأسفل
            child: TabBarView(
              controller: _tabController,
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
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(25, 15, 25, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "باقات سند بلس",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "اختر خطة التوفير وابدأ رحلة التفوق",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required IconData icon,
    required List<Color> gradient,
    required bool isSubscribed,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isSubscribed ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withAlpha(80),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isSubscribed)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 30,
                  )
                else ...[
                  Text(
                    price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    period,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _initializeInAppPurchase() {
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _purchaseSubscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList);
      },
      onDone: () {
        _purchaseSubscription.cancel();
      },
      onError: (error) {
        debugPrint("IAP Error: $error");
      },
    );
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // العملية قيد الانتظار
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // حدث خطأ في الدفع
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // نجاح عملية الدفع!
        await _activateSubscription();
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _activateSubscription() async {
    final expiryDate = DateTime.now().add(const Duration(days: 30));
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'ads_removed_until': expiryDate.toIso8601String()})
            .eq('id', user.id);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('user_ads_removed', true);
        if (mounted) setState(() => isAdsRemoved = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تفعيل الاشتراك عبر جوجل بلاي بنجاح!"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint("DB Sync Error: $e");
      }
    }
  }

  Future<void> _buySubscription() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("متجر جوجل بلاي غير متاح على هذا الجهاز"),
          ),
        );
      }
      return;
    }

    const Set<String> ids = <String>{_noAdsId};
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(ids);

    if (response.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ من جوجل: ${response.error!.message}")),
        );
      }
      return;
    }

    if (response.productDetails.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "لم يتم العثور على المنتج في متجر جوجل (تأكد من الـ ID)",
            ),
          ),
        );
      }
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _processPayment(String type) async {
    if (type == 'ads') {
      await _buySubscription();
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
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Drawer(
      backgroundColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // رأس الدراور ملون وجذاب
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withAlpha(40),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
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
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Expanded(flex: 1, child: SizedBox(height: 20)),

                    // زر الترقية الذهبي
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                            ),
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
                              padding: EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 20,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  SizedBox(width: 15),
                                  Text(
                                    "سند بلس (الاشتراكات)",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Expanded(flex: 1, child: SizedBox(height: 10)),

                    _buildDrawerItem(
                      icon: Icons.share_rounded,
                      title: "مشاركة التطبيق",
                      color: primaryColor,
                      onTap: () async {
                        try {
                          await Share.share(
                            'حمل تطبيق سند الآن، رفيقك في طريق النجاح للدراسة والتميز! 🎓✨\nhttps://play.google.com/store/apps/details?id=com.purecompany.sanad',
                            subject: 'تطبيق سند التعليمي',
                          );
                        } catch (e) {
                          debugPrint("Share Error: $e");
                        }
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.star_rate_rounded,
                      title: "تقييم التطبيق",
                      color: primaryColor,
                      onTap: () async {
                        final url = Uri.parse(
                          'https://play.google.com/store/apps/details?id=com.purecompany.sanad',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.report_problem_rounded,
                      title: "إبلاغ عن مشكلة",
                      color: primaryColor,
                      onTap: () async {
                        try {
                          final PackageInfo packageInfo =
                              await PackageInfo.fromPlatform();
                          final DeviceInfoPlugin deviceInfo =
                              DeviceInfoPlugin();
                          String deviceData = "";

                          if (Platform.isAndroid) {
                            AndroidDeviceInfo androidInfo =
                                await deviceInfo.androidInfo;
                            deviceData =
                                "Device: ${androidInfo.model}, OS: Android ${androidInfo.version.release}";
                          } else if (Platform.isIOS) {
                            IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
                            deviceData =
                                "Device: ${iosInfo.utsname.machine}, OS: iOS ${iosInfo.systemVersion}";
                          }

                          final String email = 'admin@co-pure.com';
                          final String subject =
                              'Report Problem - Sanad v${packageInfo.version}';
                          final String body =
                              '\n\n\n--- System Info ---\n$deviceData\nApp Version: ${packageInfo.version}';

                          final Uri emailLaunchUri = Uri(
                            scheme: 'mailto',
                            path: email,
                            query:
                                'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
                          );

                          if (await canLaunchUrl(emailLaunchUri)) {
                            await launchUrl(emailLaunchUri);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "لم نجد تطبيق بريد إلكتروني مثبت",
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          debugPrint("Email Launch Error: $e");
                        }
                      },
                    ),
                    const Divider(indent: 25, endIndent: 25, height: 30),
                    _buildDrawerItem(
                      icon: Icons.info_rounded,
                      title: "عن التطبيق",
                      color: primaryColor,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            backgroundColor: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withAlpha(20),
                                      shape: BoxShape.circle,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(50),
                                      child: Image.asset(
                                        AppAssets.logo,
                                        height: 60,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    "سـنـد",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "الإصدار $_appVersion",
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "سند هو تطبيق تعليمي شامل مصمم لمساعدة الطلاب العراقيين في رحلتهم الدراسية من خلال توفير الكتب، الاختبارات، المساعد الذكي، وأدوات تنظيم الوقت.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(height: 1.6, fontSize: 14),
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        "تم",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "© 2026 PureCompany",
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const Expanded(flex: 4, child: SizedBox(height: 40)),

                    Padding(
                      padding: const EdgeInsets.all(25.0),
                      child: Text(
                        "الإصدار $_appVersion",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
        Text(
          _getGreeting(),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: "مرحباً، ",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: userName,
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          selectedStage ?? "لم يتم تحديد المرحلة",
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
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
              fontWeight: FontWeight.bold,
            ),
          ),
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
                _buildSectionHeader(
                  "المواد الدراسية",
                  "${filteredSubjects.length} مواد",
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    clipBehavior: Clip.none,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                  border: Border.all(
                    color: primaryColor.withAlpha(30),
                    width: 1,
                  ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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

        if (normalizedTitle.contains(query) ||
            normalizedLabel.contains(query)) {
          results.add({
            'title': "كتاب $subjectLabel - $title",
            'type': 'كتاب',
            'icon': Icons.menu_book_rounded,
            'onTap': () => navigateAndClear(
              '/pdf_viewer',
              arguments: {'title': title, 'pdfPath': pdfData['path']},
            ),
          });
        }
      }

      // 2. البحث في الاختبارات والوزاريات
      if (_normalizeArabic("اختبارات $subjectLabel").contains(query) ||
          _normalizeArabic("الاختبارات").contains(query)) {
        results.add({
          'title': "اختبارات $subjectLabel",
          'type': 'اختبارات',
          'icon': Icons.assignment_turned_in_rounded,
          'onTap': () => navigateAndClear(
            '/exams',
            arguments: {
              'subjectName': subjectLabel,
              'category': _getCategoryForSubject(subjectLabel),
            },
          ),
        });
      }
      if (_normalizeArabic("وزاريات $subjectLabel").contains(query) ||
          _normalizeArabic("الوزاريات").contains(query)) {
        results.add({
          'title': "وزاريات $subjectLabel",
          'type': 'وزاريات',
          'icon': Icons.account_balance_rounded,
          'onTap': () => navigateAndClear(
            '/ministerials',
            arguments: {
              'subjectName': subjectLabel,
              'category': _getCategoryForSubject(subjectLabel),
            },
          ),
        });
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
      if (subjectLabel == 'العربية' &&
          _normalizeArabic("قصائد الأدب").contains(query)) {
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
            const Text(
              "لا توجد نتائج بحث مطابقة",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey[100]!),
              ),
              child: ListTile(
                onTap: item['onTap'],
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withAlpha(20),
                  child: Icon(item['icon'], color: primaryColor, size: 22),
                ),
                title: Text(
                  item['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  item['type'],
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey[400],
                ),
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
      case 'دعاء':
        return Icons.star_rounded;
      case 'تحفيز':
        return Icons.bolt_rounded;
      case 'حلم':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.lightbulb_rounded;
    }
  }

  Widget _buildAiChatView(Color primaryColor) {
    final currentConversation = _aiConversations
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (item) => item?['id']?.toString() == _currentConversationId,
          orElse: () => null,
        );
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _chatMessages.isEmpty && !_isTyping
                    ? _buildAiWelcome(primaryColor)
                    : Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.axis == Axis.vertical &&
                                  notification.metrics.maxScrollExtent > 0 &&
                                  notification.metrics.pixels -
                                          notification
                                              .metrics
                                              .minScrollExtent <=
                                      80 &&
                                  _hasMoreChatMessages &&
                                  !_isLoadingOlderMessages) {
                                _loadOlderChatMessages();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              controller: _chatScrollController,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                145,
                              ),
                              itemCount:
                                  _chatMessages.length +
                                  (_isTyping &&
                                          (_chatMessages.isEmpty ||
                                              _chatMessages.last['isMe'] ==
                                                  true)
                                      ? 1
                                      : 0),
                              itemBuilder: (context, index) {
                                final showTypingIndicator =
                                    _isTyping &&
                                    (_chatMessages.isEmpty ||
                                        _chatMessages.last['isMe'] == true);
                                if (showTypingIndicator &&
                                    index == _chatMessages.length) {
                                  return _buildTypingIndicator(primaryColor);
                                }
                                final msg = _chatMessages[index];
                                return KeyedSubtree(
                                  key: ValueKey(msg['id'] ?? 'local-$index'),
                                  child: _buildChatBubble(
                                    msg['text'],
                                    msg['isMe'],
                                    primaryColor,
                                    retryText: msg['retryText'] as String?,
                                    retryImagePath:
                                        msg['retryImagePath'] as String?,
                                    localImagePath:
                                        msg['localImagePath'] as String?,
                                    imageUrl: msg['imageUrl'] as String?,
                                    hasStoredImage: msg['imagePath'] != null,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_isLoadingOlderMessages)
                            const Positioned(
                              top: 0,
                              left: 20,
                              right: 20,
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        ],
                      ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [_buildChatInput(primaryColor)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator(Color primaryColor) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9ECF2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            'سند يكتب الآن',
            style: TextStyle(
              fontSize: 12,
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 9),
          ...List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(110 + index * 35),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildAiWelcome(Color primaryColor) {
    const suggestions = [
      'ساعدني على تعويض الدروس المتراكمة',
      'ضع لي خطة مراجعة سريعة قبل الامتحان',
      'ضع لي خطة مذاكرة لليوم',
      'حل مشكلة النسيان',
      'الوقت لا يكفي ماذا افعل',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 160),
      children: [
        const Row(
          children: [
            Text(
              'ابدأ من هنا',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 7),
            Icon(Icons.bolt_rounded, size: 17, color: Color(0xFFE9A72D)),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(suggestions.length, (index) {
          final suggestion = suggestions[index];
          const icons = [
            Icons.menu_book_rounded,
            Icons.event_note_rounded,
            Icons.today_rounded,
            Icons.psychology_alt_rounded,
            Icons.hourglass_bottom_rounded,
          ];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: _isTyping
                    ? null
                    : () {
                        _chatController.text = suggestion;
                        _sendMessage();
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFFE9ECF2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 37,
                        height: 37,
                        decoration: BoxDecoration(
                          color: primaryColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icons[index],
                          size: 18,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          suggestion,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.north_west_rounded,
                        size: 16,
                        color: Color(0xFF9AA3B3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildChatInput(Color primaryColor) {
    final canSend =
        !_isTyping &&
        (_chatController.text.trim().isNotEmpty || _pendingChatImage != null);
    final isChatFocused = _chatFocusNode.hasFocus;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingChatImage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(9, 0, 9, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7EAF0)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.file(
                      File(_pendingChatImage!.path),
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'الصورة جاهزة للإرسال',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إزالة الصورة',
                    onPressed: () => setState(() => _pendingChatImage = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              textDirection: widgets.TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Tooltip(
                  message: 'المحادثات السابقة',
                  child: AnimatedScale(
                    scale: _isHistoryButtonPressed ? 0.94 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: ScaleTransition(
                      scale: _chatHistoryPulseScale,
                      child: Container(
                        width: 56,
                        height: 56,
                        margin: const EdgeInsets.only(left: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E9),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE7EAF0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF17233F).withAlpha(18),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _isTyping ? null : _showConversationPicker,
                            onTapDown: (_) =>
                                setState(() => _isHistoryButtonPressed = true),
                            onTapUp: (_) =>
                                setState(() => _isHistoryButtonPressed = false),
                            onTapCancel: () =>
                                setState(() => _isHistoryButtonPressed = false),
                            child: Icon(
                              _currentConversationId == null
                                  ? Icons.forum_outlined
                                  : Icons.chat_rounded,
                              color: Color(0xFF465064),
                              size: 23,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isChatFocused
                            ? const Color(0xFFD8B45B).withAlpha(150)
                            : const Color(0xFFE7EAF0),
                      ),
                      boxShadow: [
                        if (isChatFocused)
                          BoxShadow(
                            color: const Color(0xFFE9B642).withAlpha(24),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        BoxShadow(
                          color: const Color(0xFF17233F).withAlpha(22),
                          blurRadius: 22,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Row(
                      textDirection: widgets.TextDirection.ltr,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: (_isTyping || canSend)
                                ? const Color(0xFF1D2433)
                                : const Color(0xFFD7DAE1),
                            shape: BoxShape.circle,
                            boxShadow: canSend
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1D2433,
                                      ).withAlpha(35),
                                      blurRadius: 9,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: canSend ? _sendMessage : null,
                              child: Center(
                                child: _isTyping
                                    ? _buildSendingDots()
                                    : const Icon(
                                        Icons.arrow_upward_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            focusNode: _chatFocusNode,
                            minLines: 1,
                            maxLines: 4,
                            keyboardType: TextInputType.multiline,
                            textInputAction: _chatController.text.trim().isEmpty
                                ? TextInputAction.done
                                : TextInputAction.newline,
                            textDirection: widgets.TextDirection.rtl,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              if (_chatController.text.trim().isEmpty) {
                                _chatFocusNode.unfocus();
                              }
                            },
                            decoration: const InputDecoration(
                              hintText: 'اسأل سند...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF929BAD),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Tooltip(
                          message: 'إرفاق صورة',
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _isTyping ? null : _pickChatImage,
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  Icons.add_rounded,
                                  color: Color(0xFF465064),
                                  size: 25,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendingDots() => AnimatedBuilder(
    animation: _sendDotsController,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final phase = (_sendDotsController.value + index / 3) % 1;
        final lift = phase < 0.5 ? phase * 8 : (1 - phase) * 8;
        return Transform.translate(
          offset: Offset(0, -lift),
          child: Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    ),
  );

  Future<void> _pickChatImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (image != null && mounted) {
        setState(() => _pendingChatImage = image);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر اختيار الصورة. حاول مجدداً.')),
      );
    }
  }

  void _showChatImageFullScreen({String? localPath, String? imageUrl}) {
    if (localPath == null && imageUrl == null) return;
    final screenSize = MediaQuery.of(context).size;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(242),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: screenSize.width,
          height: screenSize.height * 0.86,
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 4,
                    child: localPath != null
                        ? Image.file(
                            File(localPath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white,
                              size: 42,
                            ),
                          )
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(
                  tooltip: 'إغلاق الصورة',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(220),
                    foregroundColor: const Color(0xFF1D2433),
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(
    String message,
    bool isMe,
    Color primaryColor, {
    String? retryText,
    String? retryImagePath,
    String? localImagePath,
    String? imageUrl,
    bool hasStoredImage = false,
  }) {
    final hasImage =
        localImagePath != null || imageUrl != null || hasStoredImage;
    final image = hasImage
        ? GestureDetector(
            onTap: localImagePath != null || imageUrl != null
                ? () => _showChatImageFullScreen(
                    localPath: localImagePath,
                    imageUrl: imageUrl,
                  )
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: localImagePath != null
                  ? Image.file(
                      File(localImagePath),
                      width: 220,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 220,
                        height: 120,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    )
                  : imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      width: 220,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 220,
                        height: 120,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    )
                  : const SizedBox(
                      width: 220,
                      height: 120,
                      child: Center(child: Text('تعذر تحميل الصورة')),
                    ),
            ),
          )
        : const SizedBox.shrink();
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isMe ? 0.80 : 0.88),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isMe
                    ? null
                    : Border.all(color: primaryColor.withAlpha(24)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF17233F).withAlpha(isMe ? 8 : 10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isMe
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasImage) image,
                        if (hasImage && message.isNotEmpty)
                          const SizedBox(height: 8),
                        if (message.isNotEmpty)
                          Text(
                            message,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectionArea(child: _buildAssistantContent(message)),
                        if (retryText == null && message.trim().isNotEmpty)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: message),
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ الإجابة'),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 14,
                                        color: Color(0xFF7E8799),
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'نسخ',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF7E8799),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (retryText != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: _isTyping
                                  ? null
                                  : () => _retryAiMessage(
                                      retryText,
                                      imagePath: retryImagePath,
                                    ),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text(
                                'إعادة المحاولة',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantContent(String message) {
    final mathPattern = RegExp(
      r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|\$([^$\n]+)\$',
    );
    final children = <Widget>[];
    var cursor = 0;
    for (final match in mathPattern.allMatches(message)) {
      if (match.start > cursor) {
        children.add(
          _buildAssistantMarkdown(message.substring(cursor, match.start)),
        );
      }
      final displayMath = match.group(1) ?? match.group(2);
      final expression = displayMath ?? match.group(3) ?? match.group(4) ?? '';
      final isDisplay = displayMath != null;
      children.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: isDisplay ? 8 : 3),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableMath.tex(
              expression.trim(),
              mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
              textStyle: const TextStyle(color: Colors.black87, fontSize: 16),
              onErrorFallback: (_) => SelectableText(expression),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < message.length || children.isEmpty) {
      children.add(_buildAssistantMarkdown(message.substring(cursor)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildAssistantMarkdown(String text) => MarkdownBody(
    data: text,
    selectable: true,
    styleSheet: MarkdownStyleSheet(
      p: const TextStyle(
        color: Colors.black87,
        fontSize: 14,
        fontFamily: 'Tajawal',
      ),
      strong: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'Tajawal',
      ),
      listBullet: const TextStyle(color: Colors.black87, fontSize: 14),
    ),
  );

  Widget _buildToolsView(Color primaryColor, Color secondaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("الأدوات التعليمية", "4 أدوات"),
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
                  secondaryColor: secondaryColor,
                ),
                _buildToolListItem(
                  label: 'بومودورو',
                  icon: Icons.timer_outlined,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                ),
                _buildToolListItem(
                  label: 'ملاحظات',
                  icon: Icons.note_alt_rounded,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                ),
                _buildToolListItem(
                  label: 'العد التنازلي',
                  icon: Icons.timer_rounded,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return "الآن";
    } else if (difference.inMinutes < 60) {
      return "منذ ${difference.inMinutes} دقيقة";
    } else if (difference.inHours < 24) {
      return "منذ ${difference.inHours} ساعة";
    } else if (difference.inDays == 1) {
      return "أمس";
    } else if (difference.inDays < 7) {
      return "منذ ${difference.inDays} أيام";
    } else {
      // بعد أسبوع، يظهر التاريخ بشكل ثابت
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);

      debugPrint("DB: Notification $id marked as read");

      if (mounted) {
        setState(() {
          final index = _liveNotifications.indexWhere(
            (n) => n['id'].toString() == id,
          );
          if (index != -1) {
            _liveNotifications[index]['is_read'] = true;
            _unreadCount = _liveNotifications
                .where((n) => n['is_read'] != true)
                .length;
          }
        });
      }
    } catch (e) {
      debugPrint("Error marking as read in DB: $e");
    }
  }

  Future<void> _showNotificationDialog(
    Map<String, dynamic> notification,
  ) async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    // تحديد كـ مقروء عند الفتح إذا لم يكن مقروءاً مسبقاً
    if (notification['is_read'] != true) {
      _markAsRead(notification['id'].toString());
    }

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
                  color: secondaryColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 40,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                notification['title'] ?? "تنبيه",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    notification['body'] ?? "",
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "تم",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsView(Color primaryColor, Color secondaryColor) {
    if (_isLoadingNotifications)
      return const Center(child: CircularProgressIndicator());

    if (_liveNotifications.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "لا توجد إشعارات حالياً",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _liveNotifications.length,
      itemBuilder: (context, index) {
        final notification = _liveNotifications[index];
        final String id = notification['id'].toString();

        String timeText = "منذ قليل";
        try {
          final DateTime createdAt = DateTime.parse(notification['created_at']);
          timeText = _getRelativeTime(createdAt.toLocal());
        } catch (e) {
          debugPrint("Date Parse Error: $e");
        }

        return Dismissible(
          key: Key(id),
          direction: DismissDirection.startToEnd,
          onDismissed: (direction) {
            setState(() {
              _liveNotifications.removeAt(index);
            });
            _deleteNotification(id);
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
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: ListTile(
              onTap: () => _showNotificationDialog(notification),
              contentPadding: const EdgeInsets.all(15),
              leading: CircleAvatar(
                backgroundColor: notification['is_read'] == true
                    ? Colors.grey[200]
                    : secondaryColor.withAlpha(25),
                child: Icon(
                  notification['is_read'] == true
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_active_outlined,
                  color: notification['is_read'] == true
                      ? Colors.grey
                      : secondaryColor,
                ),
              ),
              title: Text(
                notification['title'] ?? "",
                style: TextStyle(
                  fontWeight: notification['is_read'] == true
                      ? FontWeight.normal
                      : FontWeight.bold,
                  color: notification['is_read'] == true
                      ? Colors.grey[600]
                      : primaryColor,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(
                    notification['body'] ?? "",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeText,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardView(Color primaryColor, Color secondaryColor) {
    if (_isLoadingLeaderboard)
      return const Center(child: CircularProgressIndicator());
    if (_leaderboardUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              "لا توجد بيانات حالياً",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
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
        SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildSectionHeader("المتصدرين", "أفضل 50 طالب"),
              const SizedBox(height: 40),
              // منصة التتويج (أول 3)
              if (_leaderboardUsers.length >= 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildPodiumUser(
                          user: _leaderboardUsers[1],
                          rank: 2,
                          height: 140,
                          primaryColor: primaryColor,
                          secondaryColor: secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPodiumUser(
                          user: _leaderboardUsers[0],
                          rank: 1,
                          height: 180,
                          hasCrown: true,
                          primaryColor: primaryColor,
                          secondaryColor: secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPodiumUser(
                          user: _leaderboardUsers[2],
                          rank: 3,
                          height: 110,
                          primaryColor: primaryColor,
                          secondaryColor: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_leaderboardUsers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_leaderboardUsers.length > 1)
                        Expanded(
                          child: _buildPodiumUser(
                            user: _leaderboardUsers[1],
                            rank: 2,
                            height: 140,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                          ),
                        ),
                      if (_leaderboardUsers.length > 1)
                        const SizedBox(width: 8),
                      Expanded(
                        child: _buildPodiumUser(
                          user: _leaderboardUsers[0],
                          rank: 1,
                          height: 180,
                          hasCrown: true,
                          primaryColor: primaryColor,
                          secondaryColor: secondaryColor,
                        ),
                      ),
                      if (_leaderboardUsers.length > 2)
                        const SizedBox(width: 8),
                      if (_leaderboardUsers.length > 2)
                        Expanded(
                          child: _buildPodiumUser(
                            user: _leaderboardUsers[2],
                            rank: 3,
                            height: 110,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
              _buildLeaderList(primaryColor),
              const SizedBox(height: 120), // مساحة إضافية للبار العائم
            ],
          ),
        ),
        if (userData != null)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              // تصغير البادينج العمودي
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
                  _buildUserCircle(
                    userData['profile_image'],
                    userData['full_name'] ?? "أنت",
                    20,
                    Colors.white,
                  ), // تصغير قطر الدائرة
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                            ? DecorationImage(
                                image: NetworkImage(_profileImagePath!),
                                fit: BoxFit.cover,
                              )
                            : DecorationImage(
                                image: FileImage(File(_profileImagePath!)),
                                fit: BoxFit.cover,
                              ))
                      : null,
                  color: Theme.of(context).colorScheme.primary.withAlpha(25),
                ),
                child: _profileImagePath == null
                    ? Center(
                        child: Text(
                          _getInitials(userName),
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 35,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (_profileImagePath != null)
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                    size: 35,
                  ),
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
                child: const Icon(
                  Icons.logout_rounded,
                  size: 50,
                  color: Colors.redAccent,
                ),
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
                      child: const Text(
                        "إلغاء",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // منطق تسجيل الخروج
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/signin',
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "خروج",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: 50,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "حذف الحساب نهائياً",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "سيؤدي هذا الإجراء إلى حذف كافة بياناتك وملاحظاتك ولا يمكن التراجع عنه. هل أنت متأكد؟",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "تراجع",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // منطق حذف الحساب
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/signup',
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "حذف الآن",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                  offset: const Offset(0, 0),
                ),
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
                    child: Text(
                      "تسجيل الخروج",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        fontSize: 16,
                      ),
                    ),
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
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDeleteAccountDialog(context),
          borderRadius: BorderRadius.circular(15),
          child: const Padding(
            padding: EdgeInsets.all(15),
            child: Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          Text(
            trailing,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
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
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/pdf_viewer',
                        arguments: {
                          'title': pdfData['title'],
                          'pdfPath': pdfData['path'],
                        },
                      );
                    });
                  },
                );
              }),
              // زر الاختبارات (مخفي لمواد معينة)
              if (![
                'الفيزياء',
                'الكيمياء',
                'الفرنسية',
              ].contains(subject['label']))
                _buildBottomSheetItem(
                  "الاختبارات",
                  Icons.assignment_turned_in_rounded,
                  primaryColor,
                  onTap: () {
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/exams',
                        arguments: {
                          'subjectName': subject['label'],
                          'category': _getCategoryForSubject(subject['label']),
                        },
                      );
                    });
                  },
                ),
              // زر الوزاريات (مخفي لمواد معينة)
              if (![
                'الفيزياء',
                'الكيمياء',
                'الفرنسية',
              ].contains(subject['label']))
                _buildBottomSheetItem(
                  "الوزاريات",
                  Icons.account_balance_rounded,
                  primaryColor,
                  onTap: () {
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/ministerials',
                        arguments: {
                          'subjectName': subject['label'],
                          'category': _getCategoryForSubject(subject['label']),
                        },
                      );
                    });
                  },
                ),
              // قسم أحكام التلاوة (فقط لمادة الإسلامية)
              if (subject['label'] == 'الإسلامية')
                _buildBottomSheetItem(
                  "أحكام التلاوة",
                  Icons.menu_book_rounded,
                  primaryColor,
                  onTap: () {
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/tajweed_rules');
                    });
                  },
                ),
              // قسم سور الحفظ (فقط لمادة الإسلامية)
              if (subject['label'] == 'الإسلامية')
                _buildBottomSheetItem(
                  "سور الحفظ",
                  Icons.menu_book_outlined,
                  primaryColor,
                  onTap: () {
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/surahs');
                    });
                  },
                ),
              // قسم الأحاديث النبوية الشريفة (فقط لمادة الإسلامية)
              if (subject['label'] == 'الإسلامية')
                _buildBottomSheetItem(
                  "الأحاديث النبوية الشريفة",
                  Icons.menu_book_rounded,
                  primaryColor,
                  onTap: () {
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/hadiths');
                    });
                  },
                ),
              // قسم قصائد الأدب (فقط لمادة العربية)
              if (subject['label'] == 'العربية')
                _buildBottomSheetItem(
                  "قصائد الأدب",
                  Icons.auto_stories_rounded,
                  primaryColor,
                  onTap: () {
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/poems');
                    });
                  },
                ),
              // قسم الإنشاءات (فقط لمادة الإنكليزي)
              if (subject['label'] == 'الإنكليزي')
                _buildBottomSheetItem(
                  "الإنشاءات",
                  Icons.edit_note_rounded,
                  primaryColor,
                  onTap: () {
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/essays');
                    });
                  },
                ),
              // قسم قطع الكتاب (فقط لمادة الإنكليزي)
              if (subject['label'] == 'الإنكليزي')
                _buildBottomSheetItem(
                  "قطع الكتاب",
                  Icons.book_rounded,
                  primaryColor,
                  onTap: () {
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/book_passages');
                    });
                  },
                ),
              // قسم الرسومات (فقط لمادة الأحياء)
              if (subject['label'] == 'الأحياء')
                _buildBottomSheetItem(
                  "الرسومات",
                  Icons.palette_rounded,
                  primaryColor,
                  onTap: () {
                    _adHelper.showRewardedAd(() {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/biology_diagrams');
                    });
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetItem(
    String title,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: ListTile(
        onTap: onTap ?? () => Navigator.pop(context),
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(20),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color.withAlpha(200),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _buildPodiumUser({
    required Map<String, dynamic> user,
    required int rank,
    required double height,
    bool hasCrown = false,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final String name = user['full_name'] ?? "طالب";
    final String? imageUrl = user['profile_image'];
    final String? stage = user['stage'];
    final int studyTime = user['weekly_study_time'] ?? 0;

    return Column(
      children: [
        if (hasCrown)
          const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.amber,
            size: 35,
          ),
        const SizedBox(height: 5),
        _buildUserCircle(imageUrl, name, 30, primaryColor),
        const SizedBox(height: 10),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.visible,
        ),
        if (stage != null && stage.isNotEmpty)
          Text(
            stage,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 4),
        Text(
          _formatDuration(studyTime),
          style: TextStyle(
            color: secondaryColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: Center(
            child: Text(
              "$rank",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCircle(
    String? imageUrl,
    String name,
    double radius,
    Color primaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: primaryColor.withAlpha(50), width: 2),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: primaryColor.withAlpha(20),
        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
            ? (imageUrl.startsWith('http')
                  ? NetworkImage(imageUrl)
                  : FileImage(File(imageUrl)) as ImageProvider)
            : null,
        child: (imageUrl == null || imageUrl.isEmpty)
            ? Text(
                _getInitials(name),
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.8,
                ),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  "${index + 4}",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 15),
                _buildUserCircle(imageUrl, name, 22, primaryColor),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (stage != null)
                        Text(
                          stage,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _formatDuration(studyTime),
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolListItem({
    required String label,
    required IconData icon,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
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
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          // يجعل تأثير الضغط دائرياً بنفس حواف الحاوية
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

  int _getSectionsCount(Map<String, dynamic> subject) {
    int count = 0;
    final String label = subject['label'] ?? "";

    // 1. الكتب (PDFs)
    if (subject['pdfs'] != null) {
      count += (subject['pdfs'] as List).length;
    }

    // 2. الاختبارات والوزاريات (موجودة لبعض المواد فقط حالياً)
    final List<String> excludedSubjects = ['الفيزياء', 'الكيمياء', 'الفرنسية'];
    String category = _getCategoryForSubject(label);

    if (!excludedSubjects.contains(label)) {
      count += 2; // الاختبارات + الوزاريات
    }

    // 4. أقسام إضافية تختلف حسب المادة
    if (label == 'الإسلامية') {
      count += 3; // أحكام التلاوة، سور الحفظ، الأحاديث النبوية
    } else if (label == 'العربية') {
      count += 1; // قصائد الأدب
    } else if (label == 'الإنكليزي') {
      count += 2; // الإنشاءات، قطع الكتاب
    } else if (label == 'الأحياء') {
      count += 1; // الرسومات
    }

    return count;
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    final int sectionCount = _getSectionsCount(subject);

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
