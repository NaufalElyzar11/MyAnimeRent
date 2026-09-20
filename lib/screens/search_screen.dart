import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/costume_provider.dart';
import '../models/costume.dart';
import '../widgets/costume_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Costume> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final provider = context.read<CostumeProvider>();
    if (query.length <= 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final lowerQuery = query.toLowerCase();
    final filtered = provider.costumes.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          c.anime.toLowerCase().contains(lowerQuery);
    }).toList();

    setState(() {
      _results = filtered;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search costumes or characters...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.length > 2
                            ? 'No results found for "${_searchController.text}"'
                            : 'Please enter more than 2 characters to search.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return CostumeCard(
                          costume: _results[index],
                          onTap: () => context.push('/detail/${_results[index].id}'),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
