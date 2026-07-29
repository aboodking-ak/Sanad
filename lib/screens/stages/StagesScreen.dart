import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_assets.dart';
import '../../core/services/auth_service.dart';

class StagesScreen extends StatefulWidget {
  const StagesScreen({super.key});

  @override
  State<StagesScreen> createState() => _StagesScreenState();
}

class _StagesScreenState extends State<StagesScreen> {
  final _authService = AuthService();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF1A2238), // نفس لون AppColors.primary
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    _loadSavedStage();
  }

  Future<void> _loadSavedStage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStage = prefs.getString('user_stage');
    if (savedStage != null) {
      setState(() {
        selectedStage = savedStage;
      });
    }
  }

  String? selectedStage;

  final List<Map<String, String>> stages = [
    {'label': 'سادس علمي', 'icon': AppAssets.sixthScientific, 'desc': 'تخصص العلوم الطبيعية والرياضيات'},
    {'label': 'سادس أدبي', 'icon': AppAssets.sixthLiterary, 'desc': 'تخصص العلوم الإنسانية واللغات'},
  ];

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
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const Expanded(flex: 1, child: SizedBox()),
                        _buildLogo(primaryColor, secondaryColor),
                        const SizedBox(height: 20),
                        _buildHeader(primaryColor),
                        const Expanded(flex: 1, child: SizedBox()),
                        _buildStagesGrid(),
                        const Expanded(flex: 2, child: SizedBox()),
                        _buildContinueButton(primaryColor),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Color primaryColor, Color secondaryColor) {
    return Center(
      child: ClipOval(
        child: Image.asset(
          AppAssets.logo,
          width: 120,
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.school, size: 80, color: primaryColor),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Column(
      children: [
        Text(
          "اختر مرحلتك الدراسية",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        Text(
          "لنقدم لك تجربة تعليمية تناسب احتياجاتك",
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildStagesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStageCard(stages[0]),
          const SizedBox(height: 20),
          _buildStageCard(stages[1]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStageCard(Map<String, String> stage) {
    final isSelected = selectedStage == stage['label'];
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTap: () => setState(() => selectedStage = stage['label']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? secondaryColor : Colors.grey[200]!,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? secondaryColor.withOpacity(0.15) 
                  : Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (isSelected)
              PositionedDirectional(
                top: 0,
                start: 0,
                child: Icon(Icons.check_circle, color: secondaryColor, size: 28),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.asset(
                      stage['icon']!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.school_outlined, size: 60, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    stage['label']!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primaryColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage['desc']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.2,
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

  Widget _buildContinueButton(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: (selectedStage == null || _isUpdating)
              ? null
              : () async {
                  setState(() => _isUpdating = true);
                  try {
                    // تحديث في السحابة ومحلياً
                    await _authService.updateUserStage(selectedStage!);
                    
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/home',
                          arguments: selectedStage);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("فشل حفظ المرحلة الدراسية، يرجى المحاولة لاحقاً")),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isUpdating = false);
                  }
                },
          child: _isUpdating 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text(
                "متابعة",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
        ),
      ),
    );
  }
}