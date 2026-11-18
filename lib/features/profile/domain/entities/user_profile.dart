enum ExperienceLevel {
  beginner('beginner', 'Iniciante'),
  intermediate('intermediate', 'Intermediário'),
  advanced('advanced', 'Avançado');

  final String value;
  final String label;

  const ExperienceLevel(this.value, this.label);

  static ExperienceLevel? fromString(String? value) {
    if (value == null) return null;
    return ExperienceLevel.values.cast<ExperienceLevel?>().firstWhere(
      (e) => e?.value == value,
      orElse: () => null,
    );
  }
}

class UserProfile {
  final String id;
  final String? displayName;
  final double? bodyWeightKg;
  final int dailyWaterGoalMl;
  final ExperienceLevel? experienceLevel;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    this.displayName,
    this.bodyWeightKg,
    this.dailyWaterGoalMl = 2000,
    this.experienceLevel,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// Considera o perfil concluído se o usuário já possui nome e peso preenchidos.
  bool get isCompleted =>
      (displayName != null && displayName!.trim().isNotEmpty) &&
      (bodyWeightKg != null && bodyWeightKg! > 0);

  UserProfile copyWith({
    String? id,
    String? displayName,
    double? bodyWeightKg,
    int? dailyWaterGoalMl,
    ExperienceLevel? experienceLevel,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
      dailyWaterGoalMl: dailyWaterGoalMl ?? this.dailyWaterGoalMl,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'body_weight_kg': bodyWeightKg,
      'daily_water_goal_ml': dailyWaterGoalMl,
      'experience_level': experienceLevel?.value,
      'avatar_url': avatarUrl,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      bodyWeightKg: (map['body_weight_kg'] as num?)?.toDouble(),
      dailyWaterGoalMl: (map['daily_water_goal_ml'] as num?)?.toInt() ?? 2000,
      experienceLevel: ExperienceLevel.fromString(
        map['experience_level'] as String?,
      ),
      avatarUrl: map['avatar_url'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          bodyWeightKg == other.bodyWeightKg &&
          dailyWaterGoalMl == other.dailyWaterGoalMl &&
          experienceLevel == other.experienceLevel &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      displayName.hashCode ^
      bodyWeightKg.hashCode ^
      dailyWaterGoalMl.hashCode ^
      experienceLevel.hashCode ^
      avatarUrl.hashCode;
}
