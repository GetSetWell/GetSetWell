import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/profile_repository.dart';

/// Where a cold start should land.
enum SessionDestination {
  /// Nobody is signed in.
  welcome,

  /// Signed in with name and city saved.
  home,

  /// Signed in but the profile is not finished.
  details,

  /// Signed in, but the profile check failed or was too slow. Show Welcome
  /// and keep resolving in the background.
  unresolved,
}

/// Decides the cold-start destination without ever guessing Home: a signed-in
/// user only goes Home once the profile check says the profile is complete.
Future<SessionDestination> resolveSessionDestination({
  Duration timeout = const Duration(milliseconds: 1500),
  ProfileRepository? profileRepository,
}) async {
  if (FirebaseAuth.instance.currentUser == null) {
    return SessionDestination.welcome;
  }

  try {
    final repository = profileRepository ?? ProfileRepository();

    final hasCompletedProfile = await repository.hasCompletedProfile().timeout(timeout);

    if (FirebaseAuth.instance.currentUser == null) {
      return SessionDestination.welcome;
    }

    return hasCompletedProfile ? SessionDestination.home : SessionDestination.details;
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Session check failed: $error');
    }

    return SessionDestination.unresolved;
  }
}
