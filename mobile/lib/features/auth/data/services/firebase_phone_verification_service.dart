import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class FirebasePhoneVerificationService {
  FirebasePhoneVerificationService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<String> sendTestOtp({required String phone}) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) {
        // Automatic verification will be handled separately.
        // Do not create a Firebase session here.
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
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

  Future<String> verifyTestOtp({required String verificationId, required String otp}) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otp);

    final result = await _auth.signInWithCredential(credential);

    final idToken = await result.user?.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw StateError('Firebase ID token is unavailable.');
    }

    final tokenResult = await result.user!.getIdTokenResult(true);

    if (tokenResult.claims?['role'] != 'authenticated') {
      throw StateError('Firebase token is missing the authenticated role claim.');
    }

    return idToken;
  }
}
