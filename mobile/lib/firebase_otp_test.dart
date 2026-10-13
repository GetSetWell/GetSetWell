import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/auth/data/services/firebase_phone_verification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MaterialApp(home: FirebaseOtpTestScreen()));
}

class FirebaseOtpTestScreen extends StatefulWidget {
  const FirebaseOtpTestScreen({super.key});

  @override
  State<FirebaseOtpTestScreen> createState() => _FirebaseOtpTestScreenState();
}

class _FirebaseOtpTestScreenState extends State<FirebaseOtpTestScreen> {
  final _service = FirebasePhoneVerificationService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _verificationId;
  String _status = 'Ready to test Firebase OTP';

  Future<void> _sendOtp() async {
    try {
      final id = await _service.sendTestOtp(phone: _phoneController.text.trim());

      setState(() {
        _verificationId = id;
        _status = 'Code requested. Enter the test OTP.';
      });
    } catch (error) {
      setState(() => _status = 'Send failed: $error');
    }
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => _status = 'No Firebase user signed in');
      return;
    }

    final token = await user.getIdTokenResult(true);
    final role = token.claims?['role'];

    if (!mounted) return;

    setState(() {
      _status = role == 'authenticated'
          ? 'SUCCESS: Firebase authenticated role confirmed!'
          : 'Role claim missing: ${role ?? 'null'}';
    });
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;

    try {
      await _service.verifyTestOtp(
        verificationId: _verificationId!,
        otp: _otpController.text.trim(),
      );

      setState(() {
        _status = 'Firebase OTP verified. Role claim confirmed!';
      });
    } catch (error) {
      setState(() => _status = 'Verification failed: $error');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase OTP Test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Firebase test phone (+country code)'),
            ),
            ElevatedButton(onPressed: _sendOtp, child: const Text('Send test OTP')),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Six-digit test code'),
            ),
            ElevatedButton(onPressed: _verifyOtp, child: const Text('Verify OTP')),
            const SizedBox(height: 24),
            Text(_status),
            ElevatedButton(onPressed: _checkRole, child: const Text('Check Firebase role')),
          ],
        ),
      ),
    );
  }
}
