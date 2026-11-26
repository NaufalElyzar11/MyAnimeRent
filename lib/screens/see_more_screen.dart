import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/costume_provider.dart';
import '../widgets/ui_kit.dart';

/// Semua kostum dari satu seri anime/game.
class SeeMoreScreen extends StatelessWidget {
  final String anime;
  const SeeMoreScreen({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CostumeProvider>();
    final decodedAnime = Uri.decodeComponent(anime);
    final costumes = provider.getCostumesForAnime(decodedAnime);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(decodedAnime, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${costumes.length} kostum', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: costumes.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.checkroom_outlined,
                title: 'Belum ada kostum di seri ini',
                actionLabel: 'Cari kostum lain',
                onAction: () => context.go('/search'),
              ),
            )
          : CostumeGridView(
              costumes: costumes,
              onTap: (c) => context.push('/detail/${c.id}'),
            ),
    );
  }
}
