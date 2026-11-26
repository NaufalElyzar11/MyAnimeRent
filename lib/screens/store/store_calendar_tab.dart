import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/store_admin.dart';
import '../../services/store_admin_service.dart';
import '../../services/supabase_service.dart';

/// Warna per jenis jadwal (dipakai tab kalender dan layar per set).
Color allocationColor(String kind, ColorScheme scheme) => switch (kind) {
      'order' => scheme.primary,
      'offline_order' => Colors.deepPurple.shade400,
      'laundry' => Colors.amber.shade700,
      'maintenance' => Colors.blueGrey.shade400,
      _ => Colors.grey,
    };

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);
int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;
DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String rangeLabel(DateTime first, DateTime last) {
  final d = DateFormat('d MMM', 'id_ID');
  return first == last ? d.format(first) : '${d.format(first)} – ${d.format(last)}';
}

class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(String kind, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: allocationColor(kind, scheme), borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item('order', 'Sewa via app'),
        item('offline_order', 'Sewa WA/IG/langsung'),
        item('laundry', 'Laundry'),
        item('maintenance', 'Perbaikan'),
      ],
    );
  }
}

/// Tab kalender toko: semua set fisik dalam satu bulan.
class StoreCalendarTab extends StatefulWidget {
  const StoreCalendarTab({super.key, required this.store});
  final MyStore store;

  @override
  State<StoreCalendarTab> createState() => _StoreCalendarTabState();
}

class _StoreCalendarTabState extends State<StoreCalendarTab> with AutomaticKeepAliveClientMixin {
  final _service = StoreAdminService();
  DateTime _month = monthStart(DateTime.now());
  StoreCalendar? _data;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getCalendar(widget.store.id, from: _month, days: daysInMonth(_month));
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
    _load();
  }

  Future<void> _openUnit(CalendarUnit unit) async {
    final month = DateFormat('yyyy-MM').format(_month);
    await context.push('/store/units/${unit.unitId}?store=${widget.store.id}&month=$month');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final data = _data;
    final units = data?.units ?? const <CalendarUnit>[];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Bulan sebelumnya'),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right), tooltip: 'Bulan berikutnya'),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: CalendarLegend()),
          const SizedBox(height: 8),
          if (data != null && !data.calendarEnabled)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Kalender belum aktif untuk paket toko ini. Penyewa melihat "Tanyakan ketersediaan ke toko" '
                  'dan jadwal belum bisa dicatat.',
                ),
              ),
            ),
          if (_loading && data == null)
            const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))
          else if (_error != null && data == null)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                ],
              ),
            )
          else if (units.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Text(
                'Belum ada set fisik. Setiap ukuran yang ditambahkan di katalog otomatis mendapat 1 set.',
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            for (final unit in units)
              _UnitCard(
                unit: unit,
                month: _month,
                allocations: data!.forUnit(unit.unitId),
                onTap: () => _openUnit(unit),
              ),
          ],
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit, required this.month, required this.allocations, required this.onTap});
  final CalendarUnit unit;
  final DateTime month;
  final List<Allocation> allocations;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcoming = allocations.where((a) => !a.end.isBefore(today())).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: unit.coverUrl.isEmpty
                          ? Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.checkroom, size: 20))
                          : CachedNetworkImage(imageUrl: unit.coverUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unit.productTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          [
                            unit.sizeLabel,
                            if (unit.code != null) unit.code!,
                            if (!unit.isActive) 'sedang tidak dipakai',
                            if (unit.productStatus == 'draft') 'listing belum terbit',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              MonthStrip(month: month, allocations: allocations),
              const SizedBox(height: 6),
              if (allocations.isEmpty)
                Text('Belum ada jadwal bulan ini.', style: theme.textTheme.bodySmall)
              else
                for (final a in (upcoming.isEmpty ? allocations : upcoming).take(3))
                  Text(
                    '${rangeLabel(a.start, a.end)} · ${a.kindLabel}'
                    '${a.order?.customerName == null ? '' : ' · ${a.order!.customerName}'}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris kotak kecil per hari dalam sebulan, diwarnai sesuai jadwal.
class MonthStrip extends StatelessWidget {
  const MonthStrip({super.key, required this.month, required this.allocations});
  final DateTime month;
  final List<Allocation> allocations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = daysInMonth(month);
    final now = today();
    return Row(
      children: [
        for (var i = 1; i <= n; i++)
          Expanded(
            child: Builder(builder: (context) {
              final day = DateTime(month.year, month.month, i);
              Allocation? hit;
              for (final a in allocations) {
                if (a.covers(day)) {
                  hit = a;
                  break;
                }
              }
              return Container(
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                decoration: BoxDecoration(
                  color: hit == null ? scheme.surfaceContainerHighest : allocationColor(hit.kind, scheme),
                  borderRadius: BorderRadius.circular(2),
                  border: day == now ? Border.all(color: scheme.onSurface, width: 1.2) : null,
                ),
              );
            }),
          ),
      ],
    );
  }
}
