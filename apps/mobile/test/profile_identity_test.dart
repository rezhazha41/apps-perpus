import 'package:flutter_test/flutter_test.dart';
import 'package:perpus_mobile/features/auth/profile_identity.dart';

void main() {
  group('ProfileIdentity.fromProfile', () {
    test('uses the linked student identity for member profiles', () {
      final identity = ProfileIdentity.fromProfile({
        'role': 'member',
        'claimed_student_id': 'student-1',
        'staff_id': 'staff-1',
      });

      expect(identity.isAdmin, isFalse);
      expect(identity.registryTable, 'student_registry');
      expect(identity.registryId, 'student-1');
    });

    test('uses the linked staff identity for admin profiles', () {
      final identity = ProfileIdentity.fromProfile({
        'role': 'admin',
        'claimed_student_id': 'student-1',
        'staff_id': 'staff-1',
      });

      expect(identity.isAdmin, isTrue);
      expect(identity.registryTable, 'staff_registry');
      expect(identity.registryId, 'staff-1');
    });

    test('keeps a missing member link as null', () {
      final identity = ProfileIdentity.fromProfile({'role': 'member'});

      expect(identity.registryTable, 'student_registry');
      expect(identity.registryId, isNull);
    });
  });
}
