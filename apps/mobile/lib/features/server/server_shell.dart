import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:perpus_ui_kit/perpus_ui_kit.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/date_formatters.dart';
import '../../app/form_validators.dart';
import 'loan_predicates.dart';

String? _bookCoverUrl(Map<String, dynamic>? book) {
  final path = book?['cover_path'] as String?;
  if (path == null || path.isEmpty) return null;
  return Supabase.instance.client.storage
      .from('book-covers')
      .getPublicUrl(path);
}

String _copyCategory(Map<String, dynamic> copy) =>
    ((copy['books'] as Map<String, dynamic>?)?['category'] as String? ?? '')
        .trim();

/// Server-backed screens are selected from the role loaded by SessionRouter.
class ServerShell extends StatefulWidget {
  const ServerShell({
    super.key,
    required this.isAdmin,
    required this.user,
    this.displayName,
  });
  final bool isAdmin;
  final User user;
  final String? displayName;

  @override
  State<ServerShell> createState() => _ServerShellState();
}

class _ServerShellState extends State<ServerShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final memberName = widget.displayName?.trim().isNotEmpty == true
        ? widget.displayName!.trim()
        : (widget.user.userMetadata?['full_name'] as String?)?.trim();
    final accountLabel = widget.isAdmin
        ? 'PENGURUS'
        : (memberName?.isNotEmpty == true
              ? memberName!
              : widget.user.email?.split('@').first ?? 'Anggota');
    final destinations = widget.isAdmin
        ? const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              label: 'Buku',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_rounded),
              label: 'Aktivitas',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              label: 'Anggota',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              label: 'Katalog',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Akun',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              label: 'Pinjaman',
            ),
          ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'perpus.',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 27,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Tooltip(
                message: widget.isAdmin
                    ? 'Pengurus | Keluar otomatis setelah 24 jam tanpa aktivitas.'
                    : '$accountLabel | Keluar otomatis setelah 24 jam tanpa aktivitas.',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: PerpusColors.accent.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          accountLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: widget.isAdmin
            ? [
                PopupMenuButton<String>(
                  tooltip: 'Menu pengurus',
                  onSelected: (value) {
                    if (value == 'settings') _openAdminTools(context);
                    if (value == 'logout') {
                      Supabase.instance.client.auth.signOut();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.tune),
                        title: Text('Pengaturan & audit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Keluar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Keluar',
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: switch ((widget.isAdmin, _tab)) {
              (true, 0) => AdminDashboardPage(
                openBooks: () => setState(() => _tab = 1),
                openTransactions: () => setState(() => _tab = 2),
                openMembers: () => setState(() => _tab = 3),
                openSettings: () => _openAdminTools(context),
              ),
              (true, 1) => const AdminBooksPage(),
              (true, 2) => const AdminCirculationPage(),
              (true, _) => const MembersPage(),
              (false, 0) => const CatalogPage(admin: false),
              (false, 1) => MemberQrScanPage(
                onLoanRequestSubmitted: () => setState(() => _tab = 3),
              ),
              (false, 2) => AccountHome(user: widget.user),
              (false, _) => MemberLoansPage(),
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: destinations,
      ),
    );
  }

  void _openAdminTools(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Pengaturan & audit')),
          body: const SafeArea(child: AdminToolsPage()),
        ),
      ),
    );
  }
}

class AdminBooksPage extends StatefulWidget {
  const AdminBooksPage({super.key});

  @override
  State<AdminBooksPage> createState() => _AdminBooksPageState();
}

