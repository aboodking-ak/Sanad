import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../core/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final bool initialIsLogin;
  const RegisterScreen({super.key, this.initialIsLogin = true});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  late bool _isLogin;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _agreeToTerms = false;
  bool _completeProfile = false;
  String? _stage;
  String? _verificationEmail;
  String? _error;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
    final user = _authService.currentUser;
    if (user != null &&
        user.emailConfirmedAt != null &&
        (user.userMetadata?['user_stage']?.toString().isEmpty ?? true)) {
      _completeProfile = true;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'يرجى إدخال بريد إلكتروني صحيح';
    }
    return null;
  }

  String _errorMessage(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return 'تعذر الاتصال. تحقق من الإنترنت وحاول مجدداً.';
    }
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
        case 'email_not_confirmed':
          return 'يرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول.';
        case 'user_already_exists':
        case 'email_exists':
          return 'هذا البريد مسجل بالفعل. يمكنك تسجيل الدخول.';
        case 'weak_password':
          return 'كلمة المرور ضعيفة. اختر كلمة مرور أقوى.';
        case 'over_email_send_rate_limit':
        case 'over_request_rate_limit':
          return 'طلبات كثيرة. انتظر قليلاً ثم حاول مجدداً.';
        case 'signup_disabled':
          return 'إنشاء الحسابات غير متاح حالياً. حاول لاحقاً.';
        case 'email_address_invalid':
          return 'يرجى إدخال بريد إلكتروني صحيح.';
      }
      if (error.statusCode == '429') return 'انتظر قليلاً قبل المحاولة مجدداً.';
      return 'تعذر إتمام العملية. تحقق من بياناتك وحاول مجدداً.';
    }
    if (error.toString().contains('تم إلغاء'))
      return 'تم إلغاء تسجيل الدخول باستخدام Google.';
    return 'تعذر إتمام العملية. تحقق من اتصالك وحاول مجدداً.';
  }

  void _toggleMode() {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _verificationEmail = null;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    _formKey.currentState?.reset();
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  void _showVerification(String email, {bool startCooldown = true}) {
    setState(() {
      _verificationEmail = email;
      _error = null;
    });
    if (startCooldown) _startCooldown();
  }

  Future<void> _navigateForUser(User user) async {
    if (!mounted) return;
    final stage = user.userMetadata?['user_stage']?.toString();
    if (stage == null || stage.isEmpty) {
      setState(() {
        _completeProfile = true;
        _error = null;
      });
      return;
    }
    Navigator.pushReplacementNamed(context, '/home', arguments: stage);
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_agreeToTerms) {
      setState(() => _error = 'يرجى الموافقة على الشروط وسياسة الخصوصية.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    try {
      if (_isLogin) {
        final response = await _authService.signIn(
          email: email,
          password: _passwordController.text,
        );
        if (!mounted) return;
        if (response.user != null) {
          if (response.user!.emailConfirmedAt == null) {
            await _authService.signOut();
            if (mounted) _showVerification(email, startCooldown: false);
          } else {
            await _navigateForUser(response.user!);
          }
        }
      } else {
        final response = await _authService.signUp(
          email: email,
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          stage: _stage!,
        );
        if (!mounted) return;
        if (response.session != null &&
            response.user != null &&
            response.user!.emailConfirmedAt != null) {
          await _navigateForUser(response.user!);
        } else {
          _showVerification(email);
        }
      }
    } catch (error) {
      if (mounted) {
        if (error is AuthException && error.code == 'email_not_confirmed') {
          _showVerification(email, startCooldown: false);
        } else {
          setState(() => _error = _errorMessage(error));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendConfirmation() async {
    if (_isLoading || _resendSeconds > 0 || _verificationEmail == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _authService.resendConfirmation(_verificationEmail!);
      if (mounted) {
        _startCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال رسالة التأكيد مجدداً.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _errorMessage(error));
        if (error is AuthException &&
            (error.code == 'over_email_send_rate_limit' ||
                error.statusCode == '429'))
          _startCooldown();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _googleConsent() async {
    if (_agreeToTerms) return true;
    var agreed = false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: const Text('المتابعة باستخدام Google'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'قبل المتابعة، يرجى قراءة الشروط وسياسة الخصوصية والموافقة عليهما.',
                  ),
                  _legalLinks(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'أوافق على الشروط وسياسة الخصوصية',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: agreed,
                    onChanged: (value) => update(() => agreed = value ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: agreed
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('متابعة'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    if (!_isLogin && _stage == null) {
      setState(
        () => _error = 'اختر فرعك الدراسي قبل المتابعة باستخدام Google.',
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (!await _googleConsent() || !mounted) return;
      setState(() => _agreeToTerms = true);
      final response = await _authService.signInWithGoogle();
      var user = response.user;
      if (user == null || !mounted) return;
      if ((user.userMetadata?['user_stage']?.toString().isEmpty ?? true) &&
          _stage != null) {
        await _authService.updateUserStage(_stage!);
        user = _authService.currentUser ?? user;
      }
      await _navigateForUser(user);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveStage() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (_authService.currentUser == null) throw StateError('No session');
      await _authService.updateUserStage(_stage!);
      if (mounted)
        Navigator.pushReplacementNamed(context, '/home', arguments: _stage);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_isLoading) return;
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final key = GlobalKey<FormState>();
    var sending = false;
    String? message;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !sending,
          child: AlertDialog(
            title: const Text('استعادة كلمة المرور'),
            content: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'أدخل بريدك الإلكتروني لإرسال رابط إعادة تعيين كلمة المرور.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: controller,
                      enabled: !sending,
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                    ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          message!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: sending
                    ? null
                    : () async {
                        if (!key.currentState!.validate()) return;
                        update(() {
                          sending = true;
                          message = null;
                        });
                        try {
                          await _authService.resetPassword(
                            controller.text.trim(),
                          );
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext);
                          if (mounted)
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'إذا كان البريد مسجلاً، ستصلك رسالة استعادة كلمة المرور.',
                                ),
                              ),
                            );
                        } catch (error) {
                          if (dialogContext.mounted)
                            update(() {
                              sending = false;
                              message = _errorMessage(error);
                            });
                        }
                      },
                child: Text(sending ? 'جارٍ الإرسال...' : 'إرسال الرابط'),
              ),
            ],
          ),
        ),
      ),
    );
    // انتظار إزالة النافذة قبل التخلص من المتحكم الخاص بحقلها.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  Widget _legalLinks() => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: _showTermsDialog,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF64748B),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        child: const Text('الشروط والأحكام'),
      ),
      TextButton(
        onPressed: _showPrivacyDialog,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF64748B),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        child: const Text('سياسة الخصوصية'),
      ),
    ],
  );

  Widget _stagePicker() => FormField<String>(
    initialValue: _stage,
    validator: (_) => _stage == null ? 'يرجى اختيار الفرع الدراسي' : null,
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر فرعك الدراسي',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Row(
          children: ['سادس علمي', 'سادس أدبي']
              .map(
                (stage) => Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: stage == 'سادس علمي' ? 10 : 0,
                    ),
                    child: Semantics(
                      selected: _stage == stage,
                      button: true,
                      child: InkWell(
                        onTap: _isLoading
                            ? null
                            : () {
                                setState(() => _stage = stage);
                                field.didChange(stage);
                              },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _stage == stage
                                ? const Color(0xFFFFF8E5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _stage == stage
                                  ? const Color(0xFFF5B82E)
                                  : const Color(0xFFE3E6EC),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _stage == stage
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 18,
                                color: _stage == stage
                                    ? const Color(0xFF9B751D)
                                    : const Color(0xFF9AA3B3),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  stage,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              field.errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool password = false,
    bool confirmation = false,
    bool email = false,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      enabled: !_isLoading,
      validator: validator,
      textDirection: email || password ? TextDirection.ltr : TextDirection.rtl,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      autocorrect: !email && !password,
      enableSuggestions: !email && !password,
      autofillHints: email
          ? [AutofillHints.email]
          : password
          ? [
              confirmation || !_isLogin
                  ? AutofillHints.newPassword
                  : AutofillHints.password,
            ]
          : [AutofillHints.name],
      obscureText:
          password && (confirmation ? _obscureConfirmation : _obscurePassword),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 21),
        suffixIcon: password
            ? IconButton(
                tooltip:
                    (confirmation ? _obscureConfirmation : _obscurePassword)
                    ? 'إظهار كلمة المرور'
                    : 'إخفاء كلمة المرور',
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        if (confirmation) {
                          _obscureConfirmation = !_obscureConfirmation;
                        } else {
                          _obscurePassword = !_obscurePassword;
                        }
                      }),
                icon: Icon(
                  (confirmation ? _obscureConfirmation : _obscurePassword)
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 21,
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4E7ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4E7ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1A2238), width: 1.5),
        ),
        errorMaxLines: 2,
      ),
    ),
  );

  Widget _primaryButton(String label, VoidCallback action) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: _isLoading ? null : action,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A2238),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    ),
  );

  Widget _verificationContent() => Column(
    children: [
      const Icon(
        Icons.mark_email_read_outlined,
        size: 60,
        color: Color(0xFF9B751D),
      ),
      const SizedBox(height: 10),
      const Text(
        'أكد بريدك الإلكتروني',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Text(
        'افتح رسالة التأكيد واضغط على الرابط لتفعيل حسابك، ثم سجّل الدخول. تحقق أيضاً من البريد غير المرغوب فيه.',
        textAlign: TextAlign.center,
        style: TextStyle(height: 1.7, color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 12),
      Text(
        _verificationEmail!,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      if (_error != null) _errorBanner(),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _isLoading || _resendSeconds > 0
              ? null
              : _resendConfirmation,
          child: Text(
            _resendSeconds > 0
                ? 'إعادة الإرسال بعد $_resendSeconds ثانية'
                : 'إعادة إرسال رسالة التأكيد',
          ),
        ),
      ),
      const SizedBox(height: 12),
      _primaryButton(
        'العودة إلى تسجيل الدخول',
        () => setState(() {
          _verificationEmail = null;
          _isLogin = true;
          _error = null;
        }),
      ),
    ],
  );

  Widget _errorBanner() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _error!,
        style: const TextStyle(
          color: Color(0xFFAD3434),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Read the keyboard inset before Scaffold adjusts MediaQuery for its body.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: const Color(0xFFF7F8FA),
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Color(0xFFF7F8FA),
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: keyboardOpen
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: keyboardOpen ? null : constraints.maxHeight,
                    child: _FullWidthAuthFit(
                      preserveScale: keyboardOpen,
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...[
                                const Text(
                                  'سند',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF1A2238),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_verificationEmail == null) ...[
                                  Text(
                                    _completeProfile
                                        ? 'لنجهّز موادك الدراسية'
                                        : _isLogin
                                        ? 'مرحباً بعودتك'
                                        : 'ابدأ رحلتك مع سند',
                                    style: const TextStyle(
                                      color: Color(0xFF1A2238),
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _completeProfile
                                        ? 'حدد فرعك مرة واحدة لتظهر لك المواد المناسبة.'
                                        : _isLogin
                                        ? 'سجّل الدخول وتابع رحلتك نحو التفوق.'
                                        : 'حساب واحد يجمع دراستك ومراجعتك وتنظيم وقتك.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      height: 1.6,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                              ],
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                    colors: [
                                      Color(0xFFFFFCF4),
                                      Colors.white,
                                      Colors.white,
                                    ],
                                    stops: [0, 0.35, 1],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFE5DDCA),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1A2238,
                                      ).withValues(alpha: 0.07),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: _verificationEmail != null
                                    ? _verificationContent()
                                    : AutofillGroup(
                                        child: Form(
                                          key: _formKey,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              if (!_completeProfile) ...[
                                                SizedBox(
                                                  height: 48,
                                                  child: OutlinedButton.icon(
                                                    onPressed: _isLoading
                                                        ? null
                                                        : _signInWithGoogle,
                                                    icon: Image.asset(
                                                      AppAssets.google,
                                                      width: 22,
                                                    ),
                                                    label: const Text(
                                                      'المتابعة باستخدام Google',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.white,
                                                      foregroundColor:
                                                          const Color(
                                                            0xFF1A2238,
                                                          ),
                                                      side: const BorderSide(
                                                        color: Color(
                                                          0xFFD9D2C3,
                                                        ),
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                const Row(
                                                  children: [
                                                    Expanded(child: Divider()),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                          ),
                                                      child: Text(
                                                        'أو باستخدام البريد الإلكتروني',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Color(
                                                            0xFF7A8495,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(child: Divider()),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                if (!_isLogin)
                                                  _field(
                                                    _nameController,
                                                    'الاسم الكامل',
                                                    Icons
                                                        .person_outline_rounded,
                                                    validator: (v) =>
                                                        (v?.trim().isEmpty ??
                                                            true)
                                                        ? 'يرجى إدخال الاسم الكامل'
                                                        : null,
                                                  ),
                                                _field(
                                                  _emailController,
                                                  'البريد الإلكتروني',
                                                  Icons.mail_outline_rounded,
                                                  email: true,
                                                  validator: _validateEmail,
                                                ),
                                                _field(
                                                  _passwordController,
                                                  'كلمة المرور',
                                                  Icons.lock_outline_rounded,
                                                  password: true,
                                                  validator: (v) =>
                                                      (v?.isEmpty ?? true)
                                                      ? 'يرجى إدخال كلمة المرور'
                                                      : !_isLogin &&
                                                            v!.length < 6
                                                      ? 'استخدم 6 أحرف على الأقل'
                                                      : null,
                                                ),
                                                if (!_isLogin)
                                                  _field(
                                                    _confirmPasswordController,
                                                    'تأكيد كلمة المرور',
                                                    Icons.lock_outline_rounded,
                                                    password: true,
                                                    confirmation: true,
                                                    validator: (v) =>
                                                        v !=
                                                            _passwordController
                                                                .text
                                                        ? 'كلمتا المرور غير متطابقتين'
                                                        : null,
                                                  ),
                                                if (_isLogin)
                                                  Align(
                                                    alignment:
                                                        AlignmentDirectional
                                                            .centerEnd,
                                                    child: TextButton(
                                                      onPressed: _isLoading
                                                          ? null
                                                          : _forgotPassword,
                                                      child: const Text(
                                                        'نسيت كلمة المرور؟',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                              if (!_isLogin ||
                                                  _completeProfile) ...[
                                                _stagePicker(),
                                                const SizedBox(height: 10),
                                              ],
                                              if (!_isLogin &&
                                                  !_completeProfile) ...[
                                                CheckboxListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  controlAffinity:
                                                      ListTileControlAffinity
                                                          .leading,
                                                  value: _agreeToTerms,
                                                  onChanged: _isLoading
                                                      ? null
                                                      : (v) => setState(
                                                          () => _agreeToTerms =
                                                              v ?? false,
                                                        ),
                                                  title: const Text(
                                                    'أوافق على الشروط وسياسة الخصوصية',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                              if (_error != null)
                                                _errorBanner(),
                                              _primaryButton(
                                                _completeProfile
                                                    ? 'حفظ ومتابعة'
                                                    : _isLogin
                                                    ? 'تسجيل الدخول'
                                                    : 'إنشاء حساب',
                                                _completeProfile
                                                    ? _saveStage
                                                    : _submit,
                                              ),
                                              if (_completeProfile)
                                                TextButton(
                                                  onPressed: _isLoading
                                                      ? null
                                                      : () async {
                                                          setState(
                                                            () => _isLoading =
                                                                true,
                                                          );
                                                          try {
                                                            await _authService
                                                                .signOut();
                                                            if (mounted)
                                                              setState(() {
                                                                _completeProfile =
                                                                    false;
                                                                _isLogin = true;
                                                                _stage = null;
                                                              });
                                                          } catch (e) {
                                                            if (mounted)
                                                              setState(
                                                                () => _error =
                                                                    _errorMessage(
                                                                      e,
                                                                    ),
                                                              );
                                                          } finally {
                                                            if (mounted)
                                                              setState(
                                                                () =>
                                                                    _isLoading =
                                                                        false,
                                                              );
                                                          }
                                                        },
                                                  child: const Text(
                                                    'تسجيل الخروج',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 14),
                              if (!_completeProfile &&
                                  _verificationEmail == null)
                                TextButton(
                                  onPressed: _isLoading ? null : _toggleMode,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF1A2238),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: _isLogin
                                              ? 'ليس لديك حساب؟ '
                                              : 'لديك حساب بالفعل؟ ',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        TextSpan(
                                          text: _isLogin
                                              ? 'أنشئ حساباً'
                                              : 'سجّل الدخول',
                                          style: const TextStyle(
                                            color: Color(0xFF1A2238),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              if (!_completeProfile &&
                                  _verificationEmail == null)
                                _legalLinks(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
}

/// Fits the form vertically while laying it out to fill the available width.
/// Painting and pointer coordinates use the same uniform scale.
class _FullWidthAuthFit extends SingleChildRenderObjectWidget {
  const _FullWidthAuthFit({required super.child, required this.preserveScale});

  final bool preserveScale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFullWidthAuthFit(preserveScale: preserveScale);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFullWidthAuthFit renderObject,
  ) {
    renderObject.preserveScale = preserveScale;
  }
}

class _RenderFullWidthAuthFit extends RenderProxyBox {
  _RenderFullWidthAuthFit({required bool preserveScale})
    : _preserveScale = preserveScale;

  bool _preserveScale;
  double _restingScale = 1;

  set preserveScale(bool value) {
    if (_preserveScale == value) return;
    _preserveScale = value;
    markNeedsLayout();
  }

  double _scale = 1;
  Offset _offset = Offset.zero;

  Matrix4 get _transform => Matrix4.identity()
    ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
    ..scaleByDouble(_scale, _scale, 1, 1);

  @override
  void performLayout() {
    final content = child;
    if (content == null) {
      size = constraints.smallest;
      return;
    }
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    var scale = _preserveScale ? _restingScale : 1.0;
    for (var pass = 0; !_preserveScale && pass < 12; pass++) {
      content.layout(
        BoxConstraints.tightFor(width: width / scale),
        parentUsesSize: true,
      );
      final next = content.size.height > height && content.size.height > 0
          ? height / content.size.height
          : 1.0;
      if ((next - scale).abs() < 0.0001) {
        break;
      }
      scale = next;
    }
    // Final layout uses the same width as the painted scale.
    content.layout(
      BoxConstraints.tightFor(width: width / scale),
      parentUsesSize: true,
    );
    _scale = scale;
    if (!_preserveScale) _restingScale = scale;
    size = constraints.constrain(Size(width, content.size.height * scale));
    _offset = Offset(0, (size.height - content.size.height * scale) / 2);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child!, offset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, transformed) =>
          child?.hitTest(result, position: transformed) ?? false,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}
