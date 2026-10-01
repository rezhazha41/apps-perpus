import 'package:perpus_data_access/perpus_data_access.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 9, 28, 9);
  late DemoLibrary db;
  setUp(() => db = DemoLibrary(clock: () => now));

  test('request leaves stock untouched; approval is idempotent', () {
    final request = db.submit(['BK-008'], EvidenceMethod.selfie);
    expect(db.copy('BK-008').status, CopyStatus.available);
    db.approve(request);
    db.approve(request);
    expect(db.loans.where((l) => l.copyCode == 'BK-008'), hasLength(1));
    expect(db.copy('BK-008').status, CopyStatus.borrowed);
    expect(db.loans.last.dueAt, now.add(const Duration(days: 7)));
  });
  test('duplicate scan and unavailable copies are rejected', () {
    expect(
      () => db.submit(['BK-008', 'BK-008'], EvidenceMethod.selfie),
      throwsA(isA<LibraryException>()),
    );
    expect(
      () => db.submit(['BK-001'], EvidenceMethod.selfie),
      throwsA(isA<LibraryException>()),
    );
  });
  test('approval validates all books before any mutation', () {
    final request = db.submit(['BK-008', 'BK-009'], EvidenceMethod.studentCard);
    db.copy('BK-009').status = CopyStatus.damaged;
    expect(() => db.approve(request), throwsA(isA<LibraryException>()));
    expect(db.copy('BK-008').status, CopyStatus.available);
    expect(db.openLoans(DemoLibrary.memberId), hasLength(1));
    expect(request.status, RequestStatus.pending);
  });
  test(
    'partial return leaves other loans open and damaged book unavailable',
    () {
      db.approve(db.submit(['BK-008', 'BK-009'], EvidenceMethod.selfie));
      final loan = db.loans.firstWhere((l) => l.copyCode == 'BK-008');
      db.requestReturn(loan);
      expect(loan.isOpen, isTrue);
      expect(
        () => db.receive(loan, 'BK-009'),
        throwsA(isA<LibraryException>()),
      );
      db.receive(loan, 'BK-008', damaged: true);
      expect(db.openLoans(DemoLibrary.memberId), hasLength(2));
      expect(db.copy('BK-008').status, CopyStatus.damaged);
    },
  );
  test('inactive or over-limit member cannot submit', () {
    expect(
      () => db.submit(['BK-008', 'BK-009', 'BK-010'], EvidenceMethod.selfie),
      throwsA(isA<LibraryException>()),
    );
    db.student(DemoLibrary.memberId).active = false;
    expect(
      () => db.submit(['BK-008'], EvidenceMethod.selfie),
      throwsA(isA<LibraryException>()),
    );
  });
  test(
    'unresolved loss blocks borrowing and stays unavailable after resolution',
    () {
      final loan = db.loans.first;
      db.reportLoss(loan);
      expect(
        () => db.submit(['BK-008'], EvidenceMethod.selfie),
        throwsA(isA<LibraryException>()),
      );
      db.verifyLoss(loan);
      db.resolveLoss(loan, 'Diganti sesuai kebijakan sekolah');
      expect(loan.isOpen, isFalse);
      expect(db.copy(loan.copyCode).status, CopyStatus.lost);
      expect(
        db.submit(['BK-008'], EvidenceMethod.selfie).status,
        RequestStatus.pending,
      );
    },
  );
  test('existing deadlines survive setting changes', () {
    final due = db.loans.first.dueAt;
    db.settings.loanDays = 14;
    db.approve(db.submit(['BK-008'], EvidenceMethod.selfie));
    expect(db.loans.first.dueAt, due);
    expect(db.loans.last.dueAt, now.add(const Duration(days: 14)));
  });
  test('student leading zero preserved and duplicate NIS rejected', () {
    db.addStudent('Siswa Contoh', '00003', 'X A');
    expect(db.students.last.nis, '00003');
    expect(
      () => db.addStudent('Nama Lain', '00003', 'X B'),
      throwsA(isA<LibraryException>()),
    );
  });
  test('overdue blocks borrowing even without notifications', () {
    expect(
      borrowingBlock(
        student: db.student('S-002'),
        loans: db.loans,
        now: now,
        requestedCount: 1,
        maxBooks: 3,
      ),
      contains('terlambat'),
    );
  });
}
