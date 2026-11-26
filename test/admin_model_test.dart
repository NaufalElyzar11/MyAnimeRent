// Tes model data dari Supabase (nama file lama dipertahankan).
import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/models/availability.dart';
import 'package:myanimerent/models/costume.dart';
import 'package:myanimerent/models/rental_request.dart';
import 'package:myanimerent/models/store.dart';
import 'package:myanimerent/models/user.dart';
import 'package:myanimerent/services/auth_service.dart';
import 'package:myanimerent/services/supabase_service.dart';

String img(String path) => 'https://cdn.uji/$path';

void main() {
  group('Model Supabase', () {
    test('kartu search_products menjadi Costume', () {
      final c = Costume.fromCard({
        'product_id': 'p1',
        'product_slug': 'demo-2b-a',
        'store_slug': 'toko-a',
        'store_name': 'Toko A',
        'city_name': 'Banjarmasin',
        'title': '2B • Pakaian hitam',
        'character_name': '2B',
        'franchise_name': 'NieR:Automata',
        'sizes': ['S', 'M'],
        'price_idr': 120000,
        'duration_days': 3,
        'deposit_idr': 50000,
        'cover_path': 'demo/2b.png',
      }, img);
      expect(c.id, 'p1');
      expect(c.storeId, 'toko-a');
      expect(c.anime, 'NieR:Automata');
      expect(c.imageUrls, ['https://cdn.uji/demo/2b.png']);
      expect(c.sizes, ['S', 'M']);
      expect(c.hasPrice, isTrue);
      expect(c.rating, 0);
    });

    test('detail memuat varian, foto berurutan, dan estimasi harga sama dengan server', () {
      final c = Costume.fromDetail({
        'id': 'p1',
        'slug': 'demo',
        'title': 'Uji',
        'character': 'Karakter',
        'franchise': null,
        'description': 'Deskripsi',
        'package_contents': ['Baju', 'Wig'],
        'variants': [
          {'id': 'v1', 'size': 'M', 'measurements_cm': {'chest': 92}},
        ],
        'images': [
          {'path': 'a.jpg'},
          {'path': 'b.jpg'},
        ],
        'price': {'amount_idr': 100000, 'duration_days': 3, 'extra_day_idr': null, 'deposit_idr': 0},
        'store': {'slug': 'toko-a', 'name': 'Toko A', 'city': 'Banjarmasin', 'whatsapp': null},
      }, img);
      expect(c.anime, 'Lainnya');
      expect(c.variants.single.measurementsCm['chest'], 92);
      expect(c.imageUrls.last, 'https://cdn.uji/b.jpg');
      expect(c.estimateRent(3), 100000);
      // 2 hari tambahan × ceil(100000 / 3) = 2 × 33334
      expect(c.estimateRent(5), 166668);
    });

    test('toko dari list_public_stores', () {
      final s = Store.fromList({'slug': 'toko-a', 'name': 'Toko A', 'city': 'Banjarmasin', 'product_count': 2}, img);
      expect(s.id, 'toko-a');
      expect(s.productCount, 2);
      expect(s.imageUrl, '');
    });

    test('permintaan: tanggal akhir inklusif dan status', () {
      final r = RentalRequest.fromJson({
        'id': 'r1',
        'request_code': 'MAR-ABCDEF',
        'status': 'responded',
        'revision': 2,
        'product_id': 'p1',
        'product_title': 'Uji',
        'store_slug': 'toko-a',
        'store_name': 'Toko A',
        'rent_start': '2026-12-10',
        'rent_end_exclusive': '2026-12-13',
        'created_at': '2026-11-24T03:00:00Z',
        'order': {'total_rent_idr': 120000, 'deposit_idr': 50000},
      }, img);
      expect(r.days, 3);
      expect(r.rentEnd, DateTime(2026, 12, 12));
      expect(r.status.isOpen, isTrue);
      expect(r.status.label, 'Dibalas toko');
      expect(r.totalRentIdr, 120000);
    });

    test('ketersediaan menjadi daftar tanggal terisi untuk kalender', () {
      final a = ProductAvailability.fromJson({
        'calendar_active': true,
        'variants': [
          {
            'variant_id': 'v1',
            'size': 'M',
            'units': 1,
            'busy': [
              {'start': '2026-12-01', 'end_exclusive': '2026-12-04'},
            ],
            'status': 'booked',
          },
        ],
      });
      expect(a.forVariant('v1')!.bookedDateKeys, ['2026-12-01', '2026-12-02', '2026-12-03']);
      expect(a.forVariant('v1')!.status, 'booked');
      expect(a.forVariant('tidak-ada'), isNull);
    });

    test('nomor HP dinormalisasi ke format +62', () {
      expect(AuthService.normalizePhone('0812-3456-7890'), '+6281234567890');
      expect(AuthService.normalizePhone('62 812 3456 7890'), '+6281234567890');
      expect(AuthService.normalizePhone(''), isNull);
      expect(() => AuthService.normalizePhone('12'), throwsA(isA<ApiException>()));
    });

    test('inisial pengguna dan operation id', () {
      expect(AppUser(id: 'u', email: 'a@b.c', name: 'Rina Putri').initials, 'RP');
      final id = newOperationId();
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), isTrue);
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
