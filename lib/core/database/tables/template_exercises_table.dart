import 'package:drift/drift.dart';

@DataClassName('TemplateExerciseRow')
class TemplateExercises extends Table {
  TextColumn get id => text()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get templateId => text()();
  TextColumn get exerciseId => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get targetReps => integer().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
