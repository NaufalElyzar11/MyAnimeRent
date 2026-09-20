import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/store.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/imgur_service.dart';

class StoreFormScreen extends StatefulWidget {
  final String? storeId;

  const StoreFormScreen({super.key, this.storeId});

  @override
  State<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends State<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();
  final _imgurService = ImgurService();
  final _imagePicker = ImagePicker();

  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  String _imageUrl = '';
  bool _isUploadingImage = false;
  bool _isLoadingInitialData = false;
  bool _isSaving = false;

  bool get _isEditing => widget.storeId != null && widget.storeId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!_isEditing) return;

    setState(() => _isLoadingInitialData = true);
    try {
      final store = await _databaseService.getStoreById(widget.storeId!);
      if (store != null && mounted) {
        _nameController.text = store.name;
        _cityController.text = store.city;
        _imageUrl = store.imageUrl;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingInitialData = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final uploadedUrl = await _imgurService.uploadImage(File(picked.path));

      if (mounted) {
        setState(() => _isUploadingImage = false);
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          setState(() => _imageUrl = uploadedUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logo / Foto toko berhasil diunggah!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengunggah foto. Silakan coba lagi atau masukkan URL manual.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddImageModal() {
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Foto / Logo Toko',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Otomatis upload tanpa ketik link'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Ambil dari Kamera'),
                subtitle: const Text('Foto langsung tempat atau logo toko'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.link, color: Colors.orange),
                ),
                title: const Text('Masukkan Link URL Manual'),
                subtitle: const Text('Tautan gambar langsung'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showManualUrlDialog(urlController);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualUrlDialog(TextEditingController urlController) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan URL Gambar Toko'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://i.imgur.com/logo.jpg',
            prefixIcon: Icon(Icons.image),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final link = urlController.text.trim();
              if (link.isNotEmpty) {
                setState(() => _imageUrl = link);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Gunakan'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon pilih atau unggah foto/logo toko.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUid = auth.user?.id ?? 'admin';

      final store = Store(
        id: widget.storeId ?? '',
        name: _nameController.text.trim(),
        ownerUid: currentUid,
        city: _cityController.text.trim(),
        imageUrl: _imageUrl,
        rating: 4.9,
      );

      if (_isEditing) {
        await _databaseService.updateStore(widget.storeId!, store.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data toko berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        await _databaseService.createStore(store);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Toko baru berhasil didaftarkan!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan toko: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoadingInitialData) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit Toko' : 'Tambah Toko')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Toko' : 'Tambah Toko'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Simpan',
            onPressed: _isSaving ? null : _saveStore,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Store Logo / Image Picker
            Center(
              child: GestureDetector(
                onTap: _isUploadingImage ? null : _showAddImageModal,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2.5,
                        ),
                      ),
                      child: _imageUrl.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                _imageUrl,
                                width: 130,
                                height: 130,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.broken_image,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.storefront_outlined,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Pilih Foto Toko',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (_isUploadingImage)
                      Container(
                        width: 130,
                        height: 130,
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
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                _isUploadingImage
                    ? 'Mengunggah foto toko...'
                    : (_imageUrl.isEmpty ? 'Ketuk untuk upload logo/foto toko' : 'Ketuk untuk ganti foto toko'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Store Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Toko',
                hintText: 'Misal: Wibu Rent & Cosplay Hub',
                prefixIcon: Icon(Icons.store),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Nama toko wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // City / Location
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Kota / Lokasi Toko',
                hintText: 'Misal: Jakarta Selatan, Surabaya, Bandung...',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Kota / lokasi wajib diisi' : null,
            ),
            const SizedBox(height: 36),

            // Submit Button
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveStore,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving
                    ? 'Menyimpan...'
                    : (_isEditing ? 'Simpan Perubahan Toko' : 'Daftarkan Toko'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
