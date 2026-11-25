import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/water_reminder_settings.dart';
import '../../domain/repositories/i_water_reminder_repository.dart';

/// Implementação de [IWaterReminderRepository] via [SharedPreferences] locais por usuário.
class WaterReminderRepositoryImpl implements IWaterReminderRepository {
  final SharedPreferences _prefs;

  WaterReminderRepositoryImpl(this._prefs);

  static const String _kEnabled = 'water_reminder_enabled';
  static const String _kInterval = 'water_reminder_interval';
  static const String _kStartHour = 'water_reminder_start_hour';
  static const String _kStartMinute = 'water_reminder_start_minute';
  static const String _kEndHour = 'water_reminder_end_hour';
  static const String _kEndMinute = 'water_reminder_end_minute';

  String _key(String baseKey, String userId) => '${baseKey}_$userId';

  @override
  Future<WaterReminderSettings> loadSettings(String userId) async {
    final enabled = _prefs.getBool(_key(_kEnabled, userId)) ?? false;
    final interval = _prefs.getInt(_key(_kInterval, userId)) ?? 2;
    final startHour = _prefs.getInt(_key(_kStartHour, userId)) ?? 8;
    final startMinute = _prefs.getInt(_key(_kStartMinute, userId)) ?? 0;
    final endHour = _prefs.getInt(_key(_kEndHour, userId)) ?? 22;
    final endMinute = _prefs.getInt(_key(_kEndMinute, userId)) ?? 0;

    return WaterReminderSettings(
      enabled: enabled,
      intervalHours: interval,
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
    );
  }

  @override
  Future<void> saveSettings(
    String userId,
    WaterReminderSettings settings,
  ) async {
    await _prefs.setBool(_key(_kEnabled, userId), settings.enabled);
    await _prefs.setInt(_key(_kInterval, userId), settings.intervalHours);
    await _prefs.setInt(_key(_kStartHour, userId), settings.startHour);
    await _prefs.setInt(_key(_kStartMinute, userId), settings.startMinute);
    await _prefs.setInt(_key(_kEndHour, userId), settings.endHour);
    await _prefs.setInt(_key(_kEndMinute, userId), settings.endMinute);
  }

  @override
  Future<void> clearSettings(String userId) async {
    await _prefs.remove(_key(_kEnabled, userId));
    await _prefs.remove(_key(_kInterval, userId));
    await _prefs.remove(_key(_kStartHour, userId));
    await _prefs.remove(_key(_kStartMinute, userId));
    await _prefs.remove(_key(_kEndHour, userId));
    await _prefs.remove(_key(_kEndMinute, userId));
  }
}
