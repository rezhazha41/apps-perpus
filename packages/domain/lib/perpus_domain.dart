enum CopyStatus { available, borrowed, damaged, lost }

enum RequestStatus { pending, approved, rejected, cancelled }

enum EvidenceMethod { selfie, studentCard }

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.code,
    required this.description,
  });
  final String id, title, author, category, code, description;
}

class BookCopy {
  BookCopy({
    required this.code,
    required this.bookId,
    this.status = CopyStatus.available,
  });
  final String code, bookId;
  CopyStatus status;
}

class Student {
  Student({
    required this.id,
    required this.name,
    required this.className,
    required this.nis,
    this.active = true,
  });
  final String id, name, className, nis;
  bool active;
}

class LoanItem {
  LoanItem({
    required this.id,
    required this.studentId,
    required this.copyCode,
    required this.borrowedAt,
    required this.dueAt,
  });
  final String id, studentId, copyCode;
  final DateTime borrowedAt, dueAt;
  DateTime? returnedAt;
  bool returnRequested = false;
  bool lossReported = false;
  bool lossVerified = false;
  DateTime? resolvedAt;
  bool get isOpen => returnedAt == null && resolvedAt == null;
  bool isOverdue(DateTime now) => isOpen && now.isAfter(dueAt);
}

class BorrowRequest {
  BorrowRequest({
    required this.id,
    required this.studentId,
    required List<String> copyCodes,
    required this.evidence,
    required this.createdAt,
  }) : copyCodes = List.unmodifiable(copyCodes);
  final String id, studentId;
  final List<String> copyCodes;
  final EvidenceMethod evidence;
  final DateTime createdAt;
  RequestStatus status = RequestStatus.pending;
  String? reason;
}

class LibrarySettings {
  LibrarySettings({
    this.loanDays = 7,
    this.maxBooks = 3,
    this.retentionDays = 30,
  });
  int loanDays, maxBooks, retentionDays;
}

class LibraryException implements Exception {
  const LibraryException(this.message);
  final String message;
  @override
  String toString() => message;
}

String? borrowingBlock({
  required Student student,
  required Iterable<LoanItem> loans,
  required DateTime now,
  required int requestedCount,
  required int maxBooks,
}) {
  if (!student.active)
    return 'Akun belum aktif. Hubungi pengurus perpustakaan.';
  final open = loans.where((l) => l.studentId == student.id && l.isOpen);
  if (open.any((l) => l.lossReported)) {
    return 'Selesaikan laporan kehilangan sebelum meminjam lagi.';
  }
  if (open.any((l) => l.isOverdue(now))) {
    return 'Kembalikan buku yang terlambat sebelum meminjam lagi.';
  }
  if (open.length + requestedCount > maxBooks) {
    return 'Batas $maxBooks buku aktif. Kamu masih meminjam ${open.length} buku.';
  }
  return null;
}
