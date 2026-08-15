import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final bool initialIsLogin;

  const RegisterScreen({super.key, this.initialIsLogin = true});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late bool _isLogin;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    _animationController.reverse().then((_) {
      setState(() {
        _isLogin = !_isLogin;
        _formKey.currentState?.reset();
      });
      _animationController.forward();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!_isLogin && !_agreeToTerms) {
      _showSnackBar("يرجى الموافقة على الشروط والأحكام", Colors.orangeAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // تسجيل الدخول
        final response = await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (response.user != null) {
          if (response.user!.emailConfirmedAt == null) {
            _showSnackBar(
              "يرجى تأكيد بريدك الإلكتروني أولاً.",
              Colors.orangeAccent,
            );
            await _authService.signOut();
          } else {
            _navigateToHome(response.user!);
          }
        }
      } else {
        // إنشاء حساب
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
        );
        _showVerificationDialog();
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.redAccent);
    } catch (e) {
      _showSnackBar(
        "حدث خطأ غير متوقع، يرجى المحاولة لاحقاً",
        Colors.redAccent,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome(User user) {
    final userStage = user.userMetadata?['user_stage'];
    if (mounted) {
      if (userStage != null) {
        Navigator.pushReplacementNamed(context, '/home', arguments: userStage);
      } else {
        Navigator.pushReplacementNamed(context, '/stages');
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildLogo(primaryColor, secondaryColor),
                const SizedBox(height: 30),
                _buildToggle(primaryColor),
                const SizedBox(height: 30),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          _buildTextField(
                            controller: _nameController,
                            hint: "الاسم الكامل",
                            icon: Icons.person_outline,
                            validator: (v) =>
                                v!.isEmpty ? "يرجى إدخال الاسم" : null,
                          ),
                          const SizedBox(height: 15),
                        ],
                        _buildTextField(
                          controller: _emailController,
                          hint: "البريد الإلكتروني",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              !RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(v!)
                              ? "بريد إلكتروني غير صحيح"
                              : null,
                        ),
                        const SizedBox(height: 15),
                        _buildTextField(
                          controller: _passwordController,
                          hint: "كلمة المرور",
                          icon: Icons.lock_outline,
                          isPassword: true,
                          obscureText: _obscurePassword,
                          onToggleVisibility: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          validator: (v) =>
                              v!.length < 6 ? "6 أحرف على الأقل" : null,
                        ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 15),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            hint: "تأكيد كلمة المرور",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            validator: (v) => v != _passwordController.text
                                ? "كلمات المرور غير متطابقة"
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                if (_isLogin) _buildForgotPassword(secondaryColor),
                if (!_isLogin) _buildTermsCheckbox(secondaryColor),
                const SizedBox(height: 25),
                _buildSubmitButton(primaryColor),
                const SizedBox(height: 25),
                _buildDivider(),
                const SizedBox(height: 25),
                _buildGoogleButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Color primaryColor, Color secondaryColor) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          "سـنـد",
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: primaryColor,
            fontFamily: 'Tajawal',
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          width: 40,
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isLogin
              ? "مرحباً بك مجدداً في رحلتك للنجاح"
              : "ابدأ رحلتك التعليمية المتميزة معنا اليوم",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontFamily: 'Tajawal',
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(Color primaryColor) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _buildToggleButton("تسجيل الدخول", _isLogin, primaryColor),
          _buildToggleButton("حساب جديد", !_isLogin, primaryColor),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String title, bool isActive, Color primaryColor) {
    return Expanded(
      child: GestureDetector(
        onTap: isActive ? null : _toggleAuthMode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isActive ? primaryColor : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[400],
                    size: 18,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          errorStyle: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildForgotPassword(Color secondaryColor) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => _showForgotPasswordDialog(),
        child: Text(
          "نسيت كلمة المرور؟",
          style: TextStyle(
            color: secondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox(Color secondaryColor) {
    return Row(
      children: [
        Checkbox(
          value: _agreeToTerms,
          activeColor: secondaryColor,
          onChanged: (v) => setState(() => _agreeToTerms = v!),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontFamily: 'Tajawal',
              ),
              children: [
                const TextSpan(text: "أوافق على "),
                TextSpan(
                  text: "الشروط والأحكام",
                  style: TextStyle(
                    color: secondaryColor,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _showTermsDialog(),
                ),
                const TextSpan(text: " و "),
                TextSpan(
                  text: "سياسة الخصوصية",
                  style: TextStyle(
                    color: secondaryColor,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _showPrivacyDialog(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("الشروط والأحكام", textAlign: TextAlign.center),
        content: const SingleChildScrollView(
          child: Text(
            "1. الالتزام بالاستخدام التعليمي للتطبيق.\n"
            "2. عدم محاولة اختراق أو نسخ محتوى التطبيق.\n"
            "3. الحفاظ على سرية معلومات الحساب.\n"
            "4. التطبيق غير مسؤول عن سوء استخدام الحساب من قبل المستخدم.\n"
            "5. يحق لإدارة التطبيق حظر أي حساب يخالف القوانين.",
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إغلاق"),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("سياسة الخصوصية", textAlign: TextAlign.center),
        content: const SingleChildScrollView(
          child: Text(
            "1. نحن نحترم خصوصيتك ونحمي بياناتك الشخصية.\n"
            "2. يتم استخدام بريدك الإلكتروني لتوثيق الحساب فقط.\n"
            "3. لا نشارك بياناتك مع أي طرف ثالث.\n"
            "4. يتم تخزين بيانات التقدم الدراسي لتحسين تجربتك.\n"
            "5. نستخدم بروتوكولات أمان متقدمة لحماية معلوماتك.",
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إغلاق"),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                _isLogin ? "تسجيل الدخول" : "إنشاء الحساب",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[200])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            "أو عبر",
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[200])),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signInWithGoogle,
        icon: Image.asset('assets/icons/auth/google.png', width: 24),
        label: const Text(
          "حساب جوجل",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[200]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  void _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.signInWithGoogle();
      if (response.user != null) _navigateToHome(response.user!);
    } catch (e) {
      _showSnackBar("فشل تسجيل الدخول باستخدام جوجل", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تأكيد الحساب"),
        content: const Text(
          "تم إرسال رابط التحقق إلى بريدك الإلكتروني. يرجى تفعيل الحساب للمتابعة.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleAuthMode();
            },
            child: const Text("فهمت"),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_reset_rounded, size: 40, color: primaryColor),
              ),
              const SizedBox(height: 20),
              const Text(
                "استعادة كلمة المرور",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: emailCtrl,
                hint: "البريد الإلكتروني",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (emailCtrl.text.isEmpty) return;
                        await _authService.resetPassword(emailCtrl.text.trim());
                        if (mounted) {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          _showSnackBar("تم إرسال الرابط بنجاح", Colors.green);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text("إرسال", style: TextStyle(fontWeight: FontWeight.bold)),
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
}
