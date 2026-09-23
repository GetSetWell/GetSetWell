import 'package:mobile/features/booking/domain/models/concierge_match_payload.dart';


class UserDetailsRouteArgs {
  const UserDetailsRouteArgs({
    this.conciergePayload,
  });

  final ConciergeMatchPayload? conciergePayload;

  bool get isHelpMeChoose =>
      conciergePayload != null;
}