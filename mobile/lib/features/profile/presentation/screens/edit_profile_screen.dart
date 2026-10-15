import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/features/profile/model/profile_photo_bottomsheet.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.onChangeNumber});

  final VoidCallback? onChangeNumber;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String? _profilePhotoPath;
  String? _profilePhotoUrl;

  String _phone = '';

  /// 12.2f: set after a successful number change, so the helper line under
  /// the number confirms the new number instead of a snackbar.
  bool _numberChanged = false;

  String? _loadError;
  String? _saveError;

  String get _profileInitial {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      return '';
    }

    return name[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();

    _nameController.addListener(_handleFieldChanged);
    _emailController.addListener(_handleFieldChanged);

    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleFieldChanged);
    _emailController.removeListener(_handleFieldChanged);

    _nameController.dispose();
    _emailController.dispose();

    super.dispose();
  }

  void _handleFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'We could not load your profile.';
      });

      return;
    }

    try {
      final customerId = await CustomerIdentityService(client: _supabase).getCustomerId();

      final profile = await _supabase
          .from('customer_profiles')
          .select('''
            id,
            full_name,
            phone,
            email,
            city,
            profile_photo_path
          ''')
          .eq('id', customerId)
          .maybeSingle();

      if (!mounted) return;

      final name = profile?['full_name']?.toString().trim() ?? '';

      final photoPath = profile?['profile_photo_path']?.toString().trim();

      String? photoUrl;

      if (photoPath != null && photoPath.isNotEmpty) {
        // A missing or unreadable photo should not break the whole screen.
        try {
          photoUrl = await _supabase.storage
              .from('profile-photos')
              .createSignedUrl(photoPath, 60 * 60);
        } catch (error) {
          debugPrint('Profile photo URL failed: $error');
        }
      }

      final profilePhone = profile?['phone']?.toString().trim() ?? user.phoneNumber?.trim() ?? '';

      final email = profile?['email']?.toString().trim() ?? '';

      _nameController.text = name;
      _emailController.text = email;

      setState(() {
        _phone = profilePhone;
        _isLoading = false;
        _loadError = null;
        _profilePhotoPath = photoPath;
        _profilePhotoUrl = photoUrl;
      });
    } catch (error) {
      debugPrint('Edit profile load failed: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'We could not load your profile.';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Your session has expired. Please sign in again.');
      return;
    }

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _saveError = 'Enter your full name.';
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final customerId = await CustomerIdentityService(client: _supabase).getCustomerId();

      await _supabase
          .from('customer_profiles')
          .update({
            'full_name': name,
            'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', customerId);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      context.pop();

      _showMessage('Your details have been updated.');
    } catch (error) {
      debugPrint('Edit profile save failed: $error');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _saveError = 'We could not save your changes. Please try again.';
      });
    }
  }

  Future<void> _uploadProfilePhoto(XFile image) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Your session has expired. Please sign in again.');
      return;
    }

    try {
      final customerId = await CustomerIdentityService(client: _supabase).getCustomerId();

      final bytes = await image.readAsBytes();

      final extension = image.name.contains('.') ? image.name.split('.').last.toLowerCase() : 'jpg';

      final storagePath = '$customerId/profile.$extension';

      await _supabase.storage
          .from('profile-photos')
          .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(upsert: true));

      await _supabase
          .from('customer_profiles')
          .update({
            'profile_photo_path': storagePath,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', customerId);

      final photoUrl = await _supabase.storage
          .from('profile-photos')
          .createSignedUrl(storagePath, 60 * 60);

      if (!mounted) return;

      setState(() {
        _profilePhotoPath = storagePath;
        _profilePhotoUrl = photoUrl;
      });

      _showMessage('Profile photo updated.');
    } catch (error) {
      debugPrint('Profile photo upload failed: $error');

      if (!mounted) return;

      _showMessage('Could not update your photo. Please try again.');
    }
  }

  Future<void> _removeProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Your session has expired. Please sign in again.');
      return;
    }

    final photoPath = _profilePhotoPath;

    if (photoPath == null || photoPath.isEmpty) {
      return;
    }

    try {
      final customerId = await CustomerIdentityService(client: _supabase).getCustomerId();

      await _supabase.storage.from('profile-photos').remove([photoPath]);

      await _supabase
          .from('customer_profiles')
          .update({
            'profile_photo_path': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', customerId);

      if (!mounted) return;

      setState(() {
        _profilePhotoPath = null;
        _profilePhotoUrl = null;
      });

      _showMessage('Profile photo removed.');
    } catch (error) {
      debugPrint('Profile photo removal failed: $error');

      if (!mounted) return;

      _showMessage('Could not remove your photo. Please try again.');
    }
  }

  void _handleAddPhoto() {
    ProfilePhotoSheet.show(
      context,
      hasPhoto: _profilePhotoPath != null,
      onTakePhoto: _takeProfilePhoto,
      onChooseFromLibrary: _chooseProfilePhoto,
      onRemovePhoto: _removeProfilePhoto,
    );
  }

  Future<void> _takeProfilePhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null) return;

    await _uploadProfilePhoto(image);
  }

  Future<void> _chooseProfilePhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null) return;

    await _uploadProfilePhoto(image);
  }

  Future<void> _handleChangeNumber() async {
    if (widget.onChangeNumber != null) {
      widget.onChangeNumber!();
      return;
    }

    final changed = await context.push<bool>(GSWRoutes.changePhone, extra: _phone);

    if (!mounted) return;

    if (changed == true) {
      setState(() {
        _isLoading = true;
      });

      await _loadProfile();

      if (!mounted) return;

      setState(() {
        _numberChanged = true;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: GSWColors.surfaceElevated,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GSWRadius.control),
            side: const BorderSide(color: GSWColors.borderSecondary),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: GSWColors.primary))
                  : _buildContent(),
            ),

            if (!_isLoading && _loadError == null) _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackButton(),

            const Spacer(),

            Center(
              child: Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
              ),
            ),

            const Spacer(),

            GSWButton(
              label: 'Try again',
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = null;
                });

                _loadProfile();
              },
              variant: GSWButtonVariant.primary,
              size: GSWButtonSize.large,
            ),
          ],
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackButton(),

            const SizedBox(height: 24),

            Text(
              'Edit your details',
              style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
            ),

            const SizedBox(height: 24),

            _buildPhotoCard(),

            const SizedBox(height: 24),

            GSWTextField(
              controller: _nameController,
              label: 'Full name',
              hintText: 'Your full name',
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 24),

            _buildPhoneSection(),

            const SizedBox(height: 24),

            GSWTextField(
              controller: _emailController,
              label: 'Email address (optional)',
              hintText: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              helpingText: 'Only used to send your receipts. Never shared with trainers.',
            ),

            if (_saveError != null) ...[
              const SizedBox(height: 12),

              Text(_saveError!, style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.error)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          }
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            GSWIcons.arrowheadLeft,
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  /// Profile photo card (12.2c 1049:3352).
  Widget _buildPhotoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile photo (optional)',
                  style: GSWTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    height: 21 / 15,
                    fontWeight: FontWeight.w600,
                    color: GSWColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'Your trainer sees it, so they can recognise you on the day.',
                  style: GSWTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    height: 18 / 13,
                    color: GSWColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 2),

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleAddPhoto,
                  child: SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _profilePhotoPath != null ? 'Change photo' : 'Add a photo',
                        style: GSWTextStyles.labelMedium.copyWith(
                          height: 20 / 14,
                          fontWeight: FontWeight.w600,
                          color: GSWColors.textAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _handleAddPhoto,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipOval(
                child: _profilePhotoUrl != null
                    ? Image.network(
                        _profilePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildInitialAvatar();
                        },
                      )
                    : _buildInitialAvatar(),
              ),
            ),

            // Add badge: 26px at (50, 48) inside the 72px avatar.
            Positioned(
              left: 50,
              top: 48,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: GSWColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: GSWColors.surfacePrimary, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add_rounded, size: 18, color: GSWColors.iconInverse),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialAvatar() {
    return Container(
      color: GSWColors.surfaceInteractive,
      alignment: Alignment.center,
      child: Text(
        _profileInitial,
        style: GSWTextStyles.titleExtraLarge.copyWith(
          height: 34 / 28,
          fontWeight: FontWeight.w600,
          color: GSWColors.textPrimary,
        ),
      ),
    );
  }

  /// Mobile number as a field-shaped row with a Secondary "Change" button
  /// (12.2c 1049:3386). Login codes go by SMS, so the copy says SMS.
  Widget _buildPhoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile number',
          style: GSWTextStyles.bodyMedium.copyWith(height: 1, color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.control),
            border: Border.all(color: GSWColors.surfaceInteractive),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatPhone(_phone),
                      style: GSWTextStyles.labelLarge.copyWith(
                        height: 22 / 16,
                        color: GSWColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(Icons.check_rounded, color: GSWColors.iconAccent, size: 14),

                        const SizedBox(width: 6),

                        Flexible(
                          child: Text(
                            'Verified by SMS',
                            style: GSWTextStyles.bodyMedium.copyWith(
                              fontSize: 13,
                              height: 18 / 13,
                              color: GSWColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              SizedBox(
                height: 40,
                child: GSWButton(
                  label: 'Change',
                  onPressed: _handleChangeNumber,
                  variant: GSWButtonVariant.secondary,
                  size: GSWButtonSize.medium,
                  fullWidth: false,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _numberChanged
              ? "Changed just now. We'll use ${_formatPhone(_phone)} for your codes and session messages."
              : "To change it, we'll send a code to your new number by SMS.",
          style: GSWTextStyles.bodySmall.copyWith(
            height: 17 / 12,
            color: _numberChanged ? GSWColors.textPrimary : GSWColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: GSWButton(
        label: 'Save',
        onPressed: _isSaving ? null : _saveProfile,
        variant: _isSaving ? GSWButtonVariant.disabled : GSWButtonVariant.primary,
        size: GSWButtonSize.large,
        isLoading: _isSaving,
      ),
    );
  }

  String _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 12 && digits.startsWith('971')) {
      return '+971 ${digits.substring(3, 5)} '
          '${digits.substring(5, 8)} '
          '${digits.substring(8)}';
    }

    if (digits.length == 9) {
      return '+971 ${digits.substring(0, 2)} '
          '${digits.substring(2, 5)} '
          '${digits.substring(5)}';
    }

    if (value.startsWith('+')) {
      return value;
    }

    if (value.isEmpty) {
      return '';
    }

    return '+$value';
  }
}
