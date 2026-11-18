import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart';

typedef ActionFeedbackSettings = ({bool vibration, bool sound});

const _vibrationKey = 'action_feedback_vibration';
const _soundKey = 'action_feedback_sound';

final actionFeedbackProvider =
    NotifierProvider<ActionFeedback, ActionFeedbackSettings>(
      ActionFeedback.new,
    );

class ActionFeedback extends Notifier<ActionFeedbackSettings> {
  @override
  ActionFeedbackSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return (
      vibration: prefs.getBool(_vibrationKey) ?? true,
      sound: prefs.getBool(_soundKey) ?? false,
    );
  }

  Future<void> setVibration(bool enabled) async {
    state = (vibration: enabled, sound: state.sound);
    await ref.read(sharedPreferencesProvider).setBool(_vibrationKey, enabled);
  }

  Future<void> setSound(bool enabled) async {
    state = (vibration: state.vibration, sound: enabled);
    await ref.read(sharedPreferencesProvider).setBool(_soundKey, enabled);
  }

  Future<void> play({bool lightImpact = false}) async {
    final settings = state;
    try {
      await Future.wait([
        if (settings.vibration)
          lightImpact
              ? HapticFeedback.lightImpact()
              : HapticFeedback.mediumImpact(),
        if (settings.sound) SystemSound.play(SystemSoundType.click),
      ]);
    } on PlatformException {
      // Uma falha de feedback do dispositivo não interfere na ação concluída.
    } on MissingPluginException {
      // O canal de feedback pode estar indisponível na plataforma.
    }
  }
}
