import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  static const completedKey = 'onboarding_completed';
  final VoidCallback onCompleted;

  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _isSaving = false;
  bool _isMoving = false;

  static const _pages = [
    (
      title: 'دراستك تبدأ من هنا',
      description: 'كتب ومواد السادس العلمي والأدبي في مكان واحد.',
    ),
    (
      title: 'راجع واختبر فهمك',
      description: 'أسئلة وزارية واختبارات للمراجعة مع الإجابات النموذجية.',
    ),
    (
      title: 'نظّم وقتك وواصل تقدمك',
      description: 'مهام وملاحظات ومؤقت دراسة تساعدك على تنظيم يومك.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_isSaving || _isMoving) return;
    if (_page < _pages.length - 1) {
      setState(() => _isMoving = true);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      if (mounted) setState(() => _isMoving = false);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setBool(OnboardingScreen.completedKey, true);
      if (!saved) throw StateError('Could not save onboarding completion');
      if (mounted) widget.onCompleted();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الإعدادات، يرجى المحاولة مجدداً.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9F6),
        appBar: AppBar(
          toolbarHeight: 0,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('سند', style: TextStyle(color: colors.primary, fontSize: 28, fontWeight: FontWeight.w900)),
                    Text('رفيقك للدراسة', style: TextStyle(color: colors.primary.withValues(alpha: 0.5), fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 36)
                                .clamp(0.0, double.infinity),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _OnboardingArtwork(
                                index: index,
                                height: (constraints.maxHeight * 0.56).clamp(180.0, 340.0),
                              ),
                              const SizedBox(height: 26),
                              Text(
                                ['تعلّم', 'راجع', 'أنجز'][index],
                                style: const TextStyle(color: Color(0xFF987427), fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 27,
                                  height: 1.3,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                page.description,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.7,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == index ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == index ? colors.secondary : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving || _isMoving ? null : _next,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _page == _pages.length - 1 ? 'ابدأ الآن' : 'التالي',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
}

// لقطات حقيقية من سند، مع تأطير متجاوب دون تعديل الصور الأصلية.
class _OnboardingArtwork extends StatelessWidget {
  final int index;
  final double height;
  const _OnboardingArtwork({required this.index, required this.height});

  static const _shots = [
    (front: 'screen-1.jpg', back: 'screen-2.jpg', label: 'علمي وأدبي'),
    (front: 'screen-3.jpg', back: 'screen-4.jpg', label: 'راجع بثقة'),
    (front: 'screen-8.jpg', back: 'screen-9.jpg', label: 'وقت للتركيز'),
  ];

  Widget _phone(String filename) {
    return Container(
      width: 174,
      height: 350,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2238),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2238).withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Image.asset(
          'assets/images/onboarding/$filename',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shots[index];
    return Semantics(
      label: 'معاينة واجهات سند: ${shot.label}',
      image: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 340,
            height: 390,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 42,
                  left: 18,
                  right: 18,
                  bottom: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EADF),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  top: 24,
                  child: Transform.rotate(
                    angle: -0.10,
                    child: _phone(shot.back),
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 7,
                  child: Transform.rotate(
                    angle: 0.07,
                    child: _phone(shot.front),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5B82E),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF5B82E).withValues(alpha: 0.20),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      shot.label,
                      style: const TextStyle(
                        color: Color(0xFF1A2238),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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
}
