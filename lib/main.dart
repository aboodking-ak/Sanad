import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/time_tracking_wrapper.dart';
import 'core/utils/ad_helper.dart';
import 'screens/splash/SplashScreen.dart';
import 'screens/auth/RegisterScreen.dart';
import 'screens/stages/StagesScreen.dart';
import 'screens/home/HomePageScreen.dart';
import 'screens/pdf/pdf_viewer_screen.dart';
import 'screens/exams/ExamsScreen.dart';
import 'screens/ministerials/MinisterialsScreen.dart';
import 'screens/islamic/SurahScreen.dart';
import 'screens/islamic/hadiths_screen.dart';
import 'screens/islamic/tajweed_rules_screen.dart';
import 'screens/arabic/poem_screen.dart';
import 'screens/english/EssaysScreen.dart';
import 'screens/english/BookPassagesScreen.dart';
import 'screens/biology/BiologyDiagramsScreen.dart';
import 'screens/tools/CountdownScreen.dart';
import 'screens/tools/NotesScreen.dart';
import 'screens/tools/PomodoroScreen.dart';
import 'screens/tools/TodosScreen.dart';
import 'screens/profile/ProfileScreen.dart';
import 'screens/auth/ChangePasswordScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: 'https://vxdhjeefbrdjwzwdlybu.supabase.co',
      publishableKey: 'sb_publishable_bh6MjtlteOB4F6eyax80jA_GjlXFpIh',
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
    );
  } catch (e) {
    debugPrint("Supabase init in main: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isLoggedIn = false;
  final AdHelper _adHelper = AdHelper();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAuthListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // تم إلغاء إعلان فتح التطبيق
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    });
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      debugPrint("Supabase Auth Event Received: $event");
      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint("Password Recovery Event Detected -> Navigating to /change-password");
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/change-password', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'سند',
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return TimeTrackingWrapper(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/signup': (context) => const RegisterScreen(initialIsLogin: false),
        '/signin': (context) => const RegisterScreen(initialIsLogin: true),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/stages': (context) => const StagesScreen(),
        '/home': (context) => const HomePageScreen(),
        '/pdf_viewer': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PdfViewerScreen(title: args['title'], pdfPath: args['pdfPath']);
        },
        '/exams': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ExamsScreen(
            subjectName: args['subjectName'],
            category: args['category'] ?? 'Preparatory',
          );
        },
        '/ministerials': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return MinisterialsScreen(
            subjectName: args['subjectName'],
            category: args['category'] ?? 'Preparatory',
          );
        },
        '/surahs': (context) => const SurahScreen(),
        '/hadiths': (context) => const HadithsScreen(),
        '/tajweed_rules': (context) => const TajweedRulesScreen(),
        '/poems': (context) => const PoemScreen(),
        '/essays': (context) => const EssaysScreen(),
        '/book_passages': (context) => const BookPassagesScreen(),
        '/biology_diagrams': (context) => const BiologyDiagramsScreen(),
        '/countdown': (context) => const CountdownScreen(),
        '/notes': (context) => const NotesScreen(),
        '/pomodoro': (context) => const PomodoroScreen(),
        '/todos': (context) => const TodosScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
