String? requiredFieldValidator(
  String? value, {
  String message = 'Bagian ini wajib diisi.',
}) => value == null || value.trim().isEmpty ? message : null;