class _AdminBooksPageState extends State<AdminBooksPage> {
  int _section = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Buku',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.auto_stories_outlined),
                  label: Text('Katalog'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.qr_code_2),
                  label: Text('Eksemplar'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selected) =>
                  setState(() => _section = selected.first),
            ),
          ],
        ),
      ),
      Expanded(
        child: _section == 0
            ? const CatalogPage(admin: true)
            : const InventoryPage(),
      ),
    ],
  );
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.openBooks,
    required this.openTransactions,
    required this.openMembers,
    required this.openSettings,
  });

  final VoidCallback openBooks;
  final VoidCallback openTransactions;
  final VoidCallback openMembers;
  final VoidCallback openSettings;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<_AdminDashboardData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<List<Map<String, dynamic>>?> _optionalRows(
    Future<dynamic> Function() request,
  ) async {
    try {
      return List<Map<String, dynamic>>.from(await request());
    } catch (_) {
      return null;
    }
  }

  Future<_AdminDashboardData> _load() async {
    final client = Supabase.instance.client;
    final results = await Future.wait([
      _optionalRows(
        () async => await client
            .from('book_copies')
            .select('status')
            .isFilter('archived_at', null),
      ),
      _optionalRows(
        () async => await client
            .from('loans')
            .select('id,loan_items(due_at,returned_at,resolved_at)'),
      ),
      _optionalRows(
        () async => await client
            .from('loan_requests')
            .select('id')
            .eq('status', 'pending'),
      ),
      _optionalRows(
        () async => await client
            .from('profiles')
            .select('id')
            .eq('role', 'member')
            .eq('status', 'pending'),
      ),
    ]);
    final copies = results[0];
    final loans = results[1];
    final requests = results[2];
    final members = results[3];
    var activeLoans = 0;
    var overdue = 0;
    if (loans != null) {
      for (final loan in loans) {
        final items = List<Map<String, dynamic>>.from(
          loan['loan_items'] as List? ?? const [],
        );
        final openItems = items.where(isLoanItemOpen);
        if (openItems.isEmpty) continue;
        activeLoans++;
        if (openItems.any(isLoanItemOverdue)) {
          overdue++;
        }
      }
    }
    return _AdminDashboardData(
      availableCopies: copies
          ?.where((copy) => copy['status'] == 'available')
          .length,
      activeLoans: loans == null ? null : activeLoans,
      overdueLoans: loans == null ? null : overdue,
      pendingRequests: requests?.length,
      pendingMembers: members?.length,
    );
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_AdminDashboardData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(error: snapshot.error, retry: _refresh);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final transactionDataMissing =
          data.activeLoans == null || data.pendingRequests == null;
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            Text(
              'Ruang pengurus',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Perpustakaan,\nlebih tertata.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 18),
            PaperCard(
              dark: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.insights_rounded, color: PerpusColors.accent),
                      SizedBox(width: 8),
                      Text(
                        'HARI INI DI PERPUS',
                        style: TextStyle(
                          color: PerpusColors.accent,
                          letterSpacing: 1.2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${data.pendingRequests ?? '—'} pengajuan menunggu',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: PerpusColors.surface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Periksa pengajuan dan pastikan buku siap diserahkan.',
                    style: TextStyle(color: PerpusColors.surface, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: PerpusColors.surface,
                      foregroundColor: PerpusColors.primary,
                    ),
                    onPressed: widget.openTransactions,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Periksa aktivitas'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _AdminMetricCard(
                    value: _metric(data.availableCopies),
                    label: 'Buku tersedia',
                    icon: Icons.menu_book_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdminMetricCard(
                    value: _metric(data.activeLoans),
                    label: 'Pinjaman aktif',
                    icon: Icons.swap_horiz_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AdminMetricCard(
                    value: _metric(data.overdueLoans),
                    label: 'Terlambat',
                    icon: Icons.schedule_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdminMetricCard(
                    value: _metric(data.pendingMembers),
                    label: 'Aktivasi anggota',
                    icon: Icons.person_add_alt_1_outlined,
                  ),
                ),
              ],
            ),
            if (transactionDataMissing) ...[
              const SizedBox(height: 12),
              const PaperCard(
                child: Text(
                  'Ringkasan aktivitas belum tersedia. Pastikan fitur peminjaman sudah siap di server.',
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Akses cepat',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.openBooks,
                  icon: const Icon(Icons.add),
                  label: const Text('Buku & stok'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.openMembers,
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Anggota'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.openSettings,
                  icon: const Icon(Icons.tune),
                  label: const Text('Pengaturan'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Buku tercatat. Layanan lebih tertata.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PerpusColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );
}

String _metric(int? value) => value?.toString() ?? '—';

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: PerpusColors.primary),
        const SizedBox(height: 10),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

class _AdminDashboardData {
  const _AdminDashboardData({
    required this.availableCopies,
    required this.activeLoans,
    required this.overdueLoans,
    required this.pendingRequests,
    required this.pendingMembers,
  });

  final int? availableCopies;
  final int? activeLoans;
  final int? overdueLoans;
  final int? pendingRequests;
  final int? pendingMembers;
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.admin});
  final bool admin;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _search = TextEditingController();
  final Set<String> _busyStockBooks = {};
  String _query = '';
  late Future<List<Map<String, dynamic>>> _books;

  @override
  void initState() {
    super.initState();
    _books = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('books')
        .select(
          'id,title,author,category,isbn,description,cover_path,archived_at,book_copies(id,code,status,archived_at)',
        )
        .isFilter('archived_at', null)
        .order('title');
    return List<Map<String, dynamic>>.from(rows);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _books = next;
    });
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _books,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(error: snapshot.error, retry: _refresh);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _query.trim().toLowerCase();
          final books = snapshot.data!.where((book) {
            if (query.isEmpty) return true;
            return ['title', 'author', 'category', 'isbn'].any(
              (field) =>
                  (book[field] as String? ?? '').toLowerCase().contains(query),
            );
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Cari judul, penulis, kategori',
                        ),
                      ),
                    ),
                    if (widget.admin) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _addBook(context),
                        label: const Text('Buku'),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: books.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(child: Text('Belum ada buku yang cocok.')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: books.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _BookCard(
                            book: books[index],
                            admin: widget.admin,
                            busy: _busyStockBooks.contains(books[index]['id']),
                            changed: _refresh,
                            adjustStock: _adjustStock,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      );

  Future<void> _addBook(BuildContext context) async {
    final form = await showDialog<_BookFormValue>(
      context: context,
      builder: (_) => const _BookDialog(),
    );
    if (form == null || !context.mounted) return;
    late final Map<String, dynamic> book;
    try {
      final codes = await _generateCopyCodes(
        category: form.category,
        title: form.title,
        count: form.initialStock,
        customPrefix: form.customQrPrefix,
      );
      book = await Supabase.instance.client
          .from('books')
          .insert({
            'title': form.title,
            'author': form.author,
            'category': form.category,
            'description': form.description,
            if (form.isbn.isNotEmpty) 'isbn': form.isbn,
          })
          .select('id')
          .single();
      final coverPath = await _uploadBookCover(
        book['id'] as String,
        form.cover,
      );
      if (coverPath != null) {
        await Supabase.instance.client
            .from('books')
            .update({'cover_path': coverPath})
            .eq('id', book['id']);
      }
      if (codes.isNotEmpty) {
        await Supabase.instance.client.rpc(
          'add_book_copies',
          params: {'p_book_id': book['id'], 'p_codes': codes},
        );
      }
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
      return;
    }
    if (!context.mounted) return;
    _refresh();
    _snack(context, 'Buku ditambahkan dengan ${form.initialStock} eksemplar.');
  }

  Future<void> _adjustStock(
    BuildContext context,
    Map<String, dynamic> book,
    int change,
  ) async {
    final bookId = book['id'] as String;
    if (_busyStockBooks.contains(bookId)) return;
    if (change < 0) {
      final copies = List<Map<String, dynamic>>.from(
        book['book_copies'] as List? ?? const [],
      ).where((copy) => copy['archived_at'] == null).toList();
      final available = copies
          .where((copy) => copy['status'] == 'available')
          .toList();
      if (available.isEmpty) {
        _snack(context, 'Tidak ada eksemplar tersedia untuk dikurangi.');
        return;
      }
      final selected = available.last;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kurangi stok satu buku?'),
          content: Text(
            'Eksemplar ${selected['code']} akan diarsipkan. Riwayatnya tetap tersimpan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kurangi 1'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      setState(() => _busyStockBooks.add(bookId));
      try {
        await Supabase.instance.client.rpc(
          'archive_available_copy',
          params: {'p_copy_id': selected['id']},
        );
        if (!context.mounted) return;
        _refresh();
        _snack(context, 'Stok dikurangi 1. Eksemplar diarsipkan.');
      } catch (error) {
        if (context.mounted) _snack(context, _friendlyError(error));
      } finally {
        if (mounted) setState(() => _busyStockBooks.remove(bookId));
      }
      return;
    }

    setState(() => _busyStockBooks.add(bookId));
    try {
      final code = (await _generateCopyCodes(
        category: book['category'] as String? ?? '',
        title: book['title'] as String? ?? '',
        count: 1,
        minimumOrdinal:
            List<Map<String, dynamic>>.from(
              book['book_copies'] as List? ?? const [],
            ).length +
            1,
      )).single;
      await Supabase.instance.client.rpc(
        'add_book_copies',
        params: {
          'p_book_id': bookId,
          'p_codes': [code],
        },
      );
      if (!context.mounted) return;
      _refresh();
      _snack(context, 'Stok ditambah 1. QR $code berhasil dibuat.');
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyStockBooks.remove(bookId));
    }
  }
}

String _acronym(String value) => value
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .map((word) => word[0])
    .join();

String _copyCodePrefix({required String category, required String title}) {
  final normalizedCategory = category.trim().replaceFirst(
    RegExp(r'^buku\s+', caseSensitive: false),
    '',
  );
  final categoryCode = _acronym(normalizedCategory);
  final titleCode = _acronym(title);
  if (categoryCode.isEmpty || titleCode.isEmpty) {
    throw const FormatException(
      'Kategori dan judul diperlukan untuk membuat kode eksemplar.',
    );
  }
  return 'B$categoryCode-$titleCode';
}

Future<List<String>> _generateCopyCodes({
  required String category,
  required String title,
  required int count,
  int minimumOrdinal = 1,
  String? customPrefix,
}) async {
  if (count <= 0) return const [];
  final prefix = customPrefix?.trim().isNotEmpty == true
      ? customPrefix!.trim().toUpperCase()
      : _copyCodePrefix(category: category, title: title);
  if (prefix.length > 48 || !RegExp(r'^[A-Z0-9_-]+$').hasMatch(prefix)) {
    throw const FormatException(
      'Kode QR khusus hanya boleh berisi huruf, angka, tanda hubung, atau garis bawah (maksimal 48 karakter).',
    );
  }
  final rows = await Supabase.instance.client
      .from('book_copies')
      .select('code')
      .ilike('code', '$prefix-%');
  var next = minimumOrdinal;
  final pattern = RegExp(
    '^${RegExp.escape(prefix)}-(\\d+)\$',
    caseSensitive: false,
  );
  for (final row in rows) {
    final match = pattern.firstMatch(row['code'] as String? ?? '');
    final value = int.tryParse(match?.group(1) ?? '');
    if (value != null) next = math.max(next, value + 1);
  }
  return List.generate(
    count,
    (index) => '$prefix-${(next + index).toString().padLeft(2, '0')}',
  );
}

Future<String?> _uploadBookCover(String bookId, XFile? image) async {
  if (image == null) return null;
  final extension = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
  final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
  final path = '$bookId/${DateTime.now().microsecondsSinceEpoch}.$extension';
  await Supabase.instance.client.storage
      .from('book-covers')
      .uploadBinary(
        path,
        await image.readAsBytes(),
        fileOptions: FileOptions(contentType: contentType),
      );
  return path;
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.admin,
    required this.busy,
    required this.changed,
    required this.adjustStock,
  });
  final Map<String, dynamic> book;
  final bool admin;
  final bool busy;
  final VoidCallback changed;
  final Future<void> Function(
    BuildContext context,
    Map<String, dynamic> book,
    int change,
  )
  adjustStock;

  @override
  Widget build(BuildContext context) {
    final copies = List<Map<String, dynamic>>.from(
      book['book_copies'] as List? ?? const [],
    );
    final activeCopies = copies
        .where((copy) => copy['archived_at'] == null)
        .toList();
    final available = activeCopies
        .where((copy) => copy['status'] == 'available')
        .length;
    final title = book['title'] as String? ?? 'Tanpa judul';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PerpusBookCover(
                  bookId: book['id'] as String? ?? title,
                  code: copies.isNotEmpty
                      ? (copies.first['code'] as String? ?? 'BUKU')
                      : 'BUKU',
                  width: 52,
                  height: 72,
                  imageUrl: (book['cover_path'] as String?)?.isNotEmpty == true
                      ? Supabase.instance.client.storage
                            .from('book-covers')
                            .getPublicUrl(book['cover_path'] as String)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: admin ? () => _openActions(context) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            book['author'] as String? ??
                                'Penulis tidak diketahui',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _BookInfoChip(
                                icon: Icons.category_outlined,
                                label: book['category'] as String? ?? 'Umum',
                              ),
                              if ((book['isbn'] as String? ?? '').isNotEmpty)
                                _BookInfoChip(
                                  icon: Icons.tag,
                                  label: 'ISBN ${book['isbn']}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (admin)
                  IconButton(
                    tooltip: 'Kelola buku',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openActions(context),
                    icon: const Icon(Icons.more_vert),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$available tersedia',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${activeCopies.length} total eksemplar',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (admin) ...[
                  IconButton.outlined(
                    tooltip: available == 0
                        ? 'Tidak ada stok tersedia untuk dikurangi'
                        : 'Kurangi stok satu eksemplar',
                    onPressed: busy || available == 0
                        ? null
                        : () => adjustStock(context, book, -1),
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '$available',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Tambah stok satu eksemplar',
                    onPressed: busy
                        ? null
                        : () => adjustStock(context, book, 1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openActions(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _BookActions(book: book, changed: changed),
  );
}

class _BookInfoChip extends StatelessWidget {
  const _BookInfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

class _BookActions extends StatelessWidget {
  const _BookActions({required this.book, required this.changed});
  final Map<String, dynamic> book;
  final VoidCallback changed;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: const Icon(Icons.menu_book_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['title'] as String? ?? 'Buku',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${book['author'] ?? '—'} · ${book['category'] ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text('Tambah eksemplar dengan kode sendiri'),
            onTap: () async {
              final code = await showTextDialog(
                context,
                'Kode QR buku',
                'Contoh: BK-001',
              );
              if (code == null || code.trim().isEmpty || !context.mounted) {
                return;
              }
              try {
                await Supabase.instance.client.rpc(
                  'add_book_copies',
                  params: {
                    'p_book_id': book['id'],
                    'p_codes': [code.trim()],
                  },
                );
              } catch (error) {
                if (context.mounted) _snack(context, _friendlyError(error));
                return;
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              changed();
              _snack(context, 'QR buku ditambahkan.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Ubah data buku'),
            onTap: () async {
              final edited = await showDialog<_BookFormValue>(
                context: context,
                builder: (_) => _BookDialog(initial: book),
              );
              if (edited == null || !context.mounted) return;
              try {
                await Supabase.instance.client
                    .from('books')
                    .update({
                      'title': edited.title,
                      'author': edited.author,
                      'category': edited.category,
                      'isbn': edited.isbn.isEmpty ? null : edited.isbn,
                      'description': edited.description,
                    })
                    .eq('id', book['id']);
                final coverPath = await _uploadBookCover(
                  book['id'] as String,
                  edited.cover,
                );
                if (coverPath != null) {
                  await Supabase.instance.client
                      .from('books')
                      .update({'cover_path': coverPath})
                      .eq('id', book['id']);
                }
              } catch (error) {
                if (context.mounted) _snack(context, _friendlyError(error));
                return;
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              changed();
              _snack(context, 'Data buku diperbarui.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Hapus dari katalog'),
            subtitle: const Text(
              'Keluarkan buku dari katalog; riwayat tetap tersimpan',
            ),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Hapus buku dari katalog?'),
                  content: const Text(
                    'Buku dan eksemplarnya akan dikeluarkan dari katalog aktif. '
                    'Riwayat peminjaman tetap tersimpan. Selesaikan pinjaman '
                    'yang masih aktif sebelum menghapus buku ini.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Hapus dari katalog'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              try {
                await Supabase.instance.client.rpc(
                  'archive_book',
                  params: {'p_book_id': book['id']},
                );
              } catch (error) {
                if (context.mounted) _snack(context, _friendlyError(error));
                return;
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              changed();
              _snack(
                context,
                'Buku dihapus dari katalog. Riwayat tetap tersimpan.',
              );
            },
          ),
        ],
      ),
    ),
  );
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  static const _pageSize = 30;
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _copies;
  String _query = '';
  String _statusFilter = 'Semua';
  String _categoryFilter = 'Semua';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _copies = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('book_copies')
            .select('id,code,status,archived_at,books(title,category)')
            .order('code'),
      );
  void _refresh() {
    final next = _load();
    setState(() {
      _copies = next;
    });
  }

  Future<void> _printCategoryQrs(
    BuildContext context, {
    required String category,
    required List<Map<String, dynamic>> copies,
  }) async {
    if (copies.isEmpty) {
      _snack(context, 'Belum ada QR aktif pada kategori ini.');
      return;
    }
    final paper = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Ukuran kertas cetak QR'),
        children: [
          for (final size in const ['A4', 'F4'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, size),
              child: Text(size),
            ),
        ],
      ),
    );
    if (paper == null || !context.mounted) return;

    try {
      final pageFormat = paper == 'A4'
          ? PdfPageFormat.a4
          : PdfPageFormat(215 * PdfPageFormat.mm, 330 * PdfPageFormat.mm);
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          header: (_) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              'QR Buku · $category · ${copies.length} buku',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
          build: (_) => [
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final copy in copies) _qrPrintLabel(copy)],
            ),
          ],
        ),
      );
      final safeCategory = category.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
      await Printing.layoutPdf(
        name: 'qr-$safeCategory-$paper.pdf',
        onLayout: (_) => document.save(),
      );
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }

  pw.Widget _qrPrintLabel(Map<String, dynamic> copy) {
    final book = copy['books'] as Map<String, dynamic>?;
    final code = copy['code'] as String? ?? '';
    return pw.Container(
      width: 166,
      height: 170,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: .6),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            book?['title'] as String? ?? 'Buku',
            maxLines: 2,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: code,
            width: 92,
            height: 92,
          ),
          pw.Text(code, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _copies,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(error: snapshot.error, retry: _refresh);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final copies = snapshot.data!
          .where((copy) => copy['archived_at'] == null)
          .toList();
      final counts = <String, int>{};
      for (final copy in copies) {
        final status = copy['status'] as String? ?? 'unknown';
        counts[status] = (counts[status] ?? 0) + 1;
      }
      final query = _query.trim().toLowerCase();
      final categories =
          copies
              .map((copy) => _copyCategory(copy))
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final selectedCategory = categories.contains(_categoryFilter)
          ? _categoryFilter
          : 'Semua';
      final visibleCopies = copies.where((copy) {
        final status = copy['status'] as String? ?? 'unknown';
        final book = copy['books'] as Map<String, dynamic>?;
        final matchesStatus =
            _statusFilter == 'Semua' || _status(status) == _statusFilter;
        final matchesCategory =
            selectedCategory == 'Semua' ||
            _copyCategory(copy) == selectedCategory;
        final matchesQuery =
            query.isEmpty ||
            (copy['code'] as String? ?? '').toLowerCase().contains(query) ||
            (book?['title'] as String? ?? '').toLowerCase().contains(query);
        return matchesStatus && matchesCategory && matchesQuery;
      }).toList();
      final pageCount = visibleCopies.isEmpty
          ? 1
          : (visibleCopies.length + _pageSize - 1) ~/ _pageSize;
      final currentPage = _page >= pageCount ? pageCount - 1 : _page;
      final pageCopies = visibleCopies
          .skip(currentPage * _pageSize)
          .take(_pageSize);
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Inventaris',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Kelola QR buku, ketersediaan stok, dan kondisinya.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InventoryMetric(
                    label: 'Total aktif',
                    count: copies.length,
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InventoryMetric(
                    label: 'Tersedia',
                    count: counts['available'] ?? 0,
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _InventoryMetric(
                    label: 'Dipinjam',
                    count: counts['borrowed'] ?? 0,
                    icon: Icons.menu_book_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InventoryMetric(
                    label: 'Rusak / hilang',
                    count: (counts['damaged'] ?? 0) + (counts['lost'] ?? 0),
                    icon: Icons.report_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _search,
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Cari kode QR atau judul buku',
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _search.clear();
                          setState(() {
                            _query = '';
                            _page = 0;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final label in const [
                    'Semua',
                    'Tersedia',
                    'Dipinjam',
                    'Rusak',
                    'Hilang',
                  ]) ...[
                    if (label != 'Semua') const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(label),
                      selected: _statusFilter == label,
                      onSelected: (_) => setState(() {
                        _statusFilter = label;
                        _page = 0;
                      }),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kategori buku',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'Semua',
                  child: Text('Semua kategori'),
                ),
                for (final category in categories)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() {
                _categoryFilter = value ?? 'Semua';
                _page = 0;
              }),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: selectedCategory == 'Semua'
                  ? null
                  : () => _printCategoryQrs(
                      context,
                      category: selectedCategory,
                      copies: copies
                          .where(
                            (copy) => _copyCategory(copy) == selectedCategory,
                          )
                          .toList(),
                    ),
              icon: const Icon(Icons.print_outlined),
              label: Text(
                selectedCategory == 'Semua'
                    ? 'Pilih kategori untuk cetak QR'
                    : 'Cetak semua QR · ${copies.where((copy) => _copyCategory(copy) == selectedCategory).length}',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${visibleCopies.length} QR buku',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            if (visibleCopies.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 42),
                    SizedBox(height: 8),
                    Text('Tidak ada QR buku yang cocok.'),
                  ],
                ),
              )
            else
              for (final copy in pageCopies) ...[
                _InventoryCopyCard(
                  copy: copy,
                  onTap: () => _showCopyQr(context, copy),
                  onArchive: copy['status'] == 'available'
                      ? () => _archiveCopy(context, copy)
                      : null,
                ),
                const SizedBox(height: 8),
              ],
            if (visibleCopies.length > _pageSize) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.outlined(
                    tooltip: 'Halaman sebelumnya',
                    onPressed: currentPage == 0
                        ? null
                        : () => setState(() => _page = currentPage - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Halaman ${currentPage + 1} dari $pageCount'),
                  IconButton.outlined(
                    tooltip: 'Halaman berikutnya',
                    onPressed: currentPage + 1 >= pageCount
                        ? null
                        : () => setState(() => _page = currentPage + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  Future<void> _archiveCopy(
    BuildContext context,
    Map<String, dynamic> copy,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus eksemplar dari stok?'),
        content: Text(
          'Kode ${copy['code']} akan dikeluarkan dari stok aktif. Riwayat tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus dari stok'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await Supabase.instance.client.rpc(
        'archive_available_copy',
        params: {'p_copy_id': copy['id']},
      );
      _refresh();
      if (context.mounted) _snack(context, 'Eksemplar dikeluarkan dari stok.');
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }

  Future<void> _showCopyQr(
    BuildContext context,
    Map<String, dynamic> copy,
  ) async {
    final code = (copy['code'] as String? ?? '').trim();
    if (code.isEmpty) {
      if (context.mounted) _snack(context, 'Kode QR eksemplar belum tersedia.');
      return;
    }
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CopyQrPage(copy: copy, onPrint: _printCopyQr),
      ),
    );
  }

  Future<void> _printCopyQr(
    BuildContext context,
    Map<String, dynamic> copy,
  ) async {
    final code = copy['code'] as String? ?? '';
    final book = copy['books'] as Map<String, dynamic>?;
    try {
      final image = await QrPainter(
        data: code,
        version: QrVersions.auto,
        gapless: true,
      ).toImageData(900);
      if (image == null) throw StateError('QR tidak dapat dibuat.');
      final document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a6,
          margin: const pw.EdgeInsets.all(18),
          build: (_) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  book?['title'] as String? ?? 'Buku',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Image(
                  pw.MemoryImage(image.buffer.asUint8List()),
                  width: 220,
                ),
                pw.SizedBox(height: 10),
                pw.Text(code, style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      );
      await Printing.layoutPdf(
        name: 'label-$code.pdf',
        onLayout: (_) => document.save(),
      );
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }
}

class CopyQrPage extends StatelessWidget {
  const CopyQrPage({super.key, required this.copy, required this.onPrint});
  final Map<String, dynamic> copy;
  final Future<void> Function(BuildContext, Map<String, dynamic>) onPrint;

  @override
  Widget build(BuildContext context) {
    final code = copy['code'] as String? ?? '';
    final book = copy['books'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(title: const Text('QR eksemplar')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        book?['title'] as String? ?? 'Buku',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text('Eksemplar $code'),
                      const SizedBox(height: 20),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: code,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                          errorStateBuilder: (context, error) => SizedBox(
                            width: 240,
                            height: 240,
                            child: Center(
                              child: Text(
                                'QR gagal dibuat: $error',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        code,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'QR berisi kode tetap eksemplar. Status stok dapat berubah.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => onPrint(context, copy),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Cetak QR'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MemberQrScanPage extends StatefulWidget {
  const MemberQrScanPage({
    super.key,
    required this.onLoanRequestSubmitted,
    this.initialCopy,
  });

  final VoidCallback onLoanRequestSubmitted;
  @visibleForTesting
  final Map<String, dynamic>? initialCopy;

  @override
  State<MemberQrScanPage> createState() => _MemberQrScanPageState();
}

class _MemberQrScanPageState extends State<MemberQrScanPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _lookingUp = false;
  String? _message;
  Map<String, dynamic>? _copy;

  @override
  void initState() {
    super.initState();
    _copy = widget.initialCopy;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_lookingUp) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }
    if (code == null) return;
    setState(() {
      _lookingUp = true;
      _message = null;
      _copy = null;
    });
    await _controller.stop();
    try {
      final result = await _fetchCopyByCode(code);
      if (!mounted) return;
      final book = result?['books'] as Map<String, dynamic>?;
      if (result == null ||
          result['archived_at'] != null ||
          book?['archived_at'] != null) {
        setState(() {
          _message = 'QR buku tidak ditemukan atau sudah diarsipkan.';
          _lookingUp = false;
        });
      } else {
        setState(() {
          _copy = result;
          _lookingUp = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _friendlyError(error);
          _lookingUp = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchCopyByCode(String code) async =>
      await Supabase.instance.client
          .from('book_copies')
          .select(
            'id,code,status,archived_at,books(id,title,author,category,cover_path,archived_at)',
          )
          .eq('code', code)
          .maybeSingle();

  Future<void> _scanAgain() async {
    setState(() {
      _lookingUp = false;
      _message = null;
      _copy = null;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    if (copy != null) return _buildScanResult(context, copy);
    return _buildScanner(context);
  }

  Widget _buildScanner(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Scan buku', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      const Text('Arahkan kamera ke QR buku untuk memeriksa ketersediaannya.'),
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Kamera tidak dapat dibuka. Periksa izin kamera lalu coba lagi.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
      if (_lookingUp) ...[
        const SizedBox(height: 16),
        const Center(child: CircularProgressIndicator()),
      ],
      if (_message != null) ...[
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_message!),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _scanAgain,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Coba scan lagi'),
        ),
      ],
    ],
  );

  Widget _buildScanResult(BuildContext context, Map<String, dynamic> copy) {
    final book = copy['books'] as Map<String, dynamic>?;
    final isAvailable = copy['status'] == 'available';
    final title = book?['title'] as String? ?? 'Buku';
    final statusColor = isAvailable
        ? Colors.green.shade700
        : Colors.orange.shade800;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Kembali ke kamera',
                onPressed: _scanAgain,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  'Hasil scan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PerpusBookCover(
                      bookId: book?['id'] as String? ?? copy['code'] as String,
                      code: copy['code'] as String? ?? 'BUKU',
                      width: 148,
                      height: 196,
                      imageUrl: _bookCoverUrl(book),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${book?['category'] ?? 'Buku'} · Kode ${copy['code']}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _status(copy['status'] as String? ?? ''),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isAvailable
                                  ? 'Buku tersedia. Ajukan pinjaman, lalu serahkan buku kepada pengurus untuk diperiksa sebelum dibawa.'
                                  : 'Buku ini belum tersedia untuk dipinjam.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isAvailable)
                FilledButton.icon(
                  onPressed: () => _openLoanRequest(copy),
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: const Text('Ajukan pinjaman'),
                ),
              if (isAvailable) const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _scanAgain,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan buku lain'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openLoanRequest(Map<String, dynamic> copy) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MemberLoanRequestPage(copy: copy)),
    );
    if (!mounted || completed != true) return;
    widget.onLoanRequestSubmitted();
  }
}

class MemberLoanRequestPage extends StatefulWidget {
  const MemberLoanRequestPage({super.key, required this.copy});
  final Map<String, dynamic> copy;

  @override
  State<MemberLoanRequestPage> createState() => _MemberLoanRequestPageState();
}

class _MemberLoanRequestPageState extends State<MemberLoanRequestPage> {
  final _picker = ImagePicker();
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );
  XFile? _photo;
  String? _method;
  String? _requestKey;
  String? _uploadedEvidencePath;
  bool _saving = false;
  bool _checkingPhoto = false;

  Future<void> _takePhoto() async {
    if (_saving || _checkingPhoto || _method == null) return;
    setState(() => _checkingPhoto = true);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (photo == null || !mounted) return;
      setState(() {
        _photo = null;
        _requestKey = null;
        _uploadedEvidencePath = null;
      });
      final faces = await _faceDetector.processImage(
        InputImage.fromFilePath(photo.path),
      );
      if (!mounted) return;
      if (faces.isEmpty) {
        _snack(context, 'Foto bukti harus menampilkan wajah dengan jelas.');
        return;
      }
      setState(() {
        _photo = photo;
        _requestKey = null;
        _uploadedEvidencePath = null;
      });
    } catch (error) {
      if (mounted) _snack(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _checkingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (_saving || _checkingPhoto) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final photo = _photo;
    final method = _method;
    if (user == null || photo == null || method == null) {
      _snack(
        context,
        'Pilih jenis bukti dan ambil foto yang menampilkan wajah.',
      );
      return;
    }
    setState(() => _saving = true);
    final key = _requestKey ??= _newRequestUuid();
    final ext = photo.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final path = _uploadedEvidencePath ?? '${user.id}/$key.$ext';
    try {
      if (_uploadedEvidencePath == null) {
        await client.storage
            .from('loan-evidence')
            .uploadBinary(
              path,
              await photo.readAsBytes(),
              fileOptions: FileOptions(
                contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
                upsert: false,
              ),
            );
        _uploadedEvidencePath = path;
      }
      await client.rpc(
        'submit_loan_request',
        params: {
          'p_idempotency_key': key,
          'p_copy_ids': [widget.copy['id']],
          'p_evidence_method': method,
          'p_evidence_path': path,
        },
      );
      if (!mounted) return;
      _snack(
        context,
        'Pengajuan terkirim. Tunggu persetujuan pengurus sebelum membawa buku.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _snack(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    unawaited(_faceDetector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.copy['books'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan pinjaman')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: PerpusBookCover(
                bookId: book?['id'] as String? ?? widget.copy['code'] as String,
                code: widget.copy['code'] as String? ?? 'BUKU',
                width: 96,
                height: 128,
                imageUrl: _bookCoverUrl(book),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: Text(book?['title'] as String? ?? 'Buku'),
                subtitle: Text('Eksemplar ${widget.copy['code']}'),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Jenis bukti',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih jenis foto yang akan dikirim.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.face_outlined, size: 18),
                  label: const Text('Selfie'),
                  selected: _method == 'selfie',
                  onSelected:
                      _saving || _checkingPhoto || _uploadedEvidencePath != null
                      ? null
                      : (_) => setState(() => _method = 'selfie'),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('Kartu siswa'),
                  selected: _method == 'student_card',
                  onSelected:
                      _saving || _checkingPhoto || _uploadedEvidencePath != null
                      ? null
                      : (_) => setState(() => _method = 'student_card'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving || _checkingPhoto || _method == null
                  ? null
                  : _takePhoto,
              icon: _checkingPhoto
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(
                _checkingPhoto
                    ? 'Memeriksa foto…'
                    : _method == null
                    ? 'Pilih jenis bukti terlebih dahulu'
                    : _photo == null
                    ? 'Ambil foto bukti'
                    : 'Ambil ulang foto',
              ),
            ),
            if (_photo != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_photo!.path),
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text(_photo!.name),
                    subtitle: const Text('Foto siap diunggah'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  _saving || _checkingPhoto || _photo == null || _method == null
                  ? null
                  : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_saving ? 'Mengirim…' : 'Ajukan pinjaman'),
            ),
            const SizedBox(height: 8),
            Text(
              'Pengajuan menunggu pemeriksaan siswa dan buku oleh pengurus. Stok berkurang setelah pengurus menyetujui dan menyerahkan buku.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _newRequestUuid() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _InventoryMetric extends StatelessWidget {
  const _InventoryMetric({
    required this.label,
    required this.count,
    required this.icon,
  });
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _InventoryCopyCard extends StatelessWidget {
  const _InventoryCopyCard({
    required this.copy,
    required this.onTap,
    required this.onArchive,
  });
  final Map<String, dynamic> copy;
  final VoidCallback onTap;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final book = copy['books'] as Map<String, dynamic>?;
    final status = copy['status'] as String? ?? 'unknown';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              const Icon(Icons.qr_code_2, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy['code'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(book?['title'] as String? ?? 'Buku tidak ditemukan'),
                    const SizedBox(height: 6),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(_status(status)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tindakan QR buku',
                onSelected: (value) {
                  if (value == 'qr') onTap();
                  if (value == 'archive') onArchive?.call();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'qr',
                    child: ListTile(
                      leading: Icon(Icons.qr_code_2),
                      title: Text('Tampilkan QR'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (onArchive != null)
                    const PopupMenuItem(
                      value: 'archive',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Hapus dari stok'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});
  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late Future<_MemberData> _data;
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_MemberData> _load() async {
    final client = Supabase.instance.client;
    final students = await client
        .from('student_registry')
        .select('id,nis,nisn,full_name,class_name,active,linked_user_id')
        .order('full_name');
    final profiles = await client
        .from('profiles')
        .select(
          'id,claimed_student_id,status,contact,rejection_reason,created_at',
        )
        .eq('role', 'member')
        .order('created_at');
    return _MemberData(
      List<Map<String, dynamic>>.from(students),
      List<Map<String, dynamic>>.from(profiles),
    );
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_MemberData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(error: snapshot.error, retry: _refresh);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final studentById = {for (final row in data.students) row['id']: row};
      final accountByStudentId = <dynamic, Map<String, dynamic>>{};
      for (final profile in data.profiles) {
        final studentId = profile['claimed_student_id'];
        if (studentId != null &&
            (!accountByStudentId.containsKey(studentId) ||
                profile['status'] == 'active')) {
          accountByStudentId[studentId] = profile;
        }
      }
      final studentsByClass = <String, List<Map<String, dynamic>>>{};
      for (final student in data.students) {
        final className = (student['class_name'] as String?)?.trim();
        studentsByClass
            .putIfAbsent(
              className == null || className.isEmpty
                  ? 'Kelas belum diisi'
                  : className,
              () => [],
            )
            .add(student);
      }
      final classNames = studentsByClass.keys.toList()..sort();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${data.students.length} siswa · ${classNames.length} kelas · ${data.profiles.where((p) => p['status'] == 'pending').length} menunggu aktivasi',
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Tambah anggota',
                  onPressed: () => _addStudent(context),
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (data.profiles.any((p) => p['status'] == 'pending')) ...[
                    Text(
                      'Permintaan aktivasi',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final profile in data.profiles.where(
                      (p) => p['status'] == 'pending',
                    ))
                      _PendingMemberCard(
                        profile: profile,
                        student: studentById[profile['claimed_student_id']],
                        changed: _refresh,
                      ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Daftar siswa',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (classNames.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Belum ada data siswa.')),
                    ),
                  for (final className in classNames)
                    Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.school_outlined),
                        title: Text(className),
                        subtitle: Text(
                          '${studentsByClass[className]!.length} siswa',
                        ),
                        children: [
                          for (final student in studentsByClass[className]!)
                            _StudentCard(
                              student: student,
                              onEdit: () => _editStudent(context, student),
                              onToggleActive: () =>
                                  _setStudentActive(context, student),
                              onRecover:
                                  accountByStudentId[student['id']] == null
                                  ? null
                                  : () => _recoverAccess(
                                      context,
                                      student,
                                      accountByStudentId[student['id']]!,
                                    ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Future<void> _addStudent(BuildContext context) async {
    final form = await showDialog<_StudentFormValue>(
      context: context,
      builder: (_) => const _StudentDialog(),
    );
    if (form == null || !context.mounted) return;
    try {
      await Supabase.instance.client.from('student_registry').insert({
        if (form.nis.isNotEmpty) 'nis': form.nis,
        if (form.nisn.isNotEmpty) 'nisn': form.nisn,
        'full_name': form.name,
        'class_name': form.className,
        'active': true,
      });
      _refresh();
      if (context.mounted) _snack(context, 'Anggota ditambahkan.');
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }

  Future<void> _editStudent(
    BuildContext context,
    Map<String, dynamic> student,
  ) async {
    final form = await showDialog<_StudentFormValue>(
      context: context,
      builder: (_) => _StudentDialog(initial: student),
    );
    if (form == null || !context.mounted) return;
    try {
      await Supabase.instance.client
          .from('student_registry')
          .update({
            'nis': form.nis.isEmpty ? null : form.nis,
            'nisn': form.nisn.isEmpty ? null : form.nisn,
            'full_name': form.name,
            'class_name': form.className,
          })
          .eq('id', student['id']);
      _refresh();
      if (context.mounted) _snack(context, 'Data siswa diperbarui.');
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }

  Future<void> _setStudentActive(
    BuildContext context,
    Map<String, dynamic> student,
  ) async {
    final active = student['active'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'Nonaktifkan siswa?' : 'Aktifkan siswa?'),
        content: Text(
          active
              ? 'Siswa tidak dapat mendaftar atau menggunakan akses anggota. Data dan riwayatnya tetap disimpan.'
              : 'Siswa dapat mendaftar kembali menggunakan identitas yang tercatat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(active ? 'Nonaktifkan' : 'Aktifkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await Supabase.instance.client
          .from('student_registry')
          .update({'active': !active})
          .eq('id', student['id']);
      _refresh();
      if (context.mounted) {
        _snack(context, active ? 'Siswa dinonaktifkan.' : 'Siswa diaktifkan.');
      }
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }

  Future<void> _recoverAccess(
    BuildContext context,
    Map<String, dynamic> student,
    Map<String, dynamic> profile,
  ) async {
    final input = await showDialog<_RecoveryIssueInput>(
      context: context,
      builder: (_) => _RecoveryIssueDialog(
        studentName: student['full_name'] as String? ?? 'Anggota',
      ),
    );
    if (input == null || !context.mounted) return;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'account-recovery',
        body: {
          'action': 'issue',
          'target_user_id': profile['id'],
          if (input.newEmail.isNotEmpty) 'new_email': input.newEmail,
        },
      );
      final data = response.data;
      if (data is! Map ||
          data['challenge_id'] is! String ||
          data['code'] is! String) {
        throw const FormatException('Respons kode pemulihan tidak lengkap.');
      }
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kode pemulihan siap'),
          content: SelectableText(
            'Nama: ${student['full_name']}\n\n'
            'ID pemulihan:\n${data['challenge_id']}\n\n'
            'Kode:\n${data['code']}\n\n'
            'Kode berlaku 15 menit dan hanya dapat digunakan sekali. Berikan langsung kepada siswa setelah identitas diperiksa. Setelah dialog ditutup kode tidak dapat dilihat lagi.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Saya sudah mencatat'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }
}

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({super.key});
  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage> {
  int _section = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Aturan pinjam'),
              selected: _section == 0,
              onSelected: (_) => setState(() => _section = 0),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Audit aktivitas'),
              selected: _section == 1,
              onSelected: (_) => setState(() => _section = 1),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Pengurus'),
              selected: _section == 2,
              onSelected: (_) => setState(() => _section = 2),
            ),
          ],
        ),
      ),
      Expanded(
        child: switch (_section) {
          0 => const _LibrarySettingsPanel(),
          1 => const _AuditLogPanel(),
          _ => const _StaffAdminPanel(),
        },
      ),
    ],
  );
}

class _StaffAdminPanel extends StatefulWidget {
  const _StaffAdminPanel();
  @override
  State<_StaffAdminPanel> createState() => _StaffAdminPanelState();
}

class _StaffAdminPanelState extends State<_StaffAdminPanel> {
  late Future<_StaffReviewData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_StaffReviewData> _load() async {
    final client = Supabase.instance.client;
    final profiles = List<Map<String, dynamic>>.from(
      await client
          .from('profiles')
          .select('id,staff_id,created_at')
          .eq('role', 'admin')
          .eq('status', 'pending')
          .order('created_at'),
    );
    final staff = List<Map<String, dynamic>>.from(
      await client
          .from('staff_registry')
          .select('id,email,full_name,position,linked_user_id')
          .order('full_name'),
    );
    return _StaffReviewData(profiles, staff);
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_StaffReviewData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(error: snapshot.error, retry: _refresh);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final staffById = {for (final row in data.staff) row['id']: row};
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${data.staff.length} pengurus · ${data.pending.length} menunggu aktivasi',
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Buat undangan pengurus',
                  onPressed: () => _createInvite(context),
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final next = _load();
                setState(() {
                  _data = next;
                });
                await next;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (data.pending.isNotEmpty) ...[
                    Text(
                      'Permintaan pengurus',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final profile in data.pending)
                      _PendingStaffCard(
                        profile: profile,
                        staff: staffById[profile['staff_id']],
                        changed: _refresh,
                      ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Daftar pengurus',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final person in data.staff)
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(person['full_name'] as String? ?? 'Pengurus'),
                      subtitle: Text(
                        '${person['position'] ?? 'Pengurus Perpustakaan'} · ${person['email'] ?? ''}',
                      ),
                      trailing: Chip(
                        label: Text(
                          person['linked_user_id'] == null
                              ? 'Undangan'
                              : 'Terdaftar',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Future<void> _createInvite(BuildContext context) async {
    final email = await showTextDialog(
      context,
      'Email pengurus',
      'Email penerima undangan',
    );
    if (email == null || email.trim().isEmpty || !context.mounted) return;
    final name = await showTextDialog(context, 'Nama pengurus', 'Nama lengkap');
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final position = await showTextDialog(
      context,
      'Jabatan',
      'Pengurus Perpustakaan',
    );
    if (position == null || !context.mounted) return;
    try {
      final result = await Supabase.instance.client.rpc(
        'create_staff_invite',
        params: {
          'p_email': email.trim(),
          'p_full_name': name.trim(),
          'p_position': position.trim().isEmpty
              ? 'Pengurus Perpustakaan'
              : position.trim(),
          'p_staff_no': null,
        },
      );
      final invite = (result as List).single as Map<String, dynamic>;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Undangan siap'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bagikan kode ini secara pribadi. Kode sekali pakai berlaku 48 jam.',
              ),
              const SizedBox(height: 12),
              SelectableText('${invite['invite_token']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      _refresh();
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }
}

class _PendingStaffCard extends StatelessWidget {
  const _PendingStaffCard({
    required this.profile,
    required this.staff,
    required this.changed,
  });
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? staff;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(staff?['full_name'] as String? ?? 'Pengurus'),
      subtitle: Text(staff?['email'] as String? ?? 'Email tidak tersedia'),
      trailing: IconButton(
        tooltip: 'Aktifkan setelah email terkonfirmasi',
        onPressed: () => _approve(context),
        icon: const Icon(Icons.check_circle_outline),
      ),
    ),
  );

  Future<void> _approve(BuildContext context) async {
    try {
      await Supabase.instance.client.rpc(
        'review_staff_account',
        params: {'p_user_id': profile['id']},
      );
      changed();
      if (context.mounted) _snack(context, 'Akun pengurus diaktifkan.');
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }
}

class _LibrarySettingsPanel extends StatefulWidget {
  const _LibrarySettingsPanel();
  @override
  State<_LibrarySettingsPanel> createState() => _LibrarySettingsPanelState();
}

class _LibrarySettingsPanelState extends State<_LibrarySettingsPanel> {
  late Future<Map<String, dynamic>> _settings;
  final _loanDays = TextEditingController();
  final _maxBooks = TextEditingController();
  final _timezone = TextEditingController();
  String? _retention;
  bool _confirmed = false;
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _settings = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    return await Supabase.instance.client
        .from('library_settings')
        .select(
          'loan_days,max_books,school_timezone,evidence_retention,policy_confirmed',
        )
        .eq('id', true)
        .single();
  }

  void _initFields(Map<String, dynamic> value) {
    if (_initialized) return;
    _loanDays.text = '${value['loan_days']}';
    _maxBooks.text = '${value['max_books']}';
    _timezone.text = '${value['school_timezone']}';
    _retention = value['evidence_retention'] as String?;
    _confirmed = value['policy_confirmed'] as bool? ?? false;
    _initialized = true;
  }

  @override
  void dispose() {
    _loanDays.dispose();
    _maxBooks.dispose();
    _timezone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _settings,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          error: snapshot.error,
          retry: () => setState(() {
            _initialized = false;
            _settings = _load();
          }),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      _initFields(snapshot.data!);
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            'Pengaturan perpustakaan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loanDays,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Masa pinjam (hari)',
              helperText: '1–365 hari',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxBooks,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Maksimal buku per anggota',
              helperText: '1–50 buku',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _timezone,
            decoration: const InputDecoration(labelText: 'Zona waktu'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _retention,
            decoration: const InputDecoration(labelText: 'Retensi bukti foto'),
            items: const [
              DropdownMenuItem(value: '3_days', child: Text('3 hari')),
              DropdownMenuItem(value: '7_days', child: Text('7 hari')),
              DropdownMenuItem(value: '30_days', child: Text('30 hari')),
              DropdownMenuItem(value: '1_year', child: Text('1 tahun')),
            ],
            onChanged: (value) => setState(() => _retention = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kebijakan retensi sudah disetujui sekolah'),
            value: _confirmed,
            onChanged: (value) => setState(() => _confirmed = value),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Simpan pengaturan'),
          ),
        ],
      );
    },
  );

  Future<void> _save() async {
    final days = int.tryParse(_loanDays.text.trim());
    final maxBooks = int.tryParse(_maxBooks.text.trim());
    final timezone = _timezone.text.trim();
    if (days == null ||
        days < 1 ||
        days > 365 ||
        maxBooks == null ||
        maxBooks < 1 ||
        maxBooks > 50 ||
        timezone.isEmpty) {
      _snack(context, 'Periksa masa pinjam, batas buku, dan zona waktu.');
      return;
    }
    if (_confirmed && _retention == null) {
      _snack(context, 'Pilih masa retensi sebelum mengesahkan kebijakan.');
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('library_settings')
          .update({
            'loan_days': days,
            'max_books': maxBooks,
            'school_timezone': timezone,
            'evidence_retention': _retention,
            'policy_confirmed': _confirmed,
          })
          .eq('id', true);
      if (mounted) _snack(context, 'Pengaturan perpustakaan tersimpan.');
    } catch (error) {
      if (mounted) _snack(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AuditLogPanel extends StatefulWidget {
  const _AuditLogPanel();
  @override
  State<_AuditLogPanel> createState() => _AuditLogPanelState();
}

class _AuditLogPanelState extends State<_AuditLogPanel> {
  late Future<List<Map<String, dynamic>>> _logs;
  @override
  void initState() {
    super.initState();
    _logs = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('audit_logs')
            .select('id,actor_id,action,table_name,record_id,occurred_at')
            .order('occurred_at', ascending: false)
            .limit(100),
      );

  void _refresh() {
    final next = _load();
    setState(() {
      _logs = next;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _logs,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(error: snapshot.error, retry: _refresh);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final rows = snapshot.data!;
      if (rows.isEmpty) {
        return const Center(child: Text('Belum ada aktivitas tercatat.'));
      }
      return RefreshIndicator(
        onRefresh: () async {
          final next = _load();
          setState(() {
            _logs = next;
          });
          await next;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = rows[index];
            final time = DateTime.tryParse('${row['occurred_at']}')?.toLocal();
            return ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text('${row['action']} · ${row['table_name']}'),
              subtitle: Text(
                'ID ${row['record_id']} · ${time ?? 'waktu tidak tersedia'}',
              ),
            );
          },
        ),
      );
    },
  );
}

class _PendingMemberCard extends StatelessWidget {
  const _PendingMemberCard({
    required this.profile,
    required this.student,
    required this.changed,
  });
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? student;
  final VoidCallback changed;
  @override
  Widget build(BuildContext context) {
    final name =
        student?['full_name'] as String? ?? 'Data siswa tidak ditemukan';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${student?['class_name'] ?? '—'} · NIS ${student?['nis'] ?? '—'} · NISN ${student?['nisn'] ?? '—'}',
            ),
            Text(profile['contact'] as String? ?? 'Kontak tidak dicantumkan'),
            const SizedBox(height: 8),
            Wrap(
              children: [
                TextButton.icon(
                  onPressed: () => _review(context, true, changed),
                  icon: const Icon(Icons.check),
                  label: const Text('Setujui'),
                ),
                TextButton.icon(
                  onPressed: () => _review(context, false, changed),
                  icon: const Icon(Icons.close),
                  label: const Text('Tolak'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    bool approve,
    VoidCallback changed,
  ) async {
    var reason = '';
    if (!approve) {
      final result = await showTextDialog(
        context,
        'Alasan penolakan',
        'Tuliskan alasan',
      );
      if (result == null) return;
      reason = result.trim();
      if (reason.isEmpty) {
        if (context.mounted) _snack(context, 'Alasan wajib diisi.');
        return;
      }
    }
    try {
      await Supabase.instance.client.rpc(
        'review_member',
        params: {
          'p_user_id': profile['id'],
          'p_approve': approve,
          'p_reason': approve ? null : reason,
        },
      );
      changed();
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onEdit,
    required this.onToggleActive,
    this.onRecover,
  });
  final Map<String, dynamic> student;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback? onRecover;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        student['active'] == true
            ? Icons.check_circle_outline
            : Icons.block_outlined,
      ),
      title: Text(student['full_name'] as String? ?? ''),
      subtitle: Text(
        '${student['class_name'] ?? '—'} · NIS ${student['nis'] ?? '—'} · NISN ${student['nisn'] ?? '—'}\n${student['active'] == true ? 'Aktif' : 'Nonaktif'}',
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        tooltip: 'Tindakan data siswa',
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'active') onToggleActive();
          if (value == 'recover') onRecover?.call();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Ubah data'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'active',
            child: ListTile(
              leading: Icon(
                student['active'] == true
                    ? Icons.block_outlined
                    : Icons.check_circle_outline,
              ),
              title: Text(
                student['active'] == true ? 'Nonaktifkan' : 'Aktifkan',
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (onRecover != null)
            const PopupMenuItem(
              value: 'recover',
              child: ListTile(
                leading: Icon(Icons.lock_reset_outlined),
                title: Text('Pulihkan akses akun'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
      onTap: onEdit,
    ),
  );
}

class _RecoveryIssueInput {
  const _RecoveryIssueInput(this.newEmail);
  final String newEmail;
}

class _RecoveryIssueDialog extends StatefulWidget {
  const _RecoveryIssueDialog({required this.studentName});
  final String studentName;

  @override
  State<_RecoveryIssueDialog> createState() => _RecoveryIssueDialogState();
}

class _RecoveryIssueDialogState extends State<_RecoveryIssueDialog> {
  final _email = TextEditingController();
  bool _identityChecked = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pulihkan akses anggota'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.studentName),
          const SizedBox(height: 12),
          const Text(
            'Pastikan siswa menunjukkan kartu pelajar atau identitas sekolah sebelum kode dibuat.',
          ),
          CheckboxListTile(
            value: _identityChecked,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) =>
                setState(() => _identityChecked = value ?? false),
            title: const Text('Identitas siswa sudah diperiksa'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email baru (opsional)',
              helperText: 'Kosongkan jika email akun masih digunakan.',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _identityChecked
            ? () {
                final email = _email.text.trim().toLowerCase();
                if (email.isNotEmpty &&
                    (!email.contains('@') || !email.contains('.'))) {
                  _snack(context, 'Periksa format email baru.');
                  return;
                }
                Navigator.pop(context, _RecoveryIssueInput(email));
              }
            : null,
        child: const Text('Buat kode'),
      ),
    ],
  );
}

class AccountHome extends StatelessWidget {
  const AccountHome({super.key, required this.user});
  final User user;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_circle_outlined, size: 68),
          const SizedBox(height: 12),
          Text(
            user.email ?? 'Anggota',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Akun anggota aktif. Katalog dan ketersediaan dimuat dari server.',
          ),
        ],
      ),
    ),
  );
}

class MemberLoansPage extends StatefulWidget {
  const MemberLoansPage({super.key});
  @override
  State<MemberLoansPage> createState() => _MemberLoansPageState();
}

class _MemberLoansPageState extends State<MemberLoansPage> {
  late Future<List<Map<String, dynamic>>> _loans;
  @override
  void initState() {
    super.initState();
    _loans = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('loans')
            .select(
              'id,approved_at,loan_items(id,due_at,returned_at,resolved_at,return_condition,return_request_id,book_copies(code,books(id,title,category,cover_path)),return_requests(id,status),loss_reports(id,status,description))',
            )
            .order('approved_at', ascending: false),
      );

  void _refresh() {
    final next = _load();
    setState(() {
      _loans = next;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _loans,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(error: snapshot.error, retry: _refresh);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final loans = snapshot.data!;
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Riwayat pinjaman',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const _MemberLoanRequestsPanel(),
            if (loans.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Belum ada pinjaman.')),
              ),
            for (final loan in loans)
              ...List<Map<String, dynamic>>.from(
                loan['loan_items'] as List? ?? const [],
              ).map((item) {
                final copy = item['book_copies'] as Map<String, dynamic>?;
                final book = copy?['books'] as Map<String, dynamic>?;
                final returned = item['returned_at'] != null;
                final resolved = item['resolved_at'] != null;
                final overdue = isLoanItemOverdue(item);
                final returnRequest =
                    item['return_requests'] as Map<String, dynamic>?;
                final losses = List<Map<String, dynamic>>.from(
                  item['loss_reports'] as List? ?? const [],
                );
                final loss = losses.isEmpty ? null : losses.first;
                final pendingReturn =
                    returnRequest != null &&
                    ['pending', 'partial'].contains(returnRequest['status']);
                final pendingLoss =
                    loss != null &&
                    ['reported', 'verified'].contains(loss['status']);
                return Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: PerpusBookCover(
                          bookId:
                              book?['id'] as String? ??
                              copy?['code'] as String? ??
                              'book',
                          code: copy?['code'] as String? ?? 'BUKU',
                          width: 42,
                          height: 58,
                          imageUrl: _bookCoverUrl(book),
                        ),
                        title: Text(book?['title'] as String? ?? 'Buku'),
                        subtitle: Text(
                          '${book?['category'] ?? 'Buku'} · QR ${copy?['code'] ?? '—'} · Jatuh tempo ${_date(item['due_at'])}',
                        ),
                        trailing: Text(
                          returned
                              ? 'Kembali'
                              : resolved
                              ? 'Selesai'
                              : overdue
                              ? 'Terlambat'
                              : 'Dipinjam',
                        ),
                      ),
                      if (!returned && !resolved)
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [
                            if (pendingReturn)
                              TextButton.icon(
                                onPressed: () => _cancelReturn(
                                  context,
                                  returnRequest['id'] as String,
                                ),
                                icon: const Icon(Icons.undo),
                                label: const Text('Batalkan pengembalian'),
                              )
                            else if (!pendingLoss)
                              TextButton.icon(
                                onPressed: () => _requestReturn(
                                  context,
                                  item['id'] as String,
                                ),
                                icon: const Icon(
                                  Icons.assignment_return_outlined,
                                ),
                                label: const Text('Ajukan pengembalian'),
                              ),
                            if (!pendingReturn && !pendingLoss)
                              TextButton.icon(
                                onPressed: () =>
                                    _reportLoss(context, item['id'] as String),
                                icon: const Icon(
                                  Icons.report_gmailerrorred_outlined,
                                ),
                                label: const Text('Laporkan hilang'),
                              ),
                            if (loss != null)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  'Laporan kehilangan: ${_status(loss['status'] as String? ?? '')}',
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
    },
  );

  Future<void> _requestReturn(BuildContext context, String itemId) async {
    try {
      await Supabase.instance.client.rpc(
        'request_return',
        params: {
          'p_idempotency_key': _newRequestUuid(),
          'p_loan_item_ids': [itemId],
        },
      );
      if (context.mounted) {
        _snack(context, 'Pengajuan pengembalian dikirim ke pengurus.');
        _refresh();
      }
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }

  Future<void> _cancelReturn(BuildContext context, String requestId) async {
    try {
      await Supabase.instance.client.rpc(
        'cancel_return_request',
        params: {'p_return_request_id': requestId},
      );
      if (context.mounted) {
        _snack(context, 'Pengajuan pengembalian dibatalkan.');
        _refresh();
      }
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }

  Future<void> _reportLoss(BuildContext context, String itemId) async {
    final description = await showTextDialog(
      context,
      'Laporan kehilangan',
      'Jelaskan kapan dan bagaimana buku hilang',
    );
    if (description == null || !context.mounted) return;
    try {
      await Supabase.instance.client.rpc(
        'report_loss',
        params: {
          'p_idempotency_key': _newRequestUuid(),
          'p_loan_item_id': itemId,
          'p_description': description.trim(),
        },
      );
      if (context.mounted) {
        _snack(context, 'Laporan kehilangan dikirim ke pengurus.');
        _refresh();
      }
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }
}

class AdminCirculationPage extends StatefulWidget {
  const AdminCirculationPage({super.key});
  @override
  State<AdminCirculationPage> createState() => _AdminCirculationPageState();
}

class _AdminCirculationPageState extends State<AdminCirculationPage> {
  int _section = 0;
  late Future<List<Map<String, dynamic>>> _requests;
  @override
  void initState() {
    super.initState();
    _requests = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final requests = List<Map<String, dynamic>>.from(
      await client
          .from('loan_requests')
          .select(
            'id,member_id,status,created_at,decision_reason,loan_request_items(copy_id,book_copies(code,books(id,title,cover_path))),transaction_evidence(method,object_path)',
          )
          .eq('status', 'pending')
          .order('created_at'),
    );
    if (requests.isEmpty) return requests;
    final memberIds = requests
        .map((row) => row['member_id'] as String)
        .toSet()
        .toList();
    final profiles = List<Map<String, dynamic>>.from(
      await client
          .from('profiles')
          .select('id,claimed_student_id')
          .inFilter('id', memberIds),
    );
    final studentIds = profiles
        .map((row) => row['claimed_student_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final students = studentIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await client
                .from('student_registry')
                .select('id,full_name,class_name')
                .inFilter('id', studentIds),
          );
    final studentsById = {for (final row in students) row['id']: row};
    final labels = {
      for (final row in profiles)
        row['id']:
            studentsById[row['claimed_student_id']]?['full_name'] as String? ??
            'Anggota',
    };
    for (final request in requests) {
      request['member_label'] = labels[request['member_id']] ?? 'Anggota';
    }
    return requests;
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _requests = next;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Pinjaman')),
              ButtonSegment(value: 1, label: Text('Pengembalian')),
              ButtonSegment(value: 2, label: Text('Kehilangan')),
              ButtonSegment(value: 3, label: Text('Pembelajaran')),
              ButtonSegment(value: 4, label: Text('Riwayat')),
            ],
            selected: {_section},
            onSelectionChanged: (selected) =>
                setState(() => _section = selected.first),
          ),
        ),
      ),
      Expanded(
        child: switch (_section) {
          1 => const _AdminReturnsPage(),
          2 => const _AdminLossPage(),
          3 => const _AdminClassLoansPage(),
          4 => const _AdminActivityHistoryPage(),
          _ => _buildRequests(context),
        },
      ),
    ],
  );

  Widget _buildRequests(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(error: snapshot.error, retry: _refresh);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: requests.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(child: Text('Tidak ada pengajuan menunggu.')),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Pengajuan pinjaman',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      for (final request in requests)
                        _LoanReviewCard(request: request, changed: _refresh),
                    ],
                  ),
          );
        },
      );
}

class _AdminActivityHistoryPage extends StatefulWidget {
  const _AdminActivityHistoryPage();

  @override
  State<_AdminActivityHistoryPage> createState() =>
      _AdminActivityHistoryPageState();
}

class _AdminActivityHistoryPageState extends State<_AdminActivityHistoryPage> {
  late Future<Map<String, List<Map<String, dynamic>>>> _events;

  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _load() async {
    final client = Supabase.instance.client;
    final results = await Future.wait([
      client
          .from('loans')
          .select(
            'id,member_id,approved_at,approval_mode,loan_items(id,due_at,returned_at,resolved_at,return_condition,book_copies(code,books(title)))',
          )
          .order('approved_at', ascending: false)
          .limit(60),
      client
          .from('return_requests')
          .select(
            'id,member_id,status,created_at,return_request_items(status,received_condition,loan_items(book_copies(code,books(title))))',
          )
          .order('created_at', ascending: false)
          .limit(60),
      client
          .from('loss_reports')
          .select(
            'id,member_id,status,created_at,resolved_at,loan_items(book_copies(code,books(title)))',
          )
          .order('created_at', ascending: false)
          .limit(60),
      client
          .from('class_loan_sessions')
          .select(
            'id,responsible_name,class_name,activity,due_at,returned_at,created_at,class_loan_items(id,returned_at,return_condition,book_copies(code,books(title)))',
          )
          .order('created_at', ascending: false)
          .limit(60),
    ]);
    final loans = List<Map<String, dynamic>>.from(results[0]);
    final returns = List<Map<String, dynamic>>.from(results[1]);
    final losses = List<Map<String, dynamic>>.from(results[2]);
    final classes = List<Map<String, dynamic>>.from(results[3]);
    final memberIds = <String>{
      for (final row in loans) row['member_id'] as String,
      for (final row in returns) row['member_id'] as String,
      for (final row in losses) row['member_id'] as String,
    }.toList();
    if (memberIds.isNotEmpty) {
      final profiles = List<Map<String, dynamic>>.from(
        await client
            .from('profiles')
            .select('id,claimed_student_id')
            .inFilter('id', memberIds),
      );
      final studentIds = profiles
          .map((row) => row['claimed_student_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final students = studentIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await client
                  .from('student_registry')
                  .select('id,full_name,class_name')
                  .inFilter('id', studentIds),
            );
      final studentsById = {for (final row in students) row['id']: row};
      final labels = {
        for (final profile in profiles)
          profile['id']:
              '${studentsById[profile['claimed_student_id']]?['full_name'] ?? 'Anggota'} · ${studentsById[profile['claimed_student_id']]?['class_name'] ?? 'Kelas tidak diketahui'}',
      };
      for (final row in [...loans, ...returns, ...losses]) {
        row['member_label'] = labels[row['member_id']] ?? 'Anggota';
      }
    }
    return {
      'loans': loans,
      'returns': returns,
      'losses': losses,
      'classes': classes,
    };
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _events = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _events,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(error: snapshot.error, retry: _refresh);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      final loans = data['loans']!;
      final returns = data['returns']!;
      final losses = data['losses']!;
      final classes = data['classes']!;
      final hasEvents =
          loans.isNotEmpty ||
          returns.isNotEmpty ||
          losses.isNotEmpty ||
          classes.isNotEmpty;
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Riwayat aktivitas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Peminjaman, pengembalian, kehilangan, dan pembelajaran.',
            ),
            if (!hasEvents)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: Text('Belum ada aktivitas tercatat.')),
              ),
            if (loans.isNotEmpty) ...[
              _historySectionTitle(context, 'Peminjaman', loans.length),
              for (final row in loans) _loanHistoryCard(context, row),
            ],
            if (returns.isNotEmpty) ...[
              _historySectionTitle(context, 'Pengembalian', returns.length),
              for (final row in returns) _returnHistoryCard(context, row),
            ],
            if (losses.isNotEmpty) ...[
              _historySectionTitle(context, 'Kehilangan', losses.length),
              for (final row in losses) _lossHistoryCard(context, row),
            ],
            if (classes.isNotEmpty) ...[
              _historySectionTitle(context, 'Pembelajaran', classes.length),
              for (final row in classes) _classHistoryCard(context, row),
            ],
          ],
        ),
      );
    },
  );

  Widget _historySectionTitle(BuildContext context, String title, int count) =>
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(
          '$title · $count',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );

  Widget _loanHistoryCard(BuildContext context, Map<String, dynamic> row) {
    final items = List<Map<String, dynamic>>.from(
      row['loan_items'] as List? ?? const [],
    );
    final active = items
        .where(
          (item) => item['returned_at'] == null && item['resolved_at'] == null,
        )
        .length;
    return _historyCard(
      context,
      title: 'Pinjaman · ${row['member_label'] ?? 'Anggota'}',
      status: active == 0 ? 'Selesai' : '$active buku dipinjam',
      subtitle: _date(row['approved_at']),
      items: [
        for (final item in items)
          _historyBookLine(
            item['book_copies'] as Map<String, dynamic>?,
            item['returned_at'] != null
                ? 'Dikembalikan · ${item['return_condition'] == 'damaged' ? 'rusak' : 'baik'}'
                : item['resolved_at'] != null
                ? 'Kewajiban selesai'
                : 'Jatuh tempo ${_date(item['due_at'])}',
          ),
      ],
    );
  }

  Widget _returnHistoryCard(BuildContext context, Map<String, dynamic> row) {
    final items = List<Map<String, dynamic>>.from(
      row['return_request_items'] as List? ?? const [],
    );
    return _historyCard(
      context,
      title: 'Pengembalian · ${row['member_label'] ?? 'Anggota'}',
      status: _activityStatus(row['status'] as String? ?? ''),
      subtitle: _date(row['created_at']),
      items: [
        for (final item in items)
          _historyBookLine(
            ((item['loan_items'] as Map<String, dynamic>?)?['book_copies'])
                as Map<String, dynamic>?,
            '${_activityStatus(item['status'] as String? ?? '')}${item['received_condition'] == null ? '' : ' · ${_activityStatus(item['received_condition'] as String)}'}',
          ),
      ],
    );
  }

  Widget _lossHistoryCard(BuildContext context, Map<String, dynamic> row) {
    final loanItem = row['loan_items'] as Map<String, dynamic>?;
    return _historyCard(
      context,
      title: 'Kehilangan · ${row['member_label'] ?? 'Anggota'}',
      status: _activityStatus(row['status'] as String? ?? ''),
      subtitle: _date(row['created_at']),
      items: [
        _historyBookLine(
          loanItem?['book_copies'] as Map<String, dynamic>?,
          row['resolved_at'] == null ? 'Laporan buku hilang' : 'Diselesaikan',
        ),
      ],
    );
  }

  Widget _classHistoryCard(BuildContext context, Map<String, dynamic> row) {
    final items = List<Map<String, dynamic>>.from(
      row['class_loan_items'] as List? ?? const [],
    );
    final active = items.where((item) => item['returned_at'] == null).length;
    return _historyCard(
      context,
      title: '${row['class_name']} · ${row['activity']}',
      status: active == 0 ? 'Selesai' : '$active buku dipinjam',
      subtitle: '${row['responsible_name']} · ${_date(row['created_at'])}',
      items: [
        for (final item in items)
          _historyBookLine(
            item['book_copies'] as Map<String, dynamic>?,
            item['returned_at'] == null
                ? 'Jatuh tempo ${_date(row['due_at'])}'
                : 'Dikembalikan · ${item['return_condition'] == 'damaged' ? 'rusak' : 'baik'}',
          ),
      ],
    );
  }

  Widget _historyCard(
    BuildContext context, {
    required String title,
    required String status,
    required String subtitle,
    required List<Widget> items,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('$status · $subtitle'),
          if (items.isNotEmpty) const Divider(height: 16),
          ...items,
        ],
      ),
    ),
  );

  Widget _historyBookLine(Map<String, dynamic>? copy, String detail) {
    final book = copy?['books'] as Map<String, dynamic>?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '${book?['title'] ?? 'Buku'} · ${copy?['code'] ?? 'QR tidak tersedia'} · $detail',
      ),
    );
  }
}

String _activityStatus(String status) => switch (status) {
  'pending' => 'Menunggu',
  'partial' => 'Sebagian diproses',
  'completed' => 'Selesai',
  'received' => 'Diterima',
  'rejected' => 'Ditolak',
  'cancelled' => 'Dibatalkan',
  'reported' => 'Dilaporkan',
  'verified' => 'Diverifikasi',
  'resolved' => 'Diselesaikan',
  'good' => 'Baik',
  'damaged' => 'Rusak',
  _ => status,
};

class _AdminClassLoansPage extends StatefulWidget {
  const _AdminClassLoansPage();
  @override
  State<_AdminClassLoansPage> createState() => _AdminClassLoansPageState();
}

class _AdminClassLoansPageState extends State<_AdminClassLoansPage> {
  late Future<List<Map<String, dynamic>>> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('class_loan_sessions')
            .select(
              'id,responsible_name,class_name,activity,due_at,returned_at,created_at,class_loan_items(id,returned_at,return_condition,book_copies(code,books(id,title,cover_path)))',
            )
            .order('created_at', ascending: false)
            .limit(100),
      );

  void _refresh() {
    final next = _load();
    setState(() {
      _sessions = next;
    });
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _sessions,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(error: snapshot.error, retry: _refresh);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Pinjaman untuk kegiatan kelas'),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const _ClassLoanCreatePage(),
                          ),
                        );
                        if (created == true && mounted) _refresh();
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Sesi baru'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('Belum ada sesi pembelajaran.')),
                  ),
                for (final session in sessions)
                  _ClassLoanSessionCard(session: session, changed: _refresh),
              ],
            ),
          );
        },
      );
}

class _ClassLoanSessionCard extends StatelessWidget {
  const _ClassLoanSessionCard({required this.session, required this.changed});
  final Map<String, dynamic> session;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(
      session['class_loan_items'] as List? ?? const [],
    );
    final openCount = items.where((item) => item['returned_at'] == null).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${session['class_name']} · ${session['activity']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusPill(
                  openCount == 0 ? 'Selesai' : '$openCount dipinjam',
                  icon: openCount == 0
                      ? Icons.check_circle_outline
                      : Icons.timelapse,
                ),
              ],
            ),
            Text('Penanggung jawab: ${session['responsible_name']}'),
            Text('Tenggat: ${_dateTime(session['due_at'])}'),
            const Divider(),
            for (final item in items)
              Builder(
                builder: (context) {
                  final copy = item['book_copies'] as Map<String, dynamic>?;
                  final book = copy?['books'] as Map<String, dynamic>?;
                  final returned = item['returned_at'] != null;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: PerpusBookCover(
                      bookId:
                          book?['id'] as String? ??
                          copy?['code'] as String? ??
                          'book',
                      code: copy?['code'] as String? ?? 'BUKU',
                      width: 40,
                      height: 56,
                      imageUrl: _bookCoverUrl(book),
                    ),
                    title: Text(book?['title'] as String? ?? 'Buku'),
                    subtitle: Text('QR ${copy?['code'] ?? '—'}'),
                    trailing: returned
                        ? Text(
                            item['return_condition'] == 'damaged'
                                ? 'Rusak'
                                : 'Kembali',
                          )
                        : PopupMenuButton<String>(
                            tooltip: 'Catat pengembalian',
                            onSelected: (condition) async {
                              try {
                                await Supabase.instance.client.rpc(
                                  'return_class_loan_copy',
                                  params: {
                                    'p_item_id': item['id'],
                                    'p_condition': condition,
                                  },
                                );
                                changed();
                              } catch (error) {
                                if (context.mounted) {
                                  _snack(context, _friendlyError(error));
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'good',
                                child: Text('Kembali · baik'),
                              ),
                              PopupMenuItem(
                                value: 'damaged',
                                child: Text('Kembali · rusak'),
                              ),
                            ],
                            child: const Icon(Icons.assignment_return_outlined),
                          ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassLoanCreatePage extends StatefulWidget {
  const _ClassLoanCreatePage();
  @override
  State<_ClassLoanCreatePage> createState() => _ClassLoanCreatePageState();
}

class _ClassLoanCreatePageState extends State<_ClassLoanCreatePage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final _responsible = TextEditingController(
    text:
        Supabase.instance.client.auth.currentUser?.userMetadata?['full_name']
            as String? ??
        '',
  );
  final _className = TextEditingController();
  final _activity = TextEditingController();
  final List<Map<String, dynamic>> _copies = [];
  DateTime _dueAt = DateTime.now().add(const Duration(hours: 3));
  bool _lookingUp = false;
  bool _saving = false;
  String? _scanMessage;

  @override
  void dispose() {
    _controller.dispose();
    _responsible.dispose();
    _className.dispose();
    _activity.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_lookingUp || _saving) return;
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (code == null) return;
    _lookingUp = true;
    await _controller.stop();
    try {
      final copy = await Supabase.instance.client
          .from('book_copies')
          .select(
            'id,code,status,archived_at,books(id,title,cover_path,archived_at)',
          )
          .eq('code', code)
          .maybeSingle();
      if (!mounted) return;
      final exists = _copies.any((item) => item['id'] == copy?['id']);
      final book = copy?['books'] as Map<String, dynamic>?;
      if (copy == null ||
          copy['archived_at'] != null ||
          book?['archived_at'] != null) {
        setState(
          () => _scanMessage = 'QR tidak ditemukan atau buku sudah diarsipkan.',
        );
      } else if (copy['status'] != 'available') {
        setState(() => _scanMessage = '${copy['code']} sedang tidak tersedia.');
      } else if (exists) {
        setState(() => _scanMessage = '${copy['code']} sudah ada di sesi ini.');
      } else {
        setState(() {
          _copies.add(copy);
          _scanMessage = '${copy['code']} ditambahkan.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _scanMessage = _friendlyError(error));
    } finally {
      _lookingUp = false;
      if (mounted && _copies.length < 100) await _controller.start();
    }
  }

  Future<void> _chooseDueAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt.isBefore(now) ? now : _dueAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null || !mounted) return;
    final dueAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!dueAt.isAfter(DateTime.now())) {
      _snack(context, 'Pilih waktu tenggat yang masih akan datang.');
      return;
    }
    setState(() => _dueAt = dueAt);
  }

  Future<void> _save() async {
    if (_responsible.text.trim().isEmpty ||
        _className.text.trim().isEmpty ||
        _activity.text.trim().isEmpty ||
        _copies.isEmpty) {
      _snack(
        context,
        'Isi penanggung jawab, kelas, kegiatan, dan scan minimal satu buku.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.rpc(
        'create_class_loan',
        params: {
          'p_idempotency_key': _newRequestUuid(),
          'p_responsible_name': _responsible.text.trim(),
          'p_class_name': _className.text.trim(),
          'p_activity': _activity.text.trim(),
          'p_due_at': _dueAt.toUtc().toIso8601String(),
          'p_copy_ids': _copies.map((copy) => copy['id']).toList(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(context, _friendlyError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sesi peminjaman pembelajaran')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _responsible,
            decoration: const InputDecoration(labelText: 'Penanggung jawab'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _className,
            decoration: const InputDecoration(labelText: 'Kelas'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _activity,
            decoration: const InputDecoration(
              labelText: 'Kegiatan pembelajaran',
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Tenggat pengembalian'),
            subtitle: Text(_dateTime(_dueAt.toIso8601String())),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _chooseDueAt,
          ),
          const SizedBox(height: 8),
          Text(
            'Scan eksemplar (${_copies.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => const Center(
                  child: Text(
                    'Kamera tidak dapat dibuka. Periksa izin kamera.',
                  ),
                ),
              ),
            ),
          ),
          if (_lookingUp)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          if (_scanMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_scanMessage!),
            ),
          for (final copy in _copies)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PerpusBookCover(
                bookId:
                    (copy['books'] as Map<String, dynamic>?)?['id']
                        as String? ??
                    copy['code'] as String? ??
                    'book',
                code: copy['code'] as String? ?? 'BUKU',
                width: 38,
                height: 52,
                imageUrl: _bookCoverUrl(copy['books'] as Map<String, dynamic>?),
              ),
              title: Text(
                (copy['books'] as Map<String, dynamic>?)?['title'] as String? ??
                    'Buku',
              ),
              subtitle: Text('QR ${copy['code']}'),
              trailing: IconButton(
                tooltip: 'Hapus dari sesi',
                onPressed: _saving
                    ? null
                    : () => setState(() => _copies.remove(copy)),
                icon: const Icon(Icons.close),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Menyimpan...' : 'Mulai sesi · ${_copies.length} buku',
            ),
          ),
        ],
      ),
    ),
  );
}

String _dateTime(Object? value) => formatServerDateTime(value);

class _MemberLoanRequestsPanel extends StatefulWidget {
  const _MemberLoanRequestsPanel();
  @override
  State<_MemberLoanRequestsPanel> createState() =>
      _MemberLoanRequestsPanelState();
}

class _MemberLoanRequestsPanelState extends State<_MemberLoanRequestsPanel> {
  late Future<List<Map<String, dynamic>>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('loan_requests')
            .select(
              'id,status,created_at,decision_reason,loan_request_items(book_copies(code,books(id,title,cover_path)))',
            )
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(20),
      );

  void _refresh() {
    final next = _load();
    setState(() {
      _requests = next;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _requests,
    builder: (context, snapshot) {
      final rows = snapshot.data
          ?.where(isPendingMemberLoanRequest)
          .toList(growable: false);
      if (rows == null || rows.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menunggu persetujuan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final row in rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_status(row['status'] as String? ?? '')),
                        ),
                        Text(_date(row['created_at'])),
                      ],
                    ),
                    for (final item in List<Map<String, dynamic>>.from(
                      row['loan_request_items'] as List? ?? const [],
                    ))
                      Builder(
                        builder: (context) {
                          final copy =
                              item['book_copies'] as Map<String, dynamic>?;
                          final book = copy?['books'] as Map<String, dynamic>?;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: PerpusBookCover(
                              bookId:
                                  book?['id'] as String? ??
                                  copy?['code'] as String? ??
                                  'book',
                              code: copy?['code'] as String? ?? 'BUKU',
                              width: 38,
                              height: 52,
                              imageUrl: _bookCoverUrl(book),
                            ),
                            title: Text(book?['title'] as String? ?? 'Buku'),
                            subtitle: Text('QR ${copy?['code'] ?? '—'}'),
                          );
                        },
                      ),
                    if (row['decision_reason'] != null)
                      Text('Catatan: ${row['decision_reason']}'),
                    if (row['status'] == 'pending')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _cancel(row['id'] as String),
                          icon: const Icon(Icons.close),
                          label: const Text('Batalkan pengajuan'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _cancel(String requestId) async {
    try {
      await Supabase.instance.client.rpc(
        'cancel_loan_request',
        params: {'p_request_id': requestId},
      );
      if (mounted) {
        _snack(context, 'Pengajuan pinjaman dibatalkan.');
        _refresh();
      }
    } catch (error) {
      if (mounted) _snack(context, _friendlyError(error));
    }
  }
}

class _AdminReturnsPage extends StatefulWidget {
  const _AdminReturnsPage();
  @override
  State<_AdminReturnsPage> createState() => _AdminReturnsPageState();
}

class _AdminReturnsPageState extends State<_AdminReturnsPage> {
  late Future<List<Map<String, dynamic>>> _rows;
  @override
  void initState() {
    super.initState();
    _rows = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('return_requests')
            .select(
              'id,status,created_at,return_request_items(id,status,loan_item_id,loan_items(due_at,book_copies(code,books(title))))',
            )
            .inFilter('status', ['pending', 'partial'])
            .order('created_at'),
      );

  void _refresh() {
    final next = _load();
    setState(() {
      _rows = next;
    });
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(error: snapshot.error, retry: _refresh);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: requests.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 96),
                      Center(child: Text('Tidak ada pengembalian menunggu.')),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Pengajuan pengembalian',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final request in requests)
                        for (final item in List<Map<String, dynamic>>.from(
                          request['return_request_items'] as List? ?? const [],
                        ))
                          if (item['status'] == 'pending')
                            _ReturnReviewCard(
                              item: item,
                              createdAt: request['created_at'],
                              changed: _refresh,
                            ),
                    ],
                  ),
          );
        },
      );
}

class _ReturnReviewCard extends StatelessWidget {
  const _ReturnReviewCard({
    required this.item,
    required this.createdAt,
    required this.changed,
  });
  final Map<String, dynamic> item;
  final Object? createdAt;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final loanItem = item['loan_items'] as Map<String, dynamic>?;
    final copy = loanItem?['book_copies'] as Map<String, dynamic>?;
    final book = copy?['books'] as Map<String, dynamic>?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book?['title'] as String? ?? 'Buku',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Kode ${copy?['code'] ?? '—'} · ${_date(createdAt)}'),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _scanAndReview(context, 'good'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan · baik'),
                ),
                TextButton.icon(
                  onPressed: () => _scanAndReview(context, 'damaged'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan · rusak'),
                ),
                TextButton.icon(
                  onPressed: () => _review(context, false, null),
                  icon: const Icon(Icons.close),
                  label: const Text('Tolak'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanAndReview(BuildContext context, String condition) async {
    final loanItem = item['loan_items'] as Map<String, dynamic>?;
    final copy = loanItem?['book_copies'] as Map<String, dynamic>?;
    final expectedCode = copy?['code'] as String?;
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _ReturnQrScannerPage(expectedCode: expectedCode ?? ''),
      ),
    );
    if (scannedCode == null || !context.mounted) return;
    if (!matchesExpectedReturnQr(scannedCode, expectedCode)) {
      _snack(context, 'QR tidak cocok dengan buku yang diajukan kembali.');
      return;
    }
    await _review(context, true, condition);
  }

  Future<void> _review(
    BuildContext context,
    bool accept,
    String? condition,
  ) async {
    var reason = '';
    if (!accept) {
      final result = await showTextDialog(
        context,
        'Tolak pengembalian',
        'Alasan penolakan',
      );
      if (result == null) return;
      reason = result.trim();
      if (reason.isEmpty) {
        if (context.mounted) _snack(context, 'Alasan wajib diisi.');
        return;
      }
    }
    try {
      await Supabase.instance.client.rpc(
        'review_return_item',
        params: {
          'p_return_item_id': item['id'],
          'p_accept': accept,
          'p_condition': condition,
          'p_reason': accept ? null : reason,
        },
      );
      changed();
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }
}

class _ReturnQrScannerPage extends StatefulWidget {
  const _ReturnQrScannerPage({required this.expectedCode});

  final String expectedCode;

  @override
  State<_ReturnQrScannerPage> createState() => _ReturnQrScannerPageState();
}

class _ReturnQrScannerPageState extends State<_ReturnQrScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (code == null) return;
    _handled = true;
    await _controller.stop();
    if (mounted) Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan pengembalian')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Scan QR buku ${widget.expectedCode} yang diterima.'),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => const Center(
                child: Text('Kamera tidak dapat dibuka. Periksa izin kamera.'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdminLossPage extends StatefulWidget {
  const _AdminLossPage();
  @override
  State<_AdminLossPage> createState() => _AdminLossPageState();
}

class _AdminLossPageState extends State<_AdminLossPage> {
  late Future<List<Map<String, dynamic>>> _rows;
  @override
  void initState() {
    super.initState();
    _rows = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('loss_reports')
            .select(
              'id,member_id,loan_item_id,description,status,created_at,loan_items(book_copies(code,books(title)))',
            )
            .inFilter('status', ['reported', 'verified'])
            .order('created_at'),
      );

  void _refresh() {
    final next = _load();
    setState(() {
      _rows = next;
    });
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(error: snapshot.error, retry: _refresh);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: rows.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 96),
                      Center(
                        child: Text('Tidak ada laporan kehilangan menunggu.'),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Laporan kehilangan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final report in rows)
                        _LossReviewCard(report: report, changed: _refresh),
                    ],
                  ),
          );
        },
      );
}

