import 'package:equatable/equatable.dart';

/// Item do catálogo de exercícios (`exercise_library`) para seleção ao montar ficha.
class CatalogExercise extends Equatable {
  const CatalogExercise({
    required this.id,
    required this.externalId,
    required this.name,
    this.primaryMuscles,
    this.secondaryMuscles,
    this.equipment,
    this.level,
    this.imageUrls,
  });

  final String id;
  final String externalId;
  final String name;
  final String? primaryMuscles;
  final String? secondaryMuscles;
  final String? equipment;
  final String? level;
  final String? imageUrls;

  List<String> get primaryMuscleList {
    if (primaryMuscles == null || primaryMuscles!.trim().isEmpty) {
      return const [];
    }
    return primaryMuscles!
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList(growable: false);
  }

  String? get firstImageUrl {
    if (imageUrls == null || imageUrls!.trim().isEmpty) return null;
    final first = imageUrls!.split(',').first.trim();
    return first.isEmpty ? null : first;
  }

  @override
  List<Object?> get props => [
    id,
    externalId,
    name,
    primaryMuscles,
    secondaryMuscles,
    equipment,
    level,
    imageUrls,
  ];
}
