import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

class _RoundedTabIndicator extends Decoration {
  const _RoundedTabIndicator({
    required this.color,
    this.height = 4,
    this.horizontalInset = 8,
  });

  final Color color;
  final double height;
  final double horizontalInset;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _RoundedTabIndicatorPainter(this, onChanged);
}

class _RoundedTabIndicatorPainter extends BoxPainter {
  _RoundedTabIndicatorPainter(this._decoration, super.onChanged);

  final _RoundedTabIndicator _decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;

    final indicatorWidth = size.width - (_decoration.horizontalInset * 2);
    if (indicatorWidth <= 0) return;

    final rect = Rect.fromLTWH(
      offset.dx + _decoration.horizontalInset,
      offset.dy + size.height - _decoration.height,
      indicatorWidth,
      _decoration.height,
    );
    final paint = Paint()..color = _decoration.color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(_decoration.height / 2)),
      paint,
    );
  }

}

class _HomeShortcut {
  const _HomeShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _StudyQuote {
  const _StudyQuote(this.text, this.source);

  final String text;
  final String source;

  bool get isQuran => source.startsWith('سورة ');
}

class _HomePageScreenState extends State<HomePageScreen>
    with TickerProviderStateMixin {
  static const double _homeHeaderScrollInset = 124;
  final AdHelper _adHelper = AdHelper();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  static const String _noAdsId =
      'sanad_premium_monthly'; // نفس المعرف في جوجل بلاي

  // منطق العد التنازلي
  late Timer _timer;
  Duration _timeLeft = const Duration(days: 45, hours: 12, minutes: 30);
  final PageController _quickShortcutsController = PageController(
    initialPage: 600,
    viewportFraction: 0.62,
  );
  final PageController _studySuggestionsController = PageController(
    initialPage: 5000,
    viewportFraction: 0.84,
  );
  Timer? _quickShortcutsTimer;
  Timer? _studySuggestionsTimer;
  Timer? _studyQuoteTimer;
  final Random _studyQuoteRandom = Random();
  List<_StudyQuote> _studyQuotes = [];
  int _studyQuoteIndex = 0;


  String userName = "الطالب";
  String userEmail = "user@email.com";
  String? _profileImagePath;
  String? selectedStage;
  bool _isDrawerOpen = false;
  bool isAdsRemoved = false;
  DateTime? _aiResetAt;
  List<SubjectModel> _supabaseSubjects = [];
  bool _isLoadingSubjects = false; // حالة تحميل المواد

  // متغيرات تتبع الوقت والمتصدرين
  List<Map<String, dynamic>> _leaderboardUsers = [];
  bool _isLoadingLeaderboard = false;
  String? _leaderboardError;
  int? _currentUserLeaderboardRank;
  Map<String, dynamic>? _currentUserLeaderboardData;
  int _leaderboardRankRequestId = 0;
  bool _isFetchingCurrentUserRank = false;
  Timer? _leaderboardRankRefreshTimer;
  StreamSubscription? _leaderboardSubscription;

  // متغيرات الإشعارات
  List<Map<String, dynamic>> _liveNotifications = [];
  final ValueNotifier<int> _notificationsPageRevision = ValueNotifier(0);
  final Map<String, (Map<String, dynamic>, int)> _pendingNotificationDeletes = {};
  final Map<String, Map<String, dynamic>> _recentlyRestoredNotifications = {};
  final Map<String, int> _notificationDismissGenerations = {};
  Timer? _notificationDeleteTimer;
  Timer? _undoSnackBarTimer;
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

  // Gemini AI Variables
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  late final AnimationController _sendDotsController;
  late final AnimationController _chatGlowController;
  XFile? _pendingChatImage;
  final ScrollController _chatScrollController = ScrollController(
    keepScrollOffset: true,
  );
  late TabController _tabController;
  final List<Map<String, dynamic>> _chatMessages = [];
  final ValueNotifier<String> _liveAssistantText = ValueNotifier('');
  Map<String, dynamic>? _liveAssistantMessage;
  final List<Map<String, dynamic>> _aiConversations = [];
  final Map<String, Map<String, dynamic>> _pendingConversationDeletes = {};
  Timer? _conversationDeleteTimer;
  static const int _chatPageSize = 30;
  Map<String, dynamic>? _oldestChatMessageCursor;
  int _chatLoadGeneration = 0;
  bool _hasMoreChatMessages = false;
  bool _isLoadingOlderMessages = false;
  String? _currentConversationId;
  bool _isTyping = false;
  bool _isAiInitialized = false;

  String _appVersion = "1.1.0";

  @override
  void initState() {
    super.initState();
    _loadStudyQuotes();
    _sendDotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _chatGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _chatFocusNode.addListener(() {
      if (_chatFocusNode.hasFocus) {
        _chatGlowController.stop();
      } else {
        _chatGlowController.repeat();
      }
      if (mounted) setState(() {});
    });
    // تصفير القيم عند الدخول لأول مرة فقط (للتجربة)
    isAdsRemoved = false;

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _loadUserData();
    _startCountdown();
    _tabController = TabController(length: 4, vsync: this);
    _quickShortcutsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted ||
          _tabController.index != 0 ||
          !_quickShortcutsController.hasClients) {
        return;
      }
      final nextPage = (_quickShortcutsController.page?.round() ?? 600) + 1;
      _quickShortcutsController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _loadAiLimit();
      }
    });
    _studySuggestionsTimer = Timer.periodic(
      const Duration(milliseconds: 2600),
      (_) {
        if (!mounted ||
            _tabController.index != 1 ||
            _chatMessages.isNotEmpty ||
            !_studySuggestionsController.hasClients) {
          return;
        }
        final nextPage =
            (_studySuggestionsController.page?.round() ?? 5000) + 1;
        _studySuggestionsController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeInOutCubic,
        );
      },
    );
    _studyQuoteTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _tabController.index != 0 || _studyQuotes.length < 2) {
        return;
      }
      setState(() {
        final previousIndex = _studyQuoteIndex;
        var nextIndex = _studyQuoteRandom.nextInt(_studyQuotes.length - 1);
        if (nextIndex >= previousIndex) nextIndex++;
        _studyQuoteIndex = nextIndex;
      });
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

  Future<void> _loadStudyQuotes() async {
    try {
      final json = await rootBundle.loadString('assets/jsons/study_quotes.json');
      final decoded = jsonDecode(json);
      if (decoded is! List) return;

      final quotes = decoded
          .whereType<Map<String, dynamic>>()
          .where((item) => item['text'] is String && item['source'] is String)
          .map(
            (item) => _StudyQuote(
              item['text'] as String,
              item['source'] as String,
            ),
          )
          .toList();
      if (!mounted || quotes.isEmpty) return;

      setState(() {
        _studyQuotes = quotes;
        _studyQuoteIndex = _studyQuoteRandom.nextInt(quotes.length);
      });
    } catch (error) {
      debugPrint('تعذر تحميل الاقتباسات: $error');
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _quickShortcutsTimer?.cancel();
    _studySuggestionsTimer?.cancel();
    _studyQuoteTimer?.cancel();
    _quickShortcutsController.dispose();
    _studySuggestionsController.dispose();
    _chatController.dispose();
    _liveAssistantText.dispose();
    _chatFocusNode.dispose();
    _sendDotsController.dispose();
    _chatGlowController.dispose();
    _chatScrollController.dispose();
    _tabController.dispose();
    _notificationsSubscription?.cancel();
    _undoSnackBarTimer?.cancel();
    _notificationsPageRevision.dispose();
    _leaderboardSubscription?.cancel();
    _leaderboardRankRefreshTimer?.cancel();
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

  void _setTypingState(bool isTyping) {
    _isTyping = isTyping;
    if (isTyping) {
      _sendDotsController.repeat(reverse: true);
    } else {
      _sendDotsController.stop();
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

    await _leaderboardSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoadingLeaderboard = true;
      _leaderboardError = null;
    });

    // اطلب أفضل 50 من الخادم مباشرة بدلاً من تنزيل كل الملفات الشخصية وترتيبها محلياً.
    _leaderboardSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .gte('weekly_study_time', 0)
        .order('weekly_study_time', ascending: false)
        .limit(50)
        .listen(
          (data) {
            if (mounted) {
              final users = List<Map<String, dynamic>>.from(data);
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              final currentUserIndex = currentUserId == null
                  ? -1
                  : users.indexWhere((user) => user['id'] == currentUserId);
              if (currentUserIndex >= 0) _leaderboardRankRequestId++;
              setState(() {
                _leaderboardUsers = users;
                _isLoadingLeaderboard = false;
                _leaderboardError = null;
                if (currentUserIndex >= 0) {
                  _currentUserLeaderboardRank = currentUserIndex + 1;
                  _currentUserLeaderboardData = users[currentUserIndex];
                }
              });

              if (currentUserId != null &&
                  currentUserIndex < 0 &&
                  !_isFetchingCurrentUserRank) {
                if (_currentUserLeaderboardData == null) {
                  _fetchCurrentUserLeaderboardPosition(currentUserId);
                } else {
                  _scheduleCurrentUserRankRefresh(currentUserId);
                }
              } else if (currentUserIndex >= 0) {
                _leaderboardRankRefreshTimer?.cancel();
              }
            }
          },
          onError: (error) {
            debugPrint("Leaderboard Realtime Error: $error");
            if (mounted) {
              setState(() {
                _isLoadingLeaderboard = false;
                _leaderboardError = error.toString();
              });
            }
          },
        );
  }

  void _scheduleCurrentUserRankRefresh(String userId) {
    _leaderboardRankRefreshTimer?.cancel();
    _leaderboardRankRefreshTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isFetchingCurrentUserRank) {
        _fetchCurrentUserLeaderboardPosition(userId);
      }
    });
  }

  Future<void> _fetchCurrentUserLeaderboardPosition(String userId) async {
    if (_isFetchingCurrentUserRank) return;
    _isFetchingCurrentUserRank = true;
    final requestId = ++_leaderboardRankRequestId;
    try {
      final client = Supabase.instance.client;
      final user = await client
          .from('profiles')
          .select('id, full_name, profile_image, stage, weekly_study_time')
          .eq('id', userId)
          .maybeSingle();

      if (user == null) return;
      final studyTime = int.tryParse('${user['weekly_study_time'] ?? 0}') ?? 0;
      final higherRankedUsersCount = await client
          .from('profiles')
          .count()
          .gt('weekly_study_time', studyTime);

      if (!mounted || requestId != _leaderboardRankRequestId) return;
      setState(() {
        _currentUserLeaderboardData = Map<String, dynamic>.from(user);
        _currentUserLeaderboardRank = higherRankedUsersCount + 1;
      });
    } catch (error) {
      debugPrint('تعذر جلب ترتيب المستخدم في المتصدرين: $error');
    } finally {
      _isFetchingCurrentUserRank = false;
    }
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
                final snapshot = List<Map<String, dynamic>>.from(data)
                    .where((item) => !_pendingNotificationDeletes.containsKey(item['id'].toString()))
                    .toList();
                final snapshotIds = snapshot.map((item) => item['id'].toString()).toSet();
                for (final entry in _recentlyRestoredNotifications.entries) {
                  if (snapshotIds.add(entry.key)) snapshot.add(entry.value);
                }
                _liveNotifications = snapshot;
                _recentlyRestoredNotifications.removeWhere((id, _) => snapshotIds.contains(id));
                _unreadCount = _liveNotifications
                    .where((n) => n['is_read'] != true)
                    .length;
                _isLoadingNotifications = false;
              });
              _refreshNotificationsPage();
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
        _refreshNotificationsPage();
      }
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  void _refreshNotificationsPage() {
    _notificationsPageRevision.value++;
  }

  void _scheduleNotificationDelete(Map<String, dynamic> notification, int index) {
    final id = notification['id'].toString();
    _pendingNotificationDeletes[id] = (Map<String, dynamic>.from(notification), index);
    _notificationDeleteTimer?.cancel();
    _notificationDeleteTimer = Timer(const Duration(seconds: 5), _commitNotificationDeletes);
    _showUndoSnackBar('تم حذف الإشعار', _undoNotificationDeletes);
  }

  void _undoNotificationDeletes() {
    if (!mounted || _pendingNotificationDeletes.isEmpty) return;
    _notificationDeleteTimer?.cancel();
    _undoSnackBarTimer?.cancel();
    final pending = _pendingNotificationDeletes.values.toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    for (final entry in pending) {
      final id = entry.$1['id'].toString();
      _recentlyRestoredNotifications[id] = entry.$1;
      _notificationDismissGenerations[id] =
          (_notificationDismissGenerations[id] ?? 0) + 1;
    }
    setState(() {
      for (final entry in pending) {
        final index = entry.$2.clamp(0, _liveNotifications.length).toInt();
        _liveNotifications.insert(index, entry.$1);
      }
      _pendingNotificationDeletes.clear();
      _unreadCount = _liveNotifications.where((n) => n['is_read'] != true).length;
    });
    _refreshNotificationsPage();
    _refreshNotificationsAfterUndo();
  }

  Future<void> _refreshNotificationsAfterUndo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        final refreshed = List<Map<String, dynamic>>.from(rows);
        final ids = refreshed.map((item) => item['id'].toString()).toSet();
        _recentlyRestoredNotifications.removeWhere((id, _) => ids.contains(id));
        for (final entry in _recentlyRestoredNotifications.entries) {
          if (ids.add(entry.key)) refreshed.add(entry.value);
        }
        for (final item in _liveNotifications) {
          if (ids.add(item['id'].toString())) refreshed.add(item);
        }
        _liveNotifications = refreshed;
        _unreadCount = refreshed.where((n) => n['is_read'] != true).length;
      });
      _refreshNotificationsPage();
    } catch (error) {
      debugPrint('Could not refresh notifications after undo: $error');
    }
  }

  Future<void> _commitNotificationDeletes() async {
    final ids = _pendingNotificationDeletes.keys.toList();
    _pendingNotificationDeletes.clear();
    for (final id in ids) {
      try {
        await Supabase.instance.client.from('notifications').delete().eq('id', id);
      } catch (e) {
        debugPrint('Error deleting notification: $e');
      }
    }
  }

  void _showUndoSnackBar(String message, VoidCallback onUndo) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'تراجع',
          textColor: const Color(0xFFF2B833),
          onPressed: onUndo,
        ),
      ));
    _undoSnackBarTimer?.cancel();
    _undoSnackBarTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) messenger.hideCurrentSnackBar();
    });
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return "$hours س $minutes د";
    return "$minutes دقيقة";
  }

  String _getGreeting() {
    return DateTime.now().hour < 12 ? 'صباح الخير' : 'مساء الخير';
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
    setState(() {
      _aiResetAt = DateTime.tryParse(usage['reset_at']?.toString() ?? '');
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
    } catch (_) {}
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
      _setTypingState(true);
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
          _setTypingState(false);
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
        _setTypingState(false);
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
          if (liveReply == null) {
            liveReply = {'text': text, 'isMe': false};
            _chatMessages.add(liveReply!);
            _liveAssistantMessage = liveReply;
            _liveAssistantText.value = text;
            setState(() {});
          } else {
            liveReply!['text'] = text;
            _liveAssistantText.value = text;
          }
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
        _liveAssistantMessage = null;
      });
      await _saveMessageToDB(responseText!, false);
    } catch (e) {
      if (!mounted) return;
      if (liveReply != null) {
        setState(() {
          _chatMessages.remove(liveReply);
          _liveAssistantMessage = null;
          _liveAssistantText.value = '';
        });
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
                'incomplete_response' =>
                  'لم يكتمل الرد بالكامل. أعد المحاولة للحصول على الإجابة كاملة.',
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
        setState(() => _setTypingState(false));
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
      var publishedLength = 0;
      final uiUpdateClock = Stopwatch()..start();
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
          if (publishedLength == 0 || uiUpdateClock.elapsedMilliseconds >= 50) {
            onToken(answer.toString());
            publishedLength = answer.length;
            uiUpdateClock.reset();
          }
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
      if (answer.length != publishedLength) onToken(answer.toString());
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
      _setTypingState(true);
    });
    _scrollToBottom();
    Map<String, dynamic>? liveReply;
    try {
      final response = await _getGroqResponse(
        message,
        imagePath: imagePath,
        onToken: (text) {
          if (!mounted) return;
          if (liveReply == null) {
            liveReply = {'text': text, 'isMe': false};
            _chatMessages.add(liveReply!);
            _liveAssistantMessage = liveReply;
            _liveAssistantText.value = text;
            setState(() {});
          } else {
            liveReply!['text'] = text;
            _liveAssistantText.value = text;
          }
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
        _liveAssistantMessage = null;
      });
      await _saveMessageToDB(response, false);
    } catch (_) {
      if (!mounted) return;
      if (liveReply != null) {
        setState(() {
          _chatMessages.remove(liveReply);
          _liveAssistantMessage = null;
          _liveAssistantText.value = '';
        });
      }
      _showErrorMessage(
        'تعذر الاتصال بالمساعد. تحقق من الإنترنت ثم أعد المحاولة.',
        retryText: message,
        retryImagePath: imagePath,
      );
    } finally {
      if (mounted) {
        setState(() => _setTypingState(false));
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
        _refreshNotificationsPage();
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
          'هل تريد حذف هذه المحادثة؟',
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

    _conversationDeleteTimer?.cancel();
    _pendingConversationDeletes[id] = Map<String, dynamic>.from(conversation);
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
    _conversationDeleteTimer = Timer(const Duration(seconds: 5), _commitConversationDeletes);
    _showUndoSnackBar('تم حذف المحادثة', _undoConversationDeletes);
  }

  void _undoConversationDeletes() {
    if (!mounted || _pendingConversationDeletes.isEmpty) return;
    _conversationDeleteTimer?.cancel();
    _undoSnackBarTimer?.cancel();
    setState(() {
      _aiConversations.addAll(
        _pendingConversationDeletes.values.map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
      _aiConversations.sort((a, b) => (b['updated_at']?.toString() ?? '').compareTo(a['updated_at']?.toString() ?? ''));
      _pendingConversationDeletes.clear();
    });
  }

  Future<void> _commitConversationDeletes() async {
    final pending = Map<String, Map<String, dynamic>>.from(_pendingConversationDeletes);
    _pendingConversationDeletes.clear();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _aiConversations.addAll(pending.values);
          _aiConversations.sort((a, b) => (b['updated_at']?.toString() ?? '').compareTo(a['updated_at']?.toString() ?? ''));
        });
      }
      return;
    }
    final client = Supabase.instance.client;
    try {
      for (final id in pending.keys) {
      final imageRows = await client
          .from('chat_messages')
          .select('image_path')
          .eq('user_id', user.id)
          .eq('conversation_id', id);
      final imagePaths = imageRows
          .map((row) => row['image_path']?.toString())
          .whereType<String>()
          .where((path) => path.startsWith('${user.id}/'))
          .toSet()
          .toList();

      for (var start = 0; start < imagePaths.length; start += 100) {
        final end = start + 100 < imagePaths.length
            ? start + 100
            : imagePaths.length;
        await client.storage
            .from('sanad-ai-chat-images')
            .remove(imagePaths.sublist(start, end));
      }

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
      }
    } catch (error) {
      debugPrint('Error deleting AI conversation, messages, or images: $error');
      if (mounted) {
        setState(() {
          _aiConversations.addAll(pending.values);
          _aiConversations.sort((a, b) => (b['updated_at']?.toString() ?? '').compareTo(a['updated_at']?.toString() ?? ''));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إكمال حذف المحادثة أو صورها.')),
        );
      }
    }
  }

  void _showConversationPicker() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق قائمة المحادثات',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          alignment: Alignment.centerRight,
          insetPadding: const EdgeInsets.fromLTRB(28, 12, 8, 12),
          constraints: BoxConstraints(
            maxWidth: min(MediaQuery.sizeOf(dialogContext).width * 0.86, 380),
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.90,
          ),
          child: SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: SizedBox(
                width: min(MediaQuery.sizeOf(dialogContext).width * 0.86, 380),
                height: MediaQuery.sizeOf(dialogContext).height * 0.90,
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
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final expansion = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return Align(
          alignment: Alignment.centerRight,
          child: ScaleTransition(
            alignment: Alignment.centerRight,
            scale: Tween<double>(begin: 0.96, end: 1).animate(expansion),
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
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
          extendBody: true,
          resizeToAvoidBottomInset: false,
          onDrawerChanged: (isOpened) {
            if (_isDrawerOpen != isOpened) {
              setState(() => _isDrawerOpen = isOpened);
            }
          },
          // الحل الاحترافي: منع الشاشة من الانضغاط
          drawer: _buildDrawer(context, primaryColor, secondaryColor),
          bottomNavigationBar: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const minNavigationWidth = 240.0;
                final sideMargin =
                    ((constraints.maxWidth - minNavigationWidth) / 2)
                        .clamp(0.0, constraints.maxWidth / 2)
                        .toDouble();
                return Container(
                  margin: EdgeInsets.fromLTRB(sideMargin, 8, sideMargin, 10),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withAlpha(50),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorWeight: 4,
                    labelColor: secondaryColor,
                    unselectedLabelColor: Colors.white70,
                    indicator: _RoundedTabIndicator(
                      color: secondaryColor,
                      height: 4,
                      horizontalInset: 17,
                    ),
                    tabs: [
                      _buildBottomNavigationTab(Icons.home_rounded, 0),
                      _buildBottomNavigationTab(Icons.auto_awesome_rounded, 1),
                      _buildBottomNavigationTab(Icons.handyman_rounded, 2),
                      _buildBottomNavigationTab(Icons.emoji_events_rounded, 3),
                    ],
                  ),
                );
              },
            ),
          ),
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: _isDrawerOpen
                ? SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: const Color(0xFFF7F8FA),
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.white,
                  ),
            child: SafeArea(
              bottom: false,
              left: false,
              right: false,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHomeView(primaryColor, secondaryColor),
                  _buildAiChatView(primaryColor),
                  _buildToolsView(),
                  _buildLeaderboardView(primaryColor, secondaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationTab(IconData icon, int index) {
    return Tab(
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final isSelected = _tabController.index == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 40,
            alignment: Alignment.center,
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Icon(icon, size: 26),
            ),
          );
        },
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

  Widget _buildUserAvatar({double radius = 23}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/profile').then((_) => _loadUserData());
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.12),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFF0F2F6),
          backgroundImage: _profileImagePath != null
              ? (_profileImagePath!.startsWith('http')
                    ? NetworkImage(_profileImagePath!) as ImageProvider
                    : FileImage(File(_profileImagePath!)))
              : null,
          child: _profileImagePath == null
              ? Text(
                  _getInitials(userName),
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: radius * 0.7,
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
    const navy = Color(0xFF1A2238);
    const gold = Color(0xFFF2B833);
    return Drawer(
      width: 330,
      backgroundColor: const Color(0xFFF7F8FA),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 21,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFFFFFFFF), Color(0xFFFFFCF3)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFE8E2D3)),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: .06),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  textDirection: widgets.TextDirection.rtl,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(19),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withValues(alpha: .09),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'سند',
                              textAlign: TextAlign.right,
                              textDirection: widgets.TextDirection.rtl,
                              style: TextStyle(
                                color: navy,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'رفيقك في طريق النجاح',
                              textAlign: TextAlign.right,
                              textDirection: widgets.TextDirection.rtl,
                              style: TextStyle(
                                color: Color(0xFF747D8E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: .13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFD49A1B),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: navy,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showSubscriptionSheet();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          navy,
                          navy.withValues(alpha: .93),
                          const Color(0xFF293653),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: .17),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: gold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'سند بلس',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'اكتشف مزايا الاشتراك',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          textDirection: widgets.TextDirection.ltr,
                          color: Colors.white70,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _drawerSectionTitle('تابع سند'),
              const SizedBox(height: 9),
              Row(
                children: [
                  _drawerSocialButton(
                    'فيسبوك',
                    SvgPicture.asset(
                      'assets/icons/social/facebook.svg',
                      width: 24,
                      height: 24,
                    ),
                    'https://www.facebook.com/share/1GhQf5Pxgw/',
                  ),
                  const SizedBox(width: 8),
                  _drawerSocialButton(
                    'تكتوك',
                    SvgPicture.asset(
                      'assets/icons/social/tiktok.svg',
                      width: 24,
                      height: 24,
                    ),
                    'https://tiktok.com/@purecompanystudio',
                  ),
                  const SizedBox(width: 8),
                  _drawerSocialButton(
                    'إنستغرام',
                    SvgPicture.asset(
                      'assets/icons/social/instagram.svg',
                      width: 24,
                      height: 24,
                    ),
                    'https://www.instagram.com/purecompanystudio?stkn=MTVvaGpkdDhsZ2M2YQ==',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _drawerSectionTitle('الدعم والمساعدة'),
              const SizedBox(height: 8),
              _drawerContactTile(
                icon: const Icon(Icons.email_outlined, size: 20),
                title: 'البريد الإلكتروني',
                subtitle: 'admin@co-pure.com',
                color: const Color(0xFF53627D),
                onTap: () => _openDrawerLink('mailto:admin@co-pure.com'),
              ),
              const SizedBox(height: 7),
              _drawerContactTile(
                icon: SvgPicture.asset(
                  'assets/icons/social/whatsapp.svg',
                  width: 20,
                  height: 20,
                ),
                title: 'واتساب للدعم',
                subtitle: 'تواصل معنا مباشرة',
                color: const Color(0xFF25D366),
                onTap: () => _openDrawerLink('https://wa.me/9647874371446'),
              ),
              const SizedBox(height: 7),
              _drawerContactTile(
                icon: SvgPicture.asset(
                  'assets/icons/social/telegram.svg',
                  width: 20,
                  height: 20,
                ),
                title: 'تلكرام للدعم',
                subtitle: 'راسل فريق سند',
                color: const Color(0xFF229ED9),
                onTap: () => _openDrawerLink('https://t.me/+9647874371446'),
              ),
              const SizedBox(height: 19),
              _drawerSectionTitle('المزيد'),
              const SizedBox(height: 7),
              _buildDrawerItem(
                icon: Icons.share_rounded,
                title: 'مشاركة التطبيق',
                color: navy,
                onTap: () async {
                  try {
                    await Share.share(
                      'حمل تطبيق سند الآن، رفيقك في طريق النجاح للدراسة والتميز! 🎓✨\nhttps://play.google.com/store/apps/details?id=com.purecompany.sanad',
                      subject: 'تطبيق سند التعليمي',
                    );
                  } catch (e) {
                    debugPrint('Share Error: $e');
                  }
                },
              ),
              _buildDrawerItem(
                icon: Icons.star_rate_rounded,
                title: 'تقييم التطبيق',
                color: navy,
                onTap: () => _openDrawerLink(
                  'https://play.google.com/store/apps/details?id=com.purecompany.sanad',
                ),
              ),
              _buildDrawerItem(
                icon: Icons.report_problem_outlined,
                title: 'إبلاغ عن مشكلة',
                color: navy,
                onTap: () async {
                  try {
                    final PackageInfo packageInfo =
                        await PackageInfo.fromPlatform();
                    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
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

                    await _openDrawerLink(emailLaunchUri.toString());
                  } catch (e) {
                    debugPrint("Email Launch Error: $e");
                  }
                },
              ),
              _buildDrawerItem(
                icon: Icons.info_outline_rounded,
                title: 'عن التطبيق',
                color: navy,
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
                                child: Image.asset(AppAssets.logo, height: 60),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "تم",
                                  style: TextStyle(fontWeight: FontWeight.bold),
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
              const SizedBox(height: 13),
              Center(
                child: Text(
                  'الإصدار $_appVersion',
                  style: const TextStyle(
                    color: Color(0xFF9AA1AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Center(
                child: Text(
                  '© PureCompany 2026',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9AA1AF), fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerSectionTitle(String title) => Row(
    children: [
      Container(
        width: 4,
        height: 17,
        decoration: BoxDecoration(
          color: const Color(0xFFF2B833),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1A2238),
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _drawerSocialButton(String label, Widget icon, String url) => Expanded(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDrawerLink(url),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EAF0)),
          ),
          child: Column(
            children: [
              icon,
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF4B5568),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _drawerContactTile({
    required Widget icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EAF0)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(width: 20, height: 20, child: icon),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1A2238),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF858D9D),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              textDirection: widgets.TextDirection.ltr,
              color: Color(0xFFA1A8B5),
              size: 13,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openDrawerLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز.')),
        );
      }
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز.')),
        );
      }
    } catch (error) {
      debugPrint('Could not open drawer link: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز.')),
        );
      }
    }
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

  Widget _buildHomeHeader(Color primaryColor, Color secondaryColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 10,
                spreadRadius: -3,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'القائمة',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 50, height: 50),
                    icon: SizedBox(
                      width: 27,
                      height: 25,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _menuBar(25, primaryColor),
                          const SizedBox(height: 4),
                          _menuBar(18, primaryColor),
                          const SizedBox(height: 4),
                          _menuBar(12, primaryColor),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedStage ?? 'لم يتم تحديد المرحلة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7B8292),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildNotificationsButton(primaryColor),
                const SizedBox(width: 8),
                _buildUserAvatar(radius: 25),
              ],
            ),
          ),
        ),
        const SizedBox(height: 34),
      ],
    );
  }

  Widget _buildNotificationsButton(Color primaryColor) {
    return IconButton(
      tooltip: 'الإشعارات',
      onPressed: _openNotificationsPage,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 25,
            color: primaryColor,
          ),
          if (_unreadCount > 0)
            Positioned(
              top: -3,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openNotificationsPage() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => Directionality(
          textDirection: widgets.TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F8FA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: primaryColor,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'الإشعارات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            body: ValueListenableBuilder<int>(
              valueListenable: _notificationsPageRevision,
              builder: (context, revision, child) =>
                  _buildNotificationsView(primaryColor, secondaryColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuBar(double width, Color color) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );

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
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: _homeHeaderScrollInset),
            child: Column(
              children: [
                _buildQuickShortcuts(primaryColor, secondaryColor),
                _buildStudyQuoteCard(primaryColor, secondaryColor),
                _buildSectionHeader(
                  'المواد الدراسية',
                  '${filteredSubjects.length} مواد',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: List.generate(
                      (filteredSubjects.length / 2).ceil(),
                      (rowIndex) {
                        final firstIndex = rowIndex * 2;
                        final secondIndex = firstIndex + 1;
                        final firstHeight = rowIndex.isEven ? 176.0 : 150.0;
                        final secondHeight = rowIndex.isEven ? 150.0 : 176.0;

                        Widget animatedSubject(int index, double height) =>
                            TweenAnimationBuilder<double>(
                              key: ValueKey(filteredSubjects[index]['label']),
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(
                                milliseconds: 360 + index * 55,
                              ),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 16 * (1 - value)),
                                  child: child,
                                ),
                              ),
                              child: _buildSubjectCard(
                                filteredSubjects[index],
                                height: height,
                              ),
                            );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: rowIndex.isEven
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: animatedSubject(firstIndex, firstHeight),
                              ),
                              const SizedBox(width: 12),
                              if (secondIndex < filteredSubjects.length)
                                Expanded(
                                  child: animatedSubject(
                                    secondIndex,
                                    secondHeight,
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildHomeHeader(primaryColor, secondaryColor),
        ),
      ],
    );
  }

  Widget _buildQuickShortcuts(Color primaryColor, Color secondaryColor) {
    final shortcuts = <_HomeShortcut>[
      _HomeShortcut(
        title: 'سند AI',
        subtitle: 'اسأل وتعلّم بذكاء',
        icon: Icons.auto_awesome_rounded,
        onTap: () => _tabController.animateTo(1),
      ),
      _HomeShortcut(
        title: 'قائمة المهام',
        subtitle: 'نظّم مهامك اليومية',
        icon: Icons.checklist_rounded,
        onTap: () => Navigator.pushNamed(context, '/todos'),
      ),
      _HomeShortcut(
        title: 'بومودورو',
        subtitle: 'ركّز وأنجز أكثر',
        icon: Icons.timer_rounded,
        onTap: () => Navigator.pushNamed(context, '/pomodoro'),
      ),
      _HomeShortcut(
        title: 'ملاحظات',
        subtitle: 'أفكارك في مكان واحد',
        icon: Icons.sticky_note_2_rounded,
        onTap: () => Navigator.pushNamed(context, '/notes'),
      ),
      _HomeShortcut(
        title: 'العد التنازلي',
        subtitle: 'تابع موعدك القادم',
        icon: Icons.hourglass_bottom_rounded,
        onTap: () => Navigator.pushNamed(context, '/countdown'),
      ),
      _HomeShortcut(
        title: 'المتصدرين',
        subtitle: 'اكتشف ترتيبك',
        icon: Icons.emoji_events_rounded,
        onTap: () => _tabController.animateTo(3),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'اختصارات سريعة',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 30,
                  height: 3,
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 176,
            child: PageView.builder(
              controller: _quickShortcutsController,
              itemCount: null,
              itemBuilder: (context, index) {
                final shortcut = shortcuts[index % shortcuts.length];
                return AnimatedBuilder(
                  animation: _quickShortcutsController,
                  builder: (context, child) {
                    final currentPage = _quickShortcutsController.hasClients
                        ? (_quickShortcutsController.page ??
                              _quickShortcutsController.initialPage.toDouble())
                        : _quickShortcutsController.initialPage.toDouble();
                    final distance = (index - currentPage).abs();
                    final scale = (1 - distance * 0.16)
                        .clamp(0.72, 1.0)
                        .toDouble();
                    final opacity = (1 - distance * 0.4)
                        .clamp(0.35, 1.0)
                        .toDouble();

                    return Transform.translate(
                      offset: Offset(0, distance * 12),
                      child: Transform.rotate(
                        angle: (index - currentPage) * 0.055,
                        child: Transform.scale(
                          scale: scale,
                          child: Opacity(opacity: opacity, child: child),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: shortcut.onTap,
                        borderRadius: BorderRadius.circular(22),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [
                                primaryColor,
                                Color.lerp(
                                  primaryColor,
                                  const Color(0xFF34405C),
                                  0.52,
                                )!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: secondaryColor.withValues(alpha: 0.24),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -1,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 7,
                                    color: secondaryColor,
                                  ),
                                ),
                                Positioned(
                                  left: -28,
                                  top: -30,
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: secondaryColor.withValues(
                                        alpha: 0.055,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    16,
                                    20,
                                    16,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              shortcut.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              shortcut.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 11),
                                            Text(
                                              'استكشف',
                                              style: TextStyle(
                                                color: secondaryColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: secondaryColor.withValues(alpha: 0.16),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: secondaryColor.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        child: Icon(
                                          shortcut.icon,
                                          color: secondaryColor,
                                          size: 27,
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
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyQuoteCard(Color primaryColor, Color secondaryColor) {
    if (_studyQuotes.isEmpty) return const SizedBox.shrink();
    final quote = _studyQuotes[_studyQuoteIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: secondaryColor.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: secondaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.format_quote_rounded,
                color: primaryColor,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إلهام يومي',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 520),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: AlignmentDirectional.topStart,
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: animation.drive(
                            Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey(_studyQuoteIndex),
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '«${quote.text}»',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            quote.isQuran
                                ? 'القرآن الكريم • ${quote.source}'
                                : quote.source,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.blueGrey.shade500,
                              fontSize: 11,
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
      ),
    );
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
        _buildAiChatHeader(
          primaryColor,
          currentConversation?['title']?.toString() ?? 'محادثة جديدة',
        ),
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
                              key: PageStorageKey<String>(
                                'sanad-ai-chat-${_currentConversationId ?? "new-conversation"}',
                              ),
                              controller: _chatScrollController,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                MediaQuery.of(context).padding.bottom + 170,
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
                                  child: _buildChatBubbleForMessage(
                                    msg,
                                    primaryColor,
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
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0
                        ? MediaQuery.of(context).viewInsets.bottom + 8
                        : MediaQuery.of(context).padding.bottom + 74,
                  ),
                  child: _buildChatInput(primaryColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiChatHeader(Color primaryColor, String chatTitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Row(
        children: [
          Tooltip(
            message: 'فتح المحادثات السابقة',
            child: Material(
              color: primaryColor,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isTyping ? null : _showConversationPicker,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE6AD35).withAlpha(150),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withAlpha(22),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.forum_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سند AI',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  chatTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7D8799),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubbleForMessage(
    Map<String, dynamic> message,
    Color primaryColor,
  ) {
    Widget buildBubble(String text) => _buildChatBubble(
      text,
      message['isMe'] as bool? ?? false,
      primaryColor,
      retryText: message['retryText'] as String?,
      retryImagePath: message['retryImagePath'] as String?,
      localImagePath: message['localImagePath'] as String?,
      imageUrl: message['imageUrl'] as String?,
      hasStoredImage: message['imagePath'] != null,
    );

    if (!identical(message, _liveAssistantMessage)) {
      return buildBubble(message['text']?.toString() ?? '');
    }
    return ValueListenableBuilder<String>(
      valueListenable: _liveAssistantText,
      builder: (context, text, child) => buildBubble(text),
    );
  }

  Widget _buildTypingIndicator(Color primaryColor) => Container(
    width: double.infinity,
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
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _sendDotsController,
              builder: (context, _) {
                final phase = (_sendDotsController.value + index / 3) % 1;
                final lift = phase < 0.5 ? phase * 7 : (1 - phase) * 7;
                return Transform.translate(
                  offset: Offset(0, -lift),
                  child: Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(130 + (phase * 100).round()),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),
        ],
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
    const icons = [
      Icons.menu_book_rounded,
      Icons.event_note_rounded,
      Icons.today_rounded,
      Icons.psychology_alt_rounded,
      Icons.hourglass_bottom_rounded,
    ];

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.of(context).padding.bottom + 115,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 135)
                .clamp(0.0, double.infinity)
                .toDouble(),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF303D5D), Color(0xFF17213A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 0),
                      spreadRadius: 1.5,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.smart_toy_rounded,
                      size: 47,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    Positioned(
                      top: 17,
                      right: 19,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: Colors.white.withAlpha(220),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Text(
                'مرحبا، $userName',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1D2433),
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'كيف يمكنني مساعدتك؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7D8799),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'جرّب أن تسألني',
                  style: TextStyle(
                    color: Color(0xFF465064),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 78,
                child: Directionality(
                  textDirection: widgets.TextDirection.ltr,
                  child: PageView.builder(
                    controller: _studySuggestionsController,
                    reverse: true,
                    physics: const PageScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: 10000,
                    itemBuilder: (context, page) {
                      final index = page % suggestions.length;
                      final suggestion = suggestions[index];
                      return AnimatedBuilder(
                        animation: _studySuggestionsController,
                        builder: (context, child) {
                          final currentPage =
                              _studySuggestionsController.hasClients
                              ? (_studySuggestionsController.page ?? 5000)
                              : 5000.0;
                          final distance = (currentPage - page)
                              .abs()
                              .clamp(0.0, 1.0);
                          final scale = (1 - (distance * 0.035)).toDouble();
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(19),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(19),
                              onTap: _isTyping
                                  ? null
                                  : () {
                                      _chatController.text = suggestion;
                                      _sendMessage();
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(19),
                                  border: Border.all(
                                    color: const Color(0xFFE8EBF1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withAlpha(9),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  textDirection: widgets.TextDirection.rtl,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF5D9),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        icons[index],
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        suggestion,
                                        textAlign: TextAlign.right,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF29334B),
                                          fontSize: 13,
                                          height: 1.45,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                Expanded(
                  child: AnimatedBuilder(
                    animation: _chatGlowController,
                    builder: (context, _) => Container(
                      padding: EdgeInsets.all(isChatFocused ? 0 : 1.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: isChatFocused
                            ? null
                            : SweepGradient(
                                transform: GradientRotation(
                                  _chatGlowController.value * 2 * pi,
                                ),
                                colors: [
                                  const Color(0xFFE9B642).withAlpha(18),
                                  const Color(0xFFFFD76A).withAlpha(230),
                                  const Color(0xFFE9B642).withAlpha(35),
                                  const Color(0xFFFFD76A).withAlpha(170),
                                  const Color(0xFFE9B642).withAlpha(18),
                                ],
                                stops: const [0, 0.28, 0.52, 0.76, 1],
                              ),
                      ),
                      child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE7EAF0)),
                      boxShadow: [
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: isMe
                    ? LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          primaryColor,
                          Color.lerp(
                            primaryColor,
                            const Color(0xFF0D172D),
                            0.3,
                          )!,
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFFFCFCFE)],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 20),
                ),
                border: isMe
                    ? null
                    : Border.all(color: primaryColor.withAlpha(30)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF17233F).withAlpha(isMe ? 12 : 13),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: isMe
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF5D9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'سند AI',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  String _replaceMarkdownTablesWithLists(String text) {
    final lines = text.split('\n');
    final output = <String>[];

    List<String> cells(String line) {
      var row = line.trim();
      if (row.startsWith('|')) row = row.substring(1);
      if (row.endsWith('|')) row = row.substring(0, row.length - 1);
      return row
          .split('|')
          .map((cell) => cell.trim().replaceAll(r'\|', '|'))
          .toList();
    }

    bool isSeparator(String line) {
      final columns = cells(line);
      return columns.length > 1 &&
          columns.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell));
    }

    var index = 0;
    while (index < lines.length) {
      if (index + 1 < lines.length &&
          lines[index].contains('|') &&
          isSeparator(lines[index + 1])) {
        final headers = cells(lines[index]);
        index += 2;
        var rowCount = 0;
        while (index < lines.length &&
            lines[index].contains('|') &&
            lines[index].trim().isNotEmpty) {
          final values = cells(lines[index]);
          final fields = <String>[];
          for (var column = 0; column < headers.length; column++) {
            if (column >= values.length || values[column].isEmpty) continue;
            final label = headers[column].isEmpty
                ? 'معلومة ${column + 1}'
                : headers[column];
            fields.add('**$label:** ${values[column]}');
          }
          if (fields.isNotEmpty) output.add('- ${fields.join(' · ')}');
          rowCount++;
          index++;
        }
        if (rowCount == 0) {
          output.addAll(
            headers
                .where((header) => header.isNotEmpty)
                .map((header) => '- **$header**'),
          );
        }
        continue;
      }
      output.add(lines[index]);
      index++;
    }
    return output.join('\n');
  }

  String _isolatePlainEquationLines(String text) {
    final mathOnlyLine = RegExp(
      r'^[\s0-9٠-٩۰-۹A-Za-z=+\-−*/^().,×÷<>≤≥≠√π%→:]+$',
    );
    return text
        .split('\n')
        .map((line) {
          final trimmed = line.trim();
          final hasEquation =
              trimmed.contains('=') ||
              trimmed.contains('≤') ||
              trimmed.contains('≥') ||
              trimmed.contains('≠');
          if (hasEquation && mathOnlyLine.hasMatch(trimmed)) {
            return '\$\$$trimmed\$\$';
          }
          return line;
        })
        .join('\n');
  }

  Widget _buildAssistantContent(String message) {
    final displayMessage = _isolatePlainEquationLines(
      _replaceMarkdownTablesWithLists(message),
    );
    final mathPattern = RegExp(
      r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|\$([^$\n]+)\$',
    );
    final children = <Widget>[];
    var cursor = 0;
    for (final match in mathPattern.allMatches(displayMessage)) {
      if (match.start > cursor) {
        children.add(
          _buildAssistantMarkdown(
            displayMessage.substring(cursor, match.start),
          ),
        );
      }
      final displayMath = match.group(1) ?? match.group(2);
      final expression = displayMath ?? match.group(3) ?? match.group(4) ?? '';
      final isDisplay = displayMath != null;
      children.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: isDisplay ? 8 : 3),
          child: Directionality(
            textDirection: widgets.TextDirection.ltr,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableMath.tex(
                  expression.trim(),
                  mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
                  textStyle: const TextStyle(
                    color: Colors.black87,
                      fontSize: 15,
                  ),
                  onErrorFallback: (_) => SelectableText(expression),
                ),
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < displayMessage.length || children.isEmpty) {
      children.add(_buildAssistantMarkdown(displayMessage.substring(cursor)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildAssistantMarkdown(String text) => MarkdownBody(
    data: text
        .replaceAll(
          RegExp(r'(?:<br\s*/?>|&lt;br\s*/?&gt;)', caseSensitive: false),
          '  \n',
        )
        .replaceAll(RegExp(r'<\s*br\s*>', caseSensitive: false), '  \n'),
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

  Widget _buildToolsView() {
    const navy = Color(0xFF1A2238);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E4),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: navy, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'الأدوات التعليمية',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: navy,
                          fontFamily: 'Tajawal',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'اختر الأداة التي تساعدك اليوم',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Color(0xFF7D8799),
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 11,
                child: _buildToolListItem(
                  label: 'قائمة المهام',
                  subtitle: 'رتّب أولوياتك وأنجزها',
                  badge: 'للتنظيم',
                  icon: Icons.checklist_rounded,
                  height: 176,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 9,
                child: _buildToolListItem(
                  label: 'بومودورو',
                  subtitle: 'وازن بين التركيز والراحة',
                  badge: 'للتركيز',
                  icon: Icons.timer_outlined,
                  height: 150,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 9,
                child: _buildToolListItem(
                  label: 'ملاحظات',
                  subtitle: 'دوّن أفكارك بسهولة',
                  badge: 'للتدوين',
                  icon: Icons.note_alt_rounded,
                  height: 150,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 11,
                child: _buildToolListItem(
                  label: 'العد التنازلي',
                  subtitle: 'تابع مواعيدك المهمة',
                  badge: 'للمواعيد',
                  icon: Icons.hourglass_bottom_rounded,
                  height: 176,
                ),
              ),
            ],
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
        _refreshNotificationsPage();
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
          key: ValueKey(
            'notification-$id-${_notificationDismissGenerations[id] ?? 0}',
          ),
          direction: DismissDirection.startToEnd,
          onDismissed: (direction) {
            setState(() {
              _liveNotifications.removeAt(index);
            });
            _refreshNotificationsPage();
            _scheduleNotificationDelete(notification, index);
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
    if (_leaderboardUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoadingLeaderboard)
              CircularProgressIndicator(color: secondaryColor)
            else
              Icon(
                _leaderboardError == null
                    ? Icons.emoji_events_outlined
                    : Icons.cloud_off_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
            const SizedBox(height: 16),
            Text(
              _isLoadingLeaderboard
                  ? 'جارٍ تحميل المتصدرين...'
                  : _leaderboardError == null
                  ? 'لا توجد بيانات حالياً'
                  : 'تعذر تحميل قائمة المتصدرين',
              style: const TextStyle(
                color: Color(0xFF657087),
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!_isLoadingLeaderboard && _leaderboardError != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchLeaderboard,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      );
    }

    final currentUser = Supabase.instance.client.auth.currentUser;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildLeaderboardHeader(),
          if (_leaderboardError != null)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'تعذر تحديث النتائج. تحقق من الاتصال وحاول مجدداً.',
                      style: TextStyle(
                        color: Color(0xFF76520A),
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchLeaderboard,
                    child: const Text('إعادة'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
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
          else
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
                  if (_leaderboardUsers.length > 1) const SizedBox(width: 8),
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
                ],
              ),
            ),
          const SizedBox(height: 36),
          _buildLeaderList(primaryColor, currentUser?.id),
          const SizedBox(height: 100),
        ],
      ),
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
    final int studyTime =
        int.tryParse('${user['weekly_study_time'] ?? 0}') ?? 0;
    final isCurrentUser =
        user['id'] == Supabase.instance.client.auth.currentUser?.id;

    return Column(
      children: [
        if (hasCrown)
          const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.amber,
            size: 35,
          ),
        const SizedBox(height: 5),
        _buildUserCircle(
          imageUrl,
          name,
          30,
          isCurrentUser ? secondaryColor : primaryColor,
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: TextStyle(
            color: isCurrentUser ? primaryColor : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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

  Widget _buildLeaderList(Color primaryColor, String? currentUserId) {
    final usersAfterPodium = _leaderboardUsers.skip(3).toList();
    final currentUserIsInTop50 = currentUserId != null &&
        _leaderboardUsers.any((user) => user['id'] == currentUserId);
    final showCurrentUserSeparately = !currentUserIsInTop50 &&
        _currentUserLeaderboardData != null &&
        _currentUserLeaderboardRank != null;

    if (usersAfterPodium.isEmpty && !showCurrentUserSeparately) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (usersAfterPodium.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: usersAfterPodium.length,
              itemBuilder: (context, index) {
                final user = usersAfterPodium[index];
                final isCurrentUser = user['id'] == currentUserId;
                return _buildLeaderboardUserCard(
                  user: user,
                  rank: index + 4,
                  primaryColor: primaryColor,
                  isCurrentUser: isCurrentUser,
                );
              },
            ),
          if (showCurrentUserSeparately) ...[
            if (usersAfterPodium.isNotEmpty) const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'ترتيبك',
                  style: TextStyle(
                    color: primaryColor,
                    fontFamily: 'Tajawal',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            _buildLeaderboardUserCard(
              user: _currentUserLeaderboardData!,
              rank: _currentUserLeaderboardRank!,
              primaryColor: primaryColor,
              isCurrentUser: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaderboardHeader() {
    const navy = Color(0xFF1A2238);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E4),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: navy,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المتصدرين',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: navy,
                    fontFamily: 'Tajawal',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'أفضل 50 طالباً حسب وقت الدراسة',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Color(0xFF7D8799),
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardUserCard({
    required Map<String, dynamic> user,
    required int rank,
    required Color primaryColor,
    required bool isCurrentUser,
  }) {
    const navy = Color(0xFF1A2238);
    const gold = Color(0xFFF2B833);
    final name = user['full_name']?.toString() ?? 'طالب';
    final stage = user['stage']?.toString();
    final imageUrl = user['profile_image']?.toString();
    final studyTime =
        int.tryParse('${user['weekly_study_time'] ?? 0}') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser ? navy : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE9ECF2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: navy.withAlpha(isCurrentUser ? 28 : 12),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrentUser ? gold : primaryColor.withAlpha(12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: isCurrentUser ? navy : primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildUserCircle(
            imageUrl,
            name,
            22,
            isCurrentUser ? gold : primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : navy,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (stage != null && stage.isNotEmpty)
                  Text(
                    stage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrentUser
                          ? Colors.white70
                          : const Color(0xFF7C8493),
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(studyTime),
            style: TextStyle(
              color: isCurrentUser ? gold : primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolListItem({
    required String label,
    required String subtitle,
    required String badge,
    required IconData icon,
    required double height,
  }) {
    const navy = Color(0xFF1A2238);
    const gold = Color(0xFFF2B833);
    return Material(
      color: navy,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
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
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: navy,
            border: Border.all(color: Colors.white.withAlpha(18)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0D1830),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            height: height,
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: gold, size: 26),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_outward_rounded, color: Colors.white.withAlpha(150), size: 19),
                  ],
                ),
                const Spacer(),
                Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: gold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: navy,
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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

  Widget _buildSubjectCard(
    Map<String, dynamic> subject, {
    required double height,
  }) {
    const navy = Color(0xFF1A2238);
    const gold = Color(0xFFF2B833);
    final sectionCount = _getSectionsCount(subject);
    final label = subject['label']?.toString() ?? '';

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showSubjectDetails(context, subject),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E4),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        subject['icon'] as IconData,
                        color: gold,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        textDirection: widgets.TextDirection.ltr,
                        color: Color(0xFF7D8799),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  label,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: navy,
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 13,
                          color: navy.withAlpha(150),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$sectionCount أقسام',
                          style: const TextStyle(
                            color: Color(0xFF818897),
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
}
