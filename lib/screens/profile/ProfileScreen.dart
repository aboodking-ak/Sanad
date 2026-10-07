import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _navy = Color(0xFF1A2238);
  static const _gold = Color(0xFFF2B833);
  final _authService = AuthService();
  String userName = 'الطالب';
  String userEmail = '';
  String selectedStage = 'غير محدد';
  String? _profileImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = _authService.currentUser;
    if (user == null || !mounted) return;
    setState(() {
      userName = user.userMetadata?['full_name']?.toString() ?? 'الطالب';
      userEmail = user.email ?? '';
      selectedStage =
          user.userMetadata?['user_stage']?.toString() ?? 'غير محدد';
      _profileImagePath = user.userMetadata?['profile_image']?.toString();
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _error(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'email_exists':
        case 'user_already_exists':
          return 'البريد الإلكتروني مستخدم في حساب آخر.';
        case 'weak_password':
          return 'كلمة المرور ضعيفة. اختر كلمة مرور أقوى.';
        case 'same_password':
          return 'اختر كلمة مرور مختلفة عن الحالية.';
        case 'reauthentication_needed':
          return 'سجّل الدخول مجدداً ثم حاول تغيير كلمة المرور.';
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
          return 'انتظر قليلاً قبل إعادة المحاولة.';
      }
    }
    return 'تعذر حفظ التغيير. تحقق من اتصالك وحاول مجدداً.';
  }

  Future<void> _edit(String kind) async {
    if (_isLoading) return;
    final title = switch (kind) {
      'name' => 'تعديل الاسم',
      'email' => 'تعديل البريد الإلكتروني',
      'stage' => 'تعديل الفرع الدراسي',
      _ => 'تغيير كلمة المرور',
    };
    final controller = TextEditingController(
      text: kind == 'name'
          ? userName
          : kind == 'email'
          ? userEmail
          : '',
    );
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var stage = ['سادس علمي', 'سادس أدبي'].contains(selectedStage)
        ? selectedStage
        : null;
    var saving = false;
    var obscure = true;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) {
          InputDecoration decoration(String label) => InputDecoration(
            labelText: label,
            filled: true,
            fillColor: const Color(0xFFF5F6F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          );
          return PopScope(
            canPop: !saving,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDE0E5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            kind == 'email'
                                ? 'سنرسل رسالة تأكيد إلى البريد الجديد. وقد تحتاج إلى تأكيد التغيير من البريد الحالي أيضاً.'
                                : kind == 'stage'
                                ? 'ستظهر مواد الفرع الذي تختاره في الصفحة الرئيسية.'
                                : kind == 'password'
                                ? 'اختر كلمة مرور جديدة لا تقل عن 6 أحرف.'
                                : 'اكتب الاسم الذي تريد عرضه داخل سند.',
                            style: const TextStyle(
                              color: Color(0xFF737B8B),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (kind == 'stage')
                            DropdownButtonFormField<String>(
                              initialValue: stage,
                              decoration: decoration('الفرع الدراسي'),
                              items: ['سادس علمي', 'سادس أدبي']
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: saving
                                  ? null
                                  : (value) => stage = value,
                              validator: (value) =>
                                  value == null ? 'اختر الفرع الدراسي' : null,
                            )
                          else
                            TextFormField(
                              controller: controller,
                              enabled: !saving,
                              textDirection: kind == 'name'
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              keyboardType: kind == 'email'
                                  ? TextInputType.emailAddress
                                  : TextInputType.text,
                              obscureText: kind == 'password' && obscure,
                              autocorrect: kind == 'name',
                              enableSuggestions: kind == 'name',
                              decoration:
                                  decoration(
                                    kind == 'name'
                                        ? 'الاسم الكامل'
                                        : kind == 'email'
                                        ? 'البريد الجديد'
                                        : 'كلمة المرور الجديدة',
                                  ).copyWith(
                                    suffixIcon: kind == 'password'
                                        ? IconButton(
                                            onPressed: saving
                                                ? null
                                                : () => update(
                                                    () => obscure = !obscure,
                                                  ),
                                            icon: Icon(
                                              obscure
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                            ),
                                          )
                                        : null,
                                  ),
                              validator: (value) {
                                if (kind == 'password')
                                  return (value?.length ?? 0) < 6
                                      ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                                      : null;
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) return 'يرجى ملء هذا الحقل';
                                if (kind == 'email' &&
                                    !RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(text))
                                  return 'أدخل بريداً إلكترونياً صحيحاً';
                                return null;
                              },
                            ),
                          if (kind == 'password') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: confirmation,
                              enabled: !saving,
                              obscureText: obscure,
                              textDirection: TextDirection.ltr,
                              decoration: decoration('تأكيد كلمة المرور'),
                              validator: (value) => value != controller.text
                                  ? 'كلمتا المرور غير متطابقتين'
                                  : null,
                            ),
                          ],
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _navy,
                                    minimumSize: const Size(0, 50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          if (!formKey.currentState!.validate())
                                            return;
                                          update(() {
                                            saving = true;
                                            error = null;
                                          });
                                          try {
                                            switch (kind) {
                                              case 'name':
                                                await _authService
                                                    .updateUserName(
                                                      controller.text.trim(),
                                                    );
                                              case 'stage':
                                                await _authService
                                                    .updateUserStage(stage!);
                                              case 'email':
                                                await Supabase
                                                    .instance
                                                    .client
                                                    .auth
                                                    .updateUser(
                                                      UserAttributes(
                                                        email: controller.text
                                                            .trim(),
                                                      ),
                                                      emailRedirectTo:
                                                          'com.purecompany.sanad://login-callback',
                                                    );
                                              case 'password':
                                                await Supabase
                                                    .instance
                                                    .client
                                                    .auth
                                                    .updateUser(
                                                      UserAttributes(
                                                        password:
                                                            controller.text,
                                                      ),
                                                    );
                                            }
                                            if (!mounted ||
                                                !sheetContext.mounted)
                                              return;
                                            _loadUserData();
                                            Navigator.pop(sheetContext);
                                            _message(
                                              kind == 'email'
                                                  ? 'تم إرسال طلب تأكيد تغيير البريد الإلكتروني.'
                                                  : 'تم حفظ التغيير بنجاح.',
                                            );
                                          } catch (failure) {
                                            if (sheetContext.mounted)
                                              update(() {
                                                saving = false;
                                                error = _error(failure);
                                              });
                                          }
                                        },
                                  child: saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('حفظ التغيير'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(sheetContext),
                                child: const Text(
                                  'إلغاء',
                                  style: TextStyle(color: Color(0xFF737B8B)),
                                ),
                              ),
                            ],
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
      ),
    );
    // Wait until the sheet finishes its closing animation before disposing fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    confirmation.dispose();
  }

  Future<void> _pickImage() async {
    if (_isLoading) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 80,
      );
      if (image == null || !mounted) return;
      setState(() => _isLoading = true);
      final url = await _authService.uploadProfileImage(File(image.path));
      if (!mounted) return;
      if (url == null) throw StateError('Upload failed');
      setState(
        () => _profileImagePath =
            '$url?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      _message('تم تحديث الصورة الشخصية.');
    } catch (_) {
      _message('تعذر تحديث الصورة. حاول مجدداً.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirm(String action) async {
    if (_isLoading) return;
    final deleteAccount = action == 'account';
    final deletePhoto = action == 'photo';
    final title = deleteAccount
        ? 'حذف الحساب نهائياً'
        : deletePhoto
        ? 'حذف الصورة الشخصية'
        : 'تسجيل الخروج';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(title),
          content: Text(
            deleteAccount
                ? 'سيتم حذف بيانات حسابك ولا يمكن التراجع عن هذا الإجراء. هل تريد المتابعة؟'
                : deletePhoto
                ? 'هل تريد حذف صورتك الشخصية؟'
                : 'هل تريد تسجيل الخروج من سند؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                deleteAccount || deletePhoto ? 'حذف' : 'خروج',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      if (deletePhoto) {
        await _authService.deleteProfileImage();
        if (mounted) setState(() => _profileImagePath = null);
        _message('تم حذف الصورة الشخصية.');
      } else {
        if (deleteAccount) {
          await _authService.deleteAccount();
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        } else {
          await _authService.signOut();
        }
        if (mounted)
          Navigator.pushNamedAndRemoveUntil(
            context,
            deleteAccount ? '/signup' : '/signin',
            (_) => false,
          );
      }
    } catch (_) {
      _message('تعذر إتمام العملية. حاول مجدداً.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _initialAvatar(double fontSize) {
    final name = userName.trim();
    final initial = name.isEmpty ? 'س' : name.characters.first.toUpperCase();
    return Container(
      color: const Color(0xFFF0F2F6),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: _navy,
        ),
      ),
    );
  }

  Widget _avatar(double radius) {
    final path = _profileImagePath;
    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: path == null || path.isEmpty
            ? _initialAvatar(radius * 0.8)
            : path.startsWith('http')
            ? Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => _initialAvatar(radius * 0.8),
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => _initialAvatar(radius * 0.8),
              ),
      ),
    );
  }

  Future<void> _showFullImage() async {
    final path = _profileImagePath;
    final hasPhoto = path != null && path.isNotEmpty;
    Widget fallback() => _initialAvatar(80);
    final delete = await showDialog<bool>(
      context: context,
      builder: (viewerContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(viewerContext, false),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF737B8B),
                    ),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: SizedBox.expand(
                            child: hasPhoto
                                ? (path.startsWith('http')
                                      ? Image.network(
                                          path,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, error, stack) =>
                                              fallback(),
                                        )
                                      : Image.file(
                                          File(path),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, error, stack) =>
                                              fallback(),
                                        ))
                                : fallback(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasPhoto)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB64B4B),
                      ),
                      onPressed: () => Navigator.pop(viewerContext, true),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text('حذف الصورة'),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
    if (delete == true && mounted) await _confirm('photo');
  }

  Widget _row(
    String title,
    String? value,
    IconData icon,
    VoidCallback? tap, {
    bool danger = false,
    bool email = false,
  }) {
    final color = danger ? const Color(0xFFC44848) : _navy;
    return ListTile(
      enabled: !_isLoading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFF0F0) : const Color(0xFFF3F4F7),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: value == null ? FontWeight.w600 : FontWeight.w500,
          color: value == null ? color : const Color(0xFF737B8B),
        ),
      ),
      subtitle: value == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                value,
                textDirection: email ? TextDirection.ltr : TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      trailing: tap == null
          ? null
          : const Icon(
              Icons.chevron_left_rounded,
              textDirection: TextDirection.ltr,
              size: 20,
              color: Color(0xFFA2A9B6),
            ),
      onTap: _isLoading ? null : tap,
    );
  }

  Widget _section(String title, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: _navy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE9ECF1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 1, color: Color(0xFFF0F1F4)),
                ),
              rows[i],
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F8),
        foregroundColor: _navy,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _navy,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'الملف الشخصي',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 20,
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          onTap: _isLoading ? null : _showFullImage,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _navy.withAlpha(15),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: _avatar(78),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Material(
                            color: _navy,
                            shape: const CircleBorder(
                              side: BorderSide(color: Colors.white, width: 3),
                            ),
                            child: IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 44,
                                height: 44,
                              ),
                              padding: const EdgeInsets.all(6),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              tooltip: 'تغيير الصورة الشخصية',
                              onPressed: _isLoading ? null : _pickImage,
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        if (_isLoading)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(color: _gold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _section('المعلومات الشخصية', [
                  _row(
                    'الاسم الكامل',
                    userName,
                    Icons.person_outline_rounded,
                    () => _edit('name'),
                  ),
                  _row(
                    'البريد الإلكتروني',
                    userEmail,
                    Icons.mail_outline_rounded,
                    null,
                    email: true,
                  ),
                  _row(
                    'المرحلة والفرع الدراسي',
                    selectedStage,
                    Icons.school_outlined,
                    () => _edit('stage'),
                  ),
                ]),
                const SizedBox(height: 18),
                _section('الأمان والحساب', [
                  _row(
                    'تغيير كلمة المرور',
                    null,
                    Icons.lock_outline_rounded,
                    () => _edit('password'),
                  ),
                  _row(
                    'تسجيل الخروج',
                    null,
                    Icons.logout_rounded,
                    () => _confirm('logout'),
                  ),
                  _row(
                    'حذف الحساب',
                    null,
                    Icons.delete_outline_rounded,
                    () => _confirm('account'),
                    danger: true,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
