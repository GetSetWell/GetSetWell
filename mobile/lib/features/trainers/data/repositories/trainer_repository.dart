import 'package:mobile/features/trainers/domain/models/training_location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/trainer.dart';

class TrainerRepository {
  const TrainerRepository(this._client);

  final SupabaseClient _client;
  Future<List<String>> getAvailableLanguages() async {
    final response = await _client
        .from('trainers')
        .select('languages')
        .eq('is_active', true)
        .eq('is_verified', true);

    final languages = <String>{};

    for (final row in response) {
      final trainerLanguages = row['languages'];

      if (trainerLanguages is List) {
        for (final language in trainerLanguages) {
          if (language is String && language.trim().isNotEmpty) {
            languages.add(language.trim());
          }
        }
      }
    }

    final result = languages.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return result;
  }

  Future<List<int>> getAvailablePrices() async {
    final response = await _client
        .from('trainers')
        .select('price_per_session')
        .eq('is_active', true)
        .eq('is_verified', true)
        .not('price_per_session', 'is', null);

    final prices = <int>{};

    for (final row in response) {
      final price = row['price_per_session'];

      if (price is num) {
        prices.add(price.round());
      }
    }

    final result = prices.toList()..sort();

    return result;
  }

  Future<List<TrainingLocation>> getAvailableTrainingLocations() async {
    final response = await _client
        .from('training_locations')
        .select('''
        id,
        name,
        slug,
        location_type,
        area,
        is_partner
        ''')
        .eq('is_active', true)
        .order('name');

    return response.map<TrainingLocation>((row) => TrainingLocation.fromJson(row)).toList();
  }

  Future<Set<String>> getAvailableSpecialtySlugs() async {
    final response = await _client
        .from('trainer_specialties')
        .select('''
        specialties!inner (
          slug
        ),
        trainers!inner (
          id,
          is_active,
          is_verified
        )
      ''')
        .eq('trainers.is_active', true)
        .eq('trainers.is_verified', true);

    final slugs = <String>{};

    for (final row in response) {
      final specialty = row['specialties'];

      if (specialty is Map) {
        final slug = specialty['slug'];

        if (slug is String && slug.trim().isNotEmpty) {
          slugs.add(slug.trim().toLowerCase());
        }
      }
    }

    return slugs;
  }

  Future<List<TrainingLocation>> getTrainerTrainingLocations(String trainerId) async {
    final response = await _client
        .from('trainer_training_locations')
        .select('''
        display_order,
        training_locations (
          id,
          name,
          slug,
          location_type,
          area,
          is_partner
        )
        ''')
        .eq('trainer_id', trainerId)
        .order('display_order');

    final locations = <TrainingLocation>[];

    for (final row in response) {
      final location = row['training_locations'];

      if (location is Map<String, dynamic>) {
        locations.add(TrainingLocation.fromJson(location));
      }
    }

    return locations;
  }

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
