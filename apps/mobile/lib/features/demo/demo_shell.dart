import 'package:flutter/material.dart';
import 'package:perpus_data_access/perpus_data_access.dart';
import 'package:perpus_ui_kit/perpus_ui_kit.dart';

String dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class DemoShell extends StatefulWidget {
  const DemoShell({super.key, required this.library, required this.admin});
  final DemoLibrary library;
  final bool admin;
  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  DemoLibrary get db => widget.library;
  late bool admin = widget.admin;
  int tab = 0;
  String query = '', category = 'Semua';
  final cart = <String>[];
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void act(VoidCallback action, String success) {
    try {
      action();
      setState(() {});
      message(success);
    } on LibraryException catch (e) {
      message(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = admin
        ? ['Dashboard', 'Buku', 'Aktivitas', 'Anggota']
        : ['Beranda', 'Katalog', 'Pinjaman', 'Profil'];
    final icons = admin
        ? [
            Icons.grid_view_rounded,
            Icons.auto_stories_outlined,
            Icons.swap_horiz_rounded,
            Icons.groups_outlined,
          ]
        : [
            Icons.home_outlined,
            Icons.auto_stories_outlined,
            Icons.bookmark_border_rounded,
            Icons.person_outline,
          ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'perpus.',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 27,
            letterSpacing: -1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifikasi demo',
            onPressed: notifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu aplikasi',
            onSelected: (value) {
              if (value == 'role') {
                setState(() {
                  admin = !admin;
                  tab = 0;
                });
              }
              if (value == 'settings') settings();
              if (value == 'exit') Navigator.of(context).pop();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'role',
                child: Text(
                  admin
                      ? 'Demo: lihat sebagai anggota'
                      : 'Demo: lihat sebagai admin',
                ),
              ),
              if (admin)
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Pengaturan perpustakaan'),
                ),
              const PopupMenuItem(
                value: 'exit',
                child: Text('Kembali ke halaman awal'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: PerpusColors.accent.withValues(alpha: .4),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              child: Text(
                'DEMO ${admin ? 'ADMIN' : 'ANGGOTA'} • Data fiktif, tersimpan sementara',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: switch (tab) {
                    0 => dashboard(),
                    1 => catalog(),
                    2 => transactions(),
                    _ => admin ? members() : profile(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: List.generate(
          4,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }

  Widget page(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    children: children,
  );
  Widget gap([double value = 20]) => SizedBox(height: value);
  Widget heading(String eyebrow, String title, [String? subtitle]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.6,
          color: PerpusColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
      gap(6),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      if (subtitle != null) ...[
        gap(6),
        Text(subtitle, style: const TextStyle(color: PerpusColors.muted)),
      ],
      gap(22),
    ],
  );
  Widget section(String title, {VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (onTap != null)
          TextButton(onPressed: onTap, child: const Text('Lihat semua')),
      ],
    ),
  );

  Widget dashboard() {
    final open = admin
        ? db.loans.where((l) => l.isOpen).toList()
        : db.openLoans(DemoLibrary.memberId);
    final overdue = open.where((l) => l.isOverdue(DateTime.now())).length;
    final pending = db.requests
        .where((r) => r.status == RequestStatus.pending)
        .length;
    return page([
      heading(
        admin ? 'Ruang pengurus' : 'Selamat datang kembali',
        admin ? 'Perpustakaan,\nlebih tertata.' : 'Halo, Alya 👋',
        admin
            ? 'Satu tempat untuk setiap buku dan peminjam.'
            : 'Buku berikutnya, ide berikutnya.',
      ),
      PaperCard(
        dark: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  admin ? Icons.insights_rounded : Icons.auto_stories_rounded,
                  color: PerpusColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  admin ? 'HARI INI DI PERPUS' : 'RAK BACA KAMU',
                  style: const TextStyle(
                    color: PerpusColors.accent,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            gap(18),
            Text(
              admin
                  ? '$pending pengajuan menunggu'
                  : '${open.length} buku menemani harimu',
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: PerpusColors.surface,
              ),
            ),
            gap(8),
            Text(
              admin
                  ? 'Periksa pengajuan dan pastikan buku siap diserahkan.'
                  : open.isEmpty
                  ? 'Saatnya menemukan bacaan baru di katalog.'
                  : 'Jatuh tempo terdekat: ${dateLabel((open.toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt))).first.dueAt)}',
              style: const TextStyle(color: PerpusColors.surface, height: 1.5),
            ),
            gap(20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: PerpusColors.surface,
                foregroundColor: PerpusColors.primary,
              ),
              onPressed: admin ? () => setState(() => tab = 2) : borrow,
              icon: Icon(
                admin
                    ? Icons.fact_check_outlined
                    : Icons.qr_code_scanner_rounded,
              ),
              label: Text(
                admin ? 'Periksa aktivitas' : 'Pinjam buku • simulasi scan',
              ),
            ),
          ],
        ),
      ),
      gap(),
      Row(
        children: [
          Expanded(
            child: metric(
              admin
                  ? '${db.copies.where((c) => c.status == CopyStatus.available).length}'
                  : '${open.length}',
              admin ? 'Buku tersedia' : 'Sedang dipinjam',
              Icons.menu_book_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: metric('$overdue', 'Terlambat', Icons.schedule_rounded),
          ),
        ],
      ),
      if (overdue > 0) ...[
        gap(12),
        const PaperCard(
          child: Text(
            'Ada pinjaman lewat jatuh tempo. Selesaikan pengembalian sebelum meminjam lagi.',
          ),
        ),
      ],
      section(
        admin ? 'Perlu perhatian' : 'Pilihan untuk kamu',
        onTap: () => setState(() => tab = admin ? 2 : 1),
      ),
      if (admin) ...[
        PaperCard(
          child: Column(
            children: [
              infoRow(
                Icons.pending_actions,
                'Pengajuan peminjaman',
                '$pending menunggu',
              ),
              const Divider(height: 28),
              infoRow(
                Icons.assignment_return_outlined,
                'Pengembalian',
                '${db.loans.where((l) => l.returnRequested && l.isOpen).length} menunggu',
              ),
              const Divider(height: 28),
              infoRow(
                Icons.person_add_alt,
                'Aktivasi anggota',
                '${db.students.where((s) => !s.active).length} belum aktif',
              ),
            ],
          ),
        ),
        section('Akses cepat'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: addBook,
              icon: const Icon(Icons.add),
              label: const Text('Tambah buku'),
            ),
            OutlinedButton.icon(
              onPressed: settings,
              icon: const Icon(Icons.tune),
              label: const Text('Pengaturan'),
            ),
            OutlinedButton.icon(
              onPressed: () => showInfo(
                'Laporan & arsip',
                'Ekspor PDF/CSV dan snapshot arsip belum tersedia pada fondasi demo. Fitur ini memerlukan catatan peminjaman dan pengembalian dari server.',
              ),
              icon: const Icon(Icons.folder_outlined),
              label: const Text('Laporan & arsip'),
            ),
          ],
        ),
      ] else
        ...db.books.take(3).map(bookTile),
      gap(),
      const Text(
        'Baca hari ini. Tumbuh esok hari.',
        textAlign: TextAlign.center,
        style: TextStyle(color: PerpusColors.muted, fontSize: 12),
      ),
    ]);
  }

  Widget metric(String value, String label, IconData icon) => PaperCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: PerpusColors.primary),
        gap(10),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
  Widget infoRow(IconData icon, String title, String value) => Row(
    children: [
      Icon(icon, size: 22),
      const SizedBox(width: 12),
      Expanded(child: Text(title)),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
          textAlign: TextAlign.end,
        ),
      ),
    ],
  );
  Widget cover(Book book, {double width = 62, double height = 86}) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: book.id.hashCode.isEven ? PerpusColors.primary : PerpusColors.ink,
      borderRadius: BorderRadius.circular(6),
      border: const Border(
        left: BorderSide(color: PerpusColors.accent, width: 5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(
          Icons.auto_stories_outlined,
          color: PerpusColors.accent,
          size: 16,
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              book.code,
              maxLines: 1,
              style: TextStyle(
                fontSize: width > 80 ? 32 : 20,
                color: PerpusColors.surface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Container(height: 2, width: 24, color: PerpusColors.accent),
      ],
    ),
  );
  Widget bookTile(Book book) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => bookDetails(book),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              cover(book),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: PerpusColors.muted,
                      ),
                    ),
                    gap(4),
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      book.author,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PerpusColors.muted,
                      ),
                    ),
                    gap(8),
                    Text(
                      '${db.available(book.id).length} tersedia',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PerpusColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    ),
  );

  Widget catalog() {
    final found = db.books
        .where(
          (b) =>
              (category == 'Semua' || b.category == category) &&
              '${b.title} ${b.author}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return page([
      heading(
        admin ? 'Inventaris perpustakaan' : 'Jelajahi rak',
        admin ? 'Setiap buku, tercatat.' : 'Temukan bacaanmu.',
        '${db.books.length} judul · ${db.copies.length} eksemplar',
      ),
      TextField(
        controller: search,
        onChanged: (v) => setState(() => query = v),
        decoration: const InputDecoration(
          hintText: 'Cari judul atau penulis',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      gap(14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Semua', ...db.books.map((b) => b.category).toSet()]
              .map(
                (c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: category == c,
                    onSelected: (_) => setState(() => category = c),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      gap(20),
      if (admin) ...[
        FilledButton.icon(
          onPressed: addBook,
          icon: const Icon(Icons.add),
          label: const Text('Tambah judul buku'),
        ),
        gap(20),
      ],
      if (found.isEmpty)
        const EmptyState(
          title: 'Buku belum ditemukan',
          message: 'Coba kata kunci lain atau pilih semua kategori.',
        ),
      ...found.map(bookTile),
    ]);
  }

  void bookDetails(Book book) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => StatefulBuilder(
        builder: (context, update) => Scaffold(
          appBar: AppBar(title: const Text('Detail buku')),
          body: page([
            Center(child: cover(book, width: 130, height: 178)),
            gap(24),
            Text(
              book.title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            gap(8),
            Text(book.author, textAlign: TextAlign.center),
            gap(24),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusPill(book.category, icon: Icons.category_outlined),
                  gap(16),
                  Text(book.description),
                  gap(16),
                  const Text(
                    'Sampul tipografi untuk demo; bukan sampul penerbit.',
                    style: TextStyle(fontSize: 11, color: PerpusColors.muted),
                  ),
                ],
              ),
            ),
            section('Eksemplar buku'),
            ...db.copies
                .where((c) => c.bookId == book.id)
                .map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(c.code),
                    subtitle: Text(copyStatus(c.status)),
                    trailing: admin
                        ? IconButton(
                            tooltip: 'Identitas eksemplar',
                            icon: const Icon(Icons.tag),
                            onPressed: () => showInfo(
                              c.code,
                              'Identitas unik eksemplar: ${c.code}\nQR kamera dan cetak label akan disambungkan pada tahap inventaris.',
                            ),
                          )
                        : null,
                  ),
                ),
            gap(),
            if (admin)
              FilledButton.icon(
                onPressed: () {
                  db.addCopy(book.id);
                  update(() {});
                  setState(() {});
                },
                icon: const Icon(Icons.add),
                label: const Text('Tambah eksemplar demo'),
              ),
            if (!admin)
              FilledButton.icon(
                onPressed: db.available(book.id).isEmpty
                    ? null
                    : () {
                        final code = db.available(book.id).first.code;
                        if (!cart.contains(code)) cart.add(code);
                        Navigator.of(context).pop();
                        borrow();
                      },
                icon: const Icon(Icons.add),
                label: const Text('Tambahkan ke pengajuan demo'),
              ),
          ]),
        ),
      ),
    ),
  );
  String copyStatus(CopyStatus status) => switch (status) {
    CopyStatus.available => 'Tersedia',
    CopyStatus.borrowed => 'Dipinjam',
    CopyStatus.damaged => 'Rusak',
    CopyStatus.lost => 'Hilang',
  };

  Future<void> borrow() async {
    final code = TextEditingController();
    EvidenceMethod evidence = EvidenceMethod.selfie;
    bool sampleEvidence = false;
    String? error;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => StatefulBuilder(
          builder: (context, update) => Scaffold(
            appBar: AppBar(title: const Text('Pengajuan peminjaman')),
            body: page([
              heading(
                '01 / Pilih buku',
                'Bacaan berikutnya.',
                'Simulasi scan: masukkan kode eksemplar atau pilih buku contoh.',
              ),
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Kode eksemplar',
                  hintText: 'Contoh: BK-008',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              gap(10),
              OutlinedButton.icon(
                onPressed: () {
                  try {
                    final selected = db.copy(code.text);
                    if (cart.contains(selected.code)) {
                      throw const LibraryException(
                        'Buku ini sudah ditambahkan.',
                      );
                    }
                    db.validateCart([...cart, selected.code]);
                    update(() {
                      cart.add(selected.code);
                      code.clear();
                      error = null;
                    });
                  } on LibraryException catch (e) {
                    update(() => error = e.message);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Tambahkan kode'),
              ),
              Wrap(
                spacing: 8,
                children: db.copies
                    .where(
                      (c) =>
                          c.status == CopyStatus.available &&
                          !cart.contains(c.code),
                    )
                    .take(4)
                    .map(
                      (c) => ActionChip(
                        label: Text(c.code),
                        onPressed: () => update(() {
                          cart.add(c.code);
                          error = null;
                        }),
                      ),
                    )
                    .toList(),
              ),
              if (error != null) ...[
                gap(10),
                Text(
                  error!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (cart.isEmpty)
                const EmptyState(
                  title: 'Rak pengajuan masih kosong',
                  message: 'Tambahkan buku yang ingin kamu pinjam.',
                ),
              ...cart.map(
                (c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(db.bookForCopy(c).title),
                  subtitle: Text(c),
                  trailing: IconButton(
                    tooltip: 'Hapus $c',
                    icon: const Icon(Icons.close),
                    onPressed: () => update(() => cart.remove(c)),
                  ),
                ),
              ),
              section('02 / Bukti peminjaman'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Selfie'),
                    avatar: const Icon(Icons.face_outlined, size: 18),
                    selected: evidence == EvidenceMethod.selfie,
                    onSelected: (_) => update(() {
                      evidence = EvidenceMethod.selfie;
                      sampleEvidence = false;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Kartu OSIS'),
                    avatar: const Icon(Icons.badge_outlined, size: 18),
                    selected: evidence == EvidenceMethod.studentCard,
                    onSelected: (_) => update(() {
                      evidence = EvidenceMethod.studentCard;
                      sampleEvidence = false;
                    }),
                  ),
                ],
              ),
              gap(12),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bukti simulasi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    gap(6),
                    const Text(
                      'Demo ini tidak mengambil atau menyimpan foto pribadi. Kamera dan penyimpanan privat belum terhubung.',
                    ),
                    gap(12),
                    OutlinedButton.icon(
                      onPressed: () => update(() => sampleEvidence = true),
                      icon: Icon(
                        sampleEvidence
                            ? Icons.check_circle_outline
                            : Icons.image_outlined,
                      ),
                      label: Text(
                        sampleEvidence
                            ? 'Bukti contoh siap'
                            : 'Gunakan bukti contoh',
                      ),
                    ),
                  ],
                ),
              ),
              gap(20),
              Text(
                'Batas contoh: ${db.settings.maxBooks} buku · ${db.settings.loanDays} hari setelah disetujui. Pengajuan tidak menjamin stok.',
              ),
              gap(16),
              FilledButton.icon(
                onPressed: cart.isEmpty || !sampleEvidence
                    ? null
                    : () {
                        try {
                          db.submit(List.of(cart), evidence);
                          cart.clear();
                          Navigator.of(routeContext).pop();
                          setState(() => tab = 2);
                          message(
                            'Pengajuan demo dikirim. Beralih ke admin untuk memeriksanya.',
                          );
                        } on LibraryException catch (e) {
                          update(() => error = e.message);
                        }
                      },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Kirim pengajuan demo'),
              ),
            ]),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    code.dispose();
  }

  Widget transactions() {
    final requests = db.requests
        .where((r) => admin || r.studentId == DemoLibrary.memberId)
        .toList();
    final loans = db.loans
        .where((l) => admin || l.studentId == DemoLibrary.memberId)
        .toList();
    return page([
      heading(
        admin ? 'Sirkulasi buku' : 'Rak pribadi',
        admin ? 'Aktivitas perpustakaan' : 'Pinjaman kamu',
        'Pengembalian baru selesai setelah diperiksa pengurus.',
      ),
      if (!admin)
        FilledButton.icon(
          onPressed: borrow,
          icon: const Icon(Icons.add),
          label: const Text('Pengajuan baru'),
        ),
      section('Pengajuan'),
      if (requests.isEmpty)
        const EmptyState(
          title: 'Belum ada pengajuan',
          message: 'Pengajuan baru akan muncul di sini.',
        ),
      ...requests.map(requestCard),
      section('Pinjaman aktif'),
      if (!loans.any((l) => l.isOpen))
        const EmptyState(
          title: 'Semua sudah kembali',
          message: 'Tidak ada kewajiban pinjaman aktif.',
        ),
      ...loans.where((l) => l.isOpen).map(loanCard),
      if (loans.any((l) => !l.isOpen)) ...[
        section('Riwayat selesai'),
        ...loans.where((l) => !l.isOpen).map(loanCard),
      ],
    ]);
  }

  Widget requestCard(BorrowRequest request) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${request.id} · ${db.student(request.studentId).name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          gap(6),
          ...request.copyCodes.map(
            (c) => Text('${db.bookForCopy(c).title} · $c'),
          ),
          gap(10),
          StatusPill(switch (request.status) {
            RequestStatus.pending => 'Menunggu admin',
            RequestStatus.approved => 'Disetujui',
            RequestStatus.rejected => 'Ditolak',
            RequestStatus.cancelled => 'Dibatalkan',
          }, icon: Icons.receipt_long_outlined),
          gap(8),
          Text(
            'Bukti contoh: ${request.evidence == EvidenceMethod.selfie ? 'Selfie' : 'Kartu OSIS'} · ${dateLabel(request.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (request.reason != null) Text('Alasan: ${request.reason}'),
          if (request.status == RequestStatus.pending) ...[
            gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (admin) ...[
                  FilledButton(
                    onPressed: () => act(
                      () => db.approve(request),
                      'Pengajuan disetujui. Stok dan pinjaman diperbarui.',
                    ),
                    child: const Text('Setujui demo'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final values = await form('Tolak pengajuan', [
                        'Alasan penolakan',
                      ]);
                      if (values != null && mounted) {
                        act(
                          () => db.reject(request, values[0]),
                          'Pengajuan ditolak.',
                        );
                      }
                    },
                    child: const Text('Tolak'),
                  ),
                ] else
                  OutlinedButton(
                    onPressed: () =>
                        act(() => db.cancel(request), 'Pengajuan dibatalkan.'),
                    child: const Text('Batalkan'),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
  Widget loanCard(LoanItem loan) {
    final overdue = loan.isOverdue(DateTime.now());
    final state = !loan.isOpen
        ? loan.returnedAt != null
              ? 'Dikembalikan'
              : 'Kehilangan diselesaikan'
        : loan.lossVerified
        ? 'Hilang terverifikasi'
        : loan.lossReported
        ? 'Kehilangan dilaporkan'
        : loan.returnRequested
        ? 'Menunggu penerimaan'
        : overdue
        ? 'Terlambat'
        : 'Sedang dipinjam';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PaperCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                cover(db.bookForCopy(loan.copyCode), width: 46, height: 66),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        db.bookForCopy(loan.copyCode).title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(loan.copyCode, style: const TextStyle(fontSize: 12)),
                      if (admin)
                        Text(
                          db.student(loan.studentId).name,
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            gap(14),
            StatusPill(
              state,
              icon: overdue
                  ? Icons.warning_amber_rounded
                  : Icons.bookmark_border,
            ),
            gap(10),
            Text('Jatuh tempo: ${dateLabel(loan.dueAt)}'),
            if (loan.isOpen) ...[
              gap(12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (admin) ...[
                    OutlinedButton(
                      onPressed: () => receive(loan),
                      child: const Text('Terima buku'),
                    ),
                    if (loan.lossReported && !loan.lossVerified)
                      OutlinedButton(
                        onPressed: () => act(
                          () => db.verifyLoss(loan),
                          'Kehilangan diverifikasi; kewajiban masih aktif.',
                        ),
                        child: const Text('Verifikasi hilang'),
                      ),
                    if (loan.lossVerified)
                      OutlinedButton(
                        onPressed: () async {
                          final values = await form('Selesaikan kehilangan', [
                            'Catatan penyelesaian',
                          ]);
                          if (values != null && mounted) {
                            act(
                              () => db.resolveLoss(loan, values[0]),
                              'Kewajiban selesai. Eksemplar tetap berstatus hilang.',
                            );
                          }
                        },
                        child: const Text('Selesaikan kehilangan'),
                      ),
                  ] else ...[
                    OutlinedButton(
                      onPressed: loan.returnRequested || loan.lossVerified
                          ? null
                          : () => act(
                              () => db.requestReturn(loan),
                              'Pengembalian diajukan. Serahkan buku kepada admin.',
                            ),
                      child: const Text('Ajukan kembali'),
                    ),
                    TextButton(
                      onPressed: loan.lossReported
                          ? null
                          : () async {
                              final ok = await confirm(
                                'Laporkan kehilangan?',
                                'Laporan akan ditinjau admin. Kewajiban pinjaman tetap aktif sampai diselesaikan.',
                              );
                              if (ok && mounted) {
                                act(
                                  () => db.reportLoss(loan),
                                  'Laporan kehilangan dicatat.',
                                );
                              }
                            },
                      child: const Text('Lapor hilang'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> receive(LoanItem loan) async {
    final values = await form(
      'Terima ${loan.copyCode}',
      ['Kode buku yang diterima', 'Kondisi: baik atau rusak'],
      initial: ['', 'baik'],
    );
    if (values == null || !mounted) return;
    final condition = values[1].trim().toLowerCase();
    if (!['baik', 'rusak'].contains(condition)) {
      message('Kondisi harus baik atau rusak.');
      return;
    }
    act(
      () => db.receive(loan, values[0], damaged: condition == 'rusak'),
      'Buku diterima. Pinjaman buku lain tetap aktif.',
    );
  }

  Widget members() => page([
    heading(
      'Data sekolah',
      'Anggota perpustakaan',
      'Identitas contoh untuk meninjau alur admin.',
    ),
    FilledButton.icon(
      onPressed: () async {
        final values = await form('Tambah siswa demo', [
          'Nama lengkap',
          'NIS',
          'Kelas',
        ]);
        if (values != null && mounted) {
          act(
            () => db.addStudent(values[0], values[1], values[2]),
            'Siswa ditambahkan.',
          );
        }
      },
      icon: const Icon(Icons.person_add_alt),
      label: const Text('Tambah siswa'),
    ),
    gap(),
    ...db.students.map(
      (s) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name, style: Theme.of(context).textTheme.titleLarge),
              gap(6),
              Text('NIS ${s.nis} · ${s.className}'),
              gap(10),
              StatusPill(
                s.active ? 'Akun aktif' : 'Menunggu aktivasi',
                icon: s.active
                    ? Icons.verified_user_outlined
                    : Icons.hourglass_empty,
              ),
              gap(8),
              Text('${db.openLoans(s.id).length} buku sedang dipinjam'),
              gap(8),
              ...db
                  .openLoans(s.id)
                  .map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${db.bookForCopy(l.copyCode).title} · ${l.copyCode}\nJatuh tempo ${dateLabel(l.dueAt)}${l.isOverdue(DateTime.now()) ? ' · Terlambat' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              OutlinedButton(
                onPressed: () async {
                  final ok = await confirm(
                    s.active ? 'Nonaktifkan akun demo?' : 'Aktifkan akun demo?',
                    s.active
                        ? 'Pinjaman yang ada tetap tercatat dan dapat dikembalikan.'
                        : 'Pada aplikasi nyata, admin wajib memverifikasi kepemilikan identitas terlebih dahulu.',
                  );
                  if (ok && mounted) {
                    act(
                      () => s.active = !s.active,
                      'Status akun demo diperbarui.',
                    );
                  }
                },
                child: Text(
                  s.active ? 'Nonaktifkan' : 'Verifikasi & aktifkan demo',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ]);
  Widget profile() {
    final member = db.student(DemoLibrary.memberId);
    return page([
      heading('Akun anggota', 'Profil kamu'),
      PaperCard(
        child: Column(
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: PerpusColors.accent,
              child: Text(
                'AP',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            gap(16),
            Text(member.name, style: Theme.of(context).textTheme.titleLarge),
            gap(6),
            Text('${member.className} · NIS ${member.nis}'),
            gap(12),
            StatusPill(
              member.active ? 'Anggota aktif' : 'Akun nonaktif',
              icon: Icons.verified_user_outlined,
            ),
          ],
        ),
      ),
      section('Informasi peminjaman'),
      PaperCard(
        child: Column(
          children: [
            infoRow(
              Icons.library_books_outlined,
              'Batas buku',
              '${db.settings.maxBooks} buku',
            ),
            const Divider(height: 28),
            infoRow(
              Icons.event_outlined,
              'Durasi contoh',
              '${db.settings.loanDays} hari',
            ),
          ],
        ),
      ),
      gap(),
      const PaperCard(
        child: Text(
          'Ini profil fiktif untuk demo. Pendaftaran NIS/NISN, login email, dan aktivasi admin akan dihubungkan ke Supabase.',
        ),
      ),
      gap(),
      OutlinedButton.icon(
        onPressed: () => setState(() {
          admin = true;
          tab = 0;
        }),
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Beralih ke demo admin'),
      ),
    ]);
  }

  Future<void> settings() async {
    final values = await form(
      'Pengaturan demo',
      ['Durasi pinjaman (hari)', 'Batas buku', 'Retensi: 3, 7, 30, atau 365'],
      initial: [
        '${db.settings.loanDays}',
        '${db.settings.maxBooks}',
        '${db.settings.retentionDays}',
      ],
      note: '365 mewakili pilihan 1 tahun kalender. Retensi dimulai setelah seluruh kewajiban selesai. Demo belum menyimpan foto atau menjalankan penghapusan.',
    );
    if (values == null || !mounted) return;
    final days = int.tryParse(values[0]),
        limit = int.tryParse(values[1]),
        retention = int.tryParse(values[2]);
    if (days == null ||
        days < 1 ||
        days > 365 ||
        limit == null ||
        limit < 1 ||
        limit > 50 ||
        ![3, 7, 30, 365].contains(retention)) {
      message(
        'Isi durasi 1–365 hari, batas 1–50 buku, dan pilihan retensi yang tersedia.',
      );
      return;
    }
    setState(() {
      db.settings.loanDays = days;
      db.settings.maxBooks = limit;
      db.settings.retentionDays = retention!;
    });
    message(
      'Pengaturan demo disimpan. Jatuh tempo pinjaman lama tidak berubah.',
    );
  }

  Future<void> addBook() async {
    final values = await form('Tambah judul demo', [
      'Judul',
      'Penulis',
      'Kategori',
    ]);
    if (values != null && mounted) {
      act(
        () => db.addBook(values[0], values[1], values[2]),
        'Judul dan satu eksemplar ditambahkan.',
      );
    }
  }

  void notifications() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Aktivitas demo')),
        body: page([
          const PaperCard(
            child: Text(
              'Catatan lokal untuk demo alur. Push dan pengingat terjadwal belum aktif.',
            ),
          ),
          gap(),
          ...db.activity.map(
            (text) => ListTile(
              leading: const Icon(Icons.notifications_none),
              title: Text(text),
            ),
          ),
        ]),
      ),
    ),
  );
  Future<void> showInfo(String title, String text) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      ) ??
      false;
  Future<List<String>?> form(
    String title,
    List<String> labels, {
    List<String>? initial,
    String? note,
  }) async {
    final controllers = List.generate(
      labels.length,
      (i) => TextEditingController(text: initial?[i] ?? ''),
    );
    final key = GlobalKey<FormState>();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (note != null) ...[Text(note), gap(16)],
                ...List.generate(
                  labels.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      controller: controllers[i],
                      decoration: InputDecoration(labelText: labels[i]),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                ),
              ],
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
              if (key.currentState!.validate()) {
                Navigator.pop(
                  context,
                  controllers.map((c) => c.text.trim()).toList(),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    for (final c in controllers) {
      c.dispose();
    }
    return result;
  }
}
