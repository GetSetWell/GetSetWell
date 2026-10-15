import 'package:flutter/material.dart';
import 'package:mobile/core/widgets/common/gsw_missing_route_data_screen.dart';
import 'package:mobile/features/matching/presentation/widgets/concierge_request_detail_view.dart';

/// Request detail opened from Home, Sessions and notifications.
///
/// Renders Figma 9.2b (1174:3781) while matching, 9.2 (819:2959) when the
/// recommendation is ready and 9.4 (819:3044) once booked. The layout lives in
/// [ConciergeRequestDetailView] so YourMatchScreen shows the same record.
class ConciergeRequestStatusScreen extends StatelessWidget {
  const ConciergeRequestStatusScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    if (requestId.trim().isEmpty) {
      return const GSWMissingRouteDataScreen();
    }

    return ConciergeRequestDetailView(requestId: requestId);
  }
}
