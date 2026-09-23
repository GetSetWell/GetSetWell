import 'package:supabase_flutter/supabase_flutter.dart';

class PhoneAuthService {
  PhoneAuthService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> sendOtp({required String phone}) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyOtp({required String phone, required String otp}) async {
    return _client.auth.verifyOTP(phone: phone, token: otp, type: OtpType.sms);
  }
}
