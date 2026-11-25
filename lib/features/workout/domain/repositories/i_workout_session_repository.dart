import 'package:olimpus/features/workout/domain/entities/workout_session_entity.dart';
import 'package:olimpus/features/workout/domain/entities/workout_template_entity.dart';

abstract interface class IWorkoutSessionRepository {
  /// Inicia uma sessão a partir de [template] para [userId], criando as
  /// séries planejadas (pré-preenchidas com a carga da última sessão).
  /// Se já houver sessão em andamento da mesma ficha, ela é retomada.
  /// Retorna o ID da sessão.
  Future<String> startSession({
    required String userId,
    required WorkoutTemplateEntity template,
  });

  /// Observa a sessão [sessionId] com exercícios, séries e o contraste
  /// com a última sessão concluída de cada exercício.
  Stream<WorkoutSessionEntity?> watchSession(String sessionId);

  /// Atualiza peso, repetições e/ou conclusão de uma série.
  Future<void> updateSet(SessionSet set);

  /// Adiciona uma série extra ao exercício [exerciseId] da sessão.
  Future<void> addSet({required String sessionId, required String exerciseId});

  /// Conclui a sessão: grava `completed_at` e o volume total, descartando
  /// séries não concluídas.
  Future<void> completeSession(String sessionId);
}
