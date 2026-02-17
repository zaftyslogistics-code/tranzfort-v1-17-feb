import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String mobile,
  }) async {
    final normalizedMobile = _normalizeIndianPhone(mobile);
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'mobile': normalizedMobile,
      },
    );
    return response;
  }

  Future<AuthResponse> signInWithPassword({
    required String identifier,
    required String password,
  }) async {
    final isEmail = identifier.contains('@');

    if (isEmail) {
      return await _supabase.auth.signInWithPassword(
        email: identifier,
        password: password,
      );
    } else {
      final mobile = _normalizeIndianPhone(identifier);
      return await _supabase.auth.signInWithPassword(
        phone: mobile,
        password: password,
      );
    }
  }

  Future<void> signInWithOtp({required String mobile}) async {
    final phone = _normalizeIndianPhone(mobile);
    await _supabase.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    final phone = _normalizeIndianPhone(mobile);
    return await _supabase.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
  }

  String _normalizeIndianPhone(String input) {
    var digits = input.trim().replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }

    if (digits.length != 10) {
      throw const FormatException(
        'Please enter a valid 10-digit Indian mobile number.',
      );
    }

    return '+91$digits';
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut(scope: SignOutScope.local);
  }

  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<String?> getUserRole() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('profiles')
        .select('current_role')
        .eq('id', userId)
        .maybeSingle();

    return response?['current_role'] as String?;
  }

  Future<void> updateUserRole(String role) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    final updated = await _supabase
        .from('profiles')
        .update({'current_role': role})
        .eq('id', userId)
        .select('id')
        .maybeSingle();

    if (updated == null) {
      final user = currentUser;
      if (user == null) return;

      final fullName = user.userMetadata?['full_name'] as String? ?? '';
      final email = user.email ?? '';
      final fallbackMobile = user.userMetadata?['mobile'] as String? ?? '';
      final mobile = (user.phone?.isNotEmpty == true)
          ? user.phone!
          : fallbackMobile;

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName.isNotEmpty ? fullName : email.split('@').first,
        'email': email,
        'mobile': mobile,
        'current_role': role,
      }, onConflict: 'id');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  }

  Future<void> ensureProfileExists() async {
    final user = currentUser;
    if (user == null) return;

    final existing = await _supabase
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (existing == null) {
      final fullName =
          user.userMetadata?['full_name'] as String? ?? '';
      final email = user.email ?? '';
      final mobile = (user.phone?.isNotEmpty == true)
          ? user.phone!
          : (user.userMetadata?['mobile'] as String? ?? '');

      await _supabase.from('profiles').insert({
        'id': user.id,
        'full_name': fullName.isNotEmpty ? fullName : email.split('@').first,
        'email': email,
        'mobile': mobile,
      });
    }
  }
}
