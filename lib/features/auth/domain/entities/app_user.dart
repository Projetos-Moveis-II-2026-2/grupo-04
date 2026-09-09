class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.emailConfirmedAt,
  });

  final String id;
  final String email;
  final DateTime? emailConfirmedAt;

  bool get isEmailConfirmed => emailConfirmedAt != null;
}
