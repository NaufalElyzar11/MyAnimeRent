import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/costume.dart';
import '../../models/store.dart';
import '../../services/database_service.dart';
import '../../services/imgur_service.dart';

class CostumeFormScreen extends StatefulWidget {
  final String? costumeId;

  const CostumeFormScreen({super.key, this.costumeId});

  @override
  State<CostumeFormScreen> createState() => _CostumeFormScreenState();
}

class _CostumeFormScreenState extends State<CostumeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();
  final _imgurService = ImgurService();
  final _imagePicker = ImagePicker();

  final _nameController = TextEditingController();
  final _animeController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedStoreId;
  List<Store> _stores = [];
  bool _isLoadingStores = true;

  final List<String> _imageUrls = [];
  bool _isUploadingImage = false;

  final List<String> _availableSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'All Size'];
  final Set<String> _selectedSizes = {'M', 'L'};

  bool _isAvailable = true;
  bool _isLoadingInitialData = false;
  bool _isSaving = false;

  bool get _isEditing => widget.costumeId != null && widget.costumeId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animeController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingStores = true);

    try {
      final stores = await _databaseService.getStores();
      setState(() {
        _stores = stores;
        if (stores.isNotEmpty && _selectedStoreId == null) {
          _selectedStoreId = stores.first.id;
        }
        _isLoadingStores = false;
      });

      if (_isEditing) {
        setState(() => _isLoadingInitialData = true);
        final costume = await _databaseService.getCostumeById(widget.costumeId!);
        if (costume != null && mounted) {
          _nameController.text = costume.name;
          _animeController.text = costume.anime;
          _priceController.text = costume.price.toInt().toString();
          _descriptionController.text = costume.description;
          _selectedStoreId = costume.storeId;
          _imageUrls.clear();
          _imageUrls.addAll(costume.imageUrls);
          _selectedSizes.clear();
          _selectedSizes.addAll(costume.sizes);
          _isAvailable = costume.isAvailable;
        }
        setState(() => _isLoadingInitialData = false);
      }
    } catch (e) {
      setState(() {
        _isLoadingStores = false;
        _isLoadingInitialData = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final uploadedUrl = await _imgurService.uploadImage(File(picked.path));

      if (mounted) {
        setState(() => _isUploadingImage = false);
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          setState(() {
            _imageUrls.add(uploadedUrl);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto berhasil diunggah!'),
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
                'Tambah Foto Kostum',
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
                subtitle: const Text('Foto langsung kostum'),
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
                subtitle: const Text('Jika foto sudah ada di web/cloud'),
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
        title: const Text('Masukkan URL Gambar'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://i.imgur.com/example.jpg',
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
                setState(() => _imageUrls.add(link));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCostume() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon tambahkan minimal 1 foto kostum.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedStoreId == null || _selectedStoreId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon pilih toko penyedia kostum.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final sizes = _selectedSizes.toList()..sort();

      final costume = Costume(
        id: widget.costumeId ?? '',
        name: _nameController.text.trim(),
        anime: _animeController.text.trim(),
        storeId: _selectedStoreId!,
        description: _descriptionController.text.trim(),
        imageUrls: _imageUrls,
        price: price,
        sizes: sizes.isEmpty ? ['All Size'] : sizes,
        isAvailable: _isAvailable,
        rating: 4.8,
      );

      if (_isEditing) {
        await _databaseService.updateCostume(widget.costumeId!, costume.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kostum berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        await _databaseService.createCostume(costume);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kostum baru berhasil ditambahkan!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
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
        appBar: AppBar(title: Text(_isEditing ? 'Edit Kostum' : 'Tambah Kostum')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Kostum' : 'Tambah Kostum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Simpan',
            onPressed: _isSaving ? null : _saveCostume,
          ),
        ],
      ),
      body: _isLoadingStores
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Image Gallery / Picker Section
                  Text(
                    'Foto Kostum',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pilih foto langsung dari galeri atau kamera tanpa perlu link manual.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Add Button
                        InkWell(
                          onTap: _isUploadingImage ? null : _showAddImageModal,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 110,
                            height: 120,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                width: 1.5,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Center(
                              child: _isUploadingImage
                                  ? const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2.5),
                                        ),
                                        SizedBox(height: 8),
                                        Text('Mengunggah...', style: TextStyle(fontSize: 11)),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.primary, size: 28),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Tambah Foto',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        // Image Previews
                        ..._imageUrls.asMap().entries.map((entry) {
                          final index = entry.key;
                          final url = entry.value;

                          return Container(
                            width: 110,
                            height: 120,
                            margin: const EdgeInsets.only(right: 12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    url,
                                    width: 110,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: Colors.grey.shade300,
                                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _imageUrls.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                                if (index == 0)
                                  Positioned(
                                    bottom: 4,
                                    left: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Utama',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Store Selection Dropdown
                  Text(
                    'Toko Penyedia',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_stores.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Belum ada toko yang terdaftar. Tambahkan toko terlebih dahulu di tab Toko.',
                              style: TextStyle(color: Colors.black87, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStoreId,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Toko',
                        prefixIcon: Icon(Icons.store),
                      ),
                      items: _stores.map((store) {
                        return DropdownMenuItem<String>(
                          value: store.id,
                          child: Text('${store.name} (${store.city})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedStoreId = val);
                      },
                      validator: (val) => val == null || val.isEmpty ? 'Toko wajib dipilih' : null,
                    ),
                  const SizedBox(height: 20),

                  // Costume Name & Anime
                  Text(
                    'Informasi Kostum',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kostum / Karakter',
                      hintText: 'Misal: Tanjirou Kamado Demon Slayer',
                      prefixIcon: Icon(Icons.checkroom),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Nama kostum wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _animeController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Anime / Serial',
                      hintText: 'Misal: Kimetsu no Yaiba',
                      prefixIcon: Icon(Icons.movie_filter_outlined),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Judul anime wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Harga Sewa per Hari (Rp)',
                      hintText: '75000',
                      prefixIcon: Icon(Icons.monetization_on_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Harga sewa wajib diisi';
                      final num = double.tryParse(val.trim());
                      if (num == null || num <= 0) return 'Masukkan nominal harga yang valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Sizes Selector
                  Text(
                    'Pilihan Ukuran yang Tersedia',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _availableSizes.map((size) {
                      final isSelected = _selectedSizes.contains(size);
                      return FilterChip(
                        label: Text(size),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedSizes.add(size);
                            } else {
                              _selectedSizes.remove(size);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi & Kelengkapan',
                      hintText: 'Termasuk haori, seragam, sabuk, wig, leg wrap...',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Deskripsi kostum wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  // Availability Switch
                  SwitchListTile(
                    title: const Text('Status Ketersediaan'),
                    subtitle: Text(
                      _isAvailable ? 'Kostum aktif dan dapat disewa oleh user' : 'Kostum sedang dinonaktifkan',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    value: _isAvailable,
                    activeThumbColor: theme.colorScheme.primary,
                    onChanged: (val) => setState(() => _isAvailable = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveCostume,
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
                          : (_isEditing ? 'Simpan Perubahan' : 'Terbitkan Kostum'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
