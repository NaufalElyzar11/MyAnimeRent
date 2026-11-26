import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/costume_provider.dart';
import '../models/costume.dart';
import '../widgets/costume_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.catalogBody});
  final Widget? catalogBody;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Costume> _results = [];
  bool _isSearching = false;
  String? _error;
  Timer? _debounce;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Pencarian di server (judul, karakter, seri, alias Jepang/Inggris, toleran salah ketik).
  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
        _error = null;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final seq = ++_seq;
      try {
        final found = await context.read<CostumeProvider>().search(query.trim());
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

  static const List<String> _popularSuggestions = [
    'Genshin Impact',
    'Demon Slayer',
    'Jujutsu Kaisen',
    'Spy x Family',
    'Chainsaw Man',
    'Naruto',
    'One Piece',
  ];

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Cari karakter, seri, atau kostum…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _onSearch(_searchController.text),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _searchController.text.trim().length < 2
              ? SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pencarian Populer',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _popularSuggestions.map((tag) {
                          return ActionChip(
                            label: Text(tag),
                            avatar: const Icon(Icons.search, size: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            onPressed: () {
                              _searchController.text = tag;
                              _onSearch(tag);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                )
              : _results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kostum Tidak Ditemukan',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tidak ada kostum atau karakter yang cocok dengan "${_searchController.text}"',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    return CostumeCard(
                      costume: _results[index],
                      onTap: () =>
                          context.push('/detail/${_results[index].id}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