class _LossReviewCard extends StatelessWidget {
  const _LossReviewCard({required this.report, required this.changed});
  final Map<String, dynamic> report;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final loanItem = report['loan_items'] as Map<String, dynamic>?;
    final copy = loanItem?['book_copies'] as Map<String, dynamic>?;
    final book = copy?['books'] as Map<String, dynamic>?;
    final verified = report['status'] == 'verified';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book?['title'] as String? ?? 'Buku',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Kode ${copy?['code'] ?? '—'} · ${_date(report['created_at'])}',
            ),
            Text(report['description'] as String? ?? ''),
            const SizedBox(height: 6),
            if (!verified)
              Wrap(
                children: [
                  TextButton.icon(
                    onPressed: () => _review(context, true),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Verifikasi'),
                  ),
                  TextButton.icon(
                    onPressed: () => _review(context, false),
                    icon: const Icon(Icons.close),
                    label: const Text('Tolak'),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () => _resolve(context),
                icon: const Icon(Icons.done_all),
                label: const Text('Catat penyelesaian'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context, bool verify) async {
    var reason = '';
    if (!verify) {
      final result = await showTextDialog(
        context,
        'Tolak laporan',
        'Alasan penolakan',
      );
      if (result == null) return;
      reason = result.trim();
      if (reason.isEmpty) {
        if (context.mounted) _snack(context, 'Alasan wajib diisi.');
        return;
      }
    }
    try {
      await Supabase.instance.client.rpc(
        'review_loss_report',
        params: {
          'p_report_id': report['id'],
          'p_verify': verify,
          'p_reason': verify ? null : reason,
        },
      );
      changed();
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }

  Future<void> _resolve(BuildContext context) async {
    final note = await showTextDialog(
      context,
      'Penyelesaian kehilangan',
      'Catatan penggantian atau penyelesaian',
    );
    if (note == null || note.trim().isEmpty) return;
    try {
      await Supabase.instance.client.rpc(
        'resolve_loss',
        params: {'p_report_id': report['id'], 'p_note': note.trim()},
      );
      changed();
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }
}

class _LoanReviewCard extends StatelessWidget {
  const _LoanReviewCard({required this.request, required this.changed});
  final Map<String, dynamic> request;
  final VoidCallback changed;
  @override
  Widget build(BuildContext context) {
    final evidence = request['transaction_evidence'] as Map<String, dynamic>?;
    final items = List<Map<String, dynamic>>.from(
      request['loan_request_items'] as List? ?? const [],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request['member_label'] as String? ?? 'Anggota',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${items.length} buku · ${_date(request['created_at'])}'),
            for (final item in items)
              Builder(
                builder: (context) {
                  final copy = item['book_copies'] as Map<String, dynamic>?;
                  final book = copy?['books'] as Map<String, dynamic>?;
                  return Text(
                    '• ${book?['title'] ?? 'Buku'} (${copy?['code'] ?? '—'})',
                  );
                },
              ),
            if (evidence != null)
              TextButton.icon(
                onPressed: () =>
                    _showEvidence(context, evidence['object_path'] as String),
                icon: const Icon(Icons.image_search_outlined),
                label: Text('Lihat bukti ${evidence['method'] ?? ''}'),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _decide(context, true),
                  icon: const Icon(Icons.check),
                  label: const Text('Setujui & serahkan buku'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _decide(context, false),
                  icon: const Icon(Icons.close),
                  label: const Text('Tolak'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEvidence(BuildContext context, String path) async {
    try {
      final url = await Supabase.instance.client.storage
          .from('loan-evidence')
          .createSignedUrl(path, 60);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Bukti tidak dapat dimuat.'),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }

  Future<void> _decide(BuildContext context, bool approve) async {
    var reason = '';
    if (!approve) {
      final value = await showTextDialog(
        context,
        'Alasan penolakan',
        'Tuliskan alasan',
      );
      if (value == null) return;
      reason = value.trim();
      if (reason.isEmpty) {
        if (context.mounted) _snack(context, 'Alasan wajib diisi.');
        return;
      }
    }
    try {
      await Supabase.instance.client.rpc(
        'review_loan_request',
        params: {
          'p_request_id': request['id'],
          'p_approve': approve,
          'p_reason': approve ? null : reason,
        },
      );
      changed();
    } catch (error) {
      if (context.mounted) _snack(context, _friendlyError(error));
    }
  }
}

String _date(Object? value) => formatServerDate(value);

class _BookFormValue {
  const _BookFormValue(
    this.title,
    this.author,
    this.category,
    this.isbn,
    this.description,
    this.initialStock,
    this.customQrPrefix,
    this.cover,
  );
  final String title, author, category, isbn, description;
  final int initialStock;
  final String customQrPrefix;
  final XFile? cover;
}

class _BookDialog extends StatefulWidget {
  const _BookDialog({this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<_BookDialog> createState() => _BookDialogState();
}

class _BookDialogState extends State<_BookDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.initial?['title'] as String? ?? '',
  );
  late final _author = TextEditingController(
    text: widget.initial?['author'] as String? ?? '',
  );
  final _category = TextEditingController();
  String? _categoryGroup;
  late final _isbn = TextEditingController(
    text: widget.initial?['isbn'] as String? ?? '',
  );
  late final _description = TextEditingController(
    text: widget.initial?['description'] as String? ?? '',
  );
  final _customQrPrefix = TextEditingController();
  XFile? _cover;
  final _imagePicker = ImagePicker();
  int _initialStock = 1;

  @override
  void initState() {
    super.initState();
    final initialCategory = widget.initial?['category'] as String? ?? '';
    const groups = ['Adaptif', 'Normatif', 'Produktif'];
    final group = groups.firstWhere(
      (candidate) => initialCategory.startsWith('$candidate · '),
      orElse: () => '',
    );
    if (group.isNotEmpty) {
      _categoryGroup = group;
      _category.text = initialCategory.substring(group.length + 3);
    } else if (widget.initial != null) {
      _categoryGroup = 'Kustom';
      _category.text = initialCategory;
    }
  }

  InputDecoration _fieldDecoration(
    BuildContext context,
    String label, {
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _category.dispose();
    _isbn.dispose();
    _description.dispose();
    _customQrPrefix.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image != null && mounted) setState(() => _cover = image);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Tambah buku' : 'Ubah buku'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Informasi buku',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                validator: (value) =>
                    requiredFieldValidator(value, message: 'Wajib diisi.'),
                decoration: _fieldDecoration(context, 'Judul buku'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _author,
                validator: (value) =>
                    requiredFieldValidator(value, message: 'Wajib diisi.'),
                decoration: _fieldDecoration(context, 'Penulis / pengarang'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryGroup,
                isExpanded: true,
                validator: (value) =>
                    value == null ? 'Pilih kelompok kategori.' : null,
                decoration: _fieldDecoration(context, 'Kelompok kategori'),
                items: const [
                  DropdownMenuItem(value: 'Adaptif', child: Text('Adaptif')),
                  DropdownMenuItem(value: 'Normatif', child: Text('Normatif')),
                  DropdownMenuItem(
                    value: 'Produktif',
                    child: Text('Produktif'),
                  ),
                  DropdownMenuItem(value: 'Kustom', child: Text('Kustom')),
                ],
                onChanged: (value) => setState(() => _categoryGroup = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _category,
                validator: (value) =>
                    requiredFieldValidator(value, message: 'Wajib diisi.'),
                decoration: _fieldDecoration(
                  context,
                  _categoryGroup == 'Produktif'
                      ? 'Program keahlian'
                      : _categoryGroup == 'Kustom'
                      ? 'Kategori kustom'
                      : 'Mata pelajaran / nama kategori',
                  hint: _categoryGroup == 'Produktif'
                      ? 'Contoh: TKJ'
                      : 'Isi nama mapel atau kategori',
                ),
              ),
              if (_categoryGroup == 'Produktif') ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pilihan cepat program keahlian',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final program in const ['TKJ', 'TKR', 'TPTL', 'AKT'])
                      ChoiceChip(
                        label: Text(program),
                        selected: _category.text.trim() == program,
                        onSelected: (_) => setState(() {
                          _category.text = program;
                          _category.selection = TextSelection.collapsed(
                            offset: _category.text.length,
                          );
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _isbn,
                decoration: _fieldDecoration(context, 'ISBN (opsional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 3,
                decoration: _fieldDecoration(context, 'Deskripsi (opsional)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _cover != null
                          ? Image.file(File(_cover!.path), fit: BoxFit.cover)
                          : (widget.initial?['cover_path'] as String?)
                                    ?.isNotEmpty ==
                                true
                          ? Image.network(
                              Supabase.instance.client.storage
                                  .from('book-covers')
                                  .getPublicUrl(
                                    widget.initial!['cover_path'] as String,
                                  ),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => PerpusBookCover(
                                bookId:
                                    widget.initial?['id'] as String? ??
                                    'existing-book',
                                code: _title.text.isEmpty
                                    ? 'BUKU'
                                    : _title.text.trim().toUpperCase(),
                                width: 52,
                                height: 64,
                              ),
                            )
                          : PerpusBookCover(
                              bookId:
                                  widget.initial?['id'] as String? ??
                                  'new-book',
                              code: _title.text.isEmpty
                                  ? 'BUKU'
                                  : _title.text.trim().toUpperCase(),
                              width: 52,
                              height: 64,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Logo / sampul buku'),
                        const Text(
                          'Opsional. Jika kosong, tampilan bawaan demo tetap digunakan.',
                        ),
                        TextButton.icon(
                          onPressed: _pickCover,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _cover == null ? 'Pilih gambar' : 'Ganti gambar',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.initial == null) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customQrPrefix,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 48,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Kode QR khusus (opsional)',
                    hintText: 'Contoh: BTKJ-ASJ',
                    helperText:
                        'Nomor eksemplar ditambahkan otomatis: -01, -02, ...',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Stok awal'),
                          Text('Setiap eksemplar mendapat QR unik.'),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Kurangi stok awal',
                      onPressed: _initialStock == 0
                          ? null
                          : () => setState(() => _initialStock--),
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '$_initialStock',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Tambah stok awal',
                      onPressed: _initialStock >= 100
                          ? null
                          : () => setState(() => _initialStock++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final category = _categoryGroup == 'Kustom'
              ? _category.text.trim()
              : '${_categoryGroup!} · ${_category.text.trim()}';
          Navigator.pop(
            context,
            _BookFormValue(
              _title.text.trim(),
              _author.text.trim(),
              category,
              _isbn.text.trim(),
              _description.text.trim(),
              _initialStock,
              _customQrPrefix.text.trim(),
              _cover,
            ),
          );
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _StudentFormValue {
  const _StudentFormValue(this.name, this.className, this.nis, this.nisn);
  final String name, className, nis, nisn;
}

class _StudentDialog extends StatefulWidget {
  const _StudentDialog({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?['full_name'] as String? ?? '',
  );
  late final _className = TextEditingController(
    text: widget.initial?['class_name'] as String? ?? '',
  );
  late final _nis = TextEditingController(
    text: widget.initial?['nis'] as String? ?? '',
  );
  late final _nisn = TextEditingController(
    text: widget.initial?['nisn'] as String? ?? '',
  );
  @override
  void dispose() {
    _name.dispose();
    _className.dispose();
    _nis.dispose();
    _nisn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Tambah siswa' : 'Ubah data siswa'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                validator: (value) =>
                    requiredFieldValidator(value, message: 'Wajib diisi.'),
                decoration: const InputDecoration(labelText: 'Nama lengkap'),
              ),
              TextFormField(
                controller: _className,
                validator: (value) =>
                    requiredFieldValidator(value, message: 'Wajib diisi.'),
                decoration: const InputDecoration(labelText: 'Kelas'),
              ),
              TextFormField(
                controller: _nis,
                decoration: const InputDecoration(labelText: 'NIS (opsional)'),
              ),
              TextFormField(
                controller: _nisn,
                decoration: const InputDecoration(labelText: 'NISN (opsional)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Isi minimal NIS atau NISN. Nomor disimpan sebagai teks.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          if (_nis.text.trim().isEmpty && _nisn.text.trim().isEmpty) {
            _snack(context, 'Isi minimal NIS atau NISN.');
            return;
          }
          Navigator.pop(
            context,
            _StudentFormValue(
              _name.text.trim(),
              _className.text.trim(),
              _nis.text.trim(),
              _nisn.text.trim(),
            ),
          );
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _MemberData {
  const _MemberData(this.students, this.profiles);
  final List<Map<String, dynamic>> students, profiles;
}

class _StaffReviewData {
  const _StaffReviewData(this.pending, this.staff);
  final List<Map<String, dynamic>> pending;
  final List<Map<String, dynamic>> staff;
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 8),
          const Text('Data server belum dapat dimuat.'),
          const SizedBox(height: 8),
          Text(_friendlyError(error), textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}

String _status(String value) => switch (value) {
  'pending' => 'Menunggu persetujuan',
  'available' => 'Tersedia',
  'borrowed' => 'Dipinjam',
  'damaged' => 'Rusak',
  'lost' => 'Hilang',
  _ => value,
};
String _friendlyError(Object? error) {
  final detail = error?.toString().trim() ?? '';
  final normalized = detail.toLowerCase();
  if (normalized.contains('permission denied') ||
      (normalized.contains('403') && normalized.contains('unauthorized'))) {
    return 'Bukti tidak dapat diunggah. Pastikan akun aktif dan kebijakan Storage server sudah diperbarui.';
  }
  if (error is PostgrestException) {
    if (error.code == '23505') return 'Nomor atau kode sudah digunakan.';
    if (error.code == '42501' || error.code == 'PGRST301') {
      return 'Akses ditolak. Pastikan akun aktif dan hak akses server benar.';
    }
    if (error.code == 'PGRST205' || error.code == '42P01') {
      return 'Tabel server belum tersedia atau migrasinya belum lengkap.';
    }
    return error.message;
  }
  if (normalized.contains('socketexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('handshakeexception') ||
      normalized.contains('connection refused') ||
      normalized.contains('connection reset') ||
      normalized.contains('timed out') ||
      normalized.contains('failed to fetch')) {
    return 'Server tidak dapat dijangkau. Periksa koneksi ke server perpustakaan.';
  }
  if (detail.isEmpty) return 'Operasi gagal tanpa keterangan dari server.';
  final concise = detail.length > 300 ? '${detail.substring(0, 300)}…' : detail;
  return 'Operasi gagal: $concise';
}

Future<String?> showTextDialog(
  BuildContext context,
  String title,
  String hint,
) async {
  var value = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        autofocus: true,
        onChanged: (next) => value = next,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, value),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
