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
import 'screens/tools/pomodoro_timer_service.dart';
import 'screens/tools/countdown_notification_service.dart';
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
    PomodoroTimerService.instance.initialize();
    CountdownNotificationService.instance.initialize();
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
      navigatorObservers: [_AppRouteObserver.instance],
      debugShowCheckedModeBanner: false,
      title: 'سند',
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return TimeTrackingWrapper(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(
              children: [
                child!,
                _PomodoroMiniOverlay(
                  routeObserver: _AppRouteObserver.instance,
                  onOpen: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final navigator = _navigatorKey.currentState;
                      if (navigator == null) return;

                      navigator.pushNamed('/pomodoro');
                      Future<void>.delayed(const Duration(milliseconds: 500),
                          PomodoroTimerService.instance.disableFloating);
                    });
                  },
                ),
              ],
            ),
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

class _AppRouteObserver extends NavigatorObserver {
  _AppRouteObserver._();

  static final instance = _AppRouteObserver._();
  final ValueNotifier<String?> currentRoute = ValueNotifier<String?>(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute.value = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute.value = previousRoute?.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRoute.value = newRoute?.settings.name;
  }
}

class _PomodoroMiniOverlay extends StatefulWidget {
  const _PomodoroMiniOverlay({required this.routeObserver, required this.onOpen});

  final _AppRouteObserver routeObserver;
  final VoidCallback onOpen;

  @override
  State<_PomodoroMiniOverlay> createState() => _PomodoroMiniOverlayState();
}

class _PomodoroMiniOverlayState extends State<_PomodoroMiniOverlay> {
  Offset? _position;

  static const _navy = Color(0xFF1A2238);
  static const _gold = Color(0xFFF2B833);
  static const _green = Color(0xFF43A866);

  @override
  Widget build(BuildContext context) {
    final timer = PomodoroTimerService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([timer, widget.routeObserver.currentRoute]),
      builder: (context, _) {
        if (!timer.isReady ||
            !timer.isRunning ||
            !timer.isFloatingEnabled) {
          return const SizedBox.shrink();
        }

        final media = MediaQuery.of(context);
        final size = media.size;
        const diameter = 62.0;
        const edgeInset = 10.0;
        final minTop = media.padding.top + edgeInset;
        final maxLeft = (size.width - diameter - edgeInset)
            .clamp(edgeInset, double.infinity)
            .toDouble();
        final maxTop = (size.height - diameter - media.padding.bottom - edgeInset)
            .clamp(minTop, double.infinity)
            .toDouble();
        final initialPosition = Offset(maxLeft, maxTop);
        final position = _position ?? initialPosition;
        final left = position.dx.clamp(edgeInset, maxLeft).toDouble();
        final top = position.dy.clamp(minTop, maxTop).toDouble();
        final isPomodoroRoute =
            widget.routeObserver.currentRoute.value == '/pomodoro';
        final progress = (1 -
                timer.remainingSeconds /
                    (timer.modeDurations[timer.currentMode] ?? 1))
            .clamp(0.0, 1.0)
            .toDouble();
        final accentColor = timer.currentMode == PomodoroMode.study
            ? _gold
            : _green;

        return Positioned(
          left: left,
          top: top,
          child: AnimatedOpacity(
            opacity: isPomodoroRoute ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: isPomodoroRoute,
              child: GestureDetector(
                onTap: widget.onOpen,
                onLongPress: timer.pause,
                onPanUpdate: (details) {
                  setState(() {
                    _position = Offset(
                      (left + details.delta.dx)
                          .clamp(edgeInset, maxLeft)
                          .toDouble(),
                      (top + details.delta.dy)
                          .clamp(minTop, maxTop)
                          .toDouble(),
                    );
                  });
                },
                child: Semantics(
                  label: 'مؤقت بومودورو، اضغط لفتحه واضغط مطولاً لإيقافه مؤقتاً',
                  button: true,
                  child: SizedBox(
                    width: diameter,
                    height: diameter,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3,
                            backgroundColor: _navy.withOpacity(.14),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                        Container(
                          width: diameter - 8,
                          height: diameter - 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF303B59), _navy],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(.08),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                color: accentColor,
                                size: 13,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(timer.remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(timer.remainingSeconds % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                  letterSpacing: .2,
                                  decoration: TextDecoration.none,
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
    );
  }
}
