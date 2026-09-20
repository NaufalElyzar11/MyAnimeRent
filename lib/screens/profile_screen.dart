import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/imgur_service.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingImage = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      final imgurService = ImgurService();
      final imageUrl = await imgurService.uploadImage(File(pickedFile.path));

      if (!mounted) return;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final success =
            await context.read<AuthProvider>().updateProfileImage(imageUrl);
        if (mounted) {
          setState(() => _isUploadingImage = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Profile photo updated successfully!'
                  : 'Failed to save profile photo'),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isUploadingImage = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please check your internet connection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditProfileDialog(BuildContext context, AppUser? user) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final phoneController =
        TextEditingController(text: user?.phoneNumber ?? '');
    final addressController = TextEditingController(text: user?.address ?? '');
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Profile',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(bottomSheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name cannot be empty'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp / Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: 'e.g. 08123456789',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Address',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          hintText: 'Enter complete shipping address',
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSaving = true);
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final success = await context
                                      .read<AuthProvider>()
                                      .updateUserProfile(
                                        name: nameController.text.trim(),
                                        phoneNumber: phoneController
                                                .text.trim().isEmpty
                                            ? null
                                            : phoneController.text.trim(),
                                        address: addressController
                                                .text.trim().isEmpty
                                            ? null
                                            : addressController.text.trim(),
                                      );
                                  if (bottomSheetContext.mounted) {
                                    Navigator.pop(bottomSheetContext);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(success
                                            ? 'Profile updated successfully!'
                                            : 'Failed to update profile'),
                                        backgroundColor:
                                            success ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);

    if (auth.isLoading && user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Profile Image with camera badge
          GestureDetector(
            onTap: _isUploadingImage ? null : _pickAndUploadImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: user?.profileImageUrl != null &&
                          user!.profileImageUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(user.profileImageUrl!)
                      : null,
                  child: user?.profileImageUrl == null ||
                          user!.profileImageUrl!.isEmpty
                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
                ),
                if (_isUploadingImage)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isUploadingImage ? null : _pickAndUploadImage,
            child: Text(
              _isUploadingImage ? 'Uploading photo...' : 'Tap to change photo',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name.isNotEmpty == true ? user!.name : 'Guest User',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            user?.email.isNotEmpty == true ? user!.email : 'No email',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Contact & Shipping Info Card
          Builder(
            builder: (context) {
              final phone = user?.phoneNumber;
              final address = user?.address;
              final hasPhone = phone != null && phone.isNotEmpty;
              final hasAddress = address != null && address.isNotEmpty;

              if (!hasPhone && !hasAddress) return const SizedBox.shrink();

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    if (hasPhone)
                      Row(
                        children: [
                          Icon(Icons.phone,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(phone,
                                  style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    if (hasPhone && hasAddress) const SizedBox(height: 8),
                    if (hasAddress)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(address,
                                  style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),

          // Menu Items
          _ProfileMenuItem(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: () => _showEditProfileDialog(context, user),
          ),
          const Divider(),
          _ProfileMenuItem(
            icon: Icons.history,
            label: 'Rental History',
            onTap: () => context.push('/rental_history'),
          ),
          const Divider(),
          _ProfileMenuItem(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () => context.push('/settings'),
          ),
          const Divider(),
          _ProfileMenuItem(
            icon: Icons.logout,
            label: 'Logout',
            showArrow: false,
            onTap: () async {
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showArrow;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      trailing: showArrow
          ? Icon(Icons.keyboard_arrow_right,
              color: theme.colorScheme.onSurfaceVariant)
          : null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
