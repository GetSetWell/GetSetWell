import 'package:mobile/features/booking/domain/models/concierge_match_payload.dart';

enum AuthFlowType { home, conciergeMatch }

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

  const AuthFlowIntent.conciergeMatch(ConciergeMatchPayload payload)
    : this._(
        type: AuthFlowType.conciergeMatch,
        entryPoint: AuthEntryPoint.helpMeChoose,
        conciergePayload: payload,
      );

  bool get isCreatingAccount => entryPoint == AuthEntryPoint.getStarted;

  bool get hasConciergeRequest =>
      type == AuthFlowType.conciergeMatch && conciergePayload != null;
}
