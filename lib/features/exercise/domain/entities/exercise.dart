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

  /// Helper to get all trimmed non-empty image URLs from comma-separated string
  List<String> get imageUrlList {
    if (imageUrls == null || imageUrls!.isEmpty) return const [];
    return imageUrls!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// Helper to get the first image URL if available
  String? get firstImageUrl {
    final urls = imageUrlList;
    return urls.isEmpty ? null : urls.first;
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
