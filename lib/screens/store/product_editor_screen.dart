import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/store_catalog.dart';
import '../../services/store_catalog_service.dart';
import '../../services/supabase_service.dart';
import 'store_catalog_tab.dart' show ProductStatusChip;

const _quickSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'All size'];
const _maxPhotos = 3;
const _maxPhotoBytes = 5 * 1024 * 1024;

const _fieldLabels = {
  'title': 'Judul',
  'character_name': 'Nama karakter',
  'franchise_name': 'Anime/seri',
  'description': 'Deskripsi',
  'package_contents': 'Isi paket',
  'size_notes': 'Catatan ukuran',
  'aliases': 'Nama lain',
  'variants': 'Ukuran',
  'price': 'Harga',
};

/// Tambah/edit satu listing: foto (maks. 3), info kostum, ukuran, harga, izin publik, terbitkan.
class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({super.key, this.productId, this.storeId});

  /// null = listing baru (butuh [storeId]).
  final String? productId;
  final String? storeId;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _service = StoreCatalogService();
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _character = TextEditingController();
  final _franchise = TextEditingController();
  final _description = TextEditingController();
  final _package = TextEditingController();
  final _sizeNotes = TextEditingController();
  final _aliases = TextEditingController();
  final _amount = TextEditingController();
  final _duration = TextEditingController(text: '3');
  final _extraDay = TextEditingController();
  final _deposit = TextEditingController(text: '0');
  final _bufferBefore = TextEditingController(text: '0');
  final _bufferAfter = TextEditingController(text: '1');

  String? _productId;
  String? _storeId;
  String? _slug;
  int _revision = 1;
  String _status = 'draft';
  String? _storeStatus;
  String _category = 'costume';
  bool _consent = false;
  List<EditableVariant> _variants = [];
  EditablePrice? _loadedPrice;
  List<ProductImage> _images = [];
  List<String> _missing = const ['character', 'price', 'variant', 'image', 'publication_consent'];

  bool _loading = false;
  bool _busy = false;
  bool _dirty = false;
  String? _error;
  String? _saveOp; // dipakai ulang saat simpan diulang karena gangguan jaringan

  bool get _isNew => _productId == null;

  @override
  void initState() {
    super.initState();
    _productId = widget.productId;
    _storeId = widget.storeId;
    if (_productId != null) _load();
  }

  @override
  void dispose() {
    for (final c in [
      _title, _character, _franchise, _description, _package, _sizeNotes, _aliases,
      _amount, _duration, _extraDay, _deposit, _bufferBefore, _bufferAfter,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() {
    _saveOp = null;
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _service.getProduct(_productId!);
      if (!mounted) return;
      setState(() {
        _fill(p);
        _error = null;
        _loading = false;
        _dirty = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _fill(StoreProductDetail p) {
    _storeId = p.storeId;
    _slug = p.slug;
    _title.text = p.title;
    _character.text = p.characterName ?? '';
    _franchise.text = p.franchiseName ?? '';
    _description.text = p.description ?? '';
    _package.text = p.packageContents.join('\n');
    _sizeNotes.text = p.sizeNotes ?? '';
    _aliases.text = p.aliases.join(', ');
    _category = p.category;
    _consent = p.publicationConsent;
    _variants = p.activeVariants;
    _loadedPrice = p.price;
    final price = p.price;
    if (price != null) {
      _amount.text = '${price.amountIdr}';
      _duration.text = '${price.durationDays}';
      _extraDay.text = price.extraDayIdr == null ? '' : '${price.extraDayIdr}';
      _deposit.text = '${price.depositIdr}';
      _bufferBefore.text = '${price.bufferBeforeDays}';
      _bufferAfter.text = '${price.bufferAfterDays}';
    }
    _applyServerState(p);
  }

  /// Bagian yang berubah karena aksi lain (foto, status) tanpa menimpa isian form.
  void _applyServerState(StoreProductDetail p) {
    _revision = p.revision;
    _status = p.status;
    _images = p.images;
    _missing = p.missing;
    _storeStatus = p.storeStatus;
  }

  Future<void> _refreshServerState() async {
    if (_productId == null) return;
    try {
      final p = await _service.getProduct(_productId!);
      if (mounted) setState(() => _applyServerState(p));
    } on ApiException {
      // Biarkan; tarik layar ke bawah untuk memuat ulang.
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null));
  }

  String _errorText(ApiException e) {
    final field = e.details?['field']?.toString();
    final missing = (e.details?['missing'] as List?)?.map((x) => x.toString()).toList();
    return switch (e.reason) {
      'STALE_REVISION' => 'Listing ini baru saja diubah dari perangkat lain. Muat ulang lalu ulangi.',
      'LISTING_INCOMPLETE' => 'Belum bisa terbit. Lengkapi: ${missingText(missing ?? _missing)}.',
      'DUPLICATE_SIZE' => 'Ada ukuran yang sama dua kali.',
      'PRODUCT_ARCHIVED' => 'Listing ini diarsipkan. Pulihkan ke draft dulu sebelum mengubahnya.',
      'UNPUBLISH_FIRST' => 'Tarik listing dari publik dulu.',
      'INVALID_TRANSITION' => 'Status listing sudah berubah. Muat ulang.',
      'RATE_LIMITED' => 'Terlalu banyak unggahan/perubahan. Coba lagi nanti.',
      'MAX_IMAGES' => 'Maksimal $_maxPhotos foto per listing.',
      'IMAGE_INVALID' => 'Foto ditolak: file rusak, animasi, atau terlalu besar.',
      'FIELD_INVALID' || 'FIELD_REQUIRED' when field != null =>
        '${_fieldLabels[field.split('.').first] ?? field} belum benar.',
      _ => e.message,
    };
  }

  int? _num(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), ''));

  /// Harga dari form; null bila harga belum diisi sama sekali.
  EditablePrice? _priceFromForm() {
    final amount = _num(_amount);
    if (amount == null || amount <= 0) return null;
    return EditablePrice(
      amountIdr: amount,
      durationDays: (_num(_duration) ?? 1).clamp(1, 30),
      extraDayIdr: _num(_extraDay),
      depositIdr: _num(_deposit) ?? 0,
      bufferBeforeDays: (_num(_bufferBefore) ?? 0).clamp(0, 14),
      bufferAfterDays: (_num(_bufferAfter) ?? 1).clamp(0, 14),
    );
  }

  Map<String, dynamic> _payload() {
    List<String> lines(String s, Pattern sep) =>
        s.split(sep).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final price = _priceFromForm();
    return {
      'title': _title.text.trim(),
      'category': _category,
      'character_name': opt(_character),
      'franchise_name': opt(_franchise),
      'description': opt(_description),
      'package_contents': lines(_package.text, '\n').take(30).toList(),
      'size_notes': opt(_sizeNotes),
      'aliases': lines(_aliases.text, ',').take(20).toList(),
      'publication_consent': _consent,
      'variants': [for (final v in _variants) v.toJson()],
      // Harga hanya dikirim bila berubah: setiap perubahan menjadi versi harga baru.
      if (price != null && !price.sameAs(_loadedPrice)) 'price': price.toJson(),
    };
  }

  /// Menyimpan form. Mengembalikan true bila berhasil (atau tidak ada perubahan).
  Future<bool> _save({bool announce = true}) async {
    if (!_formKey.currentState!.validate()) return false;
    if (!_dirty && !_isNew) return true;
    if (_isNew && _storeId == null) {
      _snack('Toko tidak diketahui. Buka lagi dari tab Toko.', error: true);
      return false;
    }
    _saveOp ??= newOperationId();
    setState(() => _busy = true);
    try {
      final r = await _service.saveProduct(
        operationId: _saveOp!,
        storeId: _storeId,
        productId: _productId,
        expectedRevision: _isNew ? null : _revision,
        product: _payload(),
      );
      _saveOp = null;
      if (!mounted) return true;
      setState(() {
        _productId = r['product_id']?.toString() ?? _productId;
        _slug = r['slug']?.toString() ?? _slug;
        _revision = (r['revision'] as num?)?.toInt() ?? _revision;
        _status = r['status']?.toString() ?? _status;
        _missing = ((r['missing_for_publish'] as List?) ?? const []).map((x) => x.toString()).toList();
        _loadedPrice = _priceFromForm() ?? _loadedPrice;
        _dirty = false;
      });
      if (announce) _snack(r['created'] == true ? 'Listing dibuat sebagai draft.' : 'Perubahan disimpan.');
      return true;
    } on ApiException catch (e) {
      if (!e.isNetwork) _saveOp = null;
      _snack(_errorText(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(String action, String success) async {
    if (_dirty || _isNew) {
      if (!await _save(announce: false)) return;
    }
    setState(() => _busy = true);
    try {
      final r = await _service.setStatus(action,
          productId: _productId!, expectedRevision: _revision, operationId: newOperationId());
      if (!mounted) return;
      setState(() {
        _status = r['status']?.toString() ?? _status;
        _revision = (r['revision'] as num?)?.toInt() ?? _revision;
      });
      _snack(success);
      await _refreshServerState();
    } on ApiException catch (e) {
      _snack(_errorText(e), error: true);
      if (e.reason == 'STALE_REVISION') await _refreshServerState();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final note = _storeStatus == 'published'
        ? 'Listing langsung tampil di katalog publik.'
        : 'Toko Anda belum terbit, jadi listing baru tampil publik setelah toko diterbitkan di Profil toko.';
    await _setStatus('publish_product', 'Listing terbit. $note');
  }

  Future<void> _archive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arsipkan listing?'),
        content: const Text('Listing hilang dari katalog publik dan daftar aktif. Riwayat sewa tetap ada. '
            'Anda bisa memulihkannya kapan saja.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arsipkan')),
        ],
      ),
    );
    if (ok == true && mounted) await _setStatus('archive_product', 'Listing diarsipkan.');
  }

  // ─── Foto ─────────────────────────────────────────────────
  Future<void> _addPhoto() async {
    if (_images.length >= _maxPhotos) return;
    if (_isNew || _dirty) {
      if (!await _save(announce: false)) return;
      if (!mounted) return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final XFile? file;
    try {
      // Diperkecil di HP (±1600 px) agar unggah cepat dan hemat kuota.
      file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    } catch (e) {
      _snack('Tidak bisa membuka ${source == ImageSource.camera ? 'kamera' : 'galeri'}.', error: true);
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final type = detectImageType(bytes);
    if (type == null) {
      _snack('Format foto tidak didukung. Gunakan JPG, PNG, atau WebP.', error: true);
      return;
    }
    if (bytes.length > _maxPhotoBytes) {
      _snack('Foto terlalu besar (maks. 5 MB).', error: true);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _service.uploadImage(_productId!, bytes, type);
      _snack('Foto ditambahkan. Data lokasi & kamera di foto sudah dibuang.');
      await _refreshServerState();
    } on ApiException catch (e) {
      _snack(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photoMenu(ProductImage img) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (img.position != 1)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Jadikan foto sampul'),
                onTap: () => Navigator.pop(ctx, 'cover'),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              title: const Text('Hapus foto'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (action == 'cover') {
        final ids = [img.id, ..._images.where((x) => x.id != img.id).map((x) => x.id)];
        await _service.reorderImages(_productId!, ids, expectedRevision: _revision, operationId: newOperationId());
      } else {
        await _service.removeImage(img.id, expectedRevision: _revision, operationId: newOperationId());
      }
      await _refreshServerState();
    } on ApiException catch (e) {
      _snack(_errorText(e), error: true);
      if (e.reason == 'STALE_REVISION') await _refreshServerState();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Ukuran ───────────────────────────────────────────────
  void _addSize(String label) {
    final l = label.trim();
    if (l.isEmpty || l.length > 20) return;
    if (_variants.any((v) => v.sizeLabel.toLowerCase() == l.toLowerCase())) return;
    if (_variants.length >= 12) {
      _snack('Maksimal 12 ukuran per listing.', error: true);
      return;
    }
    setState(() => _variants = [..._variants, EditableVariant(sizeLabel: l)]);
    _changed();
  }

  Future<void> _customSize() async {
    final c = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah ukuran'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: 'Mis. M, 160 cm, Anak'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Tambah')),
        ],
      ),
    );
    if (label != null) _addSize(label);
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: const Text('Ada isian yang belum disimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buang')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Kostum baru' : 'Edit listing'),
          actions: [
            if (!_isNew)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'view') context.push('/detail/$_productId');
                  if (v == 'archive') _archive();
                  if (v == 'reload') _load();
                },
                itemBuilder: (_) => [
                  if (_status == 'published') const PopupMenuItem(value: 'view', child: Text('Lihat seperti penyewa')),
                  if (_status != 'archived') const PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
                  const PopupMenuItem(value: 'reload', child: Text('Muat ulang')),
                ],
              ),
          ],
        ),
        bottomNavigationBar: _loading || _error != null ? null : _bottomBar(theme),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (_busy) const LinearProgressIndicator(minHeight: 2),
                        if (!_isNew)
                          Row(
                            children: [
                              ProductStatusChip(status: _status),
                              const SizedBox(width: 8),
                              if (_slug != null)
                                Expanded(child: Text(_slug!, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        const SizedBox(height: 8),
                        _MissingCard(missing: _missing, status: _status, isNew: _isNew),
                        _section(theme, 'Foto (maks. $_maxPhotos)'),
                        _photos(theme),
                        _section(theme, 'Info kostum'),
                        TextFormField(
                          controller: _title,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Judul listing *', hintText: 'Mis. 2B • Pakaian hitam'),
                          validator: (v) => (v == null || v.trim().length < 2) ? 'Minimal 2 huruf' : null,
                          onChanged: (_) => _changed(),
                        ),
                        TextFormField(
                          controller: _character,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Nama karakter', hintText: 'Mis. 2B'),
                          onChanged: (_) => _changed(),
                        ),
                        TextFormField(
                          controller: _franchise,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Anime/game/seri', hintText: 'Mis. NieR:Automata'),
                          onChanged: (_) => _changed(),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(labelText: 'Kategori'),
                          items: [
                            for (final e in categoryLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _category = v);
                            _changed();
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _description,
                          maxLength: 3000,
                          minLines: 2,
                          maxLines: 6,
                          decoration: const InputDecoration(labelText: 'Deskripsi'),
                          onChanged: (_) => _changed(),
                        ),
                        TextFormField(
                          controller: _package,
                          minLines: 2,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Isi paket (satu per baris)',
                            hintText: 'Dress\nWig\nPenutup mata',
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        TextFormField(
                          controller: _aliases,
                          decoration: const InputDecoration(
                            labelText: 'Nama lain untuk pencarian (pisahkan dengan koma)',
                            hintText: 'Mis. YoRHa 2B, Nier 2B',
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        _section(theme, 'Ukuran'),
                        Text(
                          'Setiap ukuran otomatis dihitung 1 set di kalender. Ukuran yang dihapus disembunyikan, '
                          'riwayat sewanya tetap ada.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final v in _variants)
                              InputChip(
                                label: Text(v.sizeLabel),
                                onDeleted: () {
                                  setState(() => _variants = _variants.where((x) => x != v).toList());
                                  _changed();
                                },
                              ),
                            for (final q in _quickSizes.where(
                                (q) => !_variants.any((v) => v.sizeLabel.toLowerCase() == q.toLowerCase())))
                              ActionChip(label: Text('+ $q'), onPressed: () => _addSize(q)),
                            ActionChip(
                              avatar: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Lainnya'),
                              onPressed: _customSize,
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: _sizeNotes,
                          maxLength: 1000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'Catatan ukuran', hintText: 'Mis. lingkar dada 86–92 cm'),
                          onChanged: (_) => _changed(),
                        ),
                        _section(theme, 'Harga sewa'),
                        Row(
                          children: [
                            Expanded(flex: 3, child: _number(_amount, 'Harga paket (Rp)', prefix: 'Rp ')),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: _number(_duration, 'Untuk (hari)', min: 1, max: 30)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _number(_extraDay, 'Per hari tambahan (Rp)', prefix: 'Rp ', optional: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _number(_deposit, 'Deposit (Rp)', prefix: 'Rp ')),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _number(_bufferBefore, 'Hari persiapan sebelum', min: 0, max: 14)),
                            const SizedBox(width: 12),
                            Expanded(child: _number(_bufferAfter, 'Hari laundry sesudah', min: 0, max: 14)),
                          ],
                        ),
                        Text(
                          'Hari persiapan & laundry ikut terkunci di kalender setiap kali kostum disewa. '
                          'Perubahan harga tidak mengubah sewa yang sudah dikonfirmasi.',
                          style: theme.textTheme.bodySmall,
                        ),
                        _section(theme, 'Izin publikasi'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _consent,
                          title: const Text('Foto & data listing ini boleh tampil publik'),
                          subtitle: const Text('Pastikan foto milik toko sendiri atau sudah mendapat izin.'),
                          onChanged: (v) {
                            setState(() => _consent = v);
                            _changed();
                          },
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _section(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _number(TextEditingController c, String label,
      {String? prefix, int? min, int? max, bool optional = false}) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, prefixText: prefix),
      validator: (v) {
        final n = int.tryParse(v ?? '');
        if (n == null) return optional || c == _amount ? null : 'Wajib diisi';
        if (min != null && n < min) return 'Minimal $min';
        if (max != null && n > max) return 'Maksimal $max';
        return null;
      },
      onChanged: (_) => _changed(),
    );
  }

  Widget _photos(ThemeData theme) {
    final canAdd = _images.length < _maxPhotos && !_busy;
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final img in _images)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _busy ? null : () => _photoMenu(img),
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(imageUrl: img.url, width: 104, height: 104, fit: BoxFit.cover),
                    ),
                    if (img.position == 1)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Sampul', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_images.length < _maxPhotos)
            InkWell(
              onTap: canAdd ? _addPhoto : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined),
                    const SizedBox(height: 4),
                    Text(_isNew ? 'Simpan & tambah' : 'Tambah foto',
                        textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(ThemeData theme) {
    final (String label, VoidCallback? onPressed) = switch (_status) {
      'published' => ('Tarik dari publik', () => _setStatus('unpublish_product', 'Listing ditarik dari publik.')),
      'archived' => ('Pulihkan ke draft', () => _setStatus('restore_product', 'Listing dipulihkan sebagai draft.')),
      _ => ('Terbitkan', _publish),
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy || (!_dirty && !_isNew) ? null : () => _save(),
                child: Text(_isNew ? 'Simpan draft' : (_dirty ? 'Simpan' : 'Tersimpan')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _busy || _isNew && _status != 'draft' ? null : onPressed, child: Text(label)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingCard extends StatelessWidget {
  const _MissingCard({required this.missing, required this.status, required this.isNew});
  final List<String> missing;
  final String status;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (status == 'archived') {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Listing diarsipkan dan tidak tampil publik. Pulihkan untuk menyunting dan menerbitkan lagi.'),
        ),
      );
    }
    if (missing.isEmpty) {
      return status == 'published'
          ? const SizedBox.shrink()
          : Card(
              color: Colors.green.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Lengkap. Tekan "Terbitkan" agar tampil di katalog.'),
              ),
            );
    }
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isNew ? 'Agar bisa terbit, lengkapi:' : 'Belum bisa terbit. Lengkapi:',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final m in missing) Text('• ${missingLabels[m] ?? m}'),
          ],
        ),
      ),
    );
  }
}
