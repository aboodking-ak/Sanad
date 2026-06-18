import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/SplashScreen.dart';
import 'screens/auth/SignUpScreen.dart';
import 'screens/auth/SignInScreen.dart';
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

  await Supabase.initialize(
    url: 'https://vxdhjeefbrdjwzwdlybu.supabase.co',
    publishableKey: 'sb_publishable_bh6MjtlteOB4F6eyax80jA_GjlXFpIh',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _setupAuthListener();
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
      if (event == AuthChangeEvent.passwordRecovery) {
        // نستخدم pushNamedAndRemoveUntil لضمان عدم تداخل شاشة السبلاتش مع عملية الاستعادة
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
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      initialRoute: _isLoggedIn ? '/home' : '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/signin': (context) => const SignInScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/stages': (context) => const StagesScreen(),
        '/home': (context) => const HomePageScreen(),
        '/pdf_viewer': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return PdfViewerScreen(title: args['title'], pdfPath: args['pdfPath']);
        },
        '/exams': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ExamsScreen(subjectName: args['subjectName']);
        },
        '/ministerials': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return MinisterialsScreen(subjectName: args['subjectName']);
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
