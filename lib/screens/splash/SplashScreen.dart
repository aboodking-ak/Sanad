import 'dart:async' show Timer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';

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
    setState(() {
      _isOffline = false;
    });
    
    final bool hasInternet = await _checkInternet();
    
    if (hasInternet) {
      if (mounted) _checkLoginStatus();
    } else {
      setState(() {
        _isOffline = true;
      });
    }
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

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final String? savedName = prefs.getString('user_name');
      final String? savedImage = prefs.getString('profile_image_path');
      final String? savedStage = prefs.getString('user_stage');

      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final user = supabase.auth.currentUser;

      if (isLoggedIn && savedImage != null && savedImage.startsWith('http') && mounted) {
        precacheImage(NetworkImage(savedImage), context);
      }

      // ضبط التايمر للانتقال
      _timer = Timer(const Duration(seconds: 2), () async {
        if (!mounted) return;

        try {
          if (isLoggedIn && session != null && user != null) {
            // التحقق من صحة الحساب
            final response = await supabase.auth.getUser().timeout(const Duration(seconds: 10));
            
            if (response.user != null) {
              final userMetadata = response.user?.userMetadata;
              final String? metadataStage = userMetadata?['user_stage'];

              if (metadataStage != null && savedStage == null) {
                await prefs.setString('user_stage', metadataStage);
              }

              if (savedStage != null || metadataStage != null) {
                Navigator.pushReplacementNamed(context, "/home", arguments: {
                  'userName': savedName ?? userMetadata?['full_name'],
                  'profileImage': savedImage ?? userMetadata?['profile_image'],
                  'selectedStage': savedStage ?? metadataStage,
                });
              } else {
                Navigator.pushReplacementNamed(context, "/stages");
              }
            } else {
              await _forceLogout(prefs);
            }
          } else {
            Navigator.pushReplacementNamed(context, "/signup");
          }
        } catch (e) {
          // في حال حدوث أي خطأ في الاتصال بالسيرفر، نذهب لصفحة التسجيل
          debugPrint("Splash Navigation Error: $e");
          Navigator.pushReplacementNamed(context, "/signup");
        }
      });
    } catch (e) {
      debugPrint("Outer Splash Error: $e");
      if (mounted) Navigator.pushReplacementNamed(context, "/signup");
    }
  }

  Future<void> _forceLogout(SharedPreferences prefs) async {
    await prefs.clear();
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/signup");
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