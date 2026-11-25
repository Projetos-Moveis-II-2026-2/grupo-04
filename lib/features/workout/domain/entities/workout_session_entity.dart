import 'package:equatable/equatable.dart';

/// Série registrada em uma sessão de treino (`exercise_sets`).
class SessionSet extends Equatable {
  const SessionSet({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.setNumber,
    this.weightKg,
    this.reps,
    this.completed = false,
  });

  final String id;
  final String sessionId;
  final String exerciseId;
  final int setNumber;
  final double? weightKg;
  final int? reps;
  final bool completed;

  /// Volume da série (peso × repetições); 0 quando incompleta.
  double get volumeKg => (weightKg ?? 0) * (reps ?? 0);

  SessionSet copyWith({double? weightKg, int? reps, bool? completed}) {
    return SessionSet(
      id: id,
      sessionId: sessionId,
      exerciseId: exerciseId,
      setNumber: setNumber,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      completed: completed ?? this.completed,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    exerciseId,
    setNumber,
    weightKg,
    reps,
    completed,
  ];
}

/// Exercício dentro da sessão: séries atuais + séries da última sessão
/// concluída do mesmo exercício (contraste da sobrecarga progressiva).
class SessionExercise extends Equatable {
  const SessionExercise({
    required this.exerciseId,
    required this.exerciseName,
    this.imageUrl,
    this.targetReps,
    this.sets = const [],
    this.previousSets = const [],
  });

  final String exerciseId;
  final String exerciseName;
  final String? imageUrl;
  final int? targetReps;
  final List<SessionSet> sets;
  final List<SessionSet> previousSets;

  /// Série correspondente (mesmo `setNumber`) da última sessão, se houver.
  SessionSet? previousFor(int setNumber) {
    for (final s in previousSets) {
      if (s.setNumber == setNumber) return s;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    exerciseId,
    exerciseName,
    imageUrl,
    targetReps,
    sets,
    previousSets,
  ];
}

/// Sessão de execução de treino (`workout_sessions`).
class WorkoutSessionEntity extends Equatable {
  const WorkoutSessionEntity({
    required this.id,
    required this.userId,
    this.templateId,
    this.templateName,
    required this.startedAt,
    this.completedAt,
    this.totalVolumeKg,
    this.exercises = const [],
  });

  final String id;
  final String userId;
  final String? templateId;
  final String? templateName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final double? totalVolumeKg;
  final List<SessionExercise> exercises;

  bool get isCompleted => completedAt != null;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets.length);

  int get completedSets => exercises.fold(
    0,
    (sum, e) => sum + e.sets.where((s) => s.completed).length,
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    templateId,
    templateName,
    startedAt,
    completedAt,
    totalVolumeKg,
    exercises,
  ];
}
