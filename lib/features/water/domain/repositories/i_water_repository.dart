import '../entities/daily_water_summary.dart';
import '../entities/water_intake_record.dart';

/// Contrato da fonte de dados de hidratação.
///
/// Serve tanto para a visualização do histórico e gráfico semanal
/// quanto como fonte reativa para a barra de hidratação da issue #25.
abstract interface class IWaterRepository {
  /// Observa todos os registros de consumo de água do dia de hoje (no fuso local),
  /// ordenados cronologicamente pelo horário do registro.
  Stream<List<WaterIntakeRecord>> watchTodayEntries(String userId);

  /// Observa a soma total (em ml) consumida no dia de hoje (no fuso local).
  Stream<int> watchTodayTotal(String userId);

  /// Observa o resumo dos últimos 7 dias (incluindo hoje) no fuso local,
  /// com preenchimento de 0 ml para os dias sem registro.
  Stream<List<DailyWaterSummary>> watchLast7DaysSummary(String userId);

  /// Registra um novo consumo de água localmente (e enfileira para sincronização).
  Future<WaterIntakeRecord> addWaterIntake({
    required String userId,
    required int amountMl,
    DateTime? recordedAt,
  });

  /// Remove um registro de água pelo seu identificador.
  Future<void> deleteWaterIntake(String id);
}

