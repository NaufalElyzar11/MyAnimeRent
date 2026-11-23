import 'dart:convert';

/// Public, read-only event projection. No legacy availability or account fields.
class CatalogCity {
  const CatalogCity(this.code, this.name);
  final String code;
  final String name;
}

class CatalogStore {
  const CatalogStore({
    required this.id,
    required this.name,
    required this.cityCode,
    required this.policies,
    required this.description,
    required this.verifiedAt,
    required this.whatsapp,
    required this.contactConsent,
  });

  final String id;
  final String name;
  final String cityCode;
  final String? policies;
  final String? description;
  final DateTime? verifiedAt;
  final String? whatsapp;
  final bool contactConsent;
}

class CatalogPrice {
  const CatalogPrice({this.amountIdr, this.durationDays});
  final int? amountIdr;
  final int? durationDays;
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.storeId,
    required this.name,
    required this.character,
    required this.series,
    required this.aliases,
    required this.imageAssets,
    required this.sizes,
    required this.price,
    required this.description,
    required this.sizeNotes,
    required this.packageContents,
    required this.policies,
    required this.depositIdr,
    required this.verifiedAt,
  });

  final String id;
  final String storeId;
  final String name;
  final String character;
  final String series;
  final List<String> aliases;
  final List<String> imageAssets;
  final List<String> sizes;
  final CatalogPrice price;
  final String? description;
  final String? sizeNotes;
  final List<String> packageContents;
  final String? policies;
  final int? depositIdr;
  final DateTime? verifiedAt;
}

class CatalogSnapshot {
  CatalogSnapshot._({
    required this.revision,
    required this.illustrative,
    required this.capturedAt,
    required this.cities,
    required this.stores,
    required this.products,
  });

  final String revision;
  final bool illustrative;
  final DateTime capturedAt;
  final List<CatalogCity> cities;
  final List<CatalogStore> stores;
  final List<CatalogProduct> products;

  CatalogStore store(String id) => stores.firstWhere((s) => s.id == id);
  String cityName(String code) => cities.firstWhere((c) => c.code == code).name;

  List<int> get priceBases =>
      (products
          .where(
            (p) => p.price.amountIdr != null && p.price.durationDays != null,
          )
          .map((p) => p.price.durationDays!)
          .toSet()
          .toList()
        ..sort());

  Set<String> get imageAssets => products.expand((p) => p.imageAssets).toSet();

