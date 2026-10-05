import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _completed = false;
  String? _error;
  static const _primary = Color(0xFF1A2238);

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_isLoading || _completed || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (mounted) {
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() => _completed = true);
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is AuthException
          ? switch (error.code) {
              'weak_password' => 'كلمة المرور ضعيفة. اختر كلمة مرور أقوى.',
              'same_password' => 'اختر كلمة مرور مختلفة عن السابقة.',
              'reauthentication_needed' =>
                'انتهت صلاحية التحقق. اطلب رابط استعادة جديداً.',
              'session_not_found' =>
                'انتهت صلاحية الجلسة. اطلب رابط استعادة جديداً.',
              'over_request_rate_limit' => 'انتظر قليلاً قبل إعادة المحاولة.',
              _ => 'تعذر تغيير كلمة المرور. حاول مجدداً.',
            }
          : 'تعذر الاتصال. تحقق من الإنترنت وحاول مجدداً.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _field({required bool confirmation}) {
    final obscure = confirmation ? _obscureConfirmation : _obscurePassword;
    return TextFormField(
      controller: confirmation
          ? _confirmPasswordController
          : _passwordController,
      enabled: !_isLoading,
      obscureText: obscure,
      textDirection: TextDirection.ltr,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: confirmation
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: confirmation ? (_) => _updatePassword() : null,
      validator: (value) {
        if (value == null || value.isEmpty)
          return confirmation
              ? 'يرجى تأكيد كلمة المرور'
              : 'يرجى إدخال كلمة المرور';
        if (confirmation)
          return value != _passwordController.text
              ? 'كلمتا المرور غير متطابقتين'
              : null;
        return value.length < 6
            ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
            : null;
      },
      decoration: InputDecoration(
        labelText: confirmation ? 'تأكيد كلمة المرور' : 'كلمة المرور الجديدة',
        prefixIcon: Icon(
          confirmation ? Icons.lock_reset_outlined : Icons.lock_outline_rounded,
          size: 20,
        ),
        suffixIcon: IconButton(
          onPressed: _isLoading
              ? null
              : () => setState(() {
                  if (confirmation) {
                    _obscureConfirmation = !_obscureConfirmation;
                  } else {
                    _obscurePassword = !_obscurePassword;
                  }
                }),
          tooltip: obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback action) => SizedBox(
    height: 50,
    child: ElevatedButton(
      onPressed: _isLoading ? null : action,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
    ),
  );

  @override
  Widget build(BuildContext context) {
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'سند',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _primary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _completed
                                  ? 'تم تغيير كلمة المرور'
                                  : 'عيّن كلمة مرور جديدة',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _completed
                                  ? 'يمكنك الآن استخدام كلمة المرور الجديدة لتسجيل الدخول.'
                                  : 'اختر كلمة مرور قوية لحماية حسابك في سند.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                height: 1.6,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 14),
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
                                    color: _primary.withValues(alpha: 0.07),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: _completed
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          child: Icon(
                                            Icons.check_circle_outline_rounded,
                                            color: Color(0xFF39805B),
                                            size: 52,
                                          ),
                                        ),
                                        _button(
                                          'تسجيل الدخول',
                                          () =>
                                              Navigator.pushNamedAndRemoveUntil(
                                                context,
                                                '/signin',
                                                (_) => false,
                                              ),
                                        ),
                                      ],
                                    )
                                  : AutofillGroup(
                                      child: Form(
                                        key: _formKey,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _field(confirmation: false),
                                            const SizedBox(height: 12),
                                            _field(confirmation: true),
                                            const SizedBox(height: 12),
                                            if (_error != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: Text(
                                                  _error!,
                                                  style: const TextStyle(
                                                    color: Colors.redAccent,
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ),
                                            _button(
                                              'تحديث كلمة المرور',
                                              _updatePassword,
                                            ),
                                          ],
                                        ),
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
            ),
          ),
        ),
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
