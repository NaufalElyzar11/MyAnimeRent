import 'dart:convert';

import 'catalog.dart';

const _unchanged = Object();

/// A bounded request contract; a shared server search can implement it later.
class CatalogQuery {
  const CatalogQuery({
    this.text = '',
    this.cityCode,
    this.size,
    this.priceBasisDays,
    this.minPrice,
    this.maxPrice,
    this.storeId,
  });
  final String text;
  final String? cityCode;
  final String? size;
  final int? priceBasisDays;
  final int? minPrice;
  final int? maxPrice;
  final String? storeId;
  bool get hasPriceRange => minPrice != null || maxPrice != null;
  bool get hasFilters =>
      cityCode != null ||
      size != null ||
      priceBasisDays != null ||
      hasPriceRange;

  CatalogQuery copyWith({
    String? text,
    Object? cityCode = _unchanged,
    Object? size = _unchanged,
    Object? priceBasisDays = _unchanged,
    Object? minPrice = _unchanged,
    Object? maxPrice = _unchanged,
  }) => CatalogQuery(
    text: text ?? this.text,
    storeId: storeId,
    cityCode: identical(cityCode, _unchanged)
        ? this.cityCode
        : cityCode as String?,
    size: identical(size, _unchanged) ? this.size : size as String?,
    priceBasisDays: identical(priceBasisDays, _unchanged)
        ? this.priceBasisDays
        : priceBasisDays as int?,
    minPrice: identical(minPrice, _unchanged)
        ? this.minPrice
        : minPrice as int?,
    maxPrice: identical(maxPrice, _unchanged)
        ? this.maxPrice
        : maxPrice as int?,
  );

  String get key => jsonEncode([
    text,
    cityCode,
    size,
    priceBasisDays,
    minPrice,
    maxPrice,
    storeId,
  ]);
}

class CatalogPage {
  const CatalogPage({
    required this.items,
    required this.total,
    required this.excludedPriceBasisCount,
    required this.nextCursor,
  });
  final List<CatalogProduct> items;
  final int total;
  final int excludedPriceBasisCount;
  final String? nextCursor;
}

String normalizeSearch(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();
String _compact(String input) => normalizeSearch(input).replaceAll(' ', '');

int _score(CatalogProduct product, String query) {
  final q = _compact(query);
  if (q.isEmpty) return 1;
  final name = _compact(product.name);
  final character = _compact(product.character);
  final series = _compact(product.series);
  final aliases = product.aliases.map(_compact).toList();
  if (character == q) return 100;
  if (name == q) return 95;
  if (aliases.contains(q)) return 90;
  if (character.startsWith(q)) return 85;
  if (name.startsWith(q)) return 80;
  if (character.contains(q) ||
      name.contains(q) ||
      aliases.any((a) => a.contains(q))) {
    return 70;
  }
  if (series == q) return 40;
  if (series.contains(q)) return 30;
  final haystack = [name, character, series, ...aliases].join(' ');
  if (normalizeSearch(query).split(' ').every((t) => haystack.contains(t))) {
    return 20;
  }
  return 0;
}

/// Deliberately scans a small bundled snapshot. This is not production search.
CatalogPage searchSnapshot(
  CatalogSnapshot snapshot,
  CatalogQuery query, {
  String? cursor,
  int limit = 12,
}) {
  if (limit < 1 || limit > 24) throw ArgumentError('limit harus 1–24');
  if (query.hasPriceRange &&
      (query.priceBasisDays == null ||
          !snapshot.priceBases.contains(query.priceBasisDays))) {
    throw ArgumentError(
      'Pilih basis durasi dari katalog sebelum menyaring harga',
    );
  }
  if ((query.minPrice != null && query.minPrice! < 0) ||
      (query.maxPrice != null && query.maxPrice! < 0) ||
      (query.minPrice != null &&
          query.maxPrice != null &&
          query.minPrice! > query.maxPrice!)) {
    throw ArgumentError('Rentang harga tidak valid');
  }
  var offset = 0;
  if (cursor != null) {
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(cursor))) as List;
      if (decoded.length != 3 ||
          decoded[0] != snapshot.revision ||
          decoded[1] != query.key ||
          decoded[2] is! int) {
        throw const FormatException('cursor berbeda');
      }
      offset = decoded[2] as int;
      if (offset < 0) throw const FormatException('offset negatif');
    } catch (_) {
      throw ArgumentError('Cursor tidak valid untuk pencarian ini');
    }
  }
  var excluded = 0;
  final scores = <String, int>{};
  final matches = <CatalogProduct>[];
  for (final p in snapshot.products) {
    final score = _score(p, query.text);
    if (score == 0 ||
        (query.storeId != null && p.storeId != query.storeId) ||
        (query.cityCode != null &&
            snapshot.store(p.storeId).cityCode != query.cityCode) ||
        (query.size != null &&
            !p.sizes.any((s) => _compact(s) == _compact(query.size!)))) {
      continue;
    }
    if (query.hasPriceRange) {
      if (p.price.durationDays != query.priceBasisDays ||
          p.price.amountIdr == null) {
        excluded++;
        continue;
      }
      if ((query.minPrice != null && p.price.amountIdr! < query.minPrice!) ||
          (query.maxPrice != null && p.price.amountIdr! > query.maxPrice!)) {
        continue;
      }
    }
    scores[p.id] = score;
    matches.add(p);
  }
  matches.sort((a, b) {
    final relevance = scores[b.id]!.compareTo(scores[a.id]!);
    return relevance == 0 ? a.id.compareTo(b.id) : relevance;
  });
  if (offset > matches.length) throw ArgumentError('Cursor melewati hasil');
  final end = (offset + limit).clamp(0, matches.length);
  return CatalogPage(
    items: List.unmodifiable(matches.sublist(offset, end)),
    total: matches.length,
    excludedPriceBasisCount: excluded,
    nextCursor: end < matches.length
        ? base64Url.encode(
            utf8.encode(jsonEncode([snapshot.revision, query.key, end])),
          )
        : null,
  );
}