  factory CatalogSnapshot.parse(String source) {
    final root = _object(jsonDecode(source), 'snapshot');
    _keys(root, {
      'schemaVersion',
      'revision',
      'kind',
      'capturedAt',
      'cities',
      'stores',
      'products',
    });
    if (root['schemaVersion'] != 1) _fail('schemaVersion harus 1');
    final kind = _text(root['kind'], 'kind');
    if (!{'illustrative', 'authorized'}.contains(kind)) {
      _fail('kind tidak valid');
    }
    final illustrative = kind == 'illustrative';
    final cities = _list(root['cities'], 'cities').map((v) {
      final m = _object(v, 'city');
      _keys(m, {'code', 'name'});
      return CatalogCity(
        _id(m['code'], 'city.code'),
        _text(m['name'], 'city.name'),
      );
    }).toList();
    _unique(cities.map((c) => c.code), 'city.code');
    final stores = _list(root['stores'], 'stores').map((v) {
      final m = _object(v, 'store');
      _keys(m, {
        'id',
        'name',
        'cityCode',
        'policies',
        'description',
        'verifiedAt',
        'whatsapp',
        'contactConsent',
        'publicationConsent',
        'consentReference',
      });
      final consent = _boolean(m['contactConsent'], 'contactConsent');
      final publication = _boolean(
        m['publicationConsent'],
        'publicationConsent',
      );
      final reference = _optionalText(
        m['consentReference'],
        'consentReference',
      );
      final phone = _optionalText(m['whatsapp'], 'whatsapp');
      if (phone != null && !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
        _fail(
          'whatsapp harus nomor internasional E.164, misalnya +62… tanpa spasi',
        );
      }
      if (illustrative && (phone != null || consent)) {
        _fail('Kontak fixture harus nonaktif');
      }
      if (phone != null && !consent) {
        _fail('Nomor bisnis memerlukan contactConsent');
      }
      if (!illustrative && (!publication || reference == null)) {
        _fail('Izin publikasi toko belum lengkap');
      }
      final cityCode = _id(m['cityCode'], 'cityCode');
      if (!cities.any((c) => c.code == cityCode)) {
        _fail('cityCode toko tidak terdaftar');
      }
      final verified = _date(
        m['verifiedAt'],
        'store.verifiedAt',
        optional: illustrative,
      );
      return CatalogStore(
        id: _id(m['id'], 'store.id'),
        name: _text(m['name'], 'store.name'),
        cityCode: cityCode,
        policies: _optionalText(m['policies'], 'policies'),
        description: _optionalText(m['description'], 'description'),
        verifiedAt: verified,
        whatsapp: phone,
        contactConsent: consent,
      );
    }).toList();
    _unique(stores.map((s) => s.id), 'store.id');
    final products = _list(root['products'], 'products').map((v) {
      final m = _object(v, 'product');
      _keys(m, {
        'id',
        'storeId',
        'name',
        'character',
        'series',
        'aliases',
        'imageAssets',
        'sizes',
        'price',
        'description',
        'sizeNotes',
        'packageContents',
        'policies',
        'depositIdr',
        'verifiedAt',
        'publicationConsent',
        'consentReference',
      });
      final publication = _boolean(
        m['publicationConsent'],
        'product.publicationConsent',
      );
      final reference = _optionalText(
        m['consentReference'],
        'product.consentReference',
      );
      if (!illustrative && (!publication || reference == null)) {
        _fail('Izin produk/foto belum lengkap');
      }
      final storeId = _id(m['storeId'], 'storeId');
      if (!stores.any((s) => s.id == storeId)) {
        _fail('Produk mengacu ke toko yang tidak ada');
      }
      final images = _strings(m['imageAssets'], 'imageAssets');
      if (images.isEmpty) _fail('Setiap produk perlu gambar lokal');
      for (final path in images) {
        if (!RegExp(
          r'^assets/event/images/[a-zA-Z0-9_-]+\.(png|jpg|jpeg|webp)$',
        ).hasMatch(path)) {
          _fail('Path gambar harus lokal di assets/event/images/: $path');
        }
      }
      final price = _object(m['price'], 'price');
      _keys(price, {'amountIdr', 'durationDays'});
      return CatalogProduct(
        id: _id(m['id'], 'product.id'),
        storeId: storeId,
        name: _text(m['name'], 'name'),
        character: _text(m['character'], 'character'),
        series: _text(m['series'], 'series'),
        aliases: _strings(m['aliases'], 'aliases'),
        imageAssets: List.unmodifiable(images),
        sizes: List.unmodifiable(_strings(m['sizes'], 'sizes')),
        price: CatalogPrice(
          amountIdr: _integer(price['amountIdr'], 'amountIdr'),
          durationDays: _integer(
            price['durationDays'],
            'durationDays',
            minimum: 1,
            maximum: 365,
          ),
        ),
        description: _optionalText(m['description'], 'description'),
        sizeNotes: _optionalText(m['sizeNotes'], 'sizeNotes'),
        packageContents: List.unmodifiable(
          _strings(m['packageContents'], 'packageContents'),
        ),
        policies: _optionalText(m['policies'], 'policies'),
        depositIdr: _integer(m['depositIdr'], 'depositIdr'),
        verifiedAt: _date(
          m['verifiedAt'],
          'product.verifiedAt',
          optional: illustrative,
        ),
      );
    }).toList();
    _unique(products.map((p) => p.id), 'product.id');
    return CatalogSnapshot._(
      revision: _id(root['revision'], 'revision'),
      illustrative: illustrative,
      capturedAt: _date(root['capturedAt'], 'capturedAt')!,
      cities: List.unmodifiable(cities),
      stores: List.unmodifiable(stores),
      products: List.unmodifiable(products),
    );
  }
}

Never _fail(String message) => throw FormatException(message);
Map<String, dynamic> _object(Object? value, String field) {
  if (value is! Map<String, dynamic>) _fail('$field harus objek');
  return value;
}

void _keys(Map<String, dynamic> value, Set<String> allowed) {
  final unknown = value.keys.where((k) => !allowed.contains(k));
  if (unknown.isNotEmpty) _fail('Field tidak didukung: ${unknown.join(', ')}');
}

List<dynamic> _list(Object? value, String field) {
  if (value is! List) _fail('$field harus array');
  return value;
}

String _text(Object? value, String field) {
  if (value is! String || value.trim().isEmpty || value.length > 3000) {
    _fail('$field harus teks terisi (maks. 3000 karakter)');
  }
  return value.trim();
}

String? _optionalText(Object? value, String field) =>
    value == null ? null : _text(value, field);
String _id(Object? value, String field) {
  final id = _text(value, field);
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,120}$').hasMatch(id)) {
    _fail('$field harus ID stabil tanpa spasi');
  }
  return id;
}

List<String> _strings(Object? value, String field) =>
    _list(value, field).map((v) => _text(v, field)).toList();
bool _boolean(Object? value, String field) {
  if (value is! bool) _fail('$field harus boolean');
  return value;
}

int? _integer(
  Object? value,
  String field, {
  int minimum = 0,
  int maximum = 1000000000,
}) {
  if (value == null) return null;
  if (value is! int || value < minimum || value > maximum) {
    _fail('$field harus integer $minimum–$maximum atau null');
  }
  return value;
}

DateTime? _date(Object? value, String field, {bool optional = false}) {
  if (value == null && optional) return null;
  final text = _text(value, field);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !text.endsWith('Z')) {
    _fail('$field harus timestamp ISO-8601 UTC berakhiran Z');
  }
  // DateTime.parse normalizes invalid calendar dates; reject them explicitly.
  if (text.length < 10 ||
      parsed.toIso8601String().substring(0, 10) != text.substring(0, 10)) {
    _fail('$field tanggal tidak valid');
  }
  return parsed;
}

void _unique(Iterable<String> ids, String field) {
  if (ids.toSet().length != ids.length) _fail('$field duplikat');
}
