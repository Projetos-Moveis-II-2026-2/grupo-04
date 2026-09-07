import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('default theme is ThemeMode.system', () {
    final container = createContainer();
    expect(container.read(themeProvider), ThemeMode.system);
  });

  test('setThemeMode persists and updates state', () async {
    final container = createContainer();
    final notifier = container.read(themeProvider.notifier);

    await notifier.setThemeMode(ThemeMode.dark);
    expect(container.read(themeProvider), ThemeMode.dark);
    expect(prefs.getString('themeMode'), 'dark');
  });

  test('toggle switches between light and dark', () async {
    final container = createContainer();
    final notifier = container.read(themeProvider.notifier);

    await notifier.setThemeMode(ThemeMode.light);
    await notifier.toggle();
    expect(container.read(themeProvider), ThemeMode.dark);

    await notifier.toggle();
    expect(container.read(themeProvider), ThemeMode.light);
  });

  test('reads persisted value on build', () async {
    await prefs.setString('themeMode', 'light');
    final container = createContainer();
    expect(container.read(themeProvider), ThemeMode.light);
  });
}
