import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // تسجيل الدخول الصامت باستخدام جوجل
  Future<AuthResponse?> signInGoogleSilently() async {
    try {
      const webClientId = '218216743464-4o6489e2bde76j4f8cvqm2n8gunib55d.apps.googleusercontent.com';
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: webClientId);
      
      final googleUser = await googleSignIn.signInSilently();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) return null;

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        // لا نقوم بتخزين بيانات المستخدم محلياً - نعتمد فقط على Supabase
      }

      return response;
    } catch (e) {
      print('Silent Google Sign-In Error: $e');
      return null;
    }
  }

  // تسجيل الدخول باستخدام جوجل
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // 1. إعداد GoogleSignIn
      // ملاحظة: لـ Android يجب استخدام webClientId من Google Cloud Console (Web application)
      const webClientId = '218216743464-4o6489e2bde76j4f8cvqm2n8gunib55d.apps.googleusercontent.com';
      
      // في Supabase، لـ Native Android نحتاج لـ idToken
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw 'تم إلغاء عملية تسجيل الدخول';

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'لم يتم العثور على ID Token من جوجل';
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        // لا نقوم بتخزين بيانات المستخدم محلياً - نعتمد فقط على Supabase
      }

      return response;
    } catch (e) {
      print('Google Sign-In Error: $e');
      rethrow;
    }
  }

  // الحصول على المستخدم الحالي
  User? get currentUser => _supabase.auth.currentUser;

  // دفق حالة المصادقة
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // حفظ بيانات المستخدم محلياً (تم إلغاؤه والاعتماد الكامل على Supabase)
  Future<void> _saveLocalData(User user, {String? fullName, String? stage}) async {
    // تم إلغاء التخزين المحلي لبيانات المستخدم
  }

  // تحديث المرحلة الدراسية في السحابة فقط
  Future<void> updateUserStage(String stage) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // تحديث في Supabase فقط
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {'user_stage': stage},
        ),
      );
    } catch (e) {
      print('Error updating stage: $e');
      rethrow;
    }
  }

  // تحديث اسم المستخدم في السحابة
  Future<void> updateUserName(String fullName) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.auth.updateUser(
        UserAttributes(
          data: {'full_name': fullName},
        ),
      );
    } catch (e) {
      print('Error updating name: $e');
      rethrow;
    }
  }

  // حذف الحساب نهائياً
  Future<void> deleteAccount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      // 1. حذف الصور من Storage
      await deleteProfileImage();

      // 2. استدعاء الدالة البرمجية لحذف الحساب نهائياً من Supabase
      await _supabase.rpc('delete_user_account');
      
      // 3. تسجيل الخروج ومسح البيانات المحلية
      await _clearLocalData();
    } catch (e) {
      print('Error during account deletion: $e');
      rethrow;
    }
  }

  // مسح البيانات المحلية
  Future<void> _clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_stage');
    await prefs.remove('profile_image_path');
  }

  // إنشاء حساب جديد
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
      },
      emailRedirectTo: 'com.purecompany.sanad://login-callback',
    );
    
    return response;
  }

  // تسجيل الدخول
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user != null && response.user!.emailConfirmedAt != null) {
      // تم تسجيل الدخول بنجاح الجلسة تحفظ تلقائيا عبر SDK Supabase
    }
    
    return response;
  }

  // رفع الصورة إلى Supabase Storage
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final fileExt = imageFile.path.split('.').last;
      final fileName = '${user.id}.$fileExt';
      final filePath = 'avatars/$fileName';

      // 1. حذف أي صور قديمة للمستخدم داخل مجلد avatars لتجنب التكرار
      try {
        final List<FileObject> existingFiles = await _supabase.storage
            .from('profiles')
            .list(path: 'avatars');
        
        final List<String> filesToDelete = existingFiles
            .where((file) => file.name.startsWith(user.id))
            .map((file) => 'avatars/${file.name}')
            .toList();

        if (filesToDelete.isNotEmpty) {
          await _supabase.storage.from('profiles').remove(filesToDelete);
        }
      } catch (e) {
        print('Cleaning old images error: $e');
      }

      // 2. رفع الملف الجديد
      await _supabase.storage.from('profiles').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      // 3. الحصول على رابط الصورة العام
      final String publicUrl = _supabase.storage.from('profiles').getPublicUrl(filePath);
      
      // إضافة طابع زمني لتجنب التخزين المؤقت
      final String finalUrl = "$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}";
      
      print('Uploading to path: $filePath');
      print('New Public URL: $finalUrl');

      // 4. تحديث بيانات المستخدم في Supabase Auth metadata
      final response = await _supabase.auth.updateUser(
        UserAttributes(
          data: {'profile_image': finalUrl},
        ),
      );

      if (response.user != null) {
        print('Database updated successfully for user: ${response.user!.id}');
      }

      return finalUrl;
    } catch (e) {
      print('CRITICAL ERROR during image upload: $e');
      rethrow;
    }
  }

  // حذف الصورة الشخصية من السحابة ومحلياً
  Future<void> deleteProfileImage() async {
    try {
      final user = currentUser;
      if (user == null) return;

      // 1. حذف الملفات من Storage
      try {
        final List<FileObject> existingFiles = await _supabase.storage
            .from('profiles')
            .list(path: 'avatars');
        
        final List<String> filesToDelete = existingFiles
            .where((file) => file.name.startsWith(user.id))
            .map((file) => 'avatars/${file.name}')
            .toList();

        if (filesToDelete.isNotEmpty) {
          await _supabase.storage.from('profiles').remove(filesToDelete);
        }
      } catch (e) {
        print('Error deleting storage file: $e');
      }

      // 2. تحديث بيانات المستخدم في Supabase (جعل الرابط null)
      final response = await _supabase.auth.updateUser(
        UserAttributes(
          data: {'profile_image': null},
        ),
      );

      // 3. تحديث البيانات المحلية
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_image_path');
      
      if (response.user != null) {
        // لا نقوم بتخزين بيانات المستخدم محلياً - نعتمد فقط على Supabase
      }
    } catch (e) {
      print('Error during image deletion: $e');
      rethrow;
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await _clearLocalData();
  }

  // إرسال رابط استعادة كلمة المرور
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'com.purecompany.sanad://login-callback',
    );
  }

  // التحقق مما إذا كان البريد الإلكتروني موثقاً
  bool isEmailVerified() {
    final user = _supabase.auth.currentUser;
    return user?.emailConfirmedAt != null;
  }
}
