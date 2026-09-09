import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/exercise.dart';

class ExerciseRemoteDataSourceFake {
  Future<List<Exercise>> fetchExercises() async {
    // Simula tempo de rede de uma API real
    await Future.delayed(const Duration(milliseconds: 500));
    final now = DateTime.now();

    try {
      // Carrega o dataset local
      final jsonString = await rootBundle.loadString('assets/data/exercises.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      return jsonList.map((json) {
        final id = json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString();
        final name = json['name'] as String? ?? 'Exercício sem nome';
        final force = json['force'] as String?;
        final level = json['level'] as String?;
        final mechanic = json['mechanic'] as String?;
        final equipment = json['equipment'] as String?;
        
        final primaryMusclesList = json['primaryMuscles'] as List<dynamic>? ?? [];
        final primaryMuscles = primaryMusclesList.join(', ');

        final secondaryMusclesList = json['secondaryMuscles'] as List<dynamic>? ?? [];
        final secondaryMuscles = secondaryMusclesList.join(', ');

        final instructionsList = json['instructions'] as List<dynamic>? ?? [];
        final instructions = instructionsList.map((e) => '• $e').join('\n');

        final category = json['category'] as String?;

        final imagesList = json['images'] as List<dynamic>? ?? [];
        final imageUrls = imagesList.map((img) => 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$img').join(',');

        return Exercise(
          id: id,
          externalId: id, // ID original do Free-Exercise-DB
          name: name,
          force: force,
          level: level,
          mechanic: mechanic,
          equipment: equipment,
          primaryMuscles: primaryMuscles,
          secondaryMuscles: secondaryMuscles,
          instructions: instructions,
          category: category,
          imageUrls: imageUrls,
          synced: true,
          updatedAt: now,
        );
      }).toList();
    } catch (e) {
      print('Erro ao carregar o JSON local: $e');
      return [];
    }
  }
}
