import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Temas claro e escuro do app, gerados a partir de [AppColors.seed].
abstract final class AppTheme {
  static ThemeData get light => _from(Brightness.light);

  static ThemeData get dark => _from(Brightness.dark);

  static ThemeData _from(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.seed,
        brightness: brightness,
      ),
    );
  }
}
