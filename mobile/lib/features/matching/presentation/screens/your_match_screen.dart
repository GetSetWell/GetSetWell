import 'package:flutter/material.dart';
import 'package:mobile/core/widgets/common/gsw_missing_route_data_screen.dart';
import 'package:mobile/features/matching/presentation/widgets/concierge_request_detail_view.dart';

/// "Your trainer request" with a recommendation ready (Figma 9.2, 819:2959).
///
/// Same record and layout as the request status screen (note 819:3021: never a
/// different goal or area), so the status chip, trainer card and actions are
/// all driven by the request's real status.
class YourMatchScreen extends StatelessWidget {
  const YourMatchScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    if (requestId.trim().isEmpty) {
      return const GSWMissingRouteDataScreen();
    }

    return ConciergeRequestDetailView(requestId: requestId);
  }
}
