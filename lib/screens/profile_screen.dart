import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.guestBody});
  final Widget? guestBody;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showEditProfileDialog(BuildContext context, AppUser? user) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit profil', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Nama', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor HP / WhatsApp (opsional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: '0812 3456 7890',
                      helperText: 'Hanya terlihat oleh toko bila kamu mengizinkan saat mengajukan sewa.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSaving = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final auth = context.read<AuthProvider>();
                              final ok = await auth.updateUserProfile(
                                name: nameController.text.trim(),
                                phoneNumber: phoneController.text.trim(),
                              );
                              if (!sheetContext.mounted) return;
                              if (ok) {
                                Navigator.pop(sheetContext);
                              } else {
                                setModalState(() => isSaving = false);
                              }
                              messenger.showSnackBar(SnackBar(
                                content: Text(ok ? 'Profil disimpan' : (auth.error ?? 'Gagal menyimpan profil')),
                                backgroundColor: ok ? Colors.green : Colors.red,
                              ));
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guestBody != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Profil'),
          automaticallyImplyLeading: false,
        ),
        body: widget.guestBody,
      );
    }
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = Theme.of(context);

    if (!auth.isLoggedIn) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.account_circle_outlined, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Masuk untuk menyewa', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Katalog bisa dilihat tanpa akun. Untuk mengajukan sewa, menyimpan wishlist, dan menerima kabar dari toko, masuk atau daftar dulu.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => context.push('/login'), child: const Text('Masuk')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => context.push('/signup'), child: const Text('Daftar')),
          const SizedBox(height: 24),
          _ProfileMenuItem(icon: Icons.settings, label: 'Pengaturan', onTap: () => context.push('/settings')),
        ],
      );
    }

    final unread = context.watch<NotificationProvider>().unreadCount;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              user?.initials ?? '?',
              style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name.isNotEmpty == true ? user!.name : 'Tanpa nama',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          Text(user?.email ?? '', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (user?.phoneNumber != null) ...[
            const SizedBox(height: 4),
            Text(user!.phoneNumber!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),
          _ProfileMenuItem(
            icon: Icons.edit_outlined,
            label: 'Edit profil',
            onTap: () => _showEditProfileDialog(context, user),
          ),
          const Divider(),
          _ProfileMenuItem(
            icon: Icons.receipt_long_outlined,
            label: 'Permintaan sewa',
            onTap: () => context.push('/requests'),
          ),
          const Divider(),
          _ProfileMenuItem(
            icon: Icons.notifications_none,
            label: unread > 0 ? 'Notifikasi ($unread baru)' : 'Notifikasi',
            onTap: () => context.push('/notifications'),
          ),
          const Divider(),
          _ProfileMenuItem(icon: Icons.settings, label: 'Pengaturan', onTap: () => context.push('/settings')),
          const Divider(),
          _ProfileMenuItem(
            icon: Icons.logout,
            label: 'Keluar',
            showArrow: false,
            onTap: () async {
              await auth.signOut();
              if (context.mounted) context.go('/home');
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
          ? Icon(
              Icons.keyboard_arrow_right,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
