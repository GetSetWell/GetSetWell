import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/common/header.dart';
import 'package:mobile/core/widgets/navigation/gsw_bottom_nav.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../trainers/data/repositories/trainer_repository.dart';
import '../../../trainers/domain/models/trainer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SupabaseClient _client;
  late final TrainerRepository _trainerRepository;
  late final Future<List<Trainer>> _trainersFuture;
  late Future<_HomeData> _homeDataFuture;

  @override
  void initState() {
    super.initState();

    _client = Supabase.instance.client;
    _trainerRepository = TrainerRepository(_client);
    _trainersFuture = _trainerRepository.getTrainers();
    _homeDataFuture = _loadHomeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: RefreshIndicator(
            color: GSWColors.primary,
            onRefresh: _refreshHomeData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: FutureBuilder<_HomeData>(
                future: _homeDataFuture,
                builder: (context, snapshot) {
                  final homeData = snapshot.data ?? const _HomeData();
                  final primaryRequest = homeData.primaryRequest;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Header(),

                      const SizedBox(height: 32),

                      // Priority 1: a confirmed upcoming session.
                      if (homeData.nextSession != null) ...[
                        _buildNextSessionCard(homeData.nextSession!),
                        const SizedBox(height: 32),
                      ]
                      // Priority 2: concierge match is ready.
                      else if (primaryRequest?.isMatched == true) ...[
                        _buildMatchReadyCard(primaryRequest!),
                        const SizedBox(height: 32),
                      ]
                      // Priority 3: concierge matching is still in progress.
                      else if (primaryRequest?.isInProgress == true) ...[
                        _buildMatchingInProgressCard(primaryRequest!),
                        const SizedBox(height: 32),
                      ],

                      _buildGreeting(homeData),

                      const SizedBox(height: 32),

                      // If any concierge request is still active, keep its
                      // tracking card visible. Otherwise show the entry point
                      // for a new Help Me Choose request.
                      if (primaryRequest != null)
                        _buildRequestReviewCard(primaryRequest)
                      else
                        _buildStartRequestCard(homeData),

                      const SizedBox(height: 32),

                      _buildFeaturedHeader(),

                      const SizedBox(height: 12),

                      _buildFeaturedTrainers(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const GSWBottomNav(currentItem: GSWBottomNavItem.home),
    );
  }

  Future<void> _refreshHomeData() async {
    final future = _loadHomeData();

    if (mounted) {
      setState(() {
        _homeDataFuture = future;
      });
    }

    await future;
  }

  Future<_HomeData> _loadHomeData() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return const _HomeData();
    }

    String? fullName;
    String? city;

    try {
      final profile = await _client
          .from('customer_profiles')
          .select('full_name, city')
          .eq('id', user.id)
          .maybeSingle();

      fullName = profile?['full_name']?.toString().trim();
      city = profile?['city']?.toString().trim();
    } catch (error) {
      debugPrint('Home profile load failed: $error');
    }

    final activeRequests = <_HomeRequest>[];

    try {
      final rows = await _client
          .from('booking_requests')
          .select('id, reference_code, goal, status, created_at, trainer_id, request_type')
          .eq('user_id', user.id)
          .eq('request_type', 'concierge_match')
          .order('created_at', ascending: false)
          .limit(20);

      for (final rawRow in rows) {
        final row = Map<String, dynamic>.from(rawRow);
        final request = _HomeRequest.fromJson(row);

        if (request.isClosed) {
          continue;
        }

        activeRequests.add(request);
      }

      // Only two open Help Me Choose requests are allowed at a time.
      if (activeRequests.length > 2) {
        activeRequests.removeRange(2, activeRequests.length);
      }

      final trainerIds = activeRequests
          .map((request) => request.trainerId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      if (trainerIds.isNotEmpty) {
        try {
          final trainerRows = await _client
              .from('trainers')
              .select('id, full_name')
              .inFilter('id', trainerIds.toList());

          final namesById = <String, String>{};

          for (final trainerRow in trainerRows) {
            final id = trainerRow['id']?.toString().trim() ?? '';
            final name = trainerRow['full_name']?.toString().trim() ?? '';

            if (id.isNotEmpty && name.isNotEmpty) {
              namesById[id] = name;
            }
          }

          for (var index = 0; index < activeRequests.length; index++) {
            final request = activeRequests[index];
            final trainerId = request.trainerId;

            if (trainerId != null && namesById.containsKey(trainerId)) {
              activeRequests[index] = request.copyWith(trainerName: namesById[trainerId]);
            }
          }
        } catch (error) {
          debugPrint('Home matched trainer load failed: $error');
        }
      }
    } catch (error) {
      debugPrint('Home request load failed: $error');
    }

    _HomeSession? nextSession;

    // The sessions table is the source for the "Next session" state.
    // Until that table is migrated, this safely falls back to no session.
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      final rows = await _client
          .from('sessions')
          .select(
            'id, booking_request_id, trainer_id, scheduled_at, location_label, status, trainers(full_name)',
          )
          .eq('user_id', user.id)
          .eq('status', 'confirmed')
          .gte('scheduled_at', nowUtc)
          .order('scheduled_at', ascending: true)
          .limit(1);

      if (rows.isNotEmpty) {
        nextSession = _HomeSession.fromJson(Map<String, dynamic>.from(rows.first));
      }
    } catch (error) {
      debugPrint('Home session load failed: $error');
    }

    return _HomeData(
      fullName: fullName,
      city: city,
      activeRequests: activeRequests,
      nextSession: nextSession,
    );
  }

  Widget _buildGreeting(_HomeData data) {
    final name = _firstName(data.fullName);
    final city = data.city?.trim().isNotEmpty == true ? data.city!.trim() : 'Dubai';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HELLO ${name.toUpperCase()}',
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(color: GSWColors.textPrimary, height: 1),
        ),
        const SizedBox(height: 8),
        Text(
          '$city trainers, checked before they appear.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMatchingInProgressCard(_HomeRequest request) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GSWColors.primary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GSWColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Matching in progress',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: GSWColors.backgroundPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                request.referenceCode,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _goalHeadline(request.goal),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _matchingProgressMessage(request),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: GSWColors.primary, height: 1.45),
          ),
          const SizedBox(height: 14),
          GSWButton(
            size: GSWButtonSize.medium,
            label: 'See the request',
            onPressed: () => _openRequestDetails(request),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchReadyCard(_HomeRequest request) {
    final trainerName = request.trainerName?.trim().isNotEmpty == true
        ? request.trainerName!.trim()
        : 'Your trainer';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GSWColors.primary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GSWColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Match ready',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: GSWColors.backgroundPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                request.referenceCode,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _goalHeadline(request.goal),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$trainerName picked for you',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GSWColors.primary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () => _openMatchedTrainer(request),
              style: FilledButton.styleFrom(
                backgroundColor: GSWColors.primary,
                foregroundColor: GSWColors.backgroundPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('See your match'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextSessionCard(_HomeSession session) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GSWColors.primary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GSWColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Next session',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: GSWColors.backgroundPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _sessionDayLabel(session.scheduledAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _sessionDateTimeLabel(session.scheduledAt),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sessionDescription(session),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GSWColors.primary),
          ),
          const SizedBox(height: 14),
          GSWButton(
            size: GSWButtonSize.medium,
            label: 'View booking',
            onPressed: () {
              // The dedicated Sessions / Booking Detail route will replace
              // this once that screen is built.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking details screen is the next step.')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestReviewCard(_HomeRequest request) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GSWColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Your request is being reviewed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: GSWColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.auto_awesome_outlined, size: 24, color: GSWColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${request.referenceCode}, ${_submittedLabel(request.createdAt)}. '
            'One request at a time gets a person\'s full attention.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          GSWButton(
            size: GSWButtonSize.medium,
            variant: GSWButtonVariant.secondary,
            label: 'See the request',
            onPressed: () => _openRequestDetails(request),
          ),
        ],
      ),
    );
  }

  Widget _buildStartRequestCard(_HomeData homeData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GSWColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not sure who to pick?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us your goal, area and when you can train. A real person reads it and helps you narrow it down.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => _handleStartConciergeRequest(homeData),
              style: OutlinedButton.styleFrom(
                foregroundColor: GSWColors.textPrimary,
                side: const BorderSide(color: GSWColors.borderSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Tell us your situation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Featured trainers',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            context.go(GSWRoutes.browseTrainers);
          },
          style: TextButton.styleFrom(
            foregroundColor: GSWColors.primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('See all'),
        ),
      ],
    );
  }

  Widget _buildFeaturedTrainers() {
    return FutureBuilder<List<Trainer>>(
      future: _trainersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: GSWColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Featured trainers load failed: ${snapshot.error}');

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Unable to load trainers right now.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary),
            ),
          );
        }

        final trainers = snapshot.data ?? [];
        final featured = trainers.take(2).toList();

        if (featured.isEmpty) {
          return Text(
            'Featured trainers will appear here soon.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary),
          );
        }

        return Column(
          children: [
            for (int index = 0; index < featured.length; index++) ...[
              TrainerCard(
                name: featured[index].fullName,
                service: featured[index].primaryService ?? 'Personal Training',
                location: featured[index].serviceArea ?? 'Dubai',
                price: featured[index].pricePerSession ?? 0,
                languages: featured[index].languages,
                imageUrl: featured[index].profileImageUrl,
                verificationChecks: featured[index].verificationChecks,
                onTap: () {
                  context.push(GSWRoutes.trainerProfile, extra: featured[index]);
                },
              ),
              if (index != featured.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Future<void> _handleStartConciergeRequest(_HomeData homeData) async {
    if (homeData.activeRequests.length < 2) {
      await context.push(GSWRoutes.helpMeChoose);

      if (mounted) {
        await _refreshHomeData();
      }
      return;
    }

    final oldestRequest = homeData.oldestActiveRequest;

    if (oldestRequest == null) {
      return;
    }

    final replace = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: GSWColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Two requests are already open',
            style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'You can keep your existing requests, or replace the oldest one '
            '(${oldestRequest.referenceCode}) with a new request.',
            style: Theme.of(
              dialogContext,
            ).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary, height: 1.45),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: GSWButton(
                size: GSWButtonSize.medium,
                variant: GSWButtonVariant.secondary,
                label: 'Keep existing',
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GSWButton(
                size: GSWButtonSize.medium,
                label: 'Replace oldest',
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
              ),
            ),
          ],
        );
      },
    );

    if (replace != true || !mounted) {
      return;
    }

    try {
      await _client.rpc('replace_oldest_open_concierge_request');

      if (!mounted) return;

      await context.push(GSWRoutes.helpMeChoose);

      if (mounted) {
        await _refreshHomeData();
      }
    } catch (error) {
      debugPrint('Could not replace concierge request: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not replace the previous request. Please try again.'),
        ),
      );
    }
  }

  void _openRequestDetails(_HomeRequest request) {
    // Intentionally NOT routed to Notifications.
    // Replace only this method when RequestDetailsScreen is created.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request ${request.referenceCode} details screen is next.')),
    );
  }

  Future<void> _openMatchedTrainer(_HomeRequest request) async {
    final trainerId = request.trainerId;

    if (trainerId == null || trainerId.isEmpty) {
      if (mounted) {
        context.go(GSWRoutes.browseTrainers);
      }
      return;
    }

    try {
      final trainers = await _trainersFuture;
      Trainer? matchedTrainer;

      for (final trainer in trainers) {
        if (trainer.id == trainerId) {
          matchedTrainer = trainer;
          break;
        }
      }

      if (!mounted) return;

      if (matchedTrainer != null) {
        context.push(GSWRoutes.trainerProfile, extra: matchedTrainer);
      } else {
        context.go(GSWRoutes.browseTrainers);
      }
    } catch (error) {
      debugPrint('Could not open matched trainer: $error');

      if (mounted) {
        context.go(GSWRoutes.browseTrainers);
      }
    }
  }

  String _firstName(String? fullName) {
    final trimmed = fullName?.trim() ?? '';

    if (trimmed.isEmpty) {
      return 'THERE';
    }

    return trimmed.split(RegExp(r'\s+')).first;
  }

  String _goalHeadline(String? goal) {
    final normalized = goal?.trim().toLowerCase() ?? '';

    switch (normalized) {
      case 'lose weight':
        return 'Lose weight and build a routine';
      case 'get stronger':
        return 'Get stronger and build a routine';
      case 'move better':
        return 'Move better and build a routine';
      case 'back after a break':
        return 'Get back into a routine';
      case 'pre or postnatal':
        return 'Build a supported routine';
      case 'something else':
        return 'Your trainer match';
      default:
        if (normalized.isEmpty) {
          return 'Your trainer match';
        }

        return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
    }
  }

  String _matchingProgressMessage(_HomeRequest request) {
    final submitted = _submittedLabel(request.createdAt);
    final capitalized = submitted.isEmpty
        ? submitted
        : '${submitted[0].toUpperCase()}${submitted.substring(1)}';

    return '$capitalized. You will hear from us by the next morning at the latest.';
  }

  String _submittedLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return 'recently sent';
    }

    final local = createdAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestDay = DateTime(local.year, local.month, local.day);
    final difference = today.difference(requestDay).inDays;
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    if (difference == 0) {
      return 'sent today at $time';
    }

    if (difference == 1) {
      return 'sent yesterday at $time';
    }

    return 'sent ${local.day}/${local.month}/${local.year} at $time';
  }

  DateTime _toDubaiTime(DateTime value) {
    return value.toUtc().add(const Duration(hours: 4));
  }

  String _sessionDayLabel(DateTime scheduledAt) {
    final dubai = _toDubaiTime(scheduledAt);
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return weekdays[dubai.weekday - 1];
  }

  String _sessionDateTimeLabel(DateTime scheduledAt) {
    final dubai = _toDubaiTime(scheduledAt);
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final time =
        '${dubai.hour.toString().padLeft(2, '0')}:'
        '${dubai.minute.toString().padLeft(2, '0')}';

    return '${weekdays[dubai.weekday - 1]} ${dubai.day} '
        '${months[dubai.month - 1]}, $time';
  }

  String _sessionDescription(_HomeSession session) {
    final trainer = session.trainerName?.trim().isNotEmpty == true
        ? session.trainerName!.trim()
        : 'your trainer';
    final location = session.locationLabel?.trim().isNotEmpty == true
        ? session.locationLabel!.trim()
        : 'the agreed location';

    return 'With $trainer, at $location';
  }
}

