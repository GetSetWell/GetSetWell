import 'package:mobile/features/booking/domain/models/concierge_match_payload.dart';

enum AuthFlowType {
  home,
  conciergeMatch,

  /// Sign in from inside a flow (booking, payment) and come back to it.
  returnToCaller,
}

enum AuthEntryPoint { getStarted, existingAccount, helpMeChoose }

class AuthFlowIntent {
  const AuthFlowIntent._({
    required this.type,
    required this.entryPoint,
    this.conciergePayload,
  });

  final AuthFlowType type;
  final AuthEntryPoint entryPoint;
  final ConciergeMatchPayload? conciergePayload;

  const AuthFlowIntent.getStarted()
    : this._(type: AuthFlowType.home, entryPoint: AuthEntryPoint.getStarted);

  const AuthFlowIntent.existingAccount()
    : this._(
        type: AuthFlowType.home,
        entryPoint: AuthEntryPoint.existingAccount,
      );

  /// "Sign in to book": after sign-in, pop back to the screen that opened
  /// the phone entry instead of going Home.
  const AuthFlowIntent.returnToCaller()
    : this._(
        type: AuthFlowType.returnToCaller,
        entryPoint: AuthEntryPoint.existingAccount,
      );

  const AuthFlowIntent.conciergeMatch(ConciergeMatchPayload payload)
    : this._(
        type: AuthFlowType.conciergeMatch,
        entryPoint: AuthEntryPoint.helpMeChoose,
        conciergePayload: payload,
      );
}
