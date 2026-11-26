import '../services/supabase_service.dart' show dateKey, parseDate;

/// Rentang tanggal [start, endExclusive).
class DateSpan {
  const DateSpan(this.start, this.endExclusive);
  final DateTime start;
  final DateTime endExclusive;
}

/// Jadwal satu ukuran dari `get_product_availability`.
class VariantAvailability {
  VariantAvailability({
    required this.variantId,
    required this.size,
    required this.units,
    required this.busy,
    this.status,
  });

  final String variantId;
  final String size;
  final int units;
  final List<DateSpan> busy;

  /// Hanya terisi bila tanggal dicek: booked / no_schedule / not_rentable.
  final String? status;

  bool get rentable => units > 0;

  /// Tanggal terisi sebagai YYYY-MM-DD (format yang dipakai kalender).
  List<String> get bookedDateKeys => [
        for (final span in busy)
          for (var d = span.start; d.isBefore(span.endExclusive); d = d.add(const Duration(days: 1)))
            dateKey(d),
      ];
}

class ProductAvailability {
  ProductAvailability({
    required this.calendarActive,
    required this.variants,
    this.calendarUpdatedAt,
    this.bufferBeforeDays = 0,
    this.bufferAfterDays = 1,
  });

  /// false = toko belum memakai kalender: tanggal kosong BUKAN berarti tersedia.
  final bool calendarActive;
  final DateTime? calendarUpdatedAt;
  final int bufferBeforeDays;
  final int bufferAfterDays;
  final List<VariantAvailability> variants;

  VariantAvailability? forVariant(String? id) {
    for (final v in variants) {
      if (v.variantId == id) return v;
    }
    return null;
  }

  factory ProductAvailability.fromJson(Map<String, dynamic> m) => ProductAvailability(
        calendarActive: m['calendar_active'] == true,
        calendarUpdatedAt: parseDate(m['calendar_updated_at']),
        bufferBeforeDays: (m['buffer_before_days'] as num?)?.toInt() ?? 0,
        bufferAfterDays: (m['buffer_after_days'] as num?)?.toInt() ?? 1,
        variants: ((m['variants'] as List?) ?? const []).whereType<Map>().map((raw) {
          final v = Map<String, dynamic>.from(raw);
          return VariantAvailability(
            variantId: v['variant_id'].toString(),
            size: (v['size'] ?? '').toString(),
            units: (v['units'] as num?)?.toInt() ?? 0,
            status: v['status']?.toString(),
            busy: ((v['busy'] as List?) ?? const []).whereType<Map>().map((b) {
              final start = parseDate(b['start']) ?? DateTime.now();
              return DateSpan(start, parseDate(b['end_exclusive']) ?? start);
            }).toList(),
          );
        }).toList(),
      );
}
