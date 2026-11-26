import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/store_catalog.dart';
import '../../providers/store_admin_provider.dart';
import '../../services/auth_service.dart';
import '../../services/store_catalog_service.dart';
import '../../services/supabase_service.dart';

/// Profil toko: nama, kota, deskripsi, kebijakan sewa, WhatsApp, pengiriman, dan status terbit.
/// Hanya owner yang bisa mengubah; staf melihat saja.
class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key, required this.storeId});
  final String storeId;

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final _service = StoreCatalogService();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _policies = TextEditingController();
  final _whatsapp = TextEditingController();
  final _shipping = TextEditingController();

  StoreProfile? _store;
  List<City> _cities = [];
  String? _cityCode;
  bool _contactPublic = false;
  bool _shipsIntercity = false;
  bool _consent = false;
  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  String? _error;
  String? _saveOp;

  bool get _canEdit => _store?.isOwner ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _policies, _whatsapp, _shipping]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_service.getStore(widget.storeId), _service.listCities()]);
      if (!mounted) return;
      final s = results[0] as StoreProfile;
      setState(() {
        _store = s;
        _cities = results[1] as List<City>;
        _name.text = s.name;
        _description.text = s.description ?? '';
        _policies.text = s.publicPolicies ?? '';
        _whatsapp.text = s.whatsapp ?? '';
        _shipping.text = s.shippingNotes ?? '';
        _cityCode = s.cityCode;
        _contactPublic = s.contactPublic;
        _shipsIntercity = s.shipsIntercity;
        _dirty = false;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _changed() {
    _saveOp = null;
    if (!_dirty) setState(() => _dirty = true);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null));
  }

  String _errorText(ApiException e) => switch (e.reason) {
        'STALE_REVISION' => 'Profil baru saja diubah dari perangkat lain. Data dimuat ulang.',
        'FIELD_INVALID' || 'FIELD_REQUIRED' => 'Ada isian yang belum benar (${e.details?['field'] ?? 'periksa form'}).',
        _ => e.message,
      };

  Future<bool> _save() async {
    final s = _store;
    if (s == null || !_formKey.currentState!.validate()) return false;
    if (!_dirty) return true;
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final wa = _whatsapp.text.trim().isEmpty ? null : AuthService.normalizePhone(_whatsapp.text);
    _saveOp ??= newOperationId();
    setState(() => _busy = true);
    try {
      final r = await _service.updateStore(s.id, expectedRevision: s.revision, operationId: _saveOp!, store: {
        'name': _name.text.trim(),
        'city_code': _cityCode,
        'description': opt(_description),
        'public_policies': opt(_policies),
        'whatsapp_e164': wa,
        'contact_public': wa != null && _contactPublic,
        'ships_intercity': _shipsIntercity,
        'shipping_notes': opt(_shipping),
      });
      _saveOp = null;
      _snack('Profil toko disimpan.');
      await _load();
      if (mounted) context.read<StoreAdminProvider>().loadStores();
      return r['ok'] != false;
    } on ApiException catch (e) {
      if (!e.isNetwork) _saveOp = null;
      _snack(_errorText(e), error: true);
      if (e.reason == 'STALE_REVISION') await _load();
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPublished(bool publish) async {
    if (_dirty && !await _save()) return;
    final s = _store;
    if (s == null) return;
    setState(() => _busy = true);
    try {
      if (publish) {
        await _service.publishStore(s.id, expectedRevision: s.revision, operationId: newOperationId());
        _snack('Toko terbit. Listing yang sudah terbit kini tampil di katalog publik.');
      } else {
        await _service.unpublishStore(s.id, expectedRevision: s.revision, operationId: newOperationId());
        _snack('Toko ditarik dari publik.');
      }
      await _load();
      if (mounted) context.read<StoreAdminProvider>().loadStores();
    } on ApiException catch (e) {
      _snack(_errorText(e), error: true);
      if (e.reason == 'STALE_REVISION') await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _store;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Buang perubahan?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buang')),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Profil toko')),
        bottomNavigationBar: s == null || !_canEdit
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: FilledButton(
                    onPressed: _busy || !_dirty ? null : _save,
                    child: Text(_dirty ? 'Simpan perubahan' : 'Tersimpan'),
                  ),
                ),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : s == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Toko tidak ditemukan.', textAlign: TextAlign.center),
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
                        _StatusCard(
                          store: s,
                          canEdit: _canEdit,
                          busy: _busy,
                          consent: _consent,
                          onConsent: (v) => setState(() => _consent = v),
                          onPublish: () => _setPublished(true),
                          onUnpublish: () => _setPublished(false),
                        ),
                        if (!_canEdit)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('Hanya owner yang bisa mengubah profil toko.', style: theme.textTheme.bodySmall),
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _name,
                          enabled: _canEdit,
                          maxLength: 80,
                          decoration: const InputDecoration(labelText: 'Nama toko *'),
                          validator: (v) => (v == null || v.trim().length < 2) ? 'Minimal 2 huruf' : null,
                          onChanged: (_) => _changed(),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _cities.any((c) => c.code == _cityCode) ? _cityCode : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Kota *'),
                          items: [
                            for (final c in _cities)
                              DropdownMenuItem(
                                value: c.code,
                                child: Text(c.province == null ? c.name : '${c.name}, ${c.province}',
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          validator: (v) => v == null ? 'Pilih kota' : null,
                          onChanged: _canEdit
                              ? (v) {
                                  setState(() => _cityCode = v);
                                  _changed();
                                }
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _description,
                          enabled: _canEdit,
                          maxLength: 1000,
                          minLines: 2,
                          maxLines: 6,
                          decoration: const InputDecoration(labelText: 'Tentang toko'),
                          onChanged: (_) => _changed(),
                        ),
                        TextFormField(
                          controller: _policies,
                          enabled: _canEdit,
                          maxLength: 2000,
                          minLines: 3,
                          maxLines: 10,
                          decoration: const InputDecoration(
                            labelText: 'Aturan sewa',
                            hintText: 'Mis. jaminan KTP, denda telat Rp20.000/hari, kostum dikembalikan tanpa dicuci',
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        Text('Kontak', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        TextFormField(
                          controller: _whatsapp,
                          enabled: _canEdit,
                          keyboardType: TextInputType.phone,
                          maxLength: 16,
                          decoration: const InputDecoration(labelText: 'Nomor WhatsApp toko', hintText: '0812…'),
                          validator: (v) => (v == null || v.trim().isEmpty || AuthService.normalizePhone(v) != null)
                              ? null
                              : 'Nomor tidak valid',
                          onChanged: (_) => _changed(),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _contactPublic,
                          title: const Text('Tampilkan nomor WhatsApp ke publik'),
                          subtitle: const Text(
                              'Bila mati, penyewa tetap bisa mengirim permintaan dan pesan lewat app; nomor baru '
                              'terlihat setelah sewa dikonfirmasi.'),
                          onChanged: _canEdit
                              ? (v) {
                                  setState(() => _contactPublic = v);
                                  _changed();
                                }
                              : null,
                        ),
                        Text('Pengiriman', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _shipsIntercity,
                          title: const Text('Melayani kirim ke luar kota'),
                          onChanged: _canEdit
                              ? (v) {
                                  setState(() => _shipsIntercity = v);
                                  _changed();
                                }
                              : null,
                        ),
                        TextFormField(
                          controller: _shipping,
                          enabled: _canEdit,
                          maxLength: 500,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'Catatan pengiriman', hintText: 'Mis. JNE/J&T, ongkir ditanggung penyewa'),
                          onChanged: (_) => _changed(),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.store,
    required this.canEdit,
    required this.busy,
    required this.consent,
    required this.onConsent,
    required this.onPublish,
    required this.onUnpublish,
  });

  final StoreProfile store;
  final bool canEdit;
  final bool busy;
  final bool consent;
  final ValueChanged<bool> onConsent;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = store;
    return Card(
      color: s.isPublished ? Colors.green.withValues(alpha: 0.08) : theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.isPublished ? 'Toko sudah terbit' : 'Toko belum terbit',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(s.isPublished
                ? '${s.publishedProducts} listing tampil di katalog publik.'
                : 'Listing toko ini belum tampil di katalog walaupun sudah diterbitkan satu per satu.'),
            if (s.isPublished)
              TextButton(
                onPressed: () => context.push('/store_detail/${s.slug}'),
                child: const Text('Lihat halaman toko'),
              ),
            if (canEdit && !s.isPublished) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: consent,
                onChanged: (v) => onConsent(v ?? false),
                title: const Text(
                  'Saya pemilik toko ini dan setuju profil, foto, harga, serta jadwal ketersediaan '
                  'listing yang terbit ditampilkan publik di MyAnimeRent.',
                ),
              ),
              FilledButton(onPressed: busy || !consent ? null : onPublish, child: const Text('Terbitkan toko')),
            ],
            if (canEdit && s.isPublished)
              OutlinedButton(onPressed: busy ? null : onUnpublish, child: const Text('Tarik toko dari publik')),
          ],
        ),
      ),
    );
  }
}
