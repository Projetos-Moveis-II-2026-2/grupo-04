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

  // Igualdade por valor: a renovação do JWT (`tokenRefreshed`, ~1h) entrega o
  // mesmo usuário e não deve reconstruir quem observa `currentUserProvider`.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          other.id == id &&
          other.email == email &&
          other.emailConfirmedAt == emailConfirmedAt;

  @override
  int get hashCode => Object.hash(id, email, emailConfirmedAt);
}
