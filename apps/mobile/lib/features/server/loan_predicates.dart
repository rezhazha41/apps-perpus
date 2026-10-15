bool isLoanItemOpen(Map<String, dynamic> item) =>
    item['returned_at'] == null && item['resolved_at'] == null;

bool isPendingMemberLoanRequest(Map<String, dynamic> request) =>
    request['status'] == 'pending';

bool isLoanItemOverdue(Map<String, dynamic> item, {DateTime? now}) {
  if (!isLoanItemOpen(item)) return false;

  return DateTime.tryParse(item['due_at'] as String? ?? '')
          ?.isBefore(now ?? DateTime.now()) ==
      true;
}

bool matchesExpectedReturnQr(String? scannedCode, String? expectedCode) =>
    scannedCode?.trim() == expectedCode?.trim() &&
    (expectedCode?.trim().isNotEmpty ?? false);
