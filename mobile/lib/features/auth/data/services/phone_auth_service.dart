import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_phone_verification_service.dart';

class PhoneAuthService {
  PhoneAuthService({FirebasePhoneVerificationService? firebaseService})
    : _firebaseService = firebaseService ?? FirebasePhoneVerificationService();

  final FirebasePhoneVerificationService _firebaseService;

  /// Sends a login code by SMS. Pass [forceResendingToken] from the previous
  /// request when resending.
  Future<PhoneOtpRequest> sendOtp({required String phone, int? forceResendingToken}) {
    return _firebaseService.sendOtp(phone: phone, forceResendingToken: forceResendingToken);
  }

  Future<User> verifyOtp({required String otp, required String verificationId}) {
    if (verificationId.isEmpty) {
      throw StateError('Firebase verification ID is missing.');
    }

    return _firebaseService.verifyOtp(verificationId: verificationId, otp: otp);
  }
}
