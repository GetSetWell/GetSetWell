import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';

class OtpRouteArgs {
  const OtpRouteArgs({required this.phone, required this.intent});

  final String phone;
  final AuthFlowIntent intent;
}
