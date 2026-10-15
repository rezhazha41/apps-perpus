import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/features/server/loan_predicates.dart';

void main() {
  group('isPendingMemberLoanRequest', () {
    test('keeps requests waiting for staff review', () {
      expect(isPendingMemberLoanRequest({'status': 'pending'}), isTrue);
    });

    test('does not show approved requests beside their recorded loans', () {
      expect(isPendingMemberLoanRequest({'status': 'approved'}), isFalse);
    });

    test('does not show rejected or cancelled requests as waiting', () {
      expect(isPendingMemberLoanRequest({'status': 'rejected'}), isFalse);
      expect(isPendingMemberLoanRequest({'status': 'cancelled'}), isFalse);
    });
  });

  group('isLoanItemOverdue', () {
    final now = DateTime(2026, 10, 1, 12);

    test('returns true for an open item with a past due date', () {
      expect(
        isLoanItemOverdue({'due_at': '2026-10-01T11:59:59'}, now: now),
        isTrue,
      );
    });

    test('returns false when the item has been returned', () {
      expect(
        isLoanItemOverdue({
          'due_at': '2026-10-01T11:59:59',
          'returned_at': '2026-10-01T11:00:00',
        }, now: now),
        isFalse,
      );
    });

    test('returns false when the item has been resolved', () {
      expect(
        isLoanItemOverdue({
          'due_at': '2026-10-01T11:59:59',
          'resolved_at': '2026-10-01T11:00:00',
        }, now: now),
        isFalse,
      );
    });

    test('returns false when due date equals now or is in the future', () {
      expect(
        isLoanItemOverdue({'due_at': '2026-10-01T12:00:00'}, now: now),
        isFalse,
      );
      expect(
        isLoanItemOverdue({'due_at': '2026-10-01T12:00:01'}, now: now),
        isFalse,
      );
    });

    test('returns false for a missing or invalid due date', () {
      expect(isLoanItemOverdue({}, now: now), isFalse);
      expect(isLoanItemOverdue({'due_at': 'not-a-date'}, now: now), isFalse);
    });
  });

  group('matchesExpectedReturnQr', () {
    test('accepts only the QR code for the returned copy', () {
      expect(matchesExpectedReturnQr(' BUA-BUL-01 ', 'BUA-BUL-01'), isTrue);
      expect(matchesExpectedReturnQr('BUA-BUL-02', 'BUA-BUL-01'), isFalse);
      expect(matchesExpectedReturnQr(null, 'BUA-BUL-01'), isFalse);
      expect(matchesExpectedReturnQr('', ''), isFalse);
    });
  });
}
