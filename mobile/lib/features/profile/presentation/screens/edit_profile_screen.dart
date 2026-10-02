import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/features/profile/model/profile_photo_bottomsheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';
import '../../../../core/widgets/inputs/gsw_text_field.dart';

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
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'We could not load your profile.';
      });

      return;
    }

    try {
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
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final name = profile?['full_name']?.toString().trim() ?? '';

      final photoPath = profile?['profile_photo_path']?.toString().trim();

      String? photoUrl;

      if (photoPath != null && photoPath.isNotEmpty) {
        photoUrl = await _supabase.storage
            .from('profile-photos')
            .createSignedUrl(photoPath, 60 * 60);
      }

      final profilePhone = profile?['phone']?.toString().trim() ?? user.phone?.trim() ?? '';

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

    final user = _supabase.auth.currentUser;

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
      await _supabase
          .from('customer_profiles')
          .update({
            'full_name': name,
            'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);

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
    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Your session has expired. Please sign in again.');
      return;
    }

    try {
      final bytes = await image.readAsBytes();

      final extension = image.name.contains('.') ? image.name.split('.').last.toLowerCase() : 'jpg';

      final storagePath = '${user.id}/profile.$extension';

      await _supabase.storage
          .from('profile-photos')
          .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(upsert: true));

      await _supabase
          .from('customer_profiles')
          .update({
            'profile_photo_path': storagePath,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);

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
    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Your session has expired. Please sign in again.');
      return;
    }

    final photoPath = _profilePhotoPath;

    if (photoPath == null || photoPath.isEmpty) {
      return;
    }

    try {
      await _supabase.storage.from('profile-photos').remove([photoPath]);

      await _supabase
          .from('customer_profiles')
          .update({
            'profile_photo_path': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);

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

  void _handleChangeNumber() {
    if (widget.onChangeNumber != null) {
      widget.onChangeNumber!();
      return;
    }

    context.push(GSWRoutes.userAuth);
    _showMessage('Phone number change will require a new verification code.');
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
            borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackButton(),

            const SizedBox(height: 40),

            Text(
              'Edit your details',
              style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
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

            const SizedBox(height: 24),
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.chevron_left_rounded, color: GSWColors.primary, size: 30),
        ),
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GSWColors.borderSecondary),
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
                  style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
                ),

                const SizedBox(height: 6),

                Text(
                  'Your trainer sees it, so they can recognise you on the day.',
                  style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                ),

                const SizedBox(height: 14),

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleAddPhoto,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Add a photo',
                      style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.primary),
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
    return SizedBox(
      width: 84,
      height: 84,
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

          Positioned(
            right: -2,
            bottom: 0,
            child: GestureDetector(
              onTap: _handleAddPhoto,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: GSWColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: GSWColors.backgroundPrimary, width: 3),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add_rounded, size: 22, color: GSWColors.backgroundPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar() {
    return Container(
      color: GSWColors.surfaceInteractive,
      alignment: Alignment.center,
      child: Text(
        _profileInitial,
        style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textPrimary),
      ),
    );
  }

  Widget _buildPhoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile number',
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatPhone(_phone),
                      style: GSWTextStyles.titleExtraSmall.copyWith(
                        color: GSWColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.check_rounded, color: GSWColors.primary, size: 20),

                        const SizedBox(width: 6),

                        Flexible(
                          child: Text(
                            'Verified on WhatsApp',
                            style: GSWTextStyles.bodyMedium.copyWith(
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
                width: 104,
                child: GSWButton(
                  label: 'Change',
                  onPressed: _handleChangeNumber,
                  variant: GSWButtonVariant.secondary,
                  size: GSWButtonSize.medium,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "To change it, we'll send a code to your new number on WhatsApp.",
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
