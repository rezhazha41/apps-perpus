class ProfileIdentity {
  const ProfileIdentity({required this.isAdmin, required this.registryId});

  factory ProfileIdentity.fromProfile(Map<String, dynamic> profile) {
    final isAdmin = profile['role'] == 'admin';
    return ProfileIdentity(
      isAdmin: isAdmin,
      registryId: isAdmin
          ? profile['staff_id'] as String?
          : profile['claimed_student_id'] as String?,
    );
  }

  final bool isAdmin;
  final String? registryId;

  String get registryTable => isAdmin ? 'staff_registry' : 'student_registry';
}
