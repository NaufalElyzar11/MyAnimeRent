import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/costume.dart';
import '../models/store.dart';
import '../providers/costume_provider.dart';
import '../widgets/costume_card.dart';

/// Profil toko publik + katalognya. [storeId] = slug toko.
class StoreDetailScreen extends StatefulWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  Store? _store;
  List<Costume> _costumes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = context.read<CostumeProvider>();
    try {
      final results = await Future.wait([
        provider.getStoreById(widget.storeId),
        provider.loadStoreCostumes(widget.storeId),
      ]);
      if (!mounted) return;
      setState(() {
        _store = results[0] as Store?;
        _costumes = results[1] as List<Costume>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = _store;
    return Scaffold(
      appBar: AppBar(
        title: Text(store?.name ?? 'Profil toko'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : store == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Toko tidak ditemukan atau belum tayang.', textAlign: TextAlign.center),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                        ],
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storefront, size: 48, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(store.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                Text(store.city, style: theme.textTheme.bodyMedium),
                                if (store.shipsIntercity)
                                  Text('Bisa kirim antarkota', style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (store.description != null && store.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(store.description!),
                      ],
                      if (store.policies != null && store.policies!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Kebijakan toko', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(store.policies!),
                      ],
                      if (store.shippingNotes != null && store.shippingNotes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Pengiriman: ${store.shippingNotes!}', style: theme.textTheme.bodySmall),
                      ],
                      const SizedBox(height: 20),
                      Text('Kostum (${_costumes.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_costumes.isEmpty)
                        const Text('Toko ini belum punya kostum yang tayang.')
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.6,
                          ),
                          itemCount: _costumes.length,
                          itemBuilder: (context, i) => CostumeCard(
                            costume: _costumes[i],
                            onTap: () => context.push('/detail/${_costumes[i].id}'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
