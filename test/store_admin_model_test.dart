// Tes model mode "Toko Saya" (bentuk JSON sama dengan migrasi 20261126000100_store_app_api.sql).
import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/models/app_notification.dart';
import 'package:myanimerent/models/rental_request.dart';
import 'package:myanimerent/models/store_admin.dart';
import 'package:myanimerent/providers/store_admin_provider.dart';

String img(String path) => 'https://cdn.uji/$path';

void main() {
  test('owner otomatis punya semua izin, staf sesuai daftar', () {
    final owner = MyStore.fromJson({
      'store_id': 's1',
      'slug': 'toko-a',
      'name': 'Toko A',
      'status': 'published',
      'role': 'owner',
      'permissions': ['catalog', 'calendar', 'orders', 'leads'],
      'calendar_enabled': true,
      'open_requests': 2,
    });
    expect(owner.canOrders && owner.canCalendar, isTrue);
    expect(owner.openRequests, 2);

    final staff = MyStore.fromJson({
      'store_id': 's1',
      'name': 'Toko A',
      'role': 'staff',
      'permissions': ['calendar'],
      'calendar_enabled': false,
    });
    expect(staff.canCalendar, isTrue);
    expect(staff.canOrders, isFalse);
    expect(staff.calendarEnabled, isFalse);
  });

  test('detail permintaan toko: penyewa, estimasi, dan set kosong', () {
    final r = StoreRequest.fromJson({
      'id': 'r1',
      'request_code': 'MAR-ABC234',
      'status': 'submitted',
      'revision': 3,
      'product_id': 'p1',
      'product_title': '2B • Pakaian hitam',
      'size': 'M',
      'rent_start': '2026-12-20',
      'rent_end_exclusive': '2026-12-23',
      'block_start': '2026-12-20',
      'block_end_exclusive': '2026-12-24',
      'calendar_enabled': true,
      'cover_path': 'demo/2b.png',
      'quote': {'total_rent_idr': 120000, 'deposit_idr': 50000},
      'renter': {'display_name': 'Penyewa Demo', 'phone': null},
      'units': [
        {'unit_id': 'u1', 'size': 'M', 'internal_code': 'DEMO-2B-M', 'free': true},
        {'unit_id': 'u2', 'size': 'M', 'free': false},
      ],
      'created_at': '2026-11-26T08:00:00Z',
    }, img);
    expect(r.status, RequestStatus.submitted);
    expect(r.needsAnswer, isTrue);
    expect(r.days, 3);
    expect(r.rentEnd, DateTime(2026, 12, 22));
    expect(r.renterName, 'Penyewa Demo');
    expect(r.renterPhone, isNull);
    expect(r.estimateRentIdr, 120000);
    expect(r.coverUrl, 'https://cdn.uji/demo/2b.png');
    expect(r.freeUnits.map((u) => u.unitId), ['u1']);
    expect(r.units.first.label, 'Ukuran M · DEMO-2B-M');
  });

  test('filter kotak permintaan', () {
    StoreRequest req(String status) => StoreRequest.fromJson({
          'id': status,
          'status': status,
          'rent_start': '2026-12-01',
          'rent_end_exclusive': '2026-12-02',
        }, img);
    expect(RequestFilter.needsAnswer.matches(req('responded')), isTrue);
    expect(RequestFilter.needsAnswer.matches(req('accepted')), isFalse);
    expect(RequestFilter.confirmed.matches(req('accepted')), isTrue);
    expect(RequestFilter.closed.matches(req('expired')), isTrue);
    expect(RequestFilter.closed.matches(req('submitted')), isFalse);
    expect(RequestStatus.submitted.storeLabel, 'Baru');
  });

  test('kalender toko: alokasi per set dan tanggal yang tertutup', () {
    final cal = StoreCalendar.fromJson({
      'calendar_enabled': true,
      'can_manage_orders': true,
      'can_manage_calendar': true,
      'from': '2026-12-01',
      'to_exclusive': '2027-01-01',
      'units': [
        {'unit_id': 'u1', 'product_id': 'p1', 'product_title': '2B', 'size': 'M', 'lifecycle': 'active'},
      ],
      'allocations': [
        {
          'allocation_id': 'a1',
          'unit_id': 'u1',
          'kind': 'offline_order',
          'start': '2026-12-05',
          'end_exclusive': '2026-12-09',
          'order': {
            'id': 'o1',
            'version': 1,
            'source': 'instagram',
            'rental_status': 'confirmed',
            'rent_start': '2026-12-05',
            'rent_end_exclusive': '2026-12-08',
            'customer_name': 'Pelanggan IG',
          },
        },
        {'allocation_id': 'a2', 'unit_id': 'u1', 'kind': 'laundry', 'start': '2026-12-10', 'end_exclusive': '2026-12-11'},
      ],
    }, img);
    final a = cal.forUnit('u1');
    expect(a, hasLength(2));
    expect(a.first.kindLabel, 'Sewa Instagram');
    expect(a.first.covers(DateTime(2026, 12, 8)), isTrue, reason: 'hari laundry setelah sewa ikut terkunci');
    expect(a.first.covers(DateTime(2026, 12, 9)), isFalse);
    expect(a.first.order!.rentEnd, DateTime(2026, 12, 7));
    expect(a.first.order!.canCancel, isTrue);
    expect(a.last.isBlock, isTrue);
    expect(cal.units.single.sizeLabel, 'Ukuran M');
  });

  test('notifikasi membuka layar sesuai penerima', () {
    expect(AppNotification.routeFor({'request_id': 'r1', 'audience': 'store'}), '/store/requests/r1');
    expect(AppNotification.routeFor({'request_id': 'r1', 'audience': 'renter'}), '/requests/r1');
    expect(AppNotification.routeFor({'request_id': 'r1'}), '/requests/r1');
    expect(AppNotification.routeFor({'kind': 'lain'}), isNull);
  });
}
