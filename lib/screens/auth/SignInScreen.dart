import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../core/services/auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    // إخفاء الكيبورد عند الضغط
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final response = await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (response.user != null) {
          if (response.user!.emailConfirmedAt == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("يرجى تأكيد بريدك الإلكتروني أولاً. تفقد صندوق الوارد."),
                  backgroundColor: Colors.orangeAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              await _authService.signOut();
            }
          } else {
            // التحقق من وجود المرحلة في Metadata
            final userStage = response.user!.userMetadata?['user_stage'];
            if (mounted) {
              if (userStage != null) {
                // إذا كانت المرحلة موجودة، نذهب للرئيسية مباشرة
                Navigator.pushReplacementNamed(context, '/home', arguments: userStage);
              } else {
                // إذا لم تكن موجودة، نذهب لشاشة اختيار المراحل
                Navigator.pushReplacementNamed(context, '/stages');
              }
            }
          }
        }
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("حدث خطأ غير متوقع، يرجى المحاولة لاحقاً"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Form(
              key: _formKey,
              child: Column(
                children: [
                const SizedBox(height: 20),
                _buildHeader(primaryColor, secondaryColor),
                const SizedBox(height: 30),
                _buildForm(),
                const SizedBox(height: 10),
                _buildForgotPassword(secondaryColor),
                const SizedBox(height: 25),
                _buildSignInButton(context, primaryColor),
                const SizedBox(height: 40),
                _buildBottomLink(context, secondaryColor),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor, Color secondaryColor) {
    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 175,
                height: 175,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[100]!, width: 1),
                ),
              ),
              SizedBox(
                width: 175,
                height: 175,
                child: CircularProgressIndicator(
                  value: 0.35,
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                ),
              ),
              Image.asset(
                AppAssets.logo,
                width: 120,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.school, size: 60, color: primaryColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "تسجيل الدخول",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        Text(
          "مرحباً بك مجدداً في رحلتك التعليمية",
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          hint: "البريد الإلكتروني",
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "يرجى إدخال البريد الإلكتروني";
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return "يرجى إدخال بريد إلكتروني صحيح";
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        _buildTextField(
          controller: _passwordController,
          hint: "كلمة المرور",
          icon: Icons.lock_outline,
          isPassword: true,
          obscureText: _obscurePassword,
          onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "يرجى إدخال كلمة المرور";
            }
            if (value.length < 6) {
              return "يجب أن تكون كلمة المرور 6 أحرف على الأقل";
            }
            return null;
          },
        ),
      ],
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
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 18),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey[400],
                  size: 18,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F3F5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F3F5)),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context, Color primaryColor) {
    final resetEmailController = TextEditingController();
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_reset_rounded, size: 50, color: primaryColor),
                ),
                const SizedBox(height: 20),
                const Text(
                  "استعادة كلمة المرور",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "أدخل بريدك الإلكتروني لتلقي رابط إعادة تعيين كلمة المرور الخاصة بك.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: resetEmailController,
                  hint: "البريد الإلكتروني",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isResetting ? null : () async {
                      // إخفاء الكيبورد
                      FocusScope.of(context).unfocus();

                      if (resetEmailController.text.isEmpty) return;
                      setState(() => isResetting = true);
                      try {
                        await _authService.resetPassword(resetEmailController.text.trim());
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } on AuthException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("خطأ: ${e.message}"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("حدث خطأ غير متوقع، يرجى المحاولة لاحقاً"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => isResetting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isResetting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("إرسال الرابط", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword(Color secondaryColor) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => _showForgotPasswordDialog(context, Theme.of(context).primaryColor),
        child: Text(
          "نسيت كلمة المرور؟",
          style: TextStyle(
              color: secondaryColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context, Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        child: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text("تسجيل الدخول", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBottomLink(BuildContext context, Color secondaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("ليس لديك حساب؟ ", style: TextStyle(color: Colors.grey, fontSize: 13)),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
          child: Text(
            "إنشاء حساب جديد",
            style: TextStyle(
                color: secondaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
      ],
    );
  }
}