class _HomeData {
  const _HomeData({this.fullName, this.city, this.activeRequests = const [], this.nextSession});

  final String? fullName;
  final String? city;
  final List<_HomeRequest> activeRequests;
  final _HomeSession? nextSession;

  _HomeRequest? get primaryRequest {
    if (activeRequests.isEmpty) {
      return null;
    }

    // A ready match is more actionable than a still-processing request.
    for (final request in activeRequests) {
      if (request.isMatched) {
        return request;
      }
    }

    return activeRequests.first;
  }

  _HomeRequest? get oldestActiveRequest {
    if (activeRequests.isEmpty) {
      return null;
    }

    final sorted = [...activeRequests]
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

    return sorted.first;
  }
}

class _HomeRequest {
  const _HomeRequest({
    required this.id,
    required this.referenceCode,
    required this.status,
    this.goal,
    this.createdAt,
    this.trainerId,
    this.trainerName,
  });

  final String id;
  final String referenceCode;
  final String status;
  final String? goal;
  final DateTime? createdAt;
  final String? trainerId;
  final String? trainerName;

  String get normalizedStatus => status.trim().toLowerCase();

  bool get isMatched => normalizedStatus == 'matched';

  bool get isClosed =>
      normalizedStatus == 'closed' ||
      normalizedStatus == 'cancelled' ||
      normalizedStatus == 'canceled' ||
      normalizedStatus == 'completed' ||
      normalizedStatus == 'confirmed' ||
      normalizedStatus == 'lost';

