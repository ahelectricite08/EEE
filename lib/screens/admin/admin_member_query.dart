/// Recherche admin membres : nom (prénom / nom / display) **et** e-mail.
/// Un profil sans e-mail reste trouvable par le nom.
bool adminMemberMatchesQuery(
  Map<String, dynamic>? data,
  String query, {
  Iterable<String> extra = const [],
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;

  final extraHit = extra.any((e) => e.trim().toLowerCase().contains(q));
  if (data == null) return extraHit;

  final first = (data['firstName'] ?? '').toString().trim().toLowerCase();
  final last = (data['lastName'] ?? '').toString().trim().toLowerCase();
  final display = (data['displayName'] ?? data['name'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final fullName = '$first $last'.trim();
  final email = (data['email'] ?? '').toString().trim().toLowerCase();
  final emailLower = (data['emailLower'] ?? '').toString().trim().toLowerCase();

  return display.contains(q) ||
      first.contains(q) ||
      last.contains(q) ||
      fullName.contains(q) ||
      email.contains(q) ||
      emailLower.contains(q) ||
      extraHit;
}

String adminMemberDisplayName(Map<String, dynamic>? data, {String fallback = ''}) {
  if (data == null) return fallback;
  final display = (data['displayName'] ?? data['name'] ?? '').toString().trim();
  if (display.isNotEmpty) return display;
  final first = (data['firstName'] ?? '').toString().trim();
  final last = (data['lastName'] ?? '').toString().trim();
  final name = [first, last].where((s) => s.isNotEmpty).join(' ');
  if (name.isNotEmpty) return name;
  final email = (data['email'] ?? data['emailLower'] ?? '').toString().trim();
  if (email.isNotEmpty) return email;
  return fallback;
}
