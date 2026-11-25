import '../entities/water_reminder_settings.dart';

/// Contrato para persistência das preferências de lembretes de hidratação.
abstract class IWaterReminderRepository {
  /// Carrega as configurações de lembrete para o usuário informado.
  Future<WaterReminderSettings> loadSettings(String userId);

  /// Salva as configurações de lembrete para o usuário informado.
  Future<void> saveSettings(String userId, WaterReminderSettings settings);

  /// Remove as preferências de lembrete salvas para o usuário.
  Future<void> clearSettings(String userId);
}