  bool get isInProgress => normalizedStatus.isNotEmpty && !isMatched && !isClosed;

  _HomeRequest copyWith({String? trainerName}) {
    return _HomeRequest(
      id: id,
      referenceCode: referenceCode,
      status: status,
      goal: goal,
      createdAt: createdAt,
      trainerId: trainerId,
      trainerName: trainerName ?? this.trainerName,
    );
  }

  factory _HomeRequest.fromJson(Map<String, dynamic> json) {
    return _HomeRequest(
      id: json['id']?.toString().trim() ?? '',
      referenceCode: json['reference_code']?.toString().trim().isNotEmpty == true
          ? json['reference_code'].toString().trim()
          : 'Request',
      status: json['status']?.toString().trim() ?? '',
      goal: json['goal']?.toString().trim(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      trainerId: json['trainer_id']?.toString().trim(),
    );
  }
}

class _HomeSession {
  const _HomeSession({
    required this.id,
    required this.scheduledAt,
    this.bookingRequestId,
    this.trainerId,
    this.trainerName,
    this.locationLabel,
  });

  final String id;
  final DateTime scheduledAt;
  final String? bookingRequestId;
  final String? trainerId;
  final String? trainerName;
  final String? locationLabel;

  factory _HomeSession.fromJson(Map<String, dynamic> json) {
    final trainer = json['trainers'];
    String? trainerName;

    if (trainer is Map) {
      trainerName = trainer['full_name']?.toString().trim();
    }

    return _HomeSession(
      id: json['id']?.toString().trim() ?? '',
      scheduledAt:
          DateTime.tryParse(json['scheduled_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      bookingRequestId: json['booking_request_id']?.toString().trim(),
      trainerId: json['trainer_id']?.toString().trim(),
      trainerName: trainerName,
      locationLabel: json['location_label']?.toString().trim(),
    );
  }
}
