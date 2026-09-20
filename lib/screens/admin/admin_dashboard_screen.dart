import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/costume.dart';
import '../../models/rental_transaction.dart';
import '../../models/store.dart';
import '../../services/database_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();

  List<Costume> _costumes = [];
  List<Store> _stores = [];
  List<RentalTransaction> _rentals = [];

  bool _isLoading = true;
  String _costumeSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final costumesFuture = _databaseService.getCostumes();
      final storesFuture = _databaseService.getStores();
      final rentalsFuture = _databaseService.getAllRentals();

      final results = await Future.wait([
        costumesFuture,
        storesFuture,
        rentalsFuture,
      ]);

      if (mounted) {
        setState(() {
          _costumes = results[0] as List<Costume>;
          _stores = results[1] as List<Store>;
          _rentals = results[2] as List<RentalTransaction>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getStoreName(String storeId) {
    try {
      return _stores.firstWhere((s) => s.id == storeId).name;
    } catch (_) {
      return 'Toko Tidak Dikenal';
    }
  }

  String _getCostumeName(String costumeId) {
    try {
      return _costumes.firstWhere((c) => c.id == costumeId).name;
    } catch (_) {
      return 'Kostum ($costumeId)';
    }
  }

  Future<void> _deleteCostume(Costume costume) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kostum?'),
        content: Text('Apakah Anda yakin ingin menghapus kostum "${costume.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.deleteCostume(costume.id);
      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kostum "${costume.name}" telah dihapus.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _deleteStore(Store store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Toko?'),
        content: Text('Apakah Anda yakin ingin menghapus toko "${store.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.deleteStore(store.id);
      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Toko "${store.name}" telah dihapus.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _changeRentalStatus(RentalTransaction rental) async {
    final newStatus = await showModalBottomSheet<RentalStatus>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Ubah Status Sewa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              ...RentalStatus.values.map((status) {
                final isSelected = rental.status == status;
                return ListTile(
                  leading: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                  ),
                  title: Text(
                    _getStatusLabel(status),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () => Navigator.pop(ctx, status),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (newStatus != null && newStatus != rental.status) {
      await _databaseService.updateRentalStatus(rental.id, newStatus);
      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status pesanan diubah ke ${_getStatusLabel(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _getStatusLabel(RentalStatus status) {
    switch (status) {
      case RentalStatus.pending:
        return 'Menunggu Konfirmasi (Pending)';
      case RentalStatus.active:
        return 'Sedang Disewa (Active)';
      case RentalStatus.completed:
        return 'Selesai (Completed)';
      case RentalStatus.cancelled:
        return 'Dibatalkan (Cancelled)';
    }
  }

  IconData _getStatusIcon(RentalStatus status) {
    switch (status) {
      case RentalStatus.pending:
        return Icons.hourglass_top_rounded;
      case RentalStatus.active:
        return Icons.play_arrow_rounded;
      case RentalStatus.completed:
        return Icons.check_circle_rounded;
      case RentalStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  Color _getStatusColor(RentalStatus status) {
    switch (status) {
      case RentalStatus.pending:
        return Colors.orange;
      case RentalStatus.active:
        return Colors.blue;
      case RentalStatus.completed:
        return Colors.green;
      case RentalStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
            onPressed: _isLoading ? null : _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: [
            Tab(
              icon: const Icon(Icons.checkroom),
              text: 'Kostum (${_costumes.length})',
            ),
            Tab(
              icon: const Icon(Icons.store),
              text: 'Toko (${_stores.length})',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long),
              text: 'Pesanan (${_rentals.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCostumesTab(theme),
                _buildStoresTab(theme),
                _buildRentalsTab(theme),
              ],
            ),
      floatingActionButton: _tabController.index < 2
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (_tabController.index == 0) {
                  final result = await context.push('/admin/costume/add');
                  if (result == true) _loadAllData();
                } else if (_tabController.index == 1) {
                  final result = await context.push('/admin/store/add');
                  if (result == true) _loadAllData();
                }
              },
              icon: const Icon(Icons.add),
              label: Text(_tabController.index == 0 ? 'Tambah Kostum' : 'Tambah Toko'),
            )
          : null,
    );
  }

  // ─── COSTUMES TAB ──────────────────────────────────────────
  Widget _buildCostumesTab(ThemeData theme) {
    final filtered = _costumes.where((c) {
      final q = _costumeSearchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.anime.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
        children: [
          // Search Box
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari kostum atau anime...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _costumeSearchQuery = val),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    _costumeSearchQuery.isEmpty ? 'Belum ada kostum.' : 'Kostum tidak ditemukan.',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tekan tombol "+ Tambah Kostum" di bawah untuk mendaftarkan kostum baru.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((costume) {
              final storeName = _getStoreName(costume.storeId);
              final hasImage = costume.imageUrls.isNotEmpty;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: hasImage
                            ? Image.network(
                                costume.imageUrls.first,
                                width: 80,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 80,
                                  height: 90,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image),
                                ),
                              )
                            : Container(
                                width: 80,
                                height: 90,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.checkroom),
                              ),
                      ),
                      const SizedBox(width: 12),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    costume.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: costume.isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: costume.isAvailable ? Colors.green : Colors.red,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    costume.isAvailable ? 'Tersedia' : 'Nonaktif',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: costume.isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              costume.anime,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '🏪 $storeName',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rp ${costume.price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}/hari',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final res = await context.push('/admin/costume/edit/${costume.id}');
                                        if (res == true) _loadAllData();
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Hapus',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteCostume(costume),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── STORES TAB ────────────────────────────────────────────
  Widget _buildStoresTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
        children: [
          if (_stores.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.storefront_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('Belum ada toko terdaftar.', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Tekan tombol "+ Tambah Toko" di bawah untuk mendaftarkan toko rental pertama.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ..._stores.map((store) {
              final costumeCount = _costumes.where((c) => c.storeId == store.id).length;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Store Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: store.imageUrl.isNotEmpty
                            ? Image.network(
                                store.imageUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.store),
                                ),
                              )
                            : Container(
                                width: 64,
                                height: 64,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.store),
                              ),
                      ),
                      const SizedBox(width: 14),

                      // Store Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  store.city,
                                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$costumeCount Kostum Tersedia',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Edit',
                            onPressed: () async {
                              final res = await context.push('/admin/store/edit/${store.id}');
                              if (res == true) _loadAllData();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            tooltip: 'Hapus',
                            onPressed: () => _deleteStore(store),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── RENTALS TAB ───────────────────────────────────────────
  Widget _buildRentalsTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 20),
        children: [
          if (_rentals.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('Belum ada pesanan sewa.', style: theme.textTheme.titleMedium),
                ],
              ),
            )
          else
            ..._rentals.map((rental) {
              final costumeName = _getCostumeName(rental.costumeId);
              final statusColor = _getStatusColor(rental.status);
              final startDateStr =
                  "${rental.startDate.day.toString().padLeft(2, '0')}/${rental.startDate.month.toString().padLeft(2, '0')}/${rental.startDate.year}";
              final endDateStr =
                  "${rental.endDate.day.toString().padLeft(2, '0')}/${rental.endDate.month.toString().padLeft(2, '0')}/${rental.endDate.year}";

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ID: ${rental.id.length > 8 ? rental.id.substring(0, 8) : rental.id}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getStatusIcon(rental.status), size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  rental.status.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        costumeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Penyewa UID: ${rental.userId}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '$startDateStr - $endDateStr',
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (rental.size != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Size ${rental.size}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total: Rp ${rental.totalPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text('Ubah Status'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _changeRentalStatus(rental),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
