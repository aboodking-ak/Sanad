import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../../core/services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    // إخفاء الكيبورد عند الضغط
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("يرجى الموافقة على الشروط والأحكام"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      setState(() => _isLoading = true);
      
      try {
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
        );

        if (mounted) {
          _showVerificationDialog();
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

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_rounded, size: 50, color: Colors.blue),
              ),
              const SizedBox(height: 20),
              const Text(
                "تأكيد الحساب",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "تم إرسال رابط التحقق إلى بريدك الإلكتروني. يرجى تفعيل الحساب لتتمكن من استخدامه.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/signin');
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("حسناً، فهمت", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final String _termsText = """
1. قبول الشروط: باستخدامك لتطبيق سند، فإنك توافق على الالتزام بهذه الشروط والأحكام بالكامل.
2. الاستخدام المسموح: التطبيق مخصص للأغراض التعليمية الشخصية فقط. يمنع نسخ أو توزيع المحتوى دون إذن خطي.
3. الحسابات: أنت مسؤول عن الحفاظ على سرية معلومات حسابك ونشاطاته.
4. حقوق الملكية: جميع المواد التعليمية والعلامات التجارية في التطبيق هي ملك حصري لـ سند.
5. التعديلات: نحتفظ بالحق في تعديل هذه الشروط في أي وقت، وسيتم إخطارك بالتغييرات الجوهرية.
""";

  final String _privacyPolicyText = """
1. جمع البيانات: نقوم بجمع المعلومات الأساسية مثل الاسم والبريد الإلكتروني لتحسين تجربتك التعليمية.
2. استخدام المعلومات: نستخدم بياناتك لتقديم محتوى مخصص، وتتبع تقدمك الدراسي، وإرسال تنبيهات هامة.
3. حماية البيانات: نلتزم بأعلى معايير الأمان لحماية بياناتك ولا نقوم ببيعها أو مشاركتها مع أطراف ثالثة لأغراض تسويقية.
4. ملفات تعريف الارتباط: يستخدم التطبيق تقنيات تقنية لتحسين الأداء وحفظ تفضيلات المستخدم.
5. حذف الحساب: يمكنك طلب حذف حسابك وكافة بياناتك المرتبطة به في أي وقت من خلال إعدادات التطبيق.
""";

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Icon(
                    title == "الشروط والأحكام" ? Icons.description_outlined : Icons.privacy_tip_outlined,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 14, height: 1.8, color: Colors.black87),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("فهمت ذلك", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
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
                const SizedBox(height: 10),
                _buildHeader(primaryColor, secondaryColor),
                const SizedBox(height: 15),
                _buildForm(),
                const SizedBox(height: 8),
                _buildTermsCheckbox(secondaryColor),
                const SizedBox(height: 15),
                _buildSignUpButton(context, primaryColor),
                const SizedBox(height: 30),
                _buildBottomLink(context, secondaryColor),
                const SizedBox(height: 15),
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
          "إنشاء حساب جديد",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        Text(
          "ابدأ رحلتك التعليمية معنا",
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _nameController,
          hint: "الاسم الكامل",
          icon: Icons.person_outline,
          height: 65,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "يرجى إدخال الاسم الكامل";
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _emailController,
          hint: "البريد الإلكتروني",
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          height: 65,
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
        const SizedBox(height: 12),
        _buildTextField(
          controller: _passwordController,
          hint: "كلمة المرور",
          icon: Icons.lock_outline,
          isPassword: true,
          height: 65,
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
        const SizedBox(height: 12),
        _buildTextField(
          controller: _confirmPasswordController,
          hint: "تأكيد كلمة المرور",
          icon: Icons.lock_outline,
          isPassword: true,
          height: 65,
          obscureText: _obscureConfirmPassword,
          onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "يرجى تأكيد كلمة المرور";
            }
            if (value != _passwordController.text) {
              return "كلمات المرور غير متطابقة";
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
    double height = 45,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onToggleVisibility,
  }) {
    return SizedBox(
      height: height,
      child: TextFormField(
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
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFF1F3F5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFF1F3F5)),
          ),
          errorStyle: const TextStyle(fontSize: 11, height: 0.8),
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
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("أوافق على ", style: TextStyle(fontSize: 11)),
              GestureDetector(
                onTap: () => _showInfoDialog("الشروط والأحكام", _termsText),
                child: Text(
                  "الشروط والأحكام",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: secondaryColor,
                      decoration: TextDecoration.underline),
                ),
              ),
              const Text(" و ", style: TextStyle(fontSize: 11)),
              GestureDetector(
                onTap: () => _showInfoDialog("سياسة الخصوصية", _privacyPolicyText),
                child: Text(
                  "سياسة الخصوصية",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: secondaryColor,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton(BuildContext context, Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        child: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text("إنشاء حساب", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBottomLink(BuildContext context, Color secondaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("لديك حساب بالفعل؟ ", style: TextStyle(color: Colors.grey, fontSize: 13)),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/signin'),
          child: Text(
            "تسجيل الدخول",
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