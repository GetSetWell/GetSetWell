import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Result of asking Firebase to send a login code by SMS.
class PhoneOtpRequest {
  const PhoneOtpRequest({
    required this.verificationId,
    this.resendToken,
    this.autoVerified = false,
  });

  /// Empty when [autoVerified] is true and no code was needed.
  final String verificationId;

  /// Pass back on resend so Firebase treats it as a resend, not a new request.
  final int? resendToken;

  /// True when Android verified the number instantly and the user is already
  /// signed in, so there is no code to type.
  final bool autoVerified;
}

/// Emitted when Android reads the SMS on its own after the code was sent and
/// the user has been signed in with that credential.
class PhoneAutoVerification {
  const PhoneAutoVerification({required this.phone, this.smsCode});

  final String phone;
  final String? smsCode;
}

class FirebasePhoneVerificationService {
  FirebasePhoneVerificationService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static final StreamController<PhoneAutoVerification> _autoVerifiedController =
      StreamController<PhoneAutoVerification>.broadcast();

  /// Android SMS auto-retrieval sign-ins that happen after the code screen is
  /// already showing. The code screen listens and completes the login.
  static Stream<PhoneAutoVerification> get autoVerifications => _autoVerifiedController.stream;

  Future<PhoneOtpRequest> sendOtp({required String phone, int? forceResendingToken}) async {
    final completer = Completer<PhoneOtpRequest>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
      verificationCompleted: (credential) async {
        // Android instant verification or SMS auto-retrieval. Sign in with the
        // credential so the user is not left waiting for the timeout.
        try {
          await _auth.signInWithCredential(credential);

          if (!completer.isCompleted) {
            completer.complete(
              PhoneOtpRequest(
                verificationId: credential.verificationId ?? '',
                resendToken: forceResendingToken,
                autoVerified: true,
              ),
            );
          } else {
            _autoVerifiedController.add(
              PhoneAutoVerification(phone: phone, smsCode: credential.smsCode),
            );
          }
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Automatic phone sign-in failed: $error');
          }

          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneOtpRequest(verificationId: verificationId, resendToken: resendToken),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Phone verification timed out.'));
        }
      },
    );

    return completer.future;
  }

  /// Signs in with the code the user typed. Waiting for the Supabase role
  /// claim is handled by the caller.
  Future<User> verifyOtp({required String verificationId, required String otp}) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otp);

    final result = await _auth.signInWithCredential(credential);

    final user = result.user;

    if (user == null) {
      throw StateError('Firebase sign-in returned no user.');
    }

    return user;
  }
}
