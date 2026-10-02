import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionDetailsScreen extends StatefulWidget {
  const SessionDetailsScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  late final Future<Map<String, dynamic>> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadSession();
  }

  Future<Map<String, dynamic>> _loadSession() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('Authentication required.');
    }

    final row = await client
        .from('sessions')
        .select('''
          id,
          booking_request_id,
          trainer_id,
          scheduled_at,
          location_label,
          status,
          trainers(
            id,
            full_name,
            profile_image_url,
            price_per_session
          ),
          booking_requests(
            id,
            reference_code,
            request_type,
            goal,
            message
          )
        ''')
        .eq('id', widget.sessionId)
        .eq('user_id', user.id)
        .single();

    return Map<String, dynamic>.from(row);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _sessionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }

            if (snapshot.hasError || snapshot.data == null) {
              debugPrint('Session details load failed: ${snapshot.error}');

              return const Center(
                child: Text('Could not load this session.', style: TextStyle(color: Colors.white)),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
