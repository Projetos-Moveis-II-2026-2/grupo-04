import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/features/water/data/repositories/water_reminder_repository_impl.dart';
import 'package:olimpus/features/water/domain/entities/water_reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late WaterReminderRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = WaterReminderRepositoryImpl(prefs);
  });

  group('WaterReminderRepositoryImpl', () {
    const userId1 = 'user-123';
    const userId2 = 'user-456';

    test('retorna valores padrão quando não há configurações salvas', () async {
      final settings = await repository.loadSettings(userId1);

      expect(settings.enabled, isFalse);
      expect(settings.intervalHours, 2);
      expect(settings.startHour, 8);
      expect(settings.startMinute, 0);
      expect(settings.endHour, 22);
      expect(settings.endMinute, 0);
    });

    test('salva e recupera configurações para um usuário', () async {
      const customSettings = WaterReminderSettings(
        enabled: true,
        intervalHours: 3,
        startHour: 7,
        startMinute: 30,
        endHour: 23,
        endMinute: 15,
      );

      await repository.saveSettings(userId1, customSettings);
      final loaded = await repository.loadSettings(userId1);

      expect(loaded, equals(customSettings));
    });

    test('isola preferências entre usuários diferentes', () async {
      const user1Settings = WaterReminderSettings(
        enabled: true,
        intervalHours: 1,
      );
      const user2Settings = WaterReminderSettings(
        enabled: false,
        intervalHours: 3,
      );

      await repository.saveSettings(userId1, user1Settings);
      await repository.saveSettings(userId2, user2Settings);

      final loaded1 = await repository.loadSettings(userId1);
      final loaded2 = await repository.loadSettings(userId2);

      expect(loaded1.enabled, isTrue);
      expect(loaded1.intervalHours, 1);

      expect(loaded2.enabled, isFalse);
      expect(loaded2.intervalHours, 3);
    });

    test('clearSettings remove dados apenas do usuário especificado', () async {
      const user1Settings = WaterReminderSettings(enabled: true);
      const user2Settings = WaterReminderSettings(enabled: true);

      await repository.saveSettings(userId1, user1Settings);
      await repository.saveSettings(userId2, user2Settings);

      await repository.clearSettings(userId1);

      final loaded1 = await repository.loadSettings(userId1);
      final loaded2 = await repository.loadSettings(userId2);

      expect(loaded1.enabled, isFalse); // voltou ao padrão
      expect(loaded2.enabled, isTrue); // mantido
    });
  });
}
