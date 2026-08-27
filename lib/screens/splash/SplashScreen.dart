import 'dart:async' show Timer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/utils/ad_helper.dart';
import '../../core/constants/app_assets.dart';
import '../../core/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    setState(() => _isOffline = false);
    final startTime = DateTime.now();

    try {
      // 1. فحص الإنترنت أولاً
      final hasInternet = await _checkInternet().timeout(const Duration(seconds: 4), onTimeout: () => false);
      if (!hasInternet) {
        setState(() => _isOffline = true);
        return;
      }

      // 2. تهيئة قاعدة البيانات أولاً لضمان جاهزيتها للفحص
      try {
        await Supabase.initialize(
          url: 'https://vxdhjeefbrdjwzwdlybu.supabase.co',
          publishableKey: 'sb_publishable_bh6MjtlteOB4F6eyax80jA_GjlXFpIh',
          authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
        );
      } catch (e) {
        // إذا كان مهيأ مسبقاً لا مشكلة
        debugPrint("Supabase already initialized");
      }

      // 3. تنفيذ الفحوصات بالتوازي (التحديثات + بيانات المستخدم + وقت الانتظار)
      final results = await Future.wait([
        _checkAppStatus(),       // فحص الصيانة والتحديثات الإجبارية
        _checkLoginStatusData(), // جلب بيانات المستخدم
        Future.delayed(const Duration(seconds: 2)), // الحد الأدنى لعرض الشعار
      ]);

      final bool canProceed = results[0] as bool;
      final Map<String, dynamic>? authData = results[1] as Map<String, dynamic>?;

      // تهيئة الإعلانات في الخلفية
      MobileAds.instance.initialize();
      AdHelper().loadRewardedAd();

      if (canProceed && mounted) {
        _navigate(authData);
      }
    } catch (e) {
      debugPrint("Init Error: $e");
      _navigateWithLocalData();
    }
  }

  Future<void> _navigateWithLocalData() async {
    if (mounted) Navigator.pushReplacementNamed(context, "/signin");
  }

  // جلب بيانات الدخول مباشرة من Supabase دون الاعتماد على التخزين المحلي
  Future<Map<String, dynamic>?> _checkLoginStatusData() async {
    try {
      final supabase = Supabase.instance.client;
      final authService = AuthService();
      
      // 1. التحقق من الجلسة الحالية من Supabase مباشرة
      var session = supabase.auth.currentSession;
      var user = supabase.auth.currentUser;

      // 2. إذا لم تكن هناك جلسة، محاولة تسجيل الدخول الصامت عبر جوجل
      if (session == null || user == null) {
        debugPrint("No active session in Supabase, attempting silent Google sign-in...");
        final response = await authService.signInGoogleSilently();
        if (response?.session != null) {
          session = response!.session;
          user = response.user;
          debugPrint("Silent Google sign-in successful");
        }
      }

      // 3. إذا وجدت الجلسة، جلب بيانات المستخدم المحدثة مباشرة من قاعدة البيانات / Supabase Auth
      if (session != null && user != null) {
        try {
          final response = await supabase.auth.getUser().timeout(const Duration(seconds: 5));
          final currentUser = response.user ?? user;
          final userMetadata = currentUser.userMetadata;
          
          final String? name = userMetadata?['full_name'];
          final String? image = userMetadata?['profile_image'];
          final String? stage = userMetadata?['user_stage'];
          
          if (image != null && image.startsWith('http') && mounted) {
            precacheImage(NetworkImage(image), context);
          }

          return {
            'isLoggedIn': true,
            'userName': name,
            'profileImage': image,
            'selectedStage': stage,
          };
        } catch (e) {
          debugPrint("Error fetching user data from Supabase: $e");
          // في حال وجود جلسة صالحة ولكن حدث خطأ مؤقت في الاتصال بالسيرفر
          final userMetadata = user.userMetadata;
          return {
            'isLoggedIn': true,
            'userName': userMetadata?['full_name'],
            'profileImage': userMetadata?['profile_image'],
            'selectedStage': userMetadata?['user_stage'],
          };
        }
      }
      
      return null;
    } catch (e) {
      debugPrint("Check Login Status Data Error: $e");
      return null;
    }
  }

  void _navigate(Map<String, dynamic>? authData) {
    if (authData != null && authData['isLoggedIn'] == true) {
      if (authData['selectedStage'] != null) {
        Navigator.pushReplacementNamed(context, "/home", arguments: authData);
      } else {
        Navigator.pushReplacementNamed(context, "/stages");
      }
    } else {
      Navigator.pushReplacementNamed(context, "/signin");
    }
  }

  Future<bool> _checkAppStatus() async {
    try {
      final supabase = Supabase.instance.client;
      
      // طلب البيانات من جدول app_settings
      final List<dynamic> settings = await supabase
          .from('app_settings')
          .select('key, value');

      // تحويل القائمة إلى Map لسهولة الوصول
      final Map<String, dynamic> config = {
        for (var item in settings) item['key']: item['value']
      };

      // 1. فحص التحديث الإجباري باستخدام المفتاح min_app_version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version; // مثل 1.2.0
      final String minVersion = config['min_app_version']?.toString() ?? "1.0.0";

      debugPrint("Checking Version: Current=$currentVersion | Required=$minVersion");

      if (_isVersionLower(currentVersion, minVersion)) {
        if (mounted) {
          _showUpdateDialog(config['update_url']?.toString() ?? "https://play.google.com/store");
        }
        return false;
      }

      // 2. فحص وضع الصيانة
      if (config['maintenance_mode'] == 'true' || config['maintenance_mode'] == true) {
        if (mounted) {
          _showMaintenanceDialog(config['maintenance_message']?.toString() ?? "التطبيق في وضع الصيانة حالياً.");
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Status Check Error: $e");
      return true; // الدخول في حال حدوث خطأ تقني لضمان عدم تعطل المستخدم
    }
  }

  bool _isVersionLower(String current, String min) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> minParts = min.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int m = i < minParts.length ? minParts[i] : 0;
        if (c < m) return true;
        if (c > m) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _showMaintenanceDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.construction_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text("صيانة مؤقتة"),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text("إغلاق التطبيق", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: Colors.blue),
              SizedBox(width: 10),
              Text("تحديث جديد متوفر"),
            ],
          ),
          content: const Text("يتوفر إصدار جديد من تطبيق سند يحتوي على تحسينات مهمة. يرجى التحديث للمتابعة."),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              child: const Text("تحديث الآن", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkInternet() async {
    try {
      // محاولة الاتصال بمهلة زمنية قدرها 5 ثوانٍ فقط
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // تم استبدال _checkLoginStatus القديمة بالمنطق الجديد أعلاه لزيادة السرعة


  Future<void> _forceLogout(SharedPreferences prefs) async {
    await prefs.clear();
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/signin");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // إعادة إظهار شريط الإشعارات عند الخروج من الشاشة
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

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
          backgroundColor: primaryColor,
          elevation: 0,
          toolbarHeight: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: primaryColor,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        body: Stack(
          children: [
            _buildBackground(primaryColor, secondaryColor),
            _buildContent(primaryColor, secondaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(Color primaryColor, Color secondaryColor) {
    return const SizedBox.shrink(); // الغاء الخلفية والاشكال والنقاط
  }

  Widget _buildContent(Color primaryColor, Color secondaryColor) {
    if (_isOffline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "لا يوجد اتصال بالإنترنت",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "يرجى التحقق من اتصالك بالشبكة للمتابعة واستخدام كافة مميزات تطبيق سند.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _initApp,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text(
                    "إعادة المحاولة",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
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

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: secondaryColor.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: 0.7,
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                ),
              ),
              Image.asset(
                AppAssets.logo,
                width: 125,
                height: 125,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.school,
                  size: 100,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            "تعلم بذكاء، تقدم بثقة",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "كل ما تحتاجه لتتفوق في مكان واحد",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "جاري التحميل...",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}