import 'dart:async' show Timer;
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

  @override
  void initState() {
    super.initState();

    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final String? savedName = prefs.getString('user_name');
    final String? savedImage = prefs.getString('profile_image_path');
    final String? savedStage = prefs.getString('user_stage');

    // التحقق من صحة الجلسة مع Supabase
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    final user = supabase.auth.currentUser;

    // تسريع ظهور الصورة في الواجهة القادمة عبر التحميل المسبق
    if (isLoggedIn && savedImage != null && savedImage.startsWith('http')) {
      precacheImage(NetworkImage(savedImage), context);
    }

    _timer = Timer(const Duration(seconds: 3), () async {
      if (mounted) {
        if (isLoggedIn && session != null && user != null) {
          try {
            // محاولة جلب بيانات المستخدم للتأكد من أن الحساب لا يزال موجوداً
            final response = await supabase.auth.getUser();
            final userMetadata = response.user?.userMetadata;
            final String? metadataStage = userMetadata?['user_stage'];

            if (response.user != null) {
              // إذا كانت المرحلة موجودة في Metadata ولكن غير موجودة محلياً، نقوم بحفظها
              if (metadataStage != null && savedStage == null) {
                await prefs.setString('user_stage', metadataStage);
              }

              // إذا كانت المرحلة موجودة (سواء محلياً أو في Metadata)، نذهب للرئيسية
              if (savedStage != null || metadataStage != null) {
                Navigator.pushReplacementNamed(context, "/home", arguments: {
                  'userName': savedName ?? userMetadata?['full_name'],
                  'profileImage': savedImage ?? userMetadata?['profile_image'],
                  'selectedStage': savedStage ?? metadataStage,
                });
              } else {
                // إذا لم تكن المرحلة موجودة نهائياً، نذهب لشاشة اختيار المراحل
                Navigator.pushReplacementNamed(context, "/stages");
              }
            } else {
              await _forceLogout(prefs);
            }
          } catch (e) {
            // في حال وجود خطأ (مثل حذف الحساب من لوحة التحكم)
            await _forceLogout(prefs);
          }
        } else {
          Navigator.pushReplacementNamed(context, "/signup");
        }
      }
    });
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
                    color: secondaryColor.withAlpha(100),
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

  Widget _buildDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}