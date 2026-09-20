import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/costume_provider.dart';
import '../widgets/store_card.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CostumeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Stores'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.stores.isEmpty
              ? const Center(child: Text('No stores found.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: provider.stores.length,
                  itemBuilder: (context, index) {
                    final store = provider.stores[index];
                    return StoreCard(
                      store: store,
                      onTap: () => context.push('/store_detail/${store.id}'),
                    );
                  },
                ),
    );
  }
}
