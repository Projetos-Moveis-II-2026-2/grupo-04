import 'package:drift/drift.dart';

@TableIndex(name: 'idx_water_intake_user_date', columns: {#userId, #date})
@DataClassName('WaterIntakeEntry')
class WaterIntake extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text()();
  IntColumn get amountMl => integer()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get date => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
