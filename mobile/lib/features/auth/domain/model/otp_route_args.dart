import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';

class OtpRouteArgs {
  const OtpRouteArgs({
    required this.phone,
    required this.intent,
    required this.verificationId,
    this.resendToken,
    this.autoVerified = false,
  });

  final String phone;
  final AuthFlowIntent intent;
  final String verificationId;

  /// Firebase resend token from the first request, passed back on resend.
  final int? resendToken;

  /// Android verified the number instantly, so the user is already signed in.
  final bool autoVerified;
}
