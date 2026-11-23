import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'catalog.dart';

String rupiah(int value) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
).format(value);
String priceLabel(CatalogPrice price) {
  if (price.amountIdr == null) return 'Harga belum diinformasikan';
  final duration = price.durationDays == null
      ? 'durasi belum diinformasikan'
      : 'paket ${price.durationDays} hari';
  return '${rupiah(price.amountIdr!)} / $duration';
}

String dateLabel(DateTime value) => DateFormat('dd/MM/yyyy').format(value);
String verifiedLabel(DateTime? value) => value == null
    ? 'Belum diinformasikan'
    : '${DateFormat('dd/MM/yyyy HH:mm').format(value.toUtc())} UTC';

class ContactDraft {
  const ContactDraft({
    required this.product,
    required this.store,
    required this.illustrative,
    this.size,
    this.startDate,
    this.endDate,
  });
  final CatalogProduct product;
  final CatalogStore store;
  final bool illustrative;
  final String? size;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get canContact =>
      !illustrative && store.contactConsent && store.whatsapp != null;
  String get message => [
    if (illustrative) '[SIMULASI — data ilustratif, bukan permintaan rental]',
    'Halo ${store.name}, saya ingin menanyakan kostum ${product.name} (${product.character}, ${product.series}).',
    'Ukuran: ${size ?? (product.sizes.isEmpty ? 'belum diinformasikan' : 'belum dipilih')}.',
    'Tanggal: ${startDate == null ? 'belum dipilih' : '${dateLabel(startDate!)} – ${dateLabel(endDate ?? startDate!)}'}.',
    'Harga katalog${illustrative ? ' (simulasi)' : ''}: ${priceLabel(product.price)}.',
    'Apakah tersedia? Mohon konfirmasi kelengkapan, harga, deposit, dan ketentuan sewa. Ini pertanyaan, belum booking.',
  ].join('\n');

  Uri? get whatsappUri => canContact
      ? Uri.https('wa.me', '/${store.whatsapp!.substring(1)}', {
          'text': message,
        })
      : null;
}

abstract interface class ContactGateway {
  Future<bool> open(Uri uri);
}

class WhatsAppGateway implements ContactGateway {
  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
