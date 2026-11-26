import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/costume_provider.dart';
import '../models/costume.dart';
import '../config/theme.dart';
import '../services/database_service.dart';
import '../widgets/ui_kit.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.catalogBody});
  final Widget? catalogBody;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Dibuat saat pertama dipakai: mode event (catalogBody) tidak boleh menyentuh cloud.
  late final DatabaseService _db = DatabaseService();
  final _searchController = TextEditingController();
  List<Costume> _results = [];
  bool _isSearching = false;
  String? _error;
  Timer? _debounce;
  int _seq = 0;

  // Filter
  String? _cityCode;
  String? _cityName;
  String? _size;
  List<({String code, String name})> _cities = [];

  static const _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'All size'];

  bool get _hasQuery => _searchController.text.trim().length >= 2;
  bool get _hasFilter => _cityCode != null || _size != null;
  bool get _browsing => !_hasQuery && !_hasFilter;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Pencarian di server (judul, karakter, seri, alias Jepang/Inggris, toleran salah ketik) + filter.
  void _run({bool immediate = false}) {
    _debounce?.cancel();
    if (_browsing) {
      setState(() {
        _results = [];
        _isSearching = false;
        _error = null;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(Duration(milliseconds: immediate ? 0 : 350), () async {
      final seq = ++_seq;
      try {
        final found = await _db.searchProducts(
          query: _hasQuery ? _searchController.text.trim() : null,
          cityCode: _cityCode,
          size: _size,
          limit: 48,
        );
        if (!mounted || seq != _seq) return;
        setState(() {
          _results = found;
          _error = null;
          _isSearching = false;
        });
      } catch (e) {
        if (!mounted || seq != _seq) return;
        setState(() {
          _error = 'Pencarian gagal. Periksa koneksi lalu coba lagi.';
          _isSearching = false;
        });
      }
    });
  }

  void _setQuery(String q) {
    _searchController.text = q;
    _searchController.selection = TextSelection.collapsed(offset: q.length);
    _run(immediate: true);
  }

  Future<void> _pickCity() async {
    if (_cities.isEmpty) {
      try {
        _cities = await _db.listCities();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daftar kota belum bisa dimuat.')));
        }
        return;
      }
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<({String code, String name})?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CityPicker(cities: _cities, selected: _cityCode),
    );
    if (picked == null) return;
    setState(() {
      _cityCode = picked.code.isEmpty ? null : picked.code;
      _cityName = picked.code.isEmpty ? null : picked.name;
    });
    _run(immediate: true);
  }

  Future<void> _pickSize() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ukuran', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(label: const Text('Semua'), selected: _size == null, onSelected: (_) => Navigator.pop(ctx, '')),
                  for (final sz in _sizes)
                    ChoiceChip(label: Text(sz), selected: _size == sz, onSelected: (_) => Navigator.pop(ctx, sz)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _size = picked.isEmpty ? null : picked);
    _run(immediate: true);
  }

  void _resetFilters() {
    setState(() {
      _cityCode = null;
      _cityName = null;
      _size = null;
    });
    _run(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.catalogBody != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Cari kostum'),
          automaticallyImplyLeading: false,
        ),
        body: widget.catalogBody,
      );
    }
    final theme = Theme.of(context);
    final catalog = context.watch<CostumeProvider>();
    final series = catalog.costumesByAnime.values.toList()..sort((a, b) => b.length.compareTo(a.length));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _run(),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(immediate: true),
            decoration: InputDecoration(
              hintText: 'Cari karakter, anime, atau kostum…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => _setQuery(''),
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 6),
            children: [
              FilterChip(
                avatar: const Icon(Icons.place_outlined, size: 16),
                label: Text(_cityName ?? 'Semua kota'),
                selected: _cityCode != null,
                onSelected: (_) => _pickCity(),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.straighten, size: 16),
                label: Text(_size == null ? 'Semua ukuran' : 'Ukuran $_size'),
                selected: _size != null,
                onSelected: (_) => _pickSize(),
              ),
              if (_hasFilter) ...[
                const SizedBox(width: 8),
                ActionChip(label: const Text('Reset'), onPressed: _resetFilters),
              ],
            ],
          ),
        ),
        Expanded(
          child: _browsing
              ? _Browse(
                  series: series,
                  all: catalog.costumes,
                  loading: catalog.isLoading && catalog.costumes.isEmpty,
                  onSeries: _setQuery,
                )
              : _isSearching && _results.isEmpty
                  ? const Padding(padding: EdgeInsets.all(AppSpacing.page), child: CostumeGridSkeleton())
                  : _error != null
                      ? Center(
                          child: EmptyState(
                            icon: Icons.wifi_off_rounded,
                            title: 'Pencarian gagal',
                            message: _error,
                            actionLabel: 'Coba lagi',
                            onAction: () => _run(immediate: true),
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                child: EmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: 'Belum ada yang cocok',
                                  message: _hasFilter
                                      ? 'Coba hapus filter kota/ukuran atau gunakan kata lain.'
                                      : 'Coba nama karakter, anime, atau ejaan lain (mis. "Kimetsu" untuk Demon Slayer).',
                                  actionLabel: _hasFilter ? 'Reset filter' : null,
                                  onAction: _hasFilter ? _resetFilters : null,
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, AppSpacing.page, 0),
                                  child: Row(
                                    children: [
                                      Text(
                                        '${_results.length}${_results.length >= 48 ? '+' : ''} kostum ditemukan',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      if (_isSearching) ...[
                                        const SizedBox(width: 8),
                                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                      ],
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: CostumeGridView(
                                    costumes: _results,
                                    onTap: (c) => context.push('/detail/${c.id}'),
                                  ),
                                ),
                              ],
                            ),
        ),
      ],
    );
  }
}

/// Isi layar Cari sebelum mengetik: seri populer + semua kostum.
class _Browse extends StatelessWidget {
  const _Browse({required this.series, required this.all, required this.loading, required this.onSeries});
  final List<List<Costume>> series;
  final List<Costume> all;
  final bool loading;
  final void Function(String) onSeries;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (series.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Seri populer'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in series.take(12))
                        ActionChip(
                          label: Text('${s.first.anime} · ${s.length}'),
                          onPressed: () => onSeries(s.first.anime),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 0),
          sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Semua kostum')),
        ),
        if (loading)
          const SliverPadding(
            padding: EdgeInsets.all(AppSpacing.page),
            sliver: SliverToBoxAdapter(child: CostumeGridSkeleton()),
          )
        else
          SliverToBoxAdapter(
            child: CostumeGridView(
              costumes: all,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
              onTap: (c) => context.push('/detail/${c.id}'),
            ),
          ),
      ],
    );
  }
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.cities, required this.selected});
  final List<({String code, String name})> cities;
  final String? selected;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.cities.where((c) => c.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Cari kota…', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: const Text('Semua kota'),
                    selected: widget.selected == null,
                    onTap: () => Navigator.pop(context, (code: '', name: '')),
                  ),
                  for (final c in filtered)
                    ListTile(
                      title: Text(c.name),
                      selected: c.code == widget.selected,
                      trailing: c.code == widget.selected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, c),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
