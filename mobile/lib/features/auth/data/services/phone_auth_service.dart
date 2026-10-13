import 'firebase_phone_verification_service.dart';

class PhoneAuthService {
  PhoneAuthService({FirebasePhoneVerificationService? firebaseService})
    : _firebaseService = firebaseService ?? FirebasePhoneVerificationService();

  final FirebasePhoneVerificationService _firebaseService;

  String? _verificationId;

  Future<void> sendOtp({required String phone}) async {
    _verificationId = await _firebaseService.sendTestOtp(phone: phone);
  }

  Future<String> verifyOtp({
    required String phone,
    required String otp,
    String? verificationId,
  }) async {
    final id = verificationId ?? _verificationId;

    if (id == null || id.isEmpty) {
      throw StateError('Firebase verification ID is missing.');
    }

    return _firebaseService.verifyTestOtp(verificationId: id, otp: otp);
  }

  String? get verificationId => _verificationId;
}
