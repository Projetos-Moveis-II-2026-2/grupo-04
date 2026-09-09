import 'package:drift/drift.dart';

@TableIndex(
  name: 'idx_workout_sessions_user_date',
  columns: {#userId, #startedAt},
)
@DataClassName('WorkoutSession')
class WorkoutSessions extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get templateId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  RealColumn get totalVolumeKg => real().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
