import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olimpus/core/database/app_database.dart';
import 'package:olimpus/core/database/providers/database_providers.dart';

void main() {
  test('appDatabaseProvider returns singleton and disposes correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final db1 = container.read(appDatabaseProvider);
    final db2 = container.read(appDatabaseProvider);

    expect(db1, same(db2));
    expect(db1, isA<AppDatabase>());
  });
}
