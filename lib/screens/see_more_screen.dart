import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/costume_provider.dart';
import '../widgets/costume_card.dart';

class SeeMoreScreen extends StatelessWidget {
  final String anime;
  const SeeMoreScreen({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CostumeProvider>();
    final costumes = provider.getCostumesForAnime(Uri.decodeComponent(anime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Costumes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: costumes.isEmpty
          ? const Center(child: Text('No costumes found.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.6,
              ),
              itemCount: costumes.length,
              itemBuilder: (context, index) {
                return CostumeCard(
                  costume: costumes[index],
                  onTap: () => context.push('/detail/${costumes[index].id}'),
                );
              },
            ),
    );
  }
}
