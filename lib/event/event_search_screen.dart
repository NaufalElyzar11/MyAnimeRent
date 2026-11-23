import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'catalog.dart';
import 'catalog_controller.dart';
import 'catalog_search.dart';
import 'contact_service.dart';
import 'event_widgets.dart';
import '../widgets/costume_grid.dart';

class EventSearchScreen extends StatefulWidget {
  const EventSearchScreen({super.key});
  @override
  State<EventSearchScreen> createState() => _EventSearchScreenState();
}

class _EventSearchScreenState extends State<EventSearchScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  CatalogController? _catalog;
  int _session = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final catalog = context.read<CatalogController>();
    if (!identical(catalog, _catalog)) {
      _catalog?.removeListener(_syncSession);
      _catalog = catalog;
      _session = catalog.session;
      _text.text = catalog.query.text;
      catalog.addListener(_syncSession);
    }
  }

  void _syncSession() {
    if (_catalog!.session != _session) {
      _session = _catalog!.session;
      _text.clear();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  void _search(CatalogQuery query) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _catalog!.setQuery(query);
  }

  @override
  void dispose() {
    _catalog?.removeListener(_syncSession);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogBody(
    builder: (context, snapshot) {
      final catalog = context.watch<CatalogController>();
      final query = catalog.query;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const ValueKey('catalog-query'),
              controller: _text,
              textInputAction: TextInputAction.search,
              onChanged: (value) => _search(query.copyWith(text: value)),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: 'Cari kostum',
                hintText: 'Karakter, seri, atau nama kostum',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _text.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _text.clear();
                          _search(query.copyWith(text: ''));
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: const PageStorageKey('event-search-results'),
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('open-filters'),
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        final result = await showModalBottomSheet<CatalogQuery>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => CatalogFilterSheet(
                            snapshot: snapshot,
                            query: query,
                          ),
                        );
                        if (result != null && mounted) _search(result);
                      },
                      icon: const Icon(Icons.tune),
                      label: const Text('Filter'),
                    ),
                    if (query.hasFilters)
                      TextButton(
                        onPressed: () =>
                            _search(CatalogQuery(text: query.text)),
                        child: const Text('Reset filter'),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (query.cityCode != null)
                      InputChip(
                        label: Text(snapshot.cityName(query.cityCode!)),
                        onDeleted: () =>
                            _search(query.copyWith(cityCode: null)),
                        deleteButtonTooltipMessage: 'Hapus filter kota',
                      ),
                    if (query.size != null)
                      InputChip(
                        label: Text('Ukuran ${query.size}'),
                        onDeleted: () => _search(query.copyWith(size: null)),
                        deleteButtonTooltipMessage: 'Hapus filter ukuran',
                      ),
                    if (query.priceBasisDays != null)
                      InputChip(
                        label: Text(
                          'Basis: paket ${query.priceBasisDays} hari',
                        ),
                        onDeleted: () => _search(
                          query.copyWith(
                            priceBasisDays: null,
                            minPrice: null,
                            maxPrice: null,
                          ),
                        ),
                        deleteButtonTooltipMessage:
                            'Hapus basis dan rentang harga',
                      ),
                    if (query.hasPriceRange)
                      InputChip(
                        label: Text(
                          '${query.minPrice == null ? 'Tanpa minimum' : rupiah(query.minPrice!)} – ${query.maxPrice == null ? 'tanpa maksimum' : rupiah(query.maxPrice!)}',
                        ),
                        onDeleted: () => _search(
                          query.copyWith(minPrice: null, maxPrice: null),
                        ),
                        deleteButtonTooltipMessage: 'Hapus rentang harga',
                      ),
                  ],
                ),
                if (catalog.searching) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '${catalog.total} kostum ditemukan',
                    key: const ValueKey('result-count'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Katalog lokal • Bisa dicari tanpa internet'),
                ),
                if (query.hasPriceRange)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${catalog.excludedPriceBasisCount} kostum dikecualikan: durasi berbeda atau harga/periode belum diinformasikan.',
                          key: const ValueKey('price-exclusions'),
                        ),
                        TextButton(
                          onPressed: () => _search(
                            query.copyWith(
                              priceBasisDays: null,
                              minPrice: null,
                              maxPrice: null,
                            ),
                          ),
                          child: const Text('Hapus filter harga'),
                        ),
                      ],
                    ),
                  ),
                if (!catalog.searching && catalog.items.isEmpty)
                  EventMessage(
                    title: 'Tidak ada kostum yang cocok',
                    message:
                        'Coba kata pencarian lain${query.hasFilters ? ' atau hapus filter' : ''}.',
                    action: query.hasFilters
                        ? OutlinedButton(
                            onPressed: () =>
                                _search(CatalogQuery(text: query.text)),
                            child: const Text('Hapus semua filter'),
                          )
                        : null,
                  ),
                CostumeGrid(
                  children: [
                    for (final product in catalog.items)
                      EventProductCard(product: product, snapshot: snapshot),
                  ],
                ),
                if (catalog.nextCursor != null)
                  OutlinedButton(
                    onPressed: catalog.searching
                        ? null
                        : () => catalog.setQuery(query, more: true),
                    child: const Text('Tampilkan lagi'),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class CatalogFilterSheet extends StatefulWidget {
  const CatalogFilterSheet({
    super.key,
    required this.snapshot,
    required this.query,
  });
  final CatalogSnapshot snapshot;
  final CatalogQuery query;
  @override
  State<CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<CatalogFilterSheet> {
  final _form = GlobalKey<FormState>();
  late String? _city;
  late String? _size;
  late int? _basis;
  late final TextEditingController _min;
  late final TextEditingController _max;
  @override
  void initState() {
    super.initState();
    _city = widget.query.cityCode;
    _size = widget.query.size;
    _basis = widget.query.priceBasisDays;
    _min = TextEditingController(text: widget.query.minPrice?.toString() ?? '');
    _max = TextEditingController(text: widget.query.maxPrice?.toString() ?? '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  String? _validatePrice(String? value) {
    if (_basis == null || value == null || value.isEmpty) return null;
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > 1000000000) {
      return 'Masukkan harga yang valid (maks. 1 miliar)';
    }
    final minimum = int.tryParse(_min.text);
    final maximum = int.tryParse(_max.text);
    if (minimum != null && maximum != null && minimum > maximum) {
      return 'Minimum tidak boleh melebihi maksimum';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sizes =
        widget.snapshot.products.expand((p) => p.sizes).toSet().toList()
          ..sort();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter katalog',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              key: const ValueKey('filter-city'),
              initialValue: _city,
              isExpanded: true,
              itemHeight: null,
              isDense: false,
              decoration: const InputDecoration(labelText: 'Kota toko'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Semua kota'),
                ),
                for (final city in widget.snapshot.cities)
                  DropdownMenuItem(value: city.code, child: Text(city.name)),
              ],
              onChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey('filter-size'),
              initialValue: _size,
              isExpanded: true,
              itemHeight: null,
              isDense: false,
              decoration: const InputDecoration(labelText: 'Ukuran'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Semua ukuran'),
                ),
                for (final size in sizes)
                  DropdownMenuItem(value: size, child: Text(size)),
              ],
              onChanged: (value) => setState(() => _size = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: const ValueKey('filter-price-basis'),
              initialValue: _basis,
              isExpanded: true,
              itemHeight: null,
              isDense: false,
              decoration: const InputDecoration(
                labelText: 'Basis durasi harga',
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('Pilih durasi'),
                ),
                for (final days in widget.snapshot.priceBases)
                  DropdownMenuItem(
                    value: days,
                    child: Text('Paket $days hari'),
                  ),
              ],
              onChanged: (value) => setState(() {
                _basis = value;
                if (value == null) {
                  _min.clear();
                  _max.clear();
                }
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _basis == null
                  ? 'Pilih durasi yang tersedia sebelum mengisi rentang harga.'
                  : 'Rentang hanya membandingkan paket $_basis hari. Tidak ada konversi tarif.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('filter-min-price'),
              controller: _min,
              enabled: _basis != null,
              decoration: const InputDecoration(
                labelText: 'Harga minimum (Rp)',
                hintText: 'Tanpa minimum',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validatePrice,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('filter-max-price'),
              controller: _max,
              enabled: _basis != null,
              decoration: const InputDecoration(
                labelText: 'Harga maksimum (Rp)',
                hintText: 'Tanpa maksimum',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validatePrice,
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('apply-filters'),
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  CatalogQuery(
                    text: widget.query.text,
                    cityCode: _city,
                    size: _size,
                    priceBasisDays: _basis,
                    minPrice: _basis == null ? null : int.tryParse(_min.text),
                    maxPrice: _basis == null ? null : int.tryParse(_max.text),
                  ),
                );
              },
              child: const Text('Terapkan filter'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }
}
