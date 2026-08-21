import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/trainer.dart';

class TrainerRepository {
  const TrainerRepository(this._client);

  final SupabaseClient _client;

  Future<List<Trainer>> getTrainers() async {
    final data = await _client
        .from('trainers')
        .select('''
        id,
        full_name,
        slug,
        gender,
        credentials,
        bio,
        years_experience,
        price_per_session,
        profile_image_url,
        service_area,
        languages,
        availability_note,
        session_duration_minutes,
        session_format,
        session_locations,
        session_schedule_note,
        payment_note,
        is_verified,
        display_order,
        trainer_services (
          is_primary,
          services (
            name
          )
        ),
        trainer_verification_checks (
          id,
          title,
          description,
          check_type,
          display_order,
          is_verified
        ),
        trainer_specialties (
          specialties (
          name,
          slug
          )
        ),
        trainer_fit_points (
          id,
          text,
          display_order
        )
        ''')
        .order('display_order', ascending: true);

    return data.map((json) {
      final trainerJson = Map<String, dynamic>.from(json);

      final imagePath = trainerJson['profile_image_url'] as String?;

      if (imagePath != null && imagePath.isNotEmpty) {
        trainerJson['profile_image_url'] = _client.storage
            .from('trainer-images')
            .getPublicUrl(imagePath);
      }

      return Trainer.fromJson(trainerJson);
    }).toList();
  }
}
