import 'package:perpus_domain/perpus_domain.dart';
export 'package:perpus_domain/perpus_domain.dart';

/// In-memory demonstration only. Never use this store for real student data.
class DemoLibrary {
  DemoLibrary({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final now = _clock();
    loans.add(
      LoanItem(
        id: 'L-001',
        studentId: 'S-001',
        copyCode: 'BK-001',
        borrowedAt: now.subtract(const Duration(days: 5)),
        dueAt: now.add(const Duration(days: 2)),
      ),
    );
    copies.first.status = CopyStatus.borrowed;
    loans.add(
      LoanItem(
        id: 'L-002',
        studentId: 'S-002',
        copyCode: 'BK-004',
        borrowedAt: now.subtract(const Duration(days: 10)),
        dueAt: now.subtract(const Duration(days: 3)),
      ),
    );
    copy('BK-004').status = CopyStatus.borrowed;
  }

  final DateTime Function() _clock;
  int _sequence = 10;
  static const memberId = 'S-001';
  final settings = LibrarySettings();
  final books = <Book>[
    const Book(
      id: 'B1',
      title: 'Laskar Pelangi',
      author: 'Andrea Hirata',
      category: 'Fiksi',
      code: 'LP',
      description:
          'Kisah persahabatan, mimpi, dan semangat belajar anak-anak Belitung.',
    ),
    const Book(
      id: 'B2',
      title: 'Bumi',
      author: 'Tere Liye',
      category: 'Fiksi',
      code: 'BU',
      description:
          'Petualangan menuju dunia yang menyimpan rahasia dan persahabatan.',
    ),
    const Book(
      id: 'B3',
      title: 'Filosofi Teras',
      author: 'Henry Manampiring',
      category: 'Pengembangan diri',
      code: 'FT',
      description: 'Mengenal filosofi Stoa dan menerapkannya dalam kehidupan sehari-hari.',
    ),
    const Book(
      id: 'B4',
      title: 'Algoritma Dasar',
      author: 'Tim Edukasi Perpus',
      category: 'Teknologi',
      code: 'AD',
      description:
          'Buku contoh untuk belajar logika, algoritma, dan dasar pemrograman.',
    ),
    const Book(
      id: 'B5',
      title: 'Jelajah Nusantara',
      author: 'Tim Edukasi Perpus',
      category: 'Pengetahuan',
      code: 'JN',
      description:
          'Buku contoh tentang bentang alam dan keragaman budaya Indonesia.',
    ),
    const Book(
      id: 'B6',
      title: 'Sains di Sekitar Kita',
      author: 'Tim Edukasi Perpus',
      category: 'Pengetahuan',
      code: 'SK',
      description:
          'Buku contoh untuk menemukan sains dalam peristiwa sederhana.',
    ),
  ];
  final copies = <BookCopy>[
    BookCopy(code: 'BK-001', bookId: 'B1'),
    BookCopy(code: 'BK-002', bookId: 'B1'),
    BookCopy(code: 'BK-003', bookId: 'B1'),
    BookCopy(code: 'BK-004', bookId: 'B2'),
    BookCopy(code: 'BK-005', bookId: 'B2'),
    BookCopy(code: 'BK-006', bookId: 'B3'),
    BookCopy(code: 'BK-007', bookId: 'B3'),
    BookCopy(code: 'BK-008', bookId: 'B4'),
    BookCopy(code: 'BK-009', bookId: 'B4'),
    BookCopy(code: 'BK-010', bookId: 'B5'),
    BookCopy(code: 'BK-011', bookId: 'B6'),
    BookCopy(code: 'BK-012', bookId: 'B6', status: CopyStatus.damaged),
  ];
  final students = <Student>[
    Student(
      id: 'S-001',
      name: 'Alya Putri',
      className: 'XI IPA 1',
      nis: '001024',
    ),
    Student(
      id: 'S-002',
      name: 'Raka Pratama',
      className: 'XI IPA 2',
      nis: '001025',
    ),
    Student(
      id: 'S-003',
      name: 'Nadia Safira',
      className: 'X IPS 1',
      nis: '001026',
      active: false,
    ),
  ];
  final requests = <BorrowRequest>[];
  final loans = <LoanItem>[];
  final activity = <String>[
    'Selamat datang di demo Perpus. Semua identitas siswa adalah fiktif.',
  ];

  BookCopy copy(String code) {
    final found = copies.where((c) => c.code == code.trim().toUpperCase());
    if (found.isEmpty)
      throw const LibraryException('Kode eksemplar tidak dikenal.');
    return found.first;
  }

  Book book(String id) => books.firstWhere((b) => b.id == id);
  Book bookForCopy(String code) => book(copy(code).bookId);
  Student student(String id) => students.firstWhere((s) => s.id == id);
  List<BookCopy> available(String bookId) => copies
      .where((c) => c.bookId == bookId && c.status == CopyStatus.available)
      .toList();
  List<LoanItem> openLoans(String studentId) =>
      loans.where((l) => l.studentId == studentId && l.isOpen).toList();

  void validateCart(Iterable<String> codes) {
    if (codes.isEmpty)
      throw const LibraryException('Tambahkan minimal satu buku.');
    if (codes.toSet().length != codes.length) {
      throw const LibraryException(
        'Eksemplar yang sama tidak boleh ditambahkan dua kali.',
      );
    }
    for (final code in codes) {
      if (copy(code).status != CopyStatus.available) {
        throw LibraryException('$code sedang tidak tersedia.');
      }
    }
  }

  BorrowRequest submit(List<String> codes, EvidenceMethod evidence) {
    validateCart(codes);
    final block = borrowingBlock(
      student: student(memberId),
      loans: loans,
      now: _clock(),
      requestedCount: codes.length,
      maxBooks: settings.maxBooks,
    );
    if (block != null) throw LibraryException(block);
    if (requests.any(
      (r) =>
          r.studentId == memberId &&
          r.status == RequestStatus.pending &&
          r.copyCodes.any(codes.contains),
    )) {
      throw const LibraryException('Buku sudah ada dalam pengajuan menunggu.');
    }
    final request = BorrowRequest(
      id: 'P-${++_sequence}',
      studentId: memberId,
      copyCodes: codes,
      evidence: evidence,
      createdAt: _clock(),
    );
    requests.insert(0, request);
    activity.insert(
      0,
      '${request.id}: pengajuan ${codes.length} buku menunggu admin.',
    );
    return request;
  }

  void approve(BorrowRequest request) {
    if (request.status == RequestStatus.approved) return;
    if (request.status != RequestStatus.pending) {
      throw const LibraryException('Pengajuan sudah diproses.');
    }
    validateCart(request.copyCodes);
    final now = _clock();
    final block = borrowingBlock(
      student: student(request.studentId),
      loans: loans,
      now: now,
      requestedCount: request.copyCodes.length,
      maxBooks: settings.maxBooks,
    );
    if (block != null) throw LibraryException(block);
    // Validate every item before changing the demo state.
    for (final code in request.copyCodes) {
      copy(code).status = CopyStatus.borrowed;
      loans.add(
        LoanItem(
          id: 'L-${++_sequence}',
          studentId: request.studentId,
          copyCode: code,
          borrowedAt: now,
          dueAt: now.add(Duration(days: settings.loanDays)),
        ),
      );
    }
    request.status = RequestStatus.approved;
    activity.insert(
      0,
      '${request.id}: disetujui. Jatuh tempo ${settings.loanDays} hari dari persetujuan.',
    );
  }

  void reject(BorrowRequest request, String reason) {
    if (request.status != RequestStatus.pending)
      throw const LibraryException('Pengajuan sudah diproses.');
    if (reason.trim().isEmpty)
      throw const LibraryException('Alasan penolakan wajib diisi.');
    request.status = RequestStatus.rejected;
    request.reason = reason.trim();
    activity.insert(0, '${request.id}: ditolak. ${request.reason}');
  }

  void cancel(BorrowRequest request) {
    if (request.status != RequestStatus.pending ||
        request.studentId != memberId) {
      throw const LibraryException('Pengajuan tidak dapat dibatalkan.');
    }
    request.status = RequestStatus.cancelled;
  }

  void requestReturn(LoanItem loan) {
    if (!loan.isOpen || loan.lossVerified)
      throw const LibraryException(
        'Buku tidak dapat diajukan untuk pengembalian.',
      );
    loan.returnRequested = true;
  }

  void receive(LoanItem loan, String scannedCode, {bool damaged = false}) {
    if (!loan.isOpen) throw const LibraryException('Pinjaman sudah selesai.');
    if (scannedCode.trim().toUpperCase() != loan.copyCode) {
      throw const LibraryException(
        'Kode tidak cocok dengan buku yang dikembalikan.',
      );
    }
    loan.returnedAt = _clock();
    loan.returnRequested = false;
    copy(loan.copyCode).status = damaged
        ? CopyStatus.damaged
        : CopyStatus.available;
    activity.insert(
      0,
      '${loan.copyCode}: pengembalian diterima${damaged ? ' dalam kondisi rusak' : ''}.',
    );
  }

  void reportLoss(LoanItem loan) {
    if (!loan.isOpen) throw const LibraryException('Pinjaman sudah selesai.');
    loan.lossReported = true;
  }

  void verifyLoss(LoanItem loan) {
    if (!loan.isOpen || !loan.lossReported)
      throw const LibraryException('Laporan tidak valid.');
    loan.lossVerified = true;
    copy(loan.copyCode).status = CopyStatus.lost;
  }

  void resolveLoss(LoanItem loan, String note) {
    if (!loan.lossVerified || !loan.isOpen || note.trim().isEmpty) {
      throw const LibraryException(
        'Verifikasi kehilangan dan isi catatan penyelesaian.',
      );
    }
    loan.resolvedAt = _clock();
    activity.insert(
      0,
      '${loan.copyCode}: kehilangan diselesaikan. ${note.trim()}',
    );
  }

  void addStudent(String name, String nis, String className) {
    if (name.trim().isEmpty || nis.trim().isEmpty || className.trim().isEmpty) {
      throw const LibraryException('Lengkapi nama, NIS, dan kelas.');
    }
    if (students.any((s) => s.nis == nis.trim()))
      throw const LibraryException('NIS sudah terdaftar.');
    students.add(
      Student(
        id: 'S-${++_sequence}',
        name: name.trim(),
        nis: nis.trim(),
        className: className.trim(),
        active: false,
      ),
    );
  }

  void addBook(String title, String author, String category) {
    if ([title, author, category].any((v) => v.trim().isEmpty)) {
      throw const LibraryException('Lengkapi judul, penulis, dan kategori.');
    }
    final id = 'B-${++_sequence}';
    books.add(
      Book(
        id: id,
        title: title.trim(),
        author: author.trim(),
        category: category.trim(),
        code: 'BK',
        description: 'Ditambahkan pada sesi demo ini.',
      ),
    );
    addCopy(id);
  }

  void addCopy(String bookId) {
    book(bookId);
    String code;
    do {
      code = 'BK-${(++_sequence).toString().padLeft(3, '0')}';
    } while (copies.any((c) => c.code == code));
    copies.add(BookCopy(code: code, bookId: bookId));
  }
}
