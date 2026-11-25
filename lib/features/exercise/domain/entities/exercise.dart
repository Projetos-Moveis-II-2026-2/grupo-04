import 'package:equatable/equatable.dart';

class Exercise extends Equatable {
  final String id;
  final String? remoteId;
  final String externalId;
  final String name;
  final String? force;
  final String? level;
  final String? mechanic;
  final String? equipment;
  final String? primaryMuscles;
  final String? secondaryMuscles;
  final String? instructions;
  final String? category;
  final String? imageUrls;
  final bool synced;
  final DateTime updatedAt;

  const Exercise({
    required this.id,
    this.remoteId,
    required this.externalId,
    required this.name,
    this.force,
    this.level,
    this.mechanic,
    this.equipment,
    this.primaryMuscles,
    this.secondaryMuscles,
    this.instructions,
    this.category,
    this.imageUrls,
    required this.synced,
    required this.updatedAt,
  });

  /// Helper to get a list of primary muscles from comma-separated string
  List<String> get primaryMuscleList {
    if (primaryMuscles == null || primaryMuscles!.isEmpty) return [];
    return primaryMuscles!.split(',').map((e) => e.trim()).toList();
  }

  /// Músculos secundários como lista (a partir da string separada por vírgula).
  List<String> get secondaryMuscleList {
    if (secondaryMuscles == null || secondaryMuscles!.trim().isEmpty) {
      return const [];
    }
    return secondaryMuscles!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// Todas as URLs de imagem do exercício, na ordem do dataset (0, 1, ...).
  List<String> get imageUrlList {
    if (imageUrls == null || imageUrls!.trim().isEmpty) return const [];
    return imageUrls!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  String? get firstImageUrl => imageUrlList.firstOrNull;

  /// Passos de instrução, um por linha, sem marcadores (`•`, `-`, `1.`).
  ///
  /// O catálogo local grava as instruções como `• passo` por linha e o
  /// catálogo remoto como texto separado por `\n`; ambos viram a mesma lista.
  List<String> get instructionSteps {
    if (instructions == null || instructions!.trim().isEmpty) return const [];
    final marker = RegExp(r'^(?:[•\-*]|\d+[.)])\s*');
    return instructions!
        .split('\n')
        .map((line) => line.trim().replaceFirst(marker, '').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  @override
  List<Object?> get props => [
    id,
    remoteId,
    externalId,
    name,
    force,
    level,
    mechanic,
    equipment,
    primaryMuscles,
    secondaryMuscles,
    instructions,
    category,
    imageUrls,
    synced,
    updatedAt,
  ];
}